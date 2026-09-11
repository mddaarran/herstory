extends Control
## Main：主流程与 UI 状态机（按 UI_0827 原型）
##
## 页面：
##   1) title       —— 仅左侧栏；右侧空白
##   2) select_event —— 两张方形事件卡，择一
##   3) select_plan  —— 顶部「事件名称」+「事件梗概」，下方两个方案长条
##   4) dice        —— 顶部能力名（带 modifier）+ 两枚骰子 + 总数 + 档位
##   5) round_end   —— 史官页：含元年 / 处理事件 / 解决方案 / 含不作为的本轮数值
##   6) ending      —— 终局结语 + 重新开始
##
## 判定：2d6 + 方案 modifier；<6 失败 / 6-9 有条件成功 / ≥10 完全成功

# ---------- 调色板（参考 herstory.html） ----------
const INK_BG     := "#14110e"   # 主背景（墨）
const INK_BG_2   := "#1c1815"   # 侧栏背景（略浅）
const PAPER      := "#e9e3d5"   # 正文（纸）
const PAPER_DIM  := "#9a9184"   # 次级文字
const PAPER_FAINT:= "#6b6459"   # 最弱文字
const GOLD       := "#c9a227"   # 金（标题 / 有条件成功）
const CINNABAR   := "#b8402f"   # 朱（危险 / 失败）
const JADE       := "#5f8a6a"   # 青（向好 / 完全成功）
const LINE       := "#332b22"   # 分隔线
const CARD_BG    := "#3a342b"   # 右侧卡片底（亮一档的墨）

const ABILITY_NAMES := {
	"insight": "洞察",
	"persuasion": "驭人",
	"majesty": "威仪",
}
const TIER_COLORS := {
	"full": JADE,
	"partial": GOLD,
	"fail": CINNABAR,
}

const TITLE_TEXT := "Herstory"
const GOAL_TEXT := "君主目标 · 守成丰年\n登基后的第一年，避免火穗危机演变为粮荒，同时维持澜朝的基本运转。\n终局主要评价人口、财政、经济、贸易、土地风险与社会支持度。"
const PROPHECY_TEXT := "预言 · 丰年将至，或万灯熄灭\n传说澜朝的第一盏灯，并非由工匠点燃，而是由一粒种子点燃。\n人们种下火穗，火穗驱动火籽炉；火籽炉抽水，水又滋养新的火穗。\n城市因土地而明亮，土地也因城市而疲惫。\n每一代君主都以为自己能够终结这场循环，\n却总会在丰收与灯火之间，再次作出同一个选择。\n当今的女帝将决定，这一次循环是继续转动，暂时停下，还是彻底断裂。"

# 5 个国势数值条的显示标签
const STATE_LABELS := {
	"treasury": "财政",
	"gdp": "GDP",
	"population": "人口",
	"military": "军力",
	"territory": "领土",
}
# 进度条上限（取初始值 × 1.25：初始占 80%，下滑即明显）
const STATE_MAX := {
	"treasury": 1000,
	"gdp": 1200,
	"population": 1500,
	"military": 12500,
	"territory": 120000,
}

var em: EventManager
var chronicler := Chronicler.new()

# 阶段
var phase_step: String = "title"   # title / select_event / select_plan / dice / round_end / ending

# 流程数据
var current_draw: Array = []
var current_selected_event: Dictionary = {}
var current_ignored_event: Dictionary = {}
var current_selected_plan: Dictionary = {}
var current_res: Dictionary = {}
var current_ability_key: String = "insight"
var current_modifier: int = 0
var current_round_chronicle: String = ""   # 本轮史官一句话（用于 round_end 一次性展示）

# UI 节点
var title_page: Control
var game_page: Control
var ending_page: Control

var header_label: Label
var sidebar: Panel
var sidebar_body: VBoxContainer

var main_row: HBoxContainer      # 左栏 + 右侧
var content_box: MarginContainer   # 右侧（只放单页内容，统一留右边距）
var page_holder: VBoxContainer   # 当前 phase 内容容器

# 结语页
var verdict_label: Label
var ending_text_label: Label
var ending_state_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	em = EventManager.new()
	_build_ui()
	show_title()

# ================= UI 构建 =================

func _build_ui() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _ink_bg())
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	title_page = _build_title_page()
	margin.add_child(title_page)

	game_page = _build_game_page()
	margin.add_child(game_page)
	game_page.visible = false

	ending_page = _build_ending_page()
	margin.add_child(ending_page)
	ending_page.visible = false

# ---------- 通用 UI 工厂 ----------
const FONT_SCALE := 1.35

func _make_label(text: String, font_size: int, color: String = PAPER, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(font_size * FONT_SCALE))
	label.add_theme_color_override("font_color", Color(color))
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 关键：让 Label 按父容器宽度排版，否则长文本会画到容器外覆盖左栏
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Label 必须有 vertical size flag 才能换行
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

# ---------- 关键字高亮（资产=金 / 骰子=青）----------
const HL_GOLD := "#c9a227"
const HL_JADE := "#5f8a6a"

var _hl_asset_kw := ["财政","GDP","人口","军力","领土","国势","资产","土地","火穗","粮仓","民心","支持度","旧姓","平民","贸易","经济"]
var _hl_dice_kw := ["骰子","掷骰","点数","判定","大成功","有条件成功","大失败"]

## 把文本里的资产类/骰子类关键词包成 BBCode 颜色标签
func _hl(text: String) -> String:
	var out := text
	# 长词优先替换，避免子串嵌套
	for kw in _sorted_by_len(_hl_asset_kw):
		out = out.replace(kw, "[color=%s]%s[/color]" % [HL_GOLD, kw])
	for kw in _sorted_by_len(_hl_dice_kw):
		out = out.replace(kw, "[color=%s]%s[/color]" % [HL_JADE, kw])
	return out

func _sorted_by_len(arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort_custom(func(x, y): return x.length() > y.length())
	return a

## 带关键字高亮的富文本标签（用 BBCode 渲染）
func _make_rich_label(text: String, font_size: int, base_color: String = PAPER, wrap: bool = false, align_center: bool = false) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	var body: String = _hl(text)
	if align_center:
		body = "[center]%s[/center]" % body
	rt.bbcode_text = "[font_size=%d]%s[/font_size]" % [int(font_size * FONT_SCALE), body]
	rt.add_theme_color_override("default_color", Color(base_color))
	# 关键：fit_content=true 让标签按内容自适应高度（默认 false → 最小尺寸 = 0 → 内容不显示）
	rt.fit_content = true
	rt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if wrap:
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rt

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 19)
	# 自定义按钮样式：金色边框 + 深色底，让按钮在深色背景上清晰可见
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a1612")
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(GOLD)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sb.set("corner_radius_" + corner, 4)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color("#28211b")
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = Color("#3a2c1a")
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", Color(PAPER))
	btn.add_theme_color_override("font_hover_color", Color(GOLD))
	btn.add_theme_color_override("font_pressed_color", Color(GOLD))
	return btn

func _ink_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_BG)
	return sb

func _sidebar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_BG_2)
	return sb

func _card_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CARD_BG)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sb.set("corner_radius_" + corner, 6)
	return sb

func _event_card_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CARD_BG)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(LINE)
	return sb

func _divider() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 1)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(LINE)
	p.add_theme_stylebox_override("panel", sb)
	return p

# ---------- 页面构建 ----------
func _build_title_page() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 让 SHRINK_CENTER 子节点真正居中
	vb.add_child(_make_label(TITLE_TEXT, 30, GOLD))
	vb.add_child(_make_label("—— 女性君主历史演绎 · 最小 Demo ——", 13, PAPER_DIM))
	vb.add_child(_make_rich_label(GOAL_TEXT, 15, PAPER, true))
	vb.add_child(_make_label(" ", 4))
	vb.add_child(_make_rich_label(PROPHECY_TEXT, 14, PAPER_DIM, true))
	vb.add_child(_make_label(" ", 4))
	var start_btn := _make_button("登 基")
	start_btn.custom_minimum_size = Vector2(180, 44)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_on_start_pressed)
	vb.add_child(start_btn)
	return vb

func _build_game_page() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 关键：让 game_page 横向撑满 margin，才能让里面的主区真正展开
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL

	header_label = _make_label("", 18, GOLD)
	header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(header_label)

	main_row = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 关键：让 main_row 横向撑满 game_page，左侧栏 SHRINK_BEGIN 不抢，右侧 content_box 才有空间
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 左侧数值栏（始终保留）
	sidebar = Panel.new()
	sidebar.custom_minimum_size.x = 260
	sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # 不争抢空间
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", _sidebar_bg())
	sidebar.clip_contents = true
	var side_margin := MarginContainer.new()
	side_margin.add_theme_constant_override("margin_left", 16)
	side_margin.add_theme_constant_override("margin_right", 16)
	side_margin.add_theme_constant_override("margin_top", 14)
	side_margin.add_theme_constant_override("margin_bottom", 14)
	side_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidebar_body = VBoxContainer.new()
	sidebar_body.add_theme_constant_override("separation", 6)
	side_margin.add_child(sidebar_body)
	sidebar.add_child(side_margin)
	main_row.add_child(sidebar)

	# 右侧：用 MarginContainer 给内容统一留出左右边距，确保文字两边都不贴边
	content_box = MarginContainer.new()
	content_box.add_theme_constant_override("margin_left", 22)
	content_box.add_theme_constant_override("margin_right", 30)
	content_box.add_theme_constant_override("margin_top", 4)
	content_box.add_theme_constant_override("margin_bottom", 12)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL

	page_holder = VBoxContainer.new()
	page_holder.add_theme_constant_override("separation", 10)
	page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 关键：让按钮等 SHRINK_CENTER 子节点真正居中
	page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_holder.clip_contents = true  # 兜底裁切，防止子节点绘制到 sidebar 上
	content_box.add_child(page_holder)

	main_row.add_child(content_box)
	vb.add_child(main_row)
	return vb

func _build_ending_page() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 让重新开始按钮居中
	vb.add_child(_make_label("史官结语", 26, GOLD))
	verdict_label = _make_label("", 18, GOLD)
	vb.add_child(verdict_label)
	ending_text_label = _make_label("", 14, PAPER)
	ending_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(ending_text_label)
	ending_state_label = _make_label("", 13, PAPER_DIM)
	vb.add_child(ending_state_label)
	var restart_btn := _make_button("重新开始")
	restart_btn.custom_minimum_size = Vector2(180, 44)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_btn.pressed.connect(_on_restart_pressed)
	vb.add_child(restart_btn)
	return vb

# ================= 页面切换 =================

func show_title() -> void:
	phase_step = "title"
	title_page.visible = true
	game_page.visible = false
	ending_page.visible = false

func show_game() -> void:
	title_page.visible = false
	game_page.visible = true
	ending_page.visible = false

func show_ending() -> void:
	var verdict: String = chronicler.judge_verdict()
	verdict_label.text = "—— %s ——" % Chronicler.VERDICT_NAMES[verdict]
	ending_text_label.text = Chronicler.VERDICT_TEXTS[verdict]
	ending_state_label.text = _state_summary()
	title_page.visible = false
	game_page.visible = false
	ending_page.visible = true

# ================= 流程 =================

func _on_start_pressed() -> void:
	GameState.reset()
	em.reset()
	show_game()
	new_round()

func _on_restart_pressed() -> void:
	show_title()

func new_round() -> void:
	em.check_progression()
	_refresh_sidebar()
	_debug_print_hidden()
	_clear_page()

	match em.phase:
		EventManager.PHASE_CRISIS:
			header_label.text = "第 %d 年 · 危机 —— 火穗锈病" % GameState.round_number
			current_selected_event = em.get_crisis_event()
			current_ignored_event = {}
			_enter_select_plan_step(current_selected_event)
			return
		EventManager.PHASE_MAJOR:
			header_label.text = "第 %d 年 · 重大事件 —— 秋收大议" % GameState.round_number
			current_selected_event = em.get_major_event()
			current_ignored_event = {}
			_enter_select_plan_step(current_selected_event)
			return
		EventManager.PHASE_ENDING:
			show_ending()
			return
		_: # daily
			# 触发风险与前兆（不掷骰）
			if GameState.radiation_risk >= 60:
				GameState.apply_effects({"plague_progress": 1})
			current_draw = em.draw_two_daily()
			header_label.text = "第 %d 年 · 朝议 —— 择一处置" % GameState.round_number
			_enter_select_event_step(current_draw)

# ---------- 步骤一：选择事件 ----------
func _enter_select_event_step(cards: Array) -> void:
	phase_step = "select_event"

	var hint := _make_label("两份奏报同时呈上，择一份亲理，另一份留作不作为。", 13, PAPER_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page_holder.add_child(hint)
	page_holder.add_child(_make_label(" ", 8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for card in cards:
		row.add_child(_make_event_choice_card(card))
	page_holder.add_child(row)

func _make_event_choice_card(event: Dictionary) -> Panel:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _event_card_bg())
	card.custom_minimum_size = Vector2(280, 400)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 注意：不设 size_flags_vertical，让卡片采用 min 高度而不是撑满，避免把按钮挤出视口

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	vb.add_theme_constant_override("margin_left", 22)
	vb.add_theme_constant_override("margin_right", 22)
	vb.add_theme_constant_override("margin_top", 22)
	vb.add_theme_constant_override("margin_bottom", 22)

	# 标签：第 N 奏报
	var tag := _make_label("第 %d 奏" % (current_draw.find(event) + 1 if current_draw.find(event) >= 0 else 1), 12, PAPER_FAINT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(tag)

	# 事件标题
	var title := _make_label(event.get("title", "事件"), 26, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(title)

	# 分隔
	vb.add_child(_divider())

	# 事件梗概（背景文案）—— 居中，左右都不贴边
	var bg_text: String = event.get("background", "")
	var desc := _make_label(bg_text, 13, PAPER_DIM, true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(desc)

	# 底部按钮（不要拉满卡片宽，居中显示）
	var btn := _make_button("处置此奏 ▸")
	btn.custom_minimum_size = Vector2(180, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_event_chosen.bind(event))
	vb.add_child(btn)

	card.add_child(vb)
	return card

func _on_event_chosen(event: Dictionary) -> void:
	if phase_step != "select_event":
		return
	current_selected_event = event
	current_ignored_event = _find_other(event)
	_clear_page()
	_enter_select_plan_step(event)

func _find_other(event: Dictionary) -> Dictionary:
	for card in em.current_draw:
		if card.get("id", "") != event.get("id", ""):
			return card
	return {}

# ---------- 步骤二：选择方案 ----------
func _enter_select_plan_step(event: Dictionary) -> void:
	phase_step = "select_plan"

	# 顶部：事件名称（标题）+ 事件梗概（副标题）—— 对齐原型图 2
	var title := _make_label(event.get("title", ""), 26, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page_holder.add_child(title)

	var subtitle := _make_rich_label(event.get("background", ""), 13, PAPER_DIM, true)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.add_child(subtitle)

	page_holder.add_child(_make_label(" ", 12))

	# 两个方案长条
	for plan in event.get("plans", []):
		page_holder.add_child(_make_plan_button(event, plan))

func _make_plan_button(event: Dictionary, plan: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn := Button.new()
	var ability_key: String = plan.get("ability", "insight")
	var ability_label: String = ABILITY_NAMES.get(ability_key, "洞察")
	var modifier: int = int(plan.get("ability_modifier", 0))
	var mod_text: String = ("+" if modifier > 0 else "") + str(modifier)
	btn.text = "【%s %s】 %s" % [ability_label, mod_text, plan.get("name", "")]
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_plan_pressed.bind(event, plan.get("id", "")))
	box.add_child(btn)

	# 方案说明：常驻可见，不再依赖 hover 提示
	var dir: String = plan.get("direction", "")
	if dir != "":
		var dir_lbl := _make_rich_label(dir, 12, PAPER_FAINT, true)
		dir_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(dir_lbl)

	return box

func _on_plan_pressed(event: Dictionary, plan_id: String) -> void:
	if phase_step != "select_plan":
		return
	var plan := _find_plan(event, plan_id)
	if plan.is_empty():
		return

	var ability_key: String = plan.get("ability", "insight")
	var modifier: int = int(plan.get("ability_modifier", 0))
	var dice: Array = GameState.roll_2d6()
	var res: Dictionary = Resolution.resolve(dice, modifier)

	# 应用主动方案效果
	GameState.apply_effects(plan["effects"][res["tier"]])
	match em.phase:
		EventManager.PHASE_CRISIS:
			em.crisis_handled = true
		EventManager.PHASE_MAJOR:
			em.major_handled = true

	current_selected_plan = plan
	current_res = res
	current_ability_key = ability_key
	current_modifier = modifier
	_refresh_sidebar()
	_clear_page()
	_enter_dice_step(event, plan, res, ability_key, modifier)

func _find_plan(event: Dictionary, plan_id: String) -> Dictionary:
	for plan in event.get("plans", []):
		if plan.get("id", "") == plan_id:
			return plan
	return {}

# ---------- 步骤三：骰子页 ----------
func _enter_dice_step(event: Dictionary, plan: Dictionary, res: Dictionary, ability_key: String, modifier: int) -> void:
	phase_step = "dice"

	var ability_label: String = ABILITY_NAMES.get(ability_key, "洞察")
	var mod_text: String = ("+" if modifier > 0 else "") + str(modifier)

	# 顶部：大字号能力名（带 modifier）
	var ability_header := _make_label(ability_label, 36, PAPER)
	ability_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_holder.add_child(ability_header)
	var mod_label := _make_label(mod_text, 20, GOLD)
	mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_holder.add_child(mod_label)

	page_holder.add_child(_make_label(" ", 16))

	# 中间：两枚骰子（垂直居中块）
	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 28)
	dice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var die1 := _make_die(int(res["dice"][0]))
	var die2 := _make_die(int(res["dice"][1]))
	# 让两枚骰子微微错位旋转（HBox 不接受 position，仅 rotation 生效）
	die1.rotation = -0.10
	die2.rotation = 0.08
	dice_row.add_child(die1)
	dice_row.add_child(die2)
	page_holder.add_child(dice_row)

	page_holder.add_child(_make_label(" ", 16))

	# 下方：总数 + 档位
	var total_label := _make_label(str(res["total"]), 36, GOLD)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_holder.add_child(total_label)
	var dice_cap := _make_rich_label("（两枚骰子之和）", 13, PAPER_DIM, false, true)
	dice_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.add_child(dice_cap)

	var tier_color: String = TIER_COLORS[res["tier"]]
	var tier_long: String = Resolution.TIER_LONG_NAMES[res["tier"]]
	var tier_label := _make_label(tier_long, 22, tier_color)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_holder.add_child(tier_label)

	# 简短结果描述（不长期保留，仅在 round_end 显示）
	var evt_title: String = event.get("title", "")
	var chronicle_text: String = plan["chronicle"][res["tier"]]
	current_round_chronicle = "【%s】%s（%s）：%s" % [
		evt_title, plan.get("name", ""), Resolution.TIER_NAMES[res["tier"]], chronicle_text]

	page_holder.add_child(_make_label(" ", 24))

	# 「查看本轮结算 ▸」按钮 —— 紧跟 tier_label 之后，确保在视口内可见
	var cont := _make_button("查看本轮结算 ▸")
	cont.custom_minimum_size.y = 44
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(_enter_round_end_step)
	page_holder.add_child(cont)

	# 骰子动画（异步）
	_run_dice_anims(die1, die2, int(res["dice"][0]), int(res["dice"][1]))

# ---------- 步骤四：史官汇总页 ----------
func _enter_round_end_step() -> void:
	phase_step = "round_end"
	_clear_page()

	# 顶部：你处理的奏报（事件名 + 方案名）
	var ev: Dictionary = current_selected_event
	page_holder.add_child(_make_label("第 %d 年 · 奏报裁决" % GameState.round_number, 16, GOLD))
	page_holder.add_child(_make_label(ev.get("title", ""), 24, PAPER))

	var tier: String = current_res.get("tier", "fail")
	var tier_color: String = TIER_COLORS[tier]
	var tier_long: String = Resolution.TIER_LONG_NAMES[tier]
	page_holder.add_child(_make_label("解决方案：「%s」（%s · %s）" % [
		current_selected_plan.get("name", ""),
		ABILITY_NAMES.get(current_ability_key, "洞察"),
		tier_long], 14, tier_color))

	page_holder.add_child(_divider())

	# 史官一段话
	var chronicle: String = current_selected_plan["chronicle"][tier]
	var chronicle_label := _make_rich_label("史官记：" + chronicle, 14, PAPER_DIM, true)
	chronicle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.add_child(chronicle_label)

	# 数值变化 + 不作为
	var ignored_text := ""
	if em.phase == EventManager.PHASE_DAILY and not current_ignored_event.is_empty():
		var ig: Dictionary = current_ignored_event.get("ignored", {})
		if not ig.is_empty():
			GameState.apply_effects(ig.get("effects", {}))
			ignored_text = ig.get("chronicle", "")
			var ig_lbl := _make_rich_label(
				"未处理的奏报「%s · 不作为」：%s" % [
					current_ignored_event.get("title", ""), ig.get("text", "")],
				12, PAPER_FAINT, true)
			ig_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			page_holder.add_child(ig_lbl)
			var ig_chron := _make_rich_label("  — " + ignored_text, 12, PAPER_DIM, true)
			ig_chron.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			page_holder.add_child(ig_chron)

	_refresh_sidebar()

	# 概括所有数值（含不作为）
	page_holder.add_child(_divider())
	page_holder.add_child(_make_label("—— 本轮国势变化 ——", 13, PAPER_DIM))
	var sum_lbl := _make_rich_label(_state_summary(), 13, PAPER, true)
	sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.add_child(sum_lbl)

	_debug_print_hidden()  # 结算后打印隐藏数值，观察变化

	page_holder.add_child(_make_label(" ", 16))

	var next_btn := _make_button("进入下一轮 ▸")
	next_btn.custom_minimum_size.y = 44
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_btn.pressed.connect(_on_next_pressed)
	page_holder.add_child(next_btn)

func _on_next_pressed() -> void:
	GameState.round_number += 1
	current_selected_event = {}
	current_ignored_event = {}
	current_selected_plan = {}
	current_res = {}
	_clear_page()
	new_round()

# ================= 左侧数值栏 =================

func _refresh_sidebar() -> void:
	for child in sidebar_body.get_children():
		child.queue_free()

	sidebar_body.add_child(_make_label("澜朝 · 国势", 14, GOLD))
	sidebar_body.add_child(_make_label("—— %d 元年 ——" % GameState.round_number, 13, PAPER_DIM))

	sidebar_body.add_child(_divider())

	# 三项能力 modifier
	for key in ["insight", "persuasion", "majesty"]:
		var mod: int = GameState.DEFAULT_ABILITY_MOD.get(key, 0)
		var label_text: String = "%s %s%d" % [ABILITY_NAMES[key], ("+" if mod > 0 else ""), mod]
		sidebar_body.add_child(_make_label(label_text, 13, PAPER))

	sidebar_body.add_child(_divider())

	# 5 个国势数值条
	var order := ["treasury", "gdp", "population", "military", "territory"]
	for k in order:
		sidebar_body.add_child(_make_meter(STATE_LABELS[k], _state_value(k), STATE_MAX[k]))

	sidebar_body.add_child(_divider())

	# 隐藏数值（临时调试：显示精确数字 + 区间文本）—— 全部用 wrap 防止侧栏太窄时截断
	sidebar_body.add_child(_make_label("民 间：%d %s" % [GameState.civilian_support, GameState.civilian_tier_text()], 12, PAPER, true))
	sidebar_body.add_child(_make_label("旧 姓：%d %s" % [GameState.noble_support, GameState.noble_tier_text()], 12, PAPER, true))
	sidebar_body.add_child(_make_label("土 地：%d %s" % [GameState.radiation_risk, GameState.radiation_tier_text()], 12, PAPER, true))
	sidebar_body.add_child(_make_label("锈病进度：%d / 3" % GameState.plague_progress, 12, GOLD, true))

	var omen := GameState.blight_omen_text()
	var omen_text: String = omen if omen != "" else "尚无征兆"
	var omen_color: String = GOLD if omen != "" else PAPER_DIM
	sidebar_body.add_child(_make_label("征 兆：" + omen_text, 12, omen_color, true))

func _state_value(key: String) -> int:
	match key:
		"treasury": return GameState.treasury
		"gdp": return GameState.gdp
		"population": return GameState.population
		"military": return GameState.military
		"territory": return GameState.territory
	return 0

## 调试：把隐藏数值打印到 Godot 编辑器 Output 面板（临时）
func _debug_print_hidden() -> void:
	print("[Herstory 隐藏数值] 第%d年 | 平民支持:%d 旧姓支持:%d 土地辐射风险:%d 火穗锈病进度:%d/3" % [
		GameState.round_number,
		GameState.civilian_support,
		GameState.noble_support,
		GameState.radiation_risk,
		GameState.plague_progress,
	])

func _make_meter(metric_name: String, value: int, maxv: int) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	var name_label := _make_label(metric_name, 12, PAPER_DIM)
	name_label.custom_minimum_size.x = 44   # 给名称固定宽度，避免被挤压换行
	row.add_child(name_label)
	var val := _make_label(str(value), 12, PAPER)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	vb.add_child(row)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxv
	bar.value = clampi(value, 0, maxv)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ratio: float = float(value) / float(maxv)
	var col := JADE
	if ratio < 0.5:
		col = CINNABAR
	elif ratio < 0.8:
		col = GOLD
	bar.add_theme_stylebox_override("fill", _bar_fill_style(col))
	bar.add_theme_stylebox_override("background", _bar_bg_style())
	vb.add_child(bar)
	return vb

func _bar_fill_style(color: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color)
	return sb

func _bar_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#262019")
	return sb

func _state_summary() -> String:
	return "%s %d ｜ %s %d ｜ %s %d ｜ %s %d ｜ %s %d\n民间：%s ｜ 旧姓：%s ｜ 土地：%s" % [
		STATE_LABELS["treasury"], GameState.treasury,
		STATE_LABELS["gdp"], GameState.gdp,
		STATE_LABELS["population"], GameState.population,
		STATE_LABELS["military"], GameState.military,
		STATE_LABELS["territory"], GameState.territory,
		GameState.civilian_tier_text(), GameState.noble_tier_text(), GameState.radiation_tier_text()]

# ================= 骰子 =================

func _make_die(number: int) -> Panel:
	var die := Panel.new()
	var die_size := Vector2(110, 110)
	die.custom_minimum_size = die_size
	die.size = die_size
	die.pivot_offset = die_size / 2.0
	die.add_theme_stylebox_override("panel", _die_bg())
	_set_die_face(die, number)
	return die

func _die_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sb.set("corner_radius_" + corner, 10)
	sb.border_width_bottom = 2
	sb.border_color = Color(LINE)
	return sb

func _pip_pattern(n: int) -> Array:
	match n:
		1: return [4]
		2: return [0, 8]
		3: return [0, 4, 8]
		4: return [0, 2, 6, 8]
		5: return [0, 2, 4, 6, 8]
		6: return [0, 2, 3, 5, 6, 8]
		_: return []

func _pip_panel(filled: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(22, 22)
	p.size = Vector2(22, 22)
	var sb := StyleBoxFlat.new()
	if filled:
		sb.bg_color = Color(INK_BG)
		for corner in ["top_left","top_right","bottom_left","bottom_right"]:
			sb.set("corner_radius_" + corner, 8)
	else:
		sb.bg_color = Color(0, 0, 0, 0)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _set_die_face(die: Node, number: int) -> void:
	if die == null or not is_instance_valid(die):
		return
	for c in die.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("hseparation", 6)
	grid.add_theme_constant_override("vseparation", 6)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 10
	grid.offset_top = 10
	grid.offset_right = -10
	grid.offset_bottom = -10
	var pattern := _pip_pattern(number)
	for i in range(9):
		grid.add_child(_pip_panel(i in pattern))
	die.add_child(grid)

func _run_dice_anims(die1: Panel, die2: Panel, target1: int, target2: int) -> void:
	# 8 帧快速滚动
	for i in range(8):
		_set_die_face(die1, randi_range(1, 6))
		_set_die_face(die2, randi_range(1, 6))
		await get_tree().create_timer(0.07).timeout
	_set_die_face(die1, target1)
	_set_die_face(die2, target2)

# ================= 通用 =================

func _clear_page() -> void:
	for child in page_holder.get_children():
		child.queue_free()
