extends Panel
## Sidebar：左侧栏（三项能力 + 5 国势数值条 + 隐藏值精确数值）
## 由 Main.gd 在每次状态变更时调用 refresh() 重建
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）
##

const Palette := preload("res://scripts/ui/Palette.gd")

const ABILITY_NAMES := {
	"insight": "洞察",
	"influence": "驭人",
	"majesty": "威仪",
}
const ABILITY_ORDER := ["insight", "influence", "majesty"]

const STATE_LABELS := {
	"treasury": "财政",
	"gdp": "GDP",
	"population": "人口",
	"military": "军力",
	"territory": "领土",
}
const STATE_ORDER := ["treasury", "gdp", "population", "military", "territory"]

@onready var body: VBoxContainer = $Margin/Body
var _last_asset_values: Dictionary = {}
var _asset_deltas: Dictionary = {}

func _ready() -> void:
	refresh()

func refresh() -> void:
	var current_assets := _asset_values()
	_asset_deltas = {}
	for key in STATE_ORDER:
		if _last_asset_values.has(key):
			var delta: int = int(current_assets[key]) - int(_last_asset_values[key])
			if delta != 0:
				_asset_deltas[key] = delta
	_last_asset_values = current_assets
	for child in body.get_children():
		child.queue_free()

	body.add_theme_constant_override("separation", 6)

	body.add_child(_make_label("中央议厅 · 国势总览", 14, Palette.AMBER))
	body.add_child(_make_label("—— 第 %d 年 ——" % GameState.round_number, 13, Palette.TEXT_DIM))
	body.add_child(_divider())

	# 三项能力 modifier：按截图改为横向三列，能力名与修正分层显示。
	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	ability_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in ABILITY_ORDER:
		var ability_col := VBoxContainer.new()
		ability_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := _make_label(ABILITY_NAMES[key], 14, Palette.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ability_col.add_child(name_label)
		var mod: int = int(GameState.ability_modifiers.get(key, 0))
		var mod_label := _make_label(("+" if mod > 0 else "") + str(mod), 20, Palette.TEXT)
		mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod_label.custom_minimum_size.y = 38
		var mod_bg := StyleBoxFlat.new()
		mod_bg.bg_color = Color(Palette.CARD_BG_HOVER)
		mod_label.add_theme_stylebox_override("normal", mod_bg)
		ability_col.add_child(mod_label)
		ability_row.add_child(ability_col)
	body.add_child(ability_row)
	body.add_child(_divider())

	# 5 个国势数值条
	if not GameState.selected_goal.is_empty():
		body.add_child(_make_label("目标：%s" % GameState.selected_goal.get("name", ""), 14, Palette.AMBER, true))
	for k in STATE_ORDER:
		body.add_child(_make_meter(STATE_LABELS[k], _state_value(k), _state_max(k), int(_asset_deltas.get(k, 0))))
	body.add_child(_divider())

	# 尾部伸缩，把内容顶在上面
	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tail)

	# 底部常驻：全局唯一预言（暗色三级文字，仅作氛围提示，不参与任何判定）
	if not GameState.prophecy_text.is_empty():
		body.add_child(_divider())
		body.add_child(_make_prophecy_footer(GameState.prophecy_text))

func _state_value(key: String) -> int:
	match key:
		"treasury": return GameState.treasury
		"gdp": return GameState.gdp
		"population": return GameState.population
		"military": return GameState.military
		"territory": return GameState.territory
	return 0

func _asset_values() -> Dictionary:
	var values := {}
	for key in STATE_ORDER:
		values[key] = _state_value(key)
	return values

func clear_change_highlights() -> void:
	if _asset_deltas.is_empty():
		return
	_asset_deltas = {}
	refresh()

func _state_max(key: String) -> int:
	return int(GameState.STATE_CONFIG.get(key, {}).get("max", 100))

func _make_label(text: String, font_size: int, color: String = Palette.TEXT, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(font_size * 1.35))
	label.add_theme_color_override("font_color", Color(color))
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## 底部预言：三级暗色 + 居中 + 小字号，常驻但不抢视线
func _make_prophecy_footer(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", int(11 * 1.35))
	label.add_theme_color_override("font_color", Color(Palette.TEXT_FAINT))
	label.add_theme_constant_override("line_spacing", 6)
	return label

func _divider() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.LINE)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_meter(metric_name: String, value: int, maxv: int, delta: int = 0) -> Control:
	var vb := HBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size.y = 24
	var row := HBoxContainer.new()
	var name_label := _make_label(metric_name, 12, Palette.TEXT_DIM)
	name_label.custom_minimum_size.x = 48
	row.add_child(name_label)
	var val := _make_label(str(value), 17, Palette.TEXT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	if delta != 0:
		var delta_label := _make_label("%s%d" % [("+" if delta > 0 else ""), delta], 15,
			Palette.JADE if delta > 0 else Palette.RUST)
		delta_label.add_theme_constant_override("outline_size", 4)
		row.add_child(delta_label)
	vb.add_child(row)
	return vb
