extends Control
signal confirmed

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(700, 360)
	root.add_theme_constant_override("separation", 24)
	center.add_child(root)
	var title := Label.new()
	title.text = "登基"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	root.add_child(title)
	var text := Label.new()
	text.text = "你的能力已经确定。\n从今天起，你将以自己的方式统治这个国家。"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 24)
	root.add_child(text)
	var button := Button.new()
	button.text = "开始第一年"
	button.custom_minimum_size = Vector2(240, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func(): confirmed.emit())
	root.add_child(button)
