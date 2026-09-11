extends Control

signal goal_confirmed(goal: Dictionary)

const Palette := preload("res://scripts/ui/Palette.gd")
const GoalButtonScript := preload("res://scripts/ui/NotchButton.gd")
@onready var vbox: VBoxContainer = $VBox
var goals: Array = []
var selected_goal: Dictionary = {}
var selector: GridContainer

func _ready() -> void:
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size.x = 1000
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_load_goals()
	_build_selector()

func _load_goals() -> void:
	var file := FileAccess.open("res://data/goals.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		goals = parsed

func _build_selector() -> void:
	selector = GridContainer.new()
	selector.columns = 1
	selector.add_theme_constant_override("v_separation", 12)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for goal in goals:
		var button := Control.new()
		button.set_script(GoalButtonScript)
		button.text = "%s（%s达到%s）" % [_goal_name(str(goal.get("state", ""))), _state_name(str(goal.get("state", ""))), str(goal.get("target", 0))]
		button.font_size = 25
		button.min_width = 0
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("goal_id", goal.get("id", ""))
		button.pressed.connect(_select_goal.bind(goal))
		selector.add_child(button)
	vbox.add_child(selector)

func _select_goal(goal: Dictionary) -> void:
	selected_goal = goal.duplicate()
	GameState.selected_goal_id = str(goal.get("id", ""))
	GameState.selected_goal = selected_goal.duplicate()
	for child in selector.get_children():
		child.modulate = Color(Palette.AMBER if str(child.get_meta("goal_id", "")) == GameState.selected_goal_id else Palette.TEXT)
	goal_confirmed.emit(selected_goal)

func _state_name(state: String) -> String:
	return {"treasury":"财政", "gdp":"GDP", "population":"人口", "military":"军力", "territory":"领土"}.get(state, "数值")

func _goal_name(state: String) -> String:
	return {"treasury":"富甲天下型君主", "gdp":"百业兴旺型君主", "military":"兵锋所向型君主", "population":"生聚民安型君主", "territory":"开疆拓土型君主"}.get(state, "君主")
