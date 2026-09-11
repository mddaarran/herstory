extends Control
## NotchButton：原子朋克「缺口角」按钮（右上角切角）
##
## 1:2:1 留白：高度 = 字号 × 2.4，即 上留白 0.6×字号 : 文字 1.2×字号 : 下留白 0.6×字号，
## 换算成 字:留白 比例约 1 : 1，松于 1:2:1 的下限；左右留白取 2×字号，保证文本两侧可见留白。
##
## 用法（.tscn 里直接挂脚本，或代码里 new() 后设 text / font_size / min_width）

signal pressed

const Palette := preload("res://scripts/ui/Palette.gd")

## 按钮文案
@export var text: String = "确认"
## 字号（决定整颗按钮的高度）
@export var font_size: int = 22
## 最小宽度；<=0 时横向撑满父容器
@export var min_width: float = 240.0
## 切角边长；<=0 时按字号的 0.8 倍自动算
@export var notch: float = 0.0
## 禁用态：不响应点击，描边与文字转灰
@export var disabled: bool = false : set = set_disabled

func set_disabled(v: bool) -> void:
	disabled = v
	if _lbl != null:
		_lbl.add_theme_color_override("font_color",
			Color(Palette.TEXT_FAINT if disabled else Palette.TEXT))
	queue_redraw()

var _hover := false
var _held := false
var _lbl: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var h: float = font_size * 2.4                      # 1:2:1 → 上下各 0.6×字号
	custom_minimum_size = Vector2(maxf(min_width, 0.0), ceili(h))
	if min_width <= 0.0:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_lbl = Label.new()
	_lbl.text = text
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", font_size)
	_lbl.add_theme_color_override("font_color", Color(Palette.TEXT))
	_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)

	resized.connect(_on_resized)

func _on_resized() -> void:
	queue_redraw()

func _notch_size() -> float:
	if notch > 0.0:
		return notch
	return maxf(float(font_size) * 0.8, 14.0)

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var n: float = minf(_notch_size(), minf(s.x, s.y) * 0.35)
	var pts := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(s.x - n, 0.0),
		Vector2(s.x, n),
		Vector2(s.x, s.y),
		Vector2(0.0, s.y),
	])
	var bg: String = Palette.CARD_BG
	if _held and not disabled:
		bg = Palette.BORDER
	elif _hover and not disabled:
		bg = Palette.CARD_BG_HOVER
	draw_colored_polygon(pts, Color(bg))
	if _held and not disabled:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), Color(Palette.BORDER_HOVER, 0.35), 8.0, true)
	var line_col: String = Palette.BORDER
	if not disabled and (_hover or _held):
		line_col = Palette.BORDER_HOVER
	elif disabled:
		line_col = Palette.LINE
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]),
		Color(line_col), 2.0, true)

# ================= 交互 =================

func _on_mouse_entered() -> void:
	if disabled:
		return
	_hover = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hover = false
	_held = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_held = true
		queue_redraw()
	else:
		if _held:
			_held = false
			pressed.emit()
			queue_redraw()

func _enter_tree() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
