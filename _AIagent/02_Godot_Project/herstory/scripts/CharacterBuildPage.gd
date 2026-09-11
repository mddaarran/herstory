extends Control

signal build_confirmed(modifiers: Dictionary)

const ORDER := ["insight", "influence", "majesty"]
const NAMES := {"insight": "洞察", "influence": "驭人", "majesty": "威仪"}
const Palette := preload("res://scripts/ui/Palette.gd")
## 建卡能力值下限：允许扣到 -1（用负项腾出点数给其他项，如 -1 / +2 / +1）
const MIN_VALUE := -1
## 能力值上限不在此定义——唯一来源是 GameState.ABILITY_CAP（=10）。
## 注意：const 不能用 autoload 的常量初始化（GameState 运行时才注册），
## 所以这里直接在函数体内内联引用 GameState.ABILITY_CAP，不再另存一份副本。
## 建卡初始可分配点数（正式值 2；能力值后续可成长至 GameState.ABILITY_CAP）
const BUDGET := 2
var values := {"insight": 0, "influence": 0, "majesty": 0}
## 成长页专用：记录进入本页时每项的能力值，作为各项的加减下限（= 只能在本项原值到原值+1 之间调整）
var base_values := {}
var value_labels := {}
var remaining_label: Label
var confirm_button: Button
var budget := 2
var base_total := 0
var upgrade_mode := false

func setup(initial: Dictionary) -> void:
	budget = BUDGET
	upgrade_mode = false
	base_total = 0
	base_values = {}
	for key in ORDER:
		values[key] = clampi(int(initial.get(key, 0)), MIN_VALUE, GameState.ABILITY_CAP)
	_build()

func setup_upgrade(initial: Dictionary) -> void:
	budget = 1
	upgrade_mode = true
	base_total = 0
	base_values = {}
	for key in ORDER:
		values[key] = clampi(int(initial.get(key, 0)), MIN_VALUE, GameState.ABILITY_CAP)
		base_values[key] = values[key]
		base_total += values[key]
	_build()

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(900, 500)
	root.add_theme_constant_override("separation", 24)
	center.add_child(root)
	var title := Label.new()
	title.text = "能力成长" if upgrade_mode else "你是一个怎样的君主"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	root.add_child(title)
	var hint := Label.new()
	hint.text = ("选择 1 项能力提升；本次危机获得 %d 点（可按 − 改选）" % budget) if upgrade_mode else ("分配 %d 点能力值；每项 %d 至 +%d" % [budget, MIN_VALUE, GameState.ABILITY_CAP])
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	root.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 46)
	root.add_child(row)
	for key in ORDER:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(220, 160)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var name := Label.new()
		name.text = NAMES[key]
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 28)
		col.add_child(name)
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(55, 55)
		minus.pressed.connect(_change.bind(key, -1))
		controls.add_child(minus)
		var value := Label.new()
		value.custom_minimum_size = Vector2(85, 55)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 30)
		controls.add_child(value)
		value_labels[key] = value
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(55, 55)
		plus.pressed.connect(_change.bind(key, 1))
		controls.add_child(plus)
		col.add_child(controls)
		row.add_child(col)
	# 判定须知：只在建卡页出现。成长页（upgrade_mode）不重复讲规则。
	if not upgrade_mode:
		root.add_child(_build_guide_panel())
	remaining_label = Label.new()
	remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_label.add_theme_font_size_override("font_size", 22)
	root.add_child(remaining_label)
	confirm_button = Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(240, 58)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.pressed.connect(func(): build_confirmed.emit(values.duplicate()))
	root.add_child(confirm_button)
	_refresh()

## 建卡页「判定须知」说明块（新手指引，仅建卡时出现）。
## 只讲一件事：这三项能力是**判定时加在骰面上的修正**，不是背景设定。
## 用「左侧竖线面板 + 正文」而非缺口角卡片——卡片带 hover / 按压反馈，会被误认为可点击。
## 全程 mouse_filter = IGNORE，不拦截下层控件的鼠标事件。
func _build_guide_panel() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.CARD_BG)
	sb.border_color = Color(Palette.BORDER)
	sb.border_width_left = 4
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var head := Label.new()
	head.text = "判定须知"
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color(Palette.AMBER))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(head)

	var body := Label.new()
	body.text = "三项能力不是背景设定，而是判定时加在骰面上的修正。每次裁决先择一方案，方案指定其中一项能力；随后掷两枚骰子——骰面合计 + 该项能力值 = 判定值，再与该次事件的门槛比对，决定完全成功 / 有条件成功 / 失败。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(Palette.TEXT_DIM))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	var example := Label.new()
	example.text = "例：驭人为 +2，掷出 3 与 5，判定值 = 3 + 5 + 2 = 10。"
	example.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	example.add_theme_font_size_override("font_size", 17)
	example.add_theme_color_override("font_color", Color(Palette.TEXT))
	example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(example)

	var negative := Label.new()
	negative.text = "能力值可为负：把某项压到 −1，即从别处腾出一点——洞察 −1 ／ 驭人 +2 ／ 威仪 +1，与 0 ／ +1 ／ +1 同样是 %d 点。" % BUDGET
	negative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	negative.add_theme_font_size_override("font_size", 17)
	negative.add_theme_color_override("font_color", Color(Palette.TEXT_FAINT))
	negative.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(negative)

	return panel

## 加减规则：
##   建卡页：每项可取 MIN_VALUE(=-1) ~ GameState.ABILITY_CAP，三项合计必须恰好 = budget 才能确认；
##           减号常态可用（允许把某项扣成负值腾点数）
##   成长页：每项只能在本项原值 ~ 原值+1 之间调整（budget=1），
##           所以「先加到 A，反悔后可以减回来再改加到 B」——减号必须可用
func _change(key: String, delta: int) -> void:
	var next := int(values[key]) + delta
	var min_value: int = MIN_VALUE
	if upgrade_mode:
		min_value = int(base_values.get(key, MIN_VALUE))
	if next < min_value or next > GameState.ABILITY_CAP:
		return
	var spent := 0
	for k in ORDER: spent += int(values[k])
	spent -= base_total
	if delta > 0 and spent >= budget: return
	values[key] = next
	_refresh()

func _refresh() -> void:
	var total := 0
	for key in ORDER:
		total += int(values[key])
		value_labels[key].text = ("+" if int(values[key]) > 0 else "") + str(values[key])
	var displayed_total := total if not upgrade_mode else total - base_total
	remaining_label.text = ("本次提升：%d / %d" % [displayed_total, budget]) if upgrade_mode else ("已分配：%d / %d" % [total, budget])
	confirm_button.disabled = displayed_total != budget
