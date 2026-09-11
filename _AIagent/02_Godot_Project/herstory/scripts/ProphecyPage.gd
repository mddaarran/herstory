extends Control
## ProphecyPage：建卡完成后的独立预言页
##
## 表现：预言正文逐行淡入，居中大字（节奏与终局结语页一致）；全部展现完毕后出现「继续」。
## 数据源：GameState.prophecy_text，唯一来源 = data/major_events.json 的 prophecy 字段（主策划案 6.4）。
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal confirmed

const Palette := preload("res://scripts/ui/Palette.gd")

## 展现节奏（秒）：每行的淡入时长、淡入结束后的停顿
const FADE_IN := 1.0
const LINE_GAP := 0.55
## 大字字号（与终局结语页的 font_size=40 对齐；本工程默认字体偏小，统一按 ×1.35 落地）
const BIG_FONT := 30

@onready var lines_box: VBoxContainer = $Center/VBox/Lines
@onready var continue_btn = $Center/VBox/ContinueBtn

var _skip := false
var _revealed := false

func _ready() -> void:
	continue_btn.visible = false
	continue_btn.pressed.connect(func(): confirmed.emit())
	call_deferred("_reveal", GameState.prophecy_text)

func _input(event: InputEvent) -> void:
	# 展现中点击任意处 = 跳过动画，直接看全文
	if _revealed:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip = true

func _reveal(text: String) -> void:
	var lines: PackedStringArray = text.split("\n", false)
	if lines.is_empty():
		_finish()
		return
	for line in lines:
		var label := _make_big_label(line)
		lines_box.add_child(label)
		if _skip:
			label.modulate.a = 1.0
			continue
		label.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(label, "modulate:a", 1.0, FADE_IN)
		await tw.finished
		if _skip:
			label.modulate.a = 1.0
			continue
		await get_tree().create_timer(LINE_GAP).timeout
	for label in lines_box.get_children():
		label.modulate.a = 1.0
	_finish()

func _finish() -> void:
	_revealed = true
	continue_btn.visible = true

func _make_big_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", int(BIG_FONT * 1.35))
	label.add_theme_color_override("font_color", Color(Palette.TEXT))
	return label
