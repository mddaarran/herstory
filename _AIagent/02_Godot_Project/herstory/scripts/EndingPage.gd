extends Control
## EndingPage：终局结语 + 史官叙述 + 重新开始
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal restart_pressed

const Palette := preload("res://scripts/ui/Palette.gd")

@onready var verdict_label: Label = $VBox/VerdictLabel
@onready var text_label: RichTextLabel = $VBox/TextLabel
@onready var state_label: Label = $VBox/StateLabel
@onready var restart_btn = $VBox/RestartBtn

func _ready() -> void:
	restart_btn.pressed.connect(func(): restart_pressed.emit())

func setup(verdict_name: String, verdict_text: String, state_summary: String) -> void:
	var is_major := verdict_text.find("[color=") >= 0
	if is_major:
		$VBox/Header.visible = false
		$VBox/VerdictLabel.visible = false
		$VBox/StateLabel.visible = false
		$VBox/Spacer.visible = false
		$VBox/RestartBtn.visible = false
		$VBox/TextLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		$VBox/TextLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		$VBox/TextLabel.custom_minimum_size = Vector2(760, 0)
		$VBox/TextLabel.add_theme_constant_override("line_separation", 28)
	verdict_label.text = "—— %s ——" % verdict_name
	verdict_label.add_theme_color_override("font_color", Color(Palette.AMBER))
	text_label.bbcode_enabled = true
	if verdict_name == "君主已归于寂静" or verdict_text.find("[color=") >= 0:
		call_deferred("_reveal_history_lines", verdict_text)
	else:
		text_label.text = "[font_size=%d][color=%s]%s[/color][/font_size]" % [
			int(14 * 1.35), Palette.TEXT, verdict_text]
	text_label.fit_content = true
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.text = state_summary
	state_label.add_theme_color_override("font_color", Color(Palette.TEXT_DIM))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not $VBox/RestartBtn.visible:
		restart_pressed.emit()

func _reveal_history_lines(text: String) -> void:
	text_label.text = ""
	for line in text.split("\n\n"):
		var current := text_label.text
		if not current.is_empty():
			current += "\n\n"
		text_label.text = current + "[font_size=40]" + line + "[/font_size]"
		await get_tree().create_timer(0.75).timeout
