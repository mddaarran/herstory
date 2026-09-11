extends Panel
## Die：单枚骰子（3x3 点阵），暴露 set_value(n) 与内置滚动动画
## 注意：不声明 class_name —— 避免依赖 Godot 全局类缓存（外部新增脚本时缓存可能过期）

const Palette := preload("res://scripts/ui/Palette.gd")

@onready var grid: GridContainer = $Center/Grid

func _ready() -> void:
	set_value(1)

func set_value(n: int) -> void:
	for c in grid.get_children():
		c.queue_free()
	var pattern := _pip_pattern(n)
	for i in range(9):
		grid.add_child(_pip_panel(i in pattern))

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
	# 3*24 + 2*10 = 92，正好填满骰子内框，点阵水平/垂直居中。
	p.custom_minimum_size = Vector2(24, 24)
	p.size = Vector2(24, 24)
	var sb := StyleBoxFlat.new()
	if filled:
		sb.bg_color = Color(Palette.TEAL)
		for corner in ["top_left","top_right","bottom_left","bottom_right"]:
			sb.set("corner_radius_" + corner, 8)
	else:
		sb.bg_color = Color(0, 0, 0, 0)
	p.add_theme_stylebox_override("panel", sb)
	return p
