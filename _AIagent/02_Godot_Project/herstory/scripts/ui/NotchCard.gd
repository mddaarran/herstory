extends Control
## NotchCard：原子朋克「缺口角」卡片（右上角切角）
##
## 为什么不用 PanelContainer：缺口角需要真正的透明三角形，
## StyleBoxFlat 只能画圆角、画不出切角，所以整块背景与描边都走 _draw()。
##
## 1:2:1 留白：pad_v / pad_h 默认按 Palette.pad_for(最大字号) 计算，
## 任何情况下 padding >= 0.5 × font_size。
##
## 用法：
##   var card := NotchCardScript.new()
##   card.build(最大字号)          # 设定留白与最小高度
##   card.get_content().add_child(vbox)
##   card.pressed.connect(...)

signal pressed
signal hover_changed(on: bool)

const Palette := preload("res://scripts/ui/Palette.gd")

var _hover := false
var _held := false
var _content: MarginContainer
var _pad_h: float = 28.0
var _pad_v: float = 24.0
var _notch: float = 22.0
## 描边配色覆盖（留空 = 默认 黄铜/琥珀）。危机事件卡传 Palette.RUST 系。
var _border_idle: String = ""
var _border_hover: String = ""
## 外发光（大议 major 卡用）：沿描边向外叠几圈更宽更淡的同色线，模拟光晕。
## 用多层描边而非 shader/WorldEnvironment，是为了不引入全局后处理、不影响其他页面。
var _glow := false

## 建卡：传入卡内最大字号，按 1:2:1 规则自动铺留白
## font_size  卡内最大字号
## min_height 卡片最小高度（不传则由内容决定 + 上下留白）
## notch      切角边长（默认 = 字号 × 0.7，不小于 16）
func build(font_size: float, min_height: float = 0.0, notch: float = 0.0) -> void:
	_pad_v = Palette.pad_for(font_size, 20.0)
	_pad_h = maxf(Palette.pad_for(font_size, 20.0) * 1.4, Palette.PAD_SIDE_MIN)
	_notch = notch if notch > 0.0 else maxf(font_size * 0.7, 16.0)
	if min_height > 0.0:
		custom_minimum_size = Vector2(0, min_height)
	_refresh_margins()

func _refresh_margins() -> void:
	if _content == null:
		return
	_content.add_theme_constant_override("margin_left", int(_pad_h))
	_content.add_theme_constant_override("margin_right", int(_pad_h))
	_content.add_theme_constant_override("margin_top", int(_pad_v))
	_content.add_theme_constant_override("margin_bottom", int(_pad_v))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = MarginContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_refresh_margins()
	resized.connect(_on_resized)

func _on_resized() -> void:
	queue_redraw()

## 内容容器：往这里塞 VBox / Label
func get_content() -> Control:
	return _content

## 覆盖描边配色。两色都传空串可恢复默认。
## glow = true 时沿描边外叠一圈光晕（大议卡用）。
func set_border_colors(idle: String, hover: String, glow: bool = false) -> void:
	_border_idle = idle
	_border_hover = hover
	_glow = glow
	queue_redraw()

func _outline(pts: PackedVector2Array) -> PackedVector2Array:
	return PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]])

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var n: float = minf(_notch, minf(s.x, s.y) * 0.35)
	var pts := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(s.x - n, 0.0),
		Vector2(s.x, n),
		Vector2(s.x, s.y),
		Vector2(0.0, s.y),
	])
	draw_colored_polygon(pts, Color(Palette.CARD_BG_HOVER if _hover else Palette.CARD_BG))
	# 自定义描边时，按压高亮也走自定义色（否则危机卡会闪成琥珀）
	var has_custom := _border_idle != ""
	var idle_col: String = _border_idle if has_custom else Palette.BORDER
	var accent_col: String = _border_hover if has_custom else Palette.BORDER_HOVER
	# 外发光：先画（在描边之下），由外向内宽度递减、alpha 递增，形成柔和光晕。
	# 光晕取 hover（更亮）那档色——没有自定义色时退回默认高亮琥珀。
	if _glow:
		var outline := _outline(pts)
		var glow_col: String = accent_col if has_custom else Palette.BORDER_HOVER
		draw_polyline(outline, Color(glow_col, 0.08), 32.0, true)
		draw_polyline(outline, Color(glow_col, 0.14), 20.0, true)
		draw_polyline(outline, Color(glow_col, 0.22), 11.0, true)
	if _held:
		draw_polyline(_outline(pts), Color(accent_col, 0.35), 8.0, true)
	var line_col: String = accent_col if _hover else idle_col
	if _held:
		line_col = accent_col if has_custom else Palette.AMBER
	draw_polyline(_outline(pts), Color(line_col), 2.0, true)

# ================= 交互 =================

func _on_mouse_entered() -> void:
	_hover = true
	hover_changed.emit(true)
	queue_redraw()

func _on_mouse_exited() -> void:
	_hover = false
	hover_changed.emit(false)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_held = true
		queue_redraw()
		accept_event()
	else:
		if _held:
			_held = false
			queue_redraw()
			pressed.emit()

func _enter_tree() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
