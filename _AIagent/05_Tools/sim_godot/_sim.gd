extends Node
## _sim.gd —— 无头批量模拟（跑量测试用临时脚本，跑完即删）
##
## 目的：不开编辑器、不开窗口，直接复用线上同一份纯逻辑类
##   EventManager（抽卡 / 危机权重 / 冷却 / 压力）
##   Resolution  （2d6 + 能力修正 vs 事件门槛）
##   GameState   （可见 State / 隐藏值 / 骰子 / 结算）
## 跑 N 局 × M 轮，把每轮、每局、每个危机的结果导成 CSV，交给 Python 做统计。
##
## 唯一需要手工与 Main.gd 同步的地方 = _run_one() 里那段每轮循环
## （Main.gd 的 new_round → _on_plan_chosen → _enter_round_end 的纯逻辑部分）。
## 差异点：本脚本不含 major（selected_goal 置空，不触发里程碑），跑到轮数上限结束。

const RUNS := 1000
const MAX_ROUNDS := 15
const BUILD_BUDGET := 2
const OUT := "C:/Users/maodr/Desktop/Herstory/outputs/sim_20260910"

const STRATEGIES := ["random", "crisis_first", "first_only"]
## 三种策略各用一段独立种子区间，保证同 run_id 下三种策略的局是独立可复现的
const SEED_BASE := {"random": 0, "crisis_first": 500000, "first_only": 1000000}

const HIDDEN_KEYS := [
	"civilian_support", "noble_support", "radiation_risk", "plague_progress",
	"agrarian_support", "guild_support", "fuel_reserve", "wealth_gap",
	"literacy_rate", "female_literacy", "legitimacy", "labor_health",
	"female_support", "technology",
]
const VISIBLE_KEYS := ["treasury", "gdp", "population", "military", "territory"]
const ABILITY_KEYS := ["insight", "influence", "majesty"]

var _em: EventManager
var _ev_lines: Array = []
var _run_lines: Array = []
var _cri_lines: Array = []

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_em = EventManager.new()

	_ev_lines.append("run_id,strategy,round,event_id,is_crisis,plan_id,ability,mod,d1,d2,diff,total,partial_at,full_at,tier,other_id,other_is_crisis")
	_run_lines.append("run_id,strategy,rounds,crisis_drawn,crisis_resolved,crisis_ignored,force_dodge,ability_points,insight,influence,majesty,uniq_events,total_events,"
		+ ",".join(PackedStringArray(VISIBLE_KEYS)) + "," + ",".join(PackedStringArray(HIDDEN_KEYS)))
	_cri_lines.append("run_id,strategy,crisis_id,first_trigger_round,rounds_in_pool,times_appeared,times_resolved")

	for st in STRATEGIES:
		for i in RUNS:
			_run_one(st, i + 1)
		print("[SIM] %s 完成 %d 局" % [st, RUNS])

	_write(OUT + "_events.csv", _ev_lines)
	_write(OUT + "_runs.csv", _run_lines)
	_write(OUT + "_crisis.csv", _cri_lines)
	var f := FileAccess.open(OUT + "_meta.txt", FileAccess.WRITE)
	f.store_string("runs_per_strategy=%d\nmax_rounds=%d\nbuild_budget=%d\nelapsed_ms=%d\n" % [
		RUNS, MAX_ROUNDS, BUILD_BUDGET, Time.get_ticks_msec() - t0])
	f.close()
	print("[SIM] done ms=%d" % (Time.get_ticks_msec() - t0))
	get_tree().quit()

# ================= 单局 =================

func _run_one(strategy: String, run_id: int) -> void:
	var seed_val: int = int(SEED_BASE[strategy]) + run_id * 7919
	seed(seed_val)                 # 影响 EventManager 里的 randi()
	GameState.rng.seed = seed_val  # 影响 GameState.roll_2d6()
	GameState.reset()
	GameState.selected_goal = {}          # 模拟不含 major：不触发里程碑
	GameState.selected_goal_id = ""
	_em.reset()

	# 建卡：BUILD_BUDGET 点随机分给三项（可能出现 +2 单项）
	var mods := {"insight": 0, "influence": 0, "majesty": 0}
	for _i in BUILD_BUDGET:
		mods[ABILITY_KEYS[randi() % ABILITY_KEYS.size()]] += 1
	GameState.ability_modifiers = mods

	var crisis_stat: Dictionary = {}   # id -> {first, in_pool, drawn, resolved}
	var uniq: Dictionary = {}
	var n_rounds: int = 0
	var c_drawn: int = 0
	var c_resolved: int = 0
	var c_ignored: int = 0
	var force: int = 0
	var pts: int = 0
	var n_events: int = 0

	for r in MAX_ROUNDS:
		GameState.round_number = r + 1
		n_rounds += 1

		# 世界推进：辐射风险高时自行滋生锈病（驱动 husk_blight 触发）
		if GameState.radiation_risk >= 60:
			GameState.apply_effects({"plague_progress": 1})

		# 本轮过线（进池）的危机 —— 过线不等于被抽中，两者分开记
		for ev in _em.get_crisis_pool():
			var cid := str(ev.get("id", ""))
			if not _em.trigger_met(ev.get("trigger", {})):
				continue
			if not crisis_stat.has(cid):
				crisis_stat[cid] = {"first": r + 1, "in_pool": 0, "appeared": 0, "resolved": 0}
			crisis_stat[cid]["in_pool"] += 1

		var draw: Array = _em.draw_two()
		if draw.is_empty():
			break

		# 强制独占：draw_two 在危机回避到上限时只返回一张
		if draw.size() == 1 and _em.crisis_ids.has(str(draw[0].get("id", ""))):
			force += 1

		var picked: Dictionary = _pick_card(draw, strategy)
		var other: Dictionary = _other(draw, picked)
		var plans: Array = picked.get("plans", [])
		if plans.is_empty():
			break
		var plan: Dictionary = plans[0] if strategy == "first_only" else plans[randi() % plans.size()]

		var ability: String = str(plan.get("ability", "insight"))
		if not GameState.DEFAULT_ABILITY_MOD.has(ability):
			ability = "insight"
		var modv: int = int(GameState.ability_modifiers[ability])
		var dice: Array = GameState.roll_2d6()
		var diff: int = int(picked.get("difficulty", 0))
		var res: Dictionary = Resolution.resolve(dice, modv, diff)

		# 抽卡结果两张都算「见过」：被处置的与被不作为的，覆盖统计口径一致
		for ev in draw:
			var did := str(ev.get("id", ""))
			uniq[did] = true
			if _em.crisis_ids.has(did):
				c_drawn += 1
				crisis_stat[did]["appeared"] += 1
		n_events += draw.size()

		var eid := str(picked.get("id", ""))
		var is_cr: bool = _em.crisis_ids.has(eid)
		var oid := str(other.get("id", ""))
		var other_is_cr: bool = _em.crisis_ids.has(oid) and not other.is_empty()

		# --- 结算：主动方案 + 另一张的「不作为」 ---
		GameState.apply_effects(plan.get("effects", {}).get(res["tier"], {}))
		if not other.is_empty():
			var ig: Dictionary = other.get("ignored", {})
			if not ig.is_empty():
				GameState.apply_effects(ig.get("effects", {}))
			if other_is_cr:
				c_ignored += 1
				_em.escalate_crisis(oid)

		# --- 危机：非失败 → +1 能力点；随后标记已处置 ---
		if is_cr:
			if str(res["tier"]) != "fail":
				var target: String = ability if strategy == "crisis_first" else _random_upgrade_key()
				if target != "":
					GameState.ability_modifiers[target] = int(GameState.ability_modifiers[target]) + 1
					pts += 1
			_em.resolve_crisis(eid)
			c_resolved += 1
			crisis_stat[eid]["resolved"] += 1

		_ev_lines.append("%d,%s,%d,%s,%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%s,%s,%d" % [
			run_id, strategy, r + 1, eid, 1 if is_cr else 0, str(plan.get("id", "")), ability,
			modv, int(dice[0]), int(dice[1]), diff, int(res["total"]),
			int(res["partial_at"]), int(res["full_at"]), str(res["tier"]),
			oid, 1 if other_is_cr else 0])

	# --- 本局汇总行 ---
	var row: Array = []
	row.append(str(run_id))
	row.append(strategy)
	row.append(str(n_rounds))
	row.append(str(c_drawn))
	row.append(str(c_resolved))
	row.append(str(c_ignored))
	row.append(str(force))
	row.append(str(pts))
	for k in ABILITY_KEYS:
		row.append(str(int(GameState.ability_modifiers[k])))
	row.append(str(uniq.size()))
	row.append(str(n_events))
	for k in VISIBLE_KEYS:
		row.append(str(int(GameState.get(k))))
	for k in HIDDEN_KEYS:
		row.append(str(GameState.hidden_value(k)))
	_run_lines.append(",".join(PackedStringArray(row)))

	# --- 本局每个过线危机一行 ---
	for cid in crisis_stat:
		var s: Dictionary = crisis_stat[cid]
		_cri_lines.append("%d,%s,%s,%d,%d,%d,%d" % [
			run_id, strategy, cid, int(s["first"]), int(s["in_pool"]),
			int(s["appeared"]), int(s["resolved"])])

# ================= 策略 =================

func _pick_card(draw: Array, strategy: String) -> Dictionary:
	match strategy:
		"crisis_first":
			for ev in draw:
				if _em.crisis_ids.has(str(ev.get("id", ""))):
					return ev
			return draw[randi() % draw.size()]
		"first_only":
			return draw[0]
	return draw[randi() % draw.size()]

func _other(draw: Array, picked: Dictionary) -> Dictionary:
	for ev in draw:
		if str(ev.get("id", "")) != str(picked.get("id", "")):
			return ev
	return {}

## 随机选一个还没到 ABILITY_CAP 的能力项（模拟玩家在成长页自选）；全满则返回 ""
func _random_upgrade_key() -> String:
	var candidates: Array = []
	for k in ABILITY_KEYS:
		if int(GameState.ability_modifiers[k]) < GameState.ABILITY_CAP:
			candidates.append(k)
	if candidates.is_empty():
		return ""
	return str(candidates[randi() % candidates.size()])

func _write(path: String, lines: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SIM] 无法写入 " + path)
		return
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()
	print("[SIM] 写出 %s（%d 行）" % [path, lines.size()])
