extends Control
## RoundEndPage：史官汇总页（事件 + 方案 + 史官记 + 不作为 + 本轮数值变化）
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal next_pressed
var _advancing := false

const Palette := preload("res://scripts/ui/Palette.gd")

@onready var year_label: Label = $VBox/YearLabel
@onready var event_title: Label = $VBox/EventTitle
@onready var plan_summary: Label = $VBox/PlanSummary
@onready var chronicle_label: RichTextLabel = $VBox/ChronicleLabel
@onready var death_label: RichTextLabel = $VBox/DeathLabel
@onready var ignored_box: VBoxContainer = $VBox/IgnoredBox
@onready var summary_label: RichTextLabel = $VBox/SummaryLabel
@onready var next_btn = $VBox/NextBtn

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
	next_btn.pressed.connect(func(): next_pressed.emit())
	next_btn.visible = false

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_next()

func _on_next() -> void:
	if _advancing:
		return
	_advancing = true
	next_pressed.emit()

func setup(round_number: int, event: Dictionary, plan: Dictionary, ability_key: String,
		tier: String, tier_long: String, ignored_event: Dictionary, state_summary: String) -> void:
	year_label.text = "第 %d 年 · 奏报裁决" % round_number
	year_label.add_theme_color_override("font_color", Color(Palette.AMBER))

	event_title.text = event.get("title", "")
	event_title.add_theme_color_override("font_color", Color(Palette.TEXT))

	var tier_color: String = TIER_COLORS.get(tier, Palette.TEXT)
	plan_summary.text = "解决方案：「%s」（%s · %s）" % [
		plan.get("name", ""),
		ABILITY_NAMES.get(ability_key, "洞察"),
		tier_long]
	plan_summary.add_theme_color_override("font_color", Color(tier_color))

	_set_rich(chronicle_label, "史官记：" + plan.get("chronicle", {}).get(tier, ""), 14, Palette.TEXT_DIM, true)
	var is_major := str(event.get("type", "")) == "major"
	death_label.visible = is_major
	if is_major:
		_set_rich(death_label, "君主死因：" + str(plan.get("death_cause", "君主最终归于寂静。")), 15, Palette.RUST, true)

	# 不作为信息
	for child in ignored_box.get_children():
		child.queue_free()
	if not ignored_event.is_empty():
		var ig: Dictionary = ignored_event.get("ignored", {})
		if not ig.is_empty():
			ignored_box.add_child(_make_rich(
				"未处理的奏报「%s · 不作为」：%s" % [
					ignored_event.get("title", ""), ig.get("text", "")],
				12, Palette.TEXT_FAINT, true))
			ignored_box.add_child(_make_rich("  — " + ig.get("chronicle", ""), 12, Palette.TEXT_DIM, true))

	_set_rich(summary_label, state_summary, 13, Palette.TEXT, true)
	if is_major:
		call_deferred("_reveal_major_lines", plan, tier)

func _reveal_major_lines(plan: Dictionary, tier: String) -> void:
	chronicle_label.bbcode_text = ""
	death_label.bbcode_text = ""
	await get_tree().create_timer(0.35).timeout
	_set_rich(chronicle_label, "史官记：" + plan.get("chronicle", {}).get(tier, ""), 14, Palette.TEXT_DIM, true)
	await get_tree().create_timer(0.55).timeout
	_set_rich(death_label, "君主死因：" + str(plan.get("death_cause", "君主最终归于寂静。")), 15, Palette.RUST, true)

func _set_rich(rt: RichTextLabel, text: String, font_size: int, color: String, wrap: bool) -> void:
	rt.bbcode_enabled = true
	rt.bbcode_text = "[font_size=%d][color=%s]%s[/color][/font_size]" % [int(font_size * 1.35), color, text]
	rt.fit_content = true
	rt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if wrap:
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _make_rich(text: String, font_size: int, color: String, wrap: bool) -> RichTextLabel:
	var rt := RichTextLabel.new()
	_set_rich(rt, text, font_size, color, wrap)
	return rt
