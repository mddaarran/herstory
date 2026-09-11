extends Control
## DicePage：能力 + 修正 + 两枚骰子 + 总数 + 档位 + 继续按钮
## 骰子走青色（仪器读数），档位走 青绿 / 琥珀 / 铁锈
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal continue_pressed
var _advancing := false

const Palette := preload("res://scripts/ui/Palette.gd")

@onready var ability_header: Label = $VBox/AbilityHeader
@onready var mod_label: Label = $VBox/ModLabel
@onready var die1 = $VBox/DiceRow/Die1
@onready var die2 = $VBox/DiceRow/Die2
@onready var total_label: Label = $VBox/TotalLabel
@onready var modifier_line: Label = $VBox/ModifierLine
@onready var final_total_label: Label = $VBox/FinalTotalLabel
@onready var tier_label: Label = $VBox/TierLabel
@onready var thresh_label: Label = $VBox/ThreshLabel
@onready var cont_btn = $VBox/ContBtn

const ABILITY_NAMES := {
	"insight": "洞察",
	"influence": "驭人",
	"majesty": "威仪",
}
const TIER_COLORS := {
	"full": Palette.JADE,
	"partial": Palette.AMBER,
	"fail": Palette.RUST,
}

func _ready() -> void:
	cont_btn.pressed.connect(_on_continue)
	cont_btn.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not cont_btn.disabled:
		_on_continue()
	elif event is InputEventScreenTouch and event.pressed and not cont_btn.disabled:
		_on_continue()

func _on_continue() -> void:
	if _advancing:
		return
	_advancing = true
	continue_pressed.emit()

func setup(ability_key: String, modifier: int, dice: Array, total: int, tier: String,
		tier_long: String, partial_at: int, full_at: int) -> void:
	var ability_label: String = ABILITY_NAMES.get(ability_key, "洞察")
	var mod_text: String = ("+" if modifier > 0 else "") + str(modifier)

	ability_header.text = ability_label
	ability_header.add_theme_color_override("font_color", Color(Palette.TEXT))
	mod_label.text = "修正 " + mod_text
	mod_label.add_theme_color_override("font_color", Color(Palette.AMBER))

	# 先展示纯骰子点数，动画结束后再展示能力修正后的结果。
	var raw_total := int(dice[0]) + int(dice[1])
	total_label.text = ""
	total_label.add_theme_color_override("font_color", Color(Palette.TEAL))
	tier_label.text = tier_long
	tier_label.visible = false
	tier_label.add_theme_color_override("font_color", Color(TIER_COLORS.get(tier, Palette.TEXT)))

	# 显示事件门槛（不折算君主能力）：门槛是事件的静态属性，同一事件每个方案都一样。
	# 玩家用本页的「骰面 + 修正 = 总数」直接与门槛核对。
	thresh_label.text = "事件门槛：≥%d 大成功 ｜ ≥%d 有条件成功 ｜ <%d 失败" % [
		full_at, partial_at, partial_at]
	thresh_label.add_theme_color_override("font_color", Color(Palette.TEXT_FAINT))

	die1.set_value(int(dice[0]))
	die2.set_value(int(dice[1]))
	die1.rotation = -0.14
	die2.rotation = 0.14

	cont_btn.disabled = true
	modifier_line.text = ""
	final_total_label.text = ""
	modifier_line.visible = false
	final_total_label.visible = false
	_run_dice_anims(int(dice[0]), int(dice[1]), modifier, total)

func _run_dice_anims(target1: int, target2: int, modifier: int, final_total: int) -> void:
	var raw_total := target1 + target2
	for i in range(8):
		die1.set_value(randi_range(1, 6))
		die2.set_value(randi_range(1, 6))
		await get_tree().create_timer(0.07).timeout
	die1.set_value(target1)
	die2.set_value(target2)
	await get_tree().create_timer(0.35).timeout
	total_label.text = str(raw_total)
	total_label.visible = true
	await get_tree().create_timer(0.45).timeout
	if modifier > 0:
		modifier_line.text = "+%d" % modifier
	elif modifier < 0:
		modifier_line.text = "-%d" % abs(modifier)
	else:
		modifier_line.text = "无修正"
	modifier_line.visible = true
	await get_tree().create_timer(0.45).timeout
	final_total_label.text = str(final_total)
	final_total_label.visible = true
	await get_tree().create_timer(0.55).timeout
	tier_label.visible = true
	cont_btn.disabled = false
