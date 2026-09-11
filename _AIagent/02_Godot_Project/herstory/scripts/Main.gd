extends Control
## Main：状态机 + 调度器（场景版）
##
## 状态：title / gallery / goal_select / character_build / prophecy / enthronement / select_event / select_plan / dice / round_end / ending
##
## 说明：所有页面脚本不声明 class_name，Main 通过 preload 场景 + 动态分派调用，
##       避免依赖 Godot 全局类缓存（外部新增脚本时缓存可能过期导致 Parse Error）。

const ABILITY_NAMES := {
	"insight": "洞察",
	"influence": "驭人",
	"majesty": "威仪",
}
## 能力 key 的显示顺序（侧栏与 UI 通用）
const ABILITY_ORDER := ["insight", "influence", "majesty"]
const TIER_COLORS := {
	"full": "#6fbf8b",
	"partial": "#ffb648",
	"fail": "#d4553a",
}
const Palette := preload("res://scripts/ui/Palette.gd")

## 史官汇总页第二行展示的 support 类隐藏值（区间文案）。
## 按主策要求：只列 support 家族，且不含 female_support（女子支持率另作处理）。
const SUMMARY_SUPPORT_KEYS := ["civilian_support", "noble_support", "agrarian_support", "guild_support"]

var em: EventManager
var chronicler := Chronicler.new()

# 阶段
var phase_step: String = "title"

# 流程数据
var current_draw: Array = []
var current_selected_event: Dictionary = {}
var current_ignored_event: Dictionary = {}
var current_selected_plan: Dictionary = {}
var current_res: Dictionary = {}
var current_ability_key: String = "insight"
var current_modifier: int = 0
var pending_effects: Dictionary = {}
var round_start_values: Dictionary = {}
## 成长页待办标记：仅取 "" / "pending" 两个值（"pending" = 危机判定非失败，
## 本轮结算后弹能力成长页）。它不存能力 key——加到哪一项由玩家在成长页自选。
var pending_crisis_growth_ability: String = ""

# UI 节点（页面脚本无 class_name，节点引用不写具体类型，避免类缓存依赖）
@onready var title_slot: Control = $Margin/TitleSlot
@onready var game_slot: VBoxContainer = $Margin/GameSlot
@onready var ending_slot: Control = $Margin/EndingSlot
@onready var header_label: Label = $Margin/GameSlot/Header
@onready var sidebar = $Margin/GameSlot/Row/Sidebar
@onready var page_holder: MarginContainer = $Margin/GameSlot/Row/PageHolder

# 预加载页面场景
const TitlePageScene := preload("res://scenes/ui/TitlePage.tscn")
const EventSelectPageScene := preload("res://scenes/ui/EventSelectPage.tscn")
const PlanSelectPageScene := preload("res://scenes/ui/PlanSelectPage.tscn")
const DicePageScene := preload("res://scenes/ui/DicePage.tscn")
const RoundEndPageScene := preload("res://scenes/ui/RoundEndPage.tscn")
const EndingPageScene := preload("res://scenes/ui/EndingPage.tscn")
const CharacterBuildPageScene := preload("res://scenes/ui/CharacterBuildPage.tscn")
const EnthronementPageScene := preload("res://scenes/ui/EnthronementPage.tscn")
const ProphecyPageScene := preload("res://scenes/ui/ProphecyPage.tscn")
const GoalSelectPageScene := preload("res://scenes/ui/GoalSelectPage.tscn")
const GalleryPageScene := preload("res://scenes/ui/GalleryPage.tscn")

func _ready() -> void:
	em = EventManager.new()
	_show_title()

# ================= 阶段切换 =================

func _show_title() -> void:
	phase_step = "title"
	var page = _swap_page(title_slot, TitlePageScene)
	page.start_pressed.connect(_on_start_pressed)
	page.gallery_pressed.connect(_show_gallery)
	page.quit_pressed.connect(func(): get_tree().quit())
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

## 图鉴：当前为空白占位页，仅提供返回主菜单
func _show_gallery() -> void:
	phase_step = "gallery"
	var page = _swap_page(title_slot, GalleryPageScene)
	page.back_pressed.connect(_show_title)
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

func _show_ending() -> void:
	phase_step = "ending"
	var verdict: String = chronicler.judge_verdict()
	var ending_name: String = str(Chronicler.VERDICT_NAMES[verdict])
	var ending_text: String = str(Chronicler.VERDICT_TEXTS[verdict])
	if not current_selected_event.is_empty() and not current_selected_plan.is_empty():
		ending_name = chronicler.base_title_for_goal(GameState.selected_goal)
		ending_text = chronicler.major_ending_text(current_selected_event, current_selected_plan, str(current_res.get("tier", "fail")), ending_name)
	var page = _swap_page(ending_slot, EndingPageScene)
	page.setup(
		ending_name,
		ending_text,
		_state_summary())
	page.restart_pressed.connect(_on_restart_pressed)
	title_slot.visible = false
	game_slot.visible = false
	ending_slot.visible = true

func _on_start_pressed() -> void:
	GameState.reset()
	em.reset()
	_show_goal_select()

func _show_goal_select() -> void:
	phase_step = "goal_select"
	var page = _swap_page(title_slot, GoalSelectPageScene)
	page.goal_confirmed.connect(_on_goal_confirmed)
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

func _on_goal_confirmed(_goal: Dictionary) -> void:
	_show_character_build()

func _show_character_build() -> void:
	phase_step = "character_build"
	var page = _swap_page(title_slot, CharacterBuildPageScene)
	page.setup(GameState.ability_modifiers)
	page.build_confirmed.connect(_on_build_confirmed)
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

func _on_build_confirmed(modifiers: Dictionary) -> void:
	GameState.ability_modifiers = modifiers.duplicate()
	_show_prophecy()

## 建卡完成后的独立预言页：逐行展现全局唯一预言（GameState.prophecy_text）
func _show_prophecy() -> void:
	phase_step = "prophecy"
	var page = _swap_page(title_slot, ProphecyPageScene)
	page.confirmed.connect(_on_prophecy_confirmed)
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

func _on_prophecy_confirmed() -> void:
	_show_enthronement()

func _show_enthronement() -> void:
	phase_step = "enthronement"
	var page = _swap_page(title_slot, EnthronementPageScene)
	page.confirmed.connect(_on_enthronement_confirmed)
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

func _on_enthronement_confirmed() -> void:
	title_slot.visible = false
	game_slot.visible = true
	ending_slot.visible = false
	new_round()

func _on_restart_pressed() -> void:
	_show_title()

# ================= 每轮流程 =================

## 测试开关：第一轮直接进入 major 事件；测试结束后改回 false。
const TEST_FORCE_MAJOR_FIRST_ROUND := false
const TEST_FORCE_SELECTED_GOAL_TARGET := false

func new_round() -> void:
	sidebar.refresh()
	_debug_print_hidden("轮首")
	_debug_print_state("轮首")

	# 重大事件已处理完 → 收尾
	if em.major_handled:
		_show_ending()
		return

	if TEST_FORCE_SELECTED_GOAL_TARGET and GameState.round_number == 1 and not GameState.selected_goal.is_empty():
		var goal_state := str(GameState.selected_goal.get("state", ""))
		var goal_target := int(GameState.selected_goal.get("target", 0))
		if goal_state in ["treasury", "population", "gdp", "military", "territory"]:
			GameState.set(goal_state, goal_target)
			# 测试值写入后再刷新侧栏，确保看到目标值而非初始值。
			sidebar.refresh()

	# 所选君主目标达成 → 强制触发对应的唯一 Major 事件
	# 仍走同一套选卡流程（单卡呈上），不直接跳方案页：玩家要先看到这份文书本身
	if _goal_target_reached():
		current_selected_event = em.pick_major_for_goal(str(GameState.selected_goal_id))
		current_ignored_event = {}
		# 同步抽取结果，否则 _find_other 会把上一轮的卡误当成本轮「被不作为」的另一张
		em.current_draw = [current_selected_event]
		header_label.text = "第 %d 年 · 大议 —— %s" % [GameState.round_number, current_selected_event.get("title", "")]
		_enter_select_event(em.current_draw)
		return

	# 日常/危机统一池：每轮抽两张（危机过线后权重跳大，可能被抽中）
	# 世界推进：土地辐射风险高时会自行滋生锈病（驱动 husk_blight 危机触发）
	if GameState.radiation_risk >= 60:
		GameState.apply_effects({"plague_progress": 1})
	current_draw = em.draw_two()
	var draw_ids: Array = []
	for ev in current_draw:
		draw_ids.append(str(ev.get("id", "")))
	print("[DRAW] 第%d年 | %s" % [GameState.round_number, ", ".join(draw_ids)])
	header_label.text = "第 %d 年 · 朝议 —— 择一处置" % GameState.round_number
	_enter_select_event(current_draw)

func _goal_target_reached() -> bool:
	var goal: Dictionary = GameState.selected_goal
	if goal.is_empty():
		return false
	var state_key := str(goal.get("state", ""))
	var target := int(goal.get("target", 0))
	if state_key == "" or target <= 0:
		return false
	return int(GameState.get(state_key)) >= target

# ---------- 步骤一：选择事件 ----------
func _enter_select_event(cards: Array) -> void:
	phase_step = "select_event"
	var page = _swap_page_to_page_holder(EventSelectPageScene)
	# 传入危机 / 大议 id 集合：危机卡红描边红标题，大议卡亮金描边亮金标题并外发光，日常卡保持黄铜
	page.setup(cards, em.crisis_ids, em.major_ids)
	page.event_chosen.connect(_on_event_chosen)

func _on_event_chosen(event: Dictionary) -> void:
	if phase_step != "select_event":
		return
	current_selected_event = event
	current_ignored_event = _find_other(event)
	_enter_select_plan(event)

func _find_other(event: Dictionary) -> Dictionary:
	for card in em.current_draw:
		if card.get("id", "") != event.get("id", ""):
			return card
	return {}

func _is_major_event(event: Dictionary) -> bool:
	var eid: String = str(event.get("id", ""))
	for ev in em.get_major_pool():
		if str(ev.get("id", "")) == eid:
			return true
	return false

## 该事件是否是危机事件（用于"不作为"后提升危机权重）
func _is_crisis_event(event: Dictionary) -> bool:
	return em.crisis_ids.has(str(event.get("id", "")))

# ---------- 步骤二：选择方案 ----------
func _enter_select_plan(event: Dictionary) -> void:
	phase_step = "select_plan"
	var page = _swap_page_to_page_holder(PlanSelectPageScene)
	# 本页只呈现方案本身（能力 + 名称 + 趋势），不显示判定门槛——
	# 门槛是事件级静态属性、与方案无关，放这里会被误读成各方案难度不同。
	page.setup(event)
	page.plan_chosen.connect(_on_plan_chosen.bind(event))

func _on_plan_chosen(plan_id: String, event: Dictionary) -> void:
	if phase_step != "select_plan":
		return
	var plan := _find_plan(event, plan_id)
	if plan.is_empty():
		return

	var ability_key: String = _safe_ability(plan.get("ability"))
	# 能力修正来自君主建卡（GameState），事件方案不再自带 ability_modifier
	var modifier: int = int(GameState.ability_modifiers.get(ability_key, 0))
	var dice: Array = GameState.roll_2d6()
	# 事件难度 = 事件自身静态属性（daily -3~+1 / crisis +1~+2 / major +3），直接进判定
	var difficulty: int = int(event.get("difficulty", 0))
	var res: Dictionary = Resolution.resolve(dice, modifier, difficulty)
	print("[CHOOSE] 第%d年 | event=%s plan=%s ability=%s" % [
		GameState.round_number, str(event.get("id", "")), str(plan_id), ability_key])
	print("[DICE] 第%d年 | 阶段%d dice=%d,%d sum=%d mod=%d diff=%d total=%d 门槛≥%d/%d tier=%s" % [
		GameState.round_number, em.current_stage() + 1,
		int(dice[0]), int(dice[1]), int(dice[0]) + int(dice[1]), modifier,
		difficulty, int(res["total"]),
		int(res["full_at"]), int(res["partial_at"]), str(res["tier"])])

	# 主动方案效果延后到史官汇总页统一结算
	pending_effects = plan["effects"][res["tier"]].duplicate()
	round_start_values = _state_values()
	if em.current_major.get("id", "") == event.get("id", "") or _is_major_event(event):
		em.major_handled = true

	current_selected_plan = plan
	current_res = res
	current_ability_key = ability_key
	current_modifier = modifier
	# 危机主动处理成功（完全/有条件）后，沿用建卡能力修正结构奖励 1 点。
	# 失败、不作为以及未选中的危机不奖励。
	if (event.get("type", "") == "crisis" or _is_crisis_event(event)) and res["tier"] != "fail":
		pending_crisis_growth_ability = "pending"
	else:
		pending_crisis_growth_ability = ""
	if _is_crisis_event(event):
		em.resolve_crisis(str(event.get("id", "")))
	_enter_dice(event, plan, res, ability_key, modifier)

## 方案 ability 兜底：配置表缺值/为 null/非法 ID 时一律回落 insight，
## 避免 null 赋给 String 变量导致运行时崩溃（数据问题不应炸引擎）
func _safe_ability(raw) -> String:
	if raw is String and GameState.DEFAULT_ABILITY_MOD.has(raw):
		return raw
	if raw != null:
		push_warning("[Main] 方案 ability 非法(%s)，已回落 insight" % str(raw))
	return "insight"

func _find_plan(event: Dictionary, plan_id: String) -> Dictionary:
	for plan in event.get("plans", []):
		if plan.get("id", "") == plan_id:
			return plan
	return {}

# ---------- 步骤三：骰子页 ----------
func _enter_dice(_event: Dictionary, _plan: Dictionary, res: Dictionary, ability_key: String, modifier: int) -> void:
	phase_step = "dice"
	var page = _swap_page_to_page_holder(DicePageScene)
	page.setup(ability_key, modifier, res["dice"], res["total"], res["tier"],
		Resolution.TIER_LONG_NAMES[res["tier"]], res["partial_at"], res["full_at"])
	page.continue_pressed.connect(_enter_round_end)

# ---------- 步骤四：史官汇总页 ----------
func _enter_round_end() -> void:
	phase_step = "round_end"

	# 所有本轮效果在进入结算页时一次性应用，投骰页期间侧栏保持不变。
	GameState.apply_effects(pending_effects)
	pending_effects = {}

	# 应用"不作为"事件的效果（统一池：未选的那张，含危机）
	# 危机被不作为 → 权重升至 25（下次几乎必出）
	if not current_ignored_event.is_empty():
		var ig: Dictionary = current_ignored_event.get("ignored", {})
		if not ig.is_empty():
			GameState.apply_effects(ig.get("effects", {}))
		if _is_crisis_event(current_ignored_event):
			em.escalate_crisis(str(current_ignored_event.get("id", "")))

	sidebar.refresh()
	_debug_print_hidden("轮末")
	_debug_print_state("轮末")

	var page = _swap_page_to_page_holder(RoundEndPageScene)
	page.setup(
		GameState.round_number,
		current_selected_event,
		current_selected_plan,
		current_ability_key,
		current_res["tier"],
		Resolution.TIER_LONG_NAMES[current_res["tier"]],
		current_ignored_event,
		_state_summary(round_start_values))
	page.next_pressed.connect(_on_next_pressed)

func _on_next_pressed() -> void:
	sidebar.clear_change_highlights()
	if pending_crisis_growth_ability == "pending":
		_show_crisis_growth()
		return
	# Major 结算已经完成：保留当前事件、方案与结果，直接进入史官终局页。
	# 不能先清空 current_selected_event，否则终局会退回旧版 verdict 文案。
	if em.major_handled:
		_show_ending()
		return
	GameState.round_number += 1
	current_selected_event = {}
	current_ignored_event = {}
	current_selected_plan = {}
	current_res = {}
	new_round()

func _show_crisis_growth() -> void:
	phase_step = "crisis_growth"
	var page = _swap_page(title_slot, CharacterBuildPageScene)
	page.setup_upgrade(GameState.ability_modifiers)
	page.build_confirmed.connect(_on_crisis_growth_confirmed)
	title_slot.visible = true
	game_slot.visible = false
	ending_slot.visible = false

func _on_crisis_growth_confirmed(modifiers: Dictionary) -> void:
	GameState.ability_modifiers = modifiers.duplicate()
	GameState.ability_points += 1
	print("[CRISIS GROWTH] +1 ability point allocated: %s" % str(GameState.ability_modifiers))
	pending_crisis_growth_ability = ""
	title_slot.visible = false
	game_slot.visible = true
	ending_slot.visible = false
	GameState.round_number += 1
	new_round()

# ================= 工具 =================

func _swap_page(slot: Control, scene: PackedScene):
	for c in slot.get_children():
		slot.remove_child(c)
		c.queue_free()
	var page = scene.instantiate()
	slot.add_child(page)
	return page

func _swap_page_to_page_holder(scene: PackedScene):
	return _swap_page(page_holder, scene)

## 调试：把隐藏数值打印到 Godot 编辑器 Output 面板
## 只打 id + 数字，不带中文名与区间文案（控制台定位用原始 key，避免与 UI 文案混淆）
## moment：轮首（本轮开始时的基准值）/ 轮末（结算后的结果值），避免同一年两行分不清先后
func _debug_print_hidden(moment: String = "") -> void:
	var parts: Array = []
	for key in GameState.HIDDEN_META:
		parts.append("%s:%d" % [key, GameState.hidden_value(key)])
	print("[Herstory 隐藏数值] 第%d年 %s| %s" % [
		GameState.round_number, _moment_tag(moment), " ".join(parts)])

## 调试：五个可见 State（id + 数字），与隐藏数值同行格式、同时点打印
func _debug_print_state(moment: String = "") -> void:
	print("[STATE] 第%d年 %s| treasury:%d gdp:%d population:%d military:%d territory:%d" % [
		GameState.round_number, _moment_tag(moment),
		GameState.treasury, GameState.gdp, GameState.population,
		GameState.military, GameState.territory])

func _moment_tag(moment: String) -> String:
	return ("·%s " % moment) if moment != "" else ""

func _state_values() -> Dictionary:
	return {"treasury": GameState.treasury, "gdp": GameState.gdp, "population": GameState.population,
		"military": GameState.military, "territory": GameState.territory}

func _state_summary(before: Dictionary = {}) -> String:
	var names := {"treasury":"财政", "gdp":"GDP", "population":"人口", "military":"军力", "territory":"领土"}
	var parts: Array = []
	for key in names:
		var now: int = int(GameState.get(key))
		var old: int = int(before.get(key, now))
		var delta := now - old
		var piece := "%s %d" % [names[key], now]
		if delta != 0:
			piece += "  [color=%s](%s%d)[/color]" % [Palette.JADE if delta > 0 else Palette.RUST, "+" if delta > 0 else "", delta]
		parts.append(piece)
	# 第二行：support 类隐藏值的区间文案（不含 female_support）
	var support_parts: Array = []
	for key in SUMMARY_SUPPORT_KEYS:
		var meta: Dictionary = GameState.HIDDEN_META.get(key, {})
		support_parts.append("%s：%s" % [str(meta.get("cn", key)), GameState.tier_text(key)])
	return " ｜ ".join(parts) + "\n" + " ｜ ".join(support_parts)
