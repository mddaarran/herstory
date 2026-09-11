class_name EventManager
## EventManager：事件数据加载、统一池抽卡与阶段控制（纯逻辑，不碰 UI）
## 阶段：round（每轮从统一池抽两张）→ 处理 → round_end → 下一轮
##
## 统一池模型（主策划案 6.4 / V1.4）：
##   - 除 major 外所有事件（daily + crisis）共用一个抽取池
##   - 权重：日常 = 1（全等权）× 阶段难度加权（见 STAGE_DIFF_WEIGHT）
##   - 危机平时不参与，任一触发门槛过线后 weight = trigger_weight(=20) + 累积压力
##   - 累积压力（2026-09-10）：危机过线后每滞留一轮 +5，没有被处置就越来越逼近；
##     被"不作为"绕开一次额外 +10；权重上限 60。处置或触发条件回落才清零。
##   - 冷却：日常出场后 3 轮；危机处理完即锁定（不再进池），仅当触发条件回落又再次过线时才会重新解锁进场
##   - major：里程碑强塞占一张卡，不走池
## 数据结构：events.json 的 daily / crisis / major 三节均为数组。

const PHASE_DAILY := "daily"
const PHASE_CRISIS := "crisis"
const PHASE_MAJOR := "major"
const PHASE_ENDING := "ending"

## 测试开关：让第一轮危机事件直接进入抽卡池，并使用极高权重。
## 测试结束后将其改回 false，即恢复正式的 trigger 门槛与权重。
const TEST_FORCE_CRISIS_FIRST_ROUND := false
const TEST_CRISIS_WEIGHT := 1000

# ================= 危机强制处置（2026-09-10 加入） =================
## 危机过线后会一直留在池里，玩家每轮只要抽中它、去点另一张卡就能一直回避
## （日志里 flu_raiding 连续四年被抽中、连续四年被绕开）。
## 为避免「拖到池里只剩危机」的僵局：该危机被连续抽到却未被处置的次数达到本阈值后，
## 下一轮它独占选卡页——只呈这一张，没有可躲的另一张，必须当轮裁示。
## 阈值 3 = 连着三次抽到都躲开 → 第四次强制。
const CRISIS_FORCE_DODGE_LIMIT := 3

# ================= 危机权重按轮累计（2026-09-10） =================
## 危机过线后权重不再是固定值，而是随"滞留轮数"往上叠：
##   权重 = trigger_weight(基础 20) + 累积压力
## 累积压力每滞留一轮 +CRISIS_PRESSURE_PER_ROUND；被"不作为"绕开一次额外 +CRISIS_DODGE_PRESSURE。
## 清零条件只有两个：当轮被处置（resolve_crisis）、或触发条件回落（威胁消退）。
## 三个数是整条危机压力曲线的调参旋钮，改这里即可同时影响所有危机。
const CRISIS_PRESSURE_PER_ROUND := 5
const CRISIS_DODGE_PRESSURE := 10
const CRISIS_WEIGHT_CAP := 60

# ================= 难度与阶段（2026-09-10 简化版） =================
## 难度是事件自身的静态属性（events.json 的 difficulty），直接进骰子判定，不叠加任何阶段基准。
##   日常 daily：-3 ~ +1（五档，越负越易）
##   危机 crisis：+2 / +3
##   重大 major：+3
## 阶段只做一件事——调整「各难度档位在抽取时的权重」：早期多出简单事件、后期多出难事件。
## 47 张日常全池常驻、不按难度拆组（拆组后每组只剩十几张，玩几轮就重复）。
## 三个数（STAGE_DIFF_WEIGHT 的每行）就是整条难度曲线的调参旋钮。
##
## 阶段划分：一期 1–5、二期 6–10、三期 11 起
const STAGE_ROUND_START: Array = [1, 6, 11]

## 阶段 × 难度档位抽取权重。
## 只作用于日常；危机/重大的出现由 trigger 决定，不乘难度权重。
## 未列出的档位按默认权重 1 处理。
const STAGE_DIFF_WEIGHT: Array = [
	{-3: 4, -2: 4, -1: 3, 0: 2, 1: 1},  # 一期：偏好简单事件
	{-3: 2, -2: 2, -1: 2, 0: 2, 1: 2},  # 二期：均匀
	{-3: 1, -2: 1, -1: 2, 0: 3, 1: 4},  # 三期：偏好难事件
]

var events_data: Dictionary = {}
var phase: String = PHASE_DAILY
var crisis_handled: bool = false
var major_handled: bool = false

## 危机事件 id 集合（加载时构建，用于区分池内事件类型）
var crisis_ids: Dictionary = {}

## 重大事件 id 集合（加载时构建，供 UI 把大议卡换成亮金配色）
var major_ids: Dictionary = {}

## 抽卡结果
var current_draw: Array = []
var current_crisis: Dictionary = {}
var current_major: Dictionary = {}

## event_id -> 冷却到第几轮（含）才可再次出现
var cooldown_until: Dictionary = {}

## event_id -> 该危机累积的压力值（每滞留一轮 +5，被绕开 +10；处置或条件回落清零）
var crisis_pressure: Dictionary = {}
var crisis_resolved: Dictionary = {}
## 已在 console 提示过的危机，避免每次抽池检查重复刷屏。
var crisis_announced: Dictionary = {}

## event_id -> 连续被抽到却未被处置的次数（选中处置后清零）。
## 达到 CRISIS_FORCE_DODGE_LIMIT 后，该危机下一轮强制独占选卡页。
var crisis_dodge_streak: Dictionary = {}

func _init() -> void:
	load_data()

# ================= 数据读取 =================

func load_data() -> void:
	var path := "res://data/events.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("EventManager: 无法读取 %s，错误码 %d" % [path, FileAccess.get_open_error()])
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("EventManager: events.json 解析失败")
		return
	events_data = parsed
	var major_file := FileAccess.open("res://data/major_events.json", FileAccess.READ)
	if major_file != null:
		var major_parsed = JSON.parse_string(major_file.get_as_text())
		if major_parsed is Dictionary:
			events_data["major"] = major_parsed.get("events", [])
	crisis_ids.clear()
	for ev in events_data.get("crisis", []):
		crisis_ids[str(ev.get("id", ""))] = true
	major_ids.clear()
	for ev in events_data.get("major", []):
		major_ids[str(ev.get("id", ""))] = true

func get_daily_pool() -> Array:
	return events_data.get("daily", [])

func get_crisis_pool() -> Array:
	return events_data.get("crisis", [])

func get_major_pool() -> Array:
	return events_data.get("major", [])

## 危机当前权重（按轮累计）：过线后 = trigger_weight(默认20) + 累积压力，封顶 CRISIS_WEIGHT_CAP(60)
## 权重随滞留轮数上升——拖得越久越逼近；被"不作为"绕开另加 CRISIS_DODGE_PRESSURE。
## 触发条件回落（威胁消退）时压力清零，下次再触发重新从基础值起算。
func _crisis_weight(ev: Dictionary) -> int:
	var event_id := str(ev.get("id", ""))
	if bool(crisis_resolved.get(event_id, false)):
		if not trigger_met(ev.get("trigger", {})):
			crisis_resolved.erase(event_id)
			crisis_pressure.erase(event_id)
		else:
			return 0
	if TEST_FORCE_CRISIS_FIRST_ROUND and GameState.round_number == 1:
		return TEST_CRISIS_WEIGHT
	if not trigger_met(ev.get("trigger", {})):
		crisis_pressure.erase(event_id)
		return 0
	var base := int(ev.get("trigger_weight", 20))
	var w := base + int(crisis_pressure.get(event_id, 0))
	return mini(w, CRISIS_WEIGHT_CAP)

## 每轮抽卡结束后调用：仍在池中、尚未处置的危机压力 +CRISIS_PRESSURE_PER_ROUND。
## 语义是"这一年又没解决它，下一年它更近了"。已处置或条件回落的危机不累积。
func _accrue_crisis_pressure() -> void:
	for ev in get_crisis_pool():
		var eid := str(ev.get("id", ""))
		if bool(crisis_resolved.get(eid, false)):
			continue
		if not trigger_met(ev.get("trigger", {})):
			continue
		crisis_pressure[eid] = int(crisis_pressure.get(eid, 0)) + CRISIS_PRESSURE_PER_ROUND

## 某事件当前有效权重（未冷却才调用）
## 危机：平时不参与（权重 0）；过线 → 基础 20 起、按滞留轮数累计至上限 60
## 日常：weight 字段（全等权 = 1）× 阶段难度加权
## 仅日常乘「阶段难度加权」——只调出现概率、不拆池，避免后期重复；
## 危机不乘（危机的出现由 trigger 决定，不需要靠难度倾斜）
func _event_weight(ev: Dictionary) -> int:
	if crisis_ids.has(str(ev.get("id", ""))):
		return _crisis_weight(ev)
	var d: int = int(ev.get("difficulty", 0))
	var w: int = diff_weight(d)
	return maxi(int(ev.get("weight", 1)), 1) * w

# ================= 阶段与难度加权 =================

## 当前阶段索引（0=一期 / 1=二期 / 2=三期），由轮次决定
func current_stage() -> int:
	var r: int = GameState.round_number
	var s: int = 0
	for i in STAGE_ROUND_START.size():
		if r >= int(STAGE_ROUND_START[i]):
			s = i
	return s

## 阶段内按难度值加权：早期偏好简单、后期偏好难；未配置的难度值默认 1
func diff_weight(difficulty: int) -> int:
	var w: Dictionary = STAGE_DIFF_WEIGHT[current_stage()]
	return int(w.get(difficulty, 1))

# ================= 统一池抽卡 =================

## 统一池 = 未冷却的日常(weight=1×阶段难度权) + 已过线且未冷却的危机(20 起、按轮累计至 60)
## 每轮抽两张（当轮不重复），major 由外部里程碑强塞（pick_major 单独处理）
## 例外：被连续回避到上限的危机强制独占（见 _forced_crisis），此时只出这一张。
func draw_two() -> Array:
	var forced: Dictionary = _forced_crisis()
	if not forced.is_empty():
		var forced_id := str(forced.get("id", ""))
		_mark_drawn(forced)
		crisis_dodge_streak.erase(forced_id)
		current_draw = [forced]
		print("[DRAW] 第%d年 | 危机无可回避，独占呈上：%s" % [GameState.round_number, forced_id])
		_accrue_crisis_pressure()
		return current_draw

	var pool: Array = _build_pool()
	_print_pool(pool)
	if pool.is_empty():
		current_draw = []
		return current_draw

	var bag: Array = pool.duplicate()
	var picked: Array = []
	for _i in range(mini(2, bag.size())):
		var ev: Dictionary = _weighted_pick(bag)
		picked.append(ev)
		bag.erase(ev)
		_mark_drawn(ev)

	# 累计「被抽到却没被处置」的危机次数：抽出来只算一次，玩家选了它会在 resolve_crisis 里清零
	for ev in picked:
		var eid := str(ev.get("id", ""))
		if crisis_ids.has(eid):
			crisis_dodge_streak[eid] = int(crisis_dodge_streak.get(eid, 0)) + 1

	current_draw = picked
	# 本轮结束仍未处置的危机累积压力（下轮权重更高）；当轮被处置者会在 resolve_crisis 清零
	_accrue_crisis_pressure()
	return current_draw

## 是否已有危机被回避到上限（取次数最高者）。返回空字典表示无需强制。
## 只在危机仍过线时才强制：触发条件已回落说明威胁消退，不再逼玩家处置。
func _forced_crisis() -> Dictionary:
	var target: Dictionary = {}
	var target_streak: int = 0
	for ev in get_crisis_pool():
		var streak: int = int(crisis_dodge_streak.get(str(ev.get("id", "")), 0))
		if streak < CRISIS_FORCE_DODGE_LIMIT or streak <= target_streak:
			continue
		if _crisis_weight(ev) <= 0:
			continue
		target = ev
		target_streak = streak
	return target

func _build_pool() -> Array:
	var pool: Array = []
	for ev in get_daily_pool():
		if _off_cooldown(ev) and _event_weight(ev) > 0:
			pool.append(ev)
	for ev in get_crisis_pool():
		_announce_crisis_trigger(ev)
		if _off_cooldown(ev) and _crisis_weight(ev) > 0:
			pool.append(ev)
	return pool

## 每轮把当前抽取池打到 console：只打 id + 权重，不带标题文案。
## 危机与日常分开两行——危机权重 20/25 与日常 1 差一个量级，混排看不出结构。
func _print_pool(pool: Array) -> void:
	var daily_parts: Array = []
	var crisis_parts: Array = []
	var total: int = 0
	for ev in pool:
		var event_id := str(ev.get("id", ""))
		var w: int = _event_weight(ev)
		total += w
		var entry := "%s:%d" % [event_id, w]
		if crisis_ids.has(event_id):
			crisis_parts.append(entry)
		else:
			daily_parts.append(entry)
	print("[POOL] 第%d年 | 阶段%d size=%d daily=%d crisis=%d total_weight=%d" % [
		GameState.round_number, current_stage() + 1,
		pool.size(), daily_parts.size(), crisis_parts.size(), total])
	if not crisis_parts.is_empty():
		print("[POOL] crisis: %s" % " ".join(crisis_parts))
	print("[POOL] daily: %s" % " ".join(daily_parts))

func _announce_crisis_trigger(ev: Dictionary) -> void:
	var event_id := str(ev.get("id", ""))
	if event_id == "" or crisis_announced.has(event_id):
		return
	var trigger: Dictionary = ev.get("trigger", {})
	var conditions: Array = trigger.get("conditions", [])
	for condition in conditions:
		if _cond_met(condition):
			var stat := str(condition.get("stat", ""))
			var current := _read_trigger_stat(stat)
			var threshold := ""
			if condition.has("min"):
				threshold = ">= %d" % int(condition["min"])
			elif condition.has("max"):
				threshold = "<= %d" % int(condition["max"])
			print("[CRISIS TRIGGER] %s triggered: %s=%d %s" % [event_id, stat, current, threshold])
			crisis_announced[event_id] = true
			return

func _read_trigger_stat(stat: String) -> int:
	if stat in ["treasury", "population", "gdp", "military", "territory"]:
		return int(GameState.get(stat))
	return GameState.hidden_value(stat)

func _mark_drawn(ev: Dictionary) -> void:
	var cd: int = int(ev.get("cooldown", 3))
	cooldown_until[str(ev.get("id", ""))] = GameState.round_number + cd

func _off_cooldown(ev: Dictionary) -> bool:
	var until: int = int(cooldown_until.get(str(ev.get("id", "")), -1))
	return GameState.round_number >= until

func _weighted_pick(bag: Array) -> Dictionary:
	var total_w: int = 0
	for ev in bag:
		total_w += _event_weight(ev)
	var roll: int = randi() % maxi(total_w, 1)
	var acc: int = 0
	for ev in bag:
		acc += _event_weight(ev)
		if roll < acc:
			return ev
	return bag[bag.size() - 1]

## 危机被"不作为"后调用：额外加压 CRISIS_DODGE_PRESSURE（玩家看见了却绕开，比单纯滞留更严重）
## 同时清掉它的冷却——被忽略的危机不该继续冷却，而应尽快卷土重来
func escalate_crisis(event_id: String) -> void:
	crisis_pressure[event_id] = int(crisis_pressure.get(event_id, 0)) + CRISIS_DODGE_PRESSURE
	cooldown_until.erase(event_id)

func resolve_crisis(event_id: String) -> void:
	crisis_resolved[event_id] = true
	cooldown_until.erase(event_id)
	# 已当轮处置 → 压力与回避计数一并清零，之后再触发是新一轮账
	crisis_pressure.erase(event_id)
	crisis_dodge_streak.erase(event_id)

# ================= 触发条件 =================

## 评估事件的 trigger 块
## type=any  → 任一条件满足即成立（门槛二选一）
## type=all  → 全部条件满足才成立
## type=milestone → 不由本函数判定，永远返回 false（交给外部流程）
## trigger 为空 → 视为无条件成立
func trigger_met(trigger: Dictionary) -> bool:
	if trigger.is_empty():
		return true
	if str(trigger.get("type", "")) == "milestone":
		return false
	var conds: Array = trigger.get("conditions", [])
	if conds.is_empty():
		return true
	var any_mode: bool = str(trigger.get("type", "any")) != "all"
	var hits: int = 0
	for c in conds:
		if _cond_met(c):
			hits += 1
	return hits > 0 if any_mode else hits == conds.size()

func _cond_met(c) -> bool:
	var stat: String = str(c.get("stat", ""))
	# 可见 State（treasury/population/gdp/military/territory）直接读属性；
	# 隐藏 State 走 hidden_value（未登记时返回 0 会导致条件误判，需先查表）
	var v: int
	if stat in ["treasury", "population", "gdp", "military", "territory"]:
		v = int(GameState.get(stat))
	else:
		v = GameState.hidden_value(stat)
	if c.has("min") and v < int(c["min"]):
		return false
	if c.has("max") and v > int(c["max"]):
		return false
	return true

# ================= 阶段推进（demo 简化：由 Main 调用） =================

## 兼容旧接口：返回是否有危机过线（Main 决定是否走危机独立页）
func any_crisis_ready() -> bool:
	for ev in get_crisis_pool():
		if _crisis_weight(ev) > 0:
			return true
	return false

## 取池内第一个过线危机（供危机独立页 / 直接展示用）
func pick_crisis() -> Dictionary:
	for ev in get_crisis_pool():
		if _crisis_weight(ev) > 0:
			current_crisis = ev
			return current_crisis
	current_crisis = {}
	return current_crisis

## 重大事件：取池内第一张（milestone 类型由外部流程决定是否出现）
func pick_major() -> Dictionary:
	var pool: Array = get_major_pool()
	current_major = pool[0] if not pool.is_empty() else {}
	return current_major

func pick_major_for_goal(goal_id: String) -> Dictionary:
	for ev in get_major_pool():
		if str(ev.get("goal_id", "")) == goal_id:
			current_major = ev
			return current_major
	return pick_major()

func reset() -> void:
	phase = PHASE_DAILY
	crisis_handled = false
	major_handled = false
	current_draw = []
	current_crisis = {}
	current_major = {}
	cooldown_until = {}
	crisis_pressure = {}
	crisis_resolved = {}
	crisis_announced = {}
	crisis_dodge_streak = {}
