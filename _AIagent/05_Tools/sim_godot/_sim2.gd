extends Node
## _sim2.gd —— 「玩到结局要几年」跑量模拟（无头批跑，跑完即删）
##
## 与 _sim.gd 的区别：那一版是固定 15 轮强制收尾，回答不了"单局多长"。
## 本版按真实结束条件跑：选定君主目标 → 资产值涨到 target → 触发 Major →
## 处置 Major → 结局。统计每局实际轮数（= 事件处理次数，每轮处置 1 张）。
##
## 策略新增 goal_greedy（模拟会看角标、专挑能推进目标的卡的玩家）：
##   选卡取 effects.full[目标值] 最大者；方案同样取该值最大者。
##
## ⚠️ 必须带 --quiet 跑：[POOL] 每轮打两次，千局量级产生 9MB 日志、慢 11 倍。
## 输出：CSV 到 outputs/，一份每局一行。

const RUNS := 500
const MAX_ROUNDS := 40          # 硬上限；到点仍未达成目标记为未达成
const BUILD_BUDGET := 2
const OUT := "C:/Users/maodr/Desktop/Herstory/outputs/sim_goal_20260910"

const STRATEGIES := ["random", "crisis_first", "first_only", "goal_greedy"]
const SEED_BASE := {"random": 0, "crisis_first": 500000, "first_only": 1000000, "goal_greedy": 1500000}
const HIDDEN_KEYS := ["civilian_support","noble_support","radiation_risk","plague_progress","agrarian_support","guild_support","fuel_reserve","wealth_gap","literacy_rate","female_literacy","legitimacy","labor_health","female_support","technology"]
const ABILITY_KEYS := ["insight", "influence", "majesty"]

var _em: EventManager
var _goals: Array = []
var _lines: Array = []


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_goals = _load_goals()
	_em = EventManager.new()
	_lines.append("run_id,strategy,goal_id,state,target,rounds,reached,major_tier,end_value,"
		+ "crisis_appeared,crisis_resolved,force_dodge,ability_points,insight,influence,majesty,"
		+ "uniq_events,total_events," + ",".join(PackedStringArray(HIDDEN_KEYS)))
	for st in STRATEGIES:
		for g in _goals:
			for i in RUNS:
				_run_one(st, g, i + 1)
	_write(OUT + ".csv", _lines)
	var f := FileAccess.open(OUT + "_meta.txt", FileAccess.WRITE)
	f.store_string("runs_per_goal=%d\nmax_rounds=%d\nbuild_budget=%d\nelapsed_ms=%d\n" % [
		RUNS, MAX_ROUNDS, BUILD_BUDGET, Time.get_ticks_msec() - t0])
	f.close()
	get_tree().quit()


func _load_goals() -> Array:
	var file := FileAccess.open("res://data/goals.json", FileAccess.READ)
	if file == null:
		push_error("_sim2: 无法读取 goals.json")
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []


func _run_one(strategy: String, goal: Dictionary, run_id: int) -> void:
	var seed_val: int = int(SEED_BASE[strategy]) + run_id * 7919
	seed(seed_val)
	GameState.rng.seed = seed_val
	GameState.reset()
	# 必须清 EventManager：cooldown / crisis_resolved / crisis_pressure 都是跨轮状态，
	# 不 reset 的话上一局的冷却会带进下一局，开局即空池（第一轮就 draw 不出卡）。
	_em.reset()
	GameState.selected_goal = goal
	GameState.selected_goal_id = str(goal.get("id", ""))
	var state_key := str(goal.get("state", ""))
	var target := int(goal.get("target", 0))

	var mods := {"insight": 0, "influence": 0, "majesty": 0}
	for _i in BUILD_BUDGET:
		mods[ABILITY_KEYS[randi() % 3]] += 1
	GameState.ability_modifiers = mods

	var uniq: Dictionary = {}
	var n_events := 0
	var c_appeared := 0
	var c_resolved := 0
	var force := 0
	var pts := 0
	var rounds := 0
	var reached := 0
	var major_tier := ""

	for r in MAX_ROUNDS:
		GameState.round_number = r + 1
		rounds += 1

		# 目标达成 → Major 单卡呈上（与 Main 的 _goal_target_reached 分支同构）
		if int(GameState.get(state_key)) >= target:
			reached = 1
			var mj: Dictionary = _em.pick_major_for_goal(GameState.selected_goal_id)
			var mplans: Array = mj.get("plans", [])
			if not mplans.is_empty():
				var mplan: Dictionary = mplans[randi() % mplans.size()]
				var mability := str(mplan.get("ability", "insight"))
				if not GameState.ability_modifiers.has(mability):
					mability = "insight"
				var mmod: int = int(GameState.ability_modifiers[mability])
				var mdice: Array = GameState.roll_2d6()
				var mres: Dictionary = Resolution.resolve(mdice, mmod, int(mj.get("difficulty", 3)))
				major_tier = str(mres["tier"])
				uniq[str(mj.get("id", ""))] = true
				n_events += 1
			break

		if GameState.radiation_risk >= 60:
			GameState.apply_effects({"plague_progress": 1})

		var draw: Array = _em.draw_two()
		if draw.is_empty():
			break
		if draw.size() == 1 and _em.crisis_ids.has(str(draw[0].get("id", ""))):
			force += 1

		var picked: Dictionary = _pick_card(draw, strategy, state_key)
		var other := _other(draw, picked)
		var plans: Array = picked.get("plans", [])
		if plans.is_empty():
			break
		var plan: Dictionary = _pick_plan(plans, strategy, state_key)

		var ability: String = str(plan.get("ability", "insight"))
		if not GameState.ability_modifiers.has(ability):
			ability = "insight"
		var modv: int = int(GameState.ability_modifiers[ability])
		var dice: Array = GameState.roll_2d6()
		var res: Dictionary = Resolution.resolve(dice, modv, int(picked.get("difficulty", 0)))

		for ev in draw:
			var did := str(ev.get("id", ""))
			uniq[did] = true
			if _em.crisis_ids.has(did):
				c_appeared += 1
		n_events += draw.size()

		var eid := str(picked.get("id", ""))
		var is_cr: bool = _em.crisis_ids.has(eid)

		GameState.apply_effects(plan.get("effects", {}).get(res["tier"], {}))
		if not other.is_empty():
			var ig: Dictionary = other.get("ignored", {})
			if not ig.is_empty():
				GameState.apply_effects(ig.get("effects", {}))
			if _em.crisis_ids.has(str(other.get("id", ""))):
				_em.escalate_crisis(str(other.get("id", "")))
		if is_cr:
			if res["tier"] != "fail":
				var up_key: String = ability if strategy != "random" else _random_upgrade_key()
				if up_key != "":
					GameState.ability_modifiers[up_key] = int(GameState.ability_modifiers[up_key]) + 1
					pts += 1
			_em.resolve_crisis(eid)
			c_resolved += 1

	var row: Array = []
	row.append(str(run_id))
	row.append(strategy)
	row.append(str(goal.get("id", "")))
	row.append(state_key)
	row.append(str(target))
	row.append(str(rounds))
	row.append(str(reached))
	row.append(major_tier)
	row.append(str(int(GameState.get(state_key))))
	row.append(str(c_appeared))
	row.append(str(c_resolved))
	row.append(str(force))
	row.append(str(pts))
	row.append(str(GameState.ability_modifiers["insight"]))
	row.append(str(GameState.ability_modifiers["influence"]))
	row.append(str(GameState.ability_modifiers["majesty"]))
	row.append(str(uniq.size()))
	row.append(str(n_events))
	for k in HIDDEN_KEYS:
		row.append(str(GameState.hidden_value(k)))
	_lines.append(",".join(PackedStringArray(row)))


func _pick_card(draw: Array, strategy: String, state_key: String) -> Dictionary:
	match strategy:
		"first_only":
			return draw[0]
		"goal_greedy":
			var best: Dictionary = {}
			var best_gain: int = -9999
			for ev in draw:
				var g := _card_gain(ev, state_key)
				if g > best_gain:
					best_gain = g
					best = ev
			if best_gain > 0:
				return best
			for ev in draw:
				if _em.crisis_ids.has(str(ev.get("id", ""))):
					return ev
			return draw[randi() % draw.size()] if best.is_empty() else best
		"crisis_first":
			for ev in draw:
				if _em.crisis_ids.has(str(ev.get("id", ""))):
					return ev
			return draw[randi() % draw.size()]
	return draw[randi() % draw.size()]


func _pick_plan(plans: Array, strategy: String, state_key: String) -> Dictionary:
	match strategy:
		"first_only":
			return plans[0]
		"goal_greedy":
			var best: Dictionary = plans[0]
			var best_gain: int = -9999
			for p in plans:
				var g: int = int(p.get("effects", {}).get("full", {}).get(state_key, 0))
				if g > best_gain:
					best_gain = g
					best = p
			return best
	return plans[randi() % plans.size()]


func _card_gain(event: Dictionary, state_key: String) -> int:
	var best: int = -9999
	for p in event.get("plans", []):
		var g: int = int(p.get("effects", {}).get("full", {}).get(state_key, 0))
		if g > best:
			best = g
	return best


func _other(draw: Array, picked: Dictionary) -> Dictionary:
	for ev in draw:
		if ev.get("id", "") != picked.get("id", ""):
			return ev
	return {}


func _random_upgrade_key() -> String:
	var pool: Array = []
	for k in ABILITY_KEYS:
		if int(GameState.ability_modifiers[k]) < GameState.ABILITY_CAP:
			pool.append(k)
	return str(pool[randi() % pool.size()]) if not pool.is_empty() else ""


func _write(path: String, lines: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("_sim2: 无法写出 " + path)
		return
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()
	print("[SIM2] 写出 %s（%d 行）" % [path, lines.size()])
