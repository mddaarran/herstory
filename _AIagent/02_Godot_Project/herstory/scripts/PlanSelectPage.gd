extends Control
## PlanSelectPage：事件名 + 事件梗概 + 若干方案卡
## 方案卡 = NotchCard（原子朋克缺口角），卡内两行（标题 + 形容）均水平居中；整卡可点击。
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal plan_chosen(plan_id: String)

const Palette := preload("res://scripts/ui/Palette.gd")
const NotchCardScript := preload("res://scripts/ui/NotchCard.gd")
const AssetChip := preload("res://scripts/ui/AssetChip.gd")
const Trend := preload("res://scripts/AssetTrend.gd")

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var plans_box: VBoxContainer = $VBox/PlansBox

# 字号（放大后）
const FS_TITLE     := 56   # 事件名称
const FS_SUBTITLE  := 26   # 事件梗概
const FS_PLAN      := 32   # 方案卡标题行（卡内最大字号，决定 1:2:1 留白）
const FS_DIRECTION := 18   # 方案卡形容行

# 趋势行字号在 AssetChip.FS 内统一（18，与 direction 同级）

const CARD_HEIGHT  := 200  # 2026-09-10 由 142 抬到 200，容纳趋势行（direction 保留）
const CARD_GAP     := 18
const CARD_SEP     := 8    # 卡内行间距
const CHIP_GAP     := 10   # 趋势标签之间的间距

const ABILITY_NAMES := {
	"insight": "洞察",
	"influence": "驭人",
	"majesty": "威仪",
}

func setup(event: Dictionary) -> void:
	# 事件名称：居中大字（琥珀）
	title_label.text = event.get("title", "")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", FS_TITLE)
	title_label.add_theme_color_override("font_color", Color(Palette.AMBER))

	# 事件梗概：居中中号灰字
	subtitle_label.text = event.get("background", "")
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.add_theme_font_size_override("font_size", FS_SUBTITLE)
	subtitle_label.add_theme_color_override("font_color", Color(Palette.TEXT_DIM))

	plans_box.add_theme_constant_override("separation", CARD_GAP)

	for child in plans_box.get_children():
		child.queue_free()

	# 注意：_build_plan_card 内部会自己 add_child（卡片必须先入树，_ready 才会建出内容容器）
	for plan in event.get("plans", []):
		_build_plan_card(plan)

# ================= 方案卡 =================

func _build_plan_card(plan: Dictionary) -> Control:
	var ability_key: String = _safe_ability(plan.get("ability"))
	var ability_label: String = ABILITY_NAMES.get(ability_key, "洞察")
	# 能力修正在君主建卡阶段提供（GameState），事件方案本身不携带 ability_modifier
	var modifier: int = int(GameState.ability_modifiers.get(ability_key, 0))
	var mod_text: String = ("+" if modifier > 0 else "") + str(modifier)

	var card = NotchCardScript.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.build(FS_PLAN, CARD_HEIGHT)
	card.set_meta("plan_id", plan.get("id", ""))
	card.pressed.connect(_on_card_pressed.bind(card))
	plans_box.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", CARD_SEP)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.get_content().add_child(vbox)

	# 标题行：【能力 +N】方案名
	var head := Label.new()
	head.text = "【%s %s】%s" % [ability_label, mod_text, plan.get("name", "")]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_font_size_override("font_size", FS_PLAN)
	head.add_theme_color_override("font_color", Color(Palette.TEXT))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(head)

	# 形容行：direction
	var dir: String = plan.get("direction", "")
	if dir != "":
		var dir_lbl := Label.new()
		dir_lbl.text = dir
		dir_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dir_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dir_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dir_lbl.add_theme_font_size_override("font_size", FS_DIRECTION)
		dir_lbl.add_theme_color_override("font_color", Color(Palette.TEXT_DIM))
		dir_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(dir_lbl)

	# 趋势行：只列「完全成功」档会变动的 5 个资产值，名称 + ▲ / ▼。
	# 不给数值、不分强弱（2026-09-10 需求）；该方案不动任何资产值时不占行。
	# 顺序固定在 AssetTrend.ASSET_ORDER，与侧栏一致。
	var changes: Array = Trend.plan_changes(plan)
	if not changes.is_empty():
		var trend_row := HBoxContainer.new()
		trend_row.alignment = BoxContainer.ALIGNMENT_CENTER
		trend_row.add_theme_constant_override("separation", CHIP_GAP)
		trend_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trend_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for change in changes:
			trend_row.add_child(AssetChip.make(
				str(GameState.ASSET_LABELS.get(str(change["state"]), "")),
				int(change["dir"]) > 0,
				int(change["dir"]) < 0))
		vbox.add_child(trend_row)

	# 本页不显示判定门槛：门槛是事件的静态属性，与方案无关，
	# 放在方案卡上会被误读成「各方案难度不同」。统一挪到投骰页展示。
	return card

## 方案 ability 兜底：配置表缺值/为 null/非法 ID 时一律回落 insight，
## 避免 null 赋给 String 变量导致运行时崩溃（数据问题不应炸引擎）
func _safe_ability(raw) -> String:
	if raw is String and ABILITY_NAMES.has(raw):
		return raw
	if raw != null:
		push_warning("[PlanSelectPage] 方案 ability 非法(%s)，已回落 insight" % str(raw))
	return "insight"

# ================= 交互 =================

func _on_card_pressed(card) -> void:
	plan_chosen.emit(card.get_meta("plan_id", ""))
