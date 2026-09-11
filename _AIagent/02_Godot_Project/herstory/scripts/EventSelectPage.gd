extends Control
## EventSelectPage：两张方形事件卡，择一（点卡即选中，无按钮）
## 卡片 = NotchCard（原子朋克缺口角），卡内居中两行，整卡可点击，hover 换描边色
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal event_chosen(event: Dictionary)

const Palette := preload("res://scripts/ui/Palette.gd")
const NotchCardScript := preload("res://scripts/ui/NotchCard.gd")
const AssetChip := preload("res://scripts/ui/AssetChip.gd")
const Trend := preload("res://scripts/AssetTrend.gd")

@onready var hint_label: Label = $VBox/Hint
@onready var cards_row: HBoxContainer = $VBox/CardsRow

## 危机 / 大议事件 id 集合（由 Main 从 EventManager 传入）。
## 本页不持有 EventManager 引用，只按 id 判断卡片配色：
##   日常 = 黄铜描边 + 琥珀标题 ｜ 危机 = 红描边 + 红标题 ｜ 大议 = 红描边 + 红标题 + 外发光
var _crisis_ids: Dictionary = {}
var _major_ids: Dictionary = {}

# 字号
const FS_HINT  := 26   # 顶部提示
const FS_TITLE := 42   # 事件名（卡内最大字号，决定 1:2:1 留白）
const FS_DESC  := 18   # 事件梗概
# 卡底目标行字号在 AssetChip.FS 内统一（18，与事件梗概同级）

const CARD_HEIGHT := 520
const CARD_GAP    := 28
const CARD_SEP    := 22   # 卡内标题与梗概的间距

const HINT_TEXT := "两份奏报同时呈上，择一亲理。"
const HINT_TEXT_SINGLE := "仅此一项呈上，无可回避，须即行裁示。"

## 单卡时两侧留白的伸缩权重：卡 1 : 留白 0.5 → 卡宽与双卡时单张同宽并居中
const SINGLE_CARD_SIDE_RATIO := 0.5

## crisis_ids：危机事件 id 集合（EventManager.crisis_ids），命中的卡描边与标题走红色。
## major_ids ：大议事件 id 集合（EventManager.major_ids），命中的卡走亮金并带外发光。
## 都不传则全部按日常卡处理（黄铜描边 + 琥珀标题）。
func setup(cards: Array, crisis_ids: Dictionary = {}, major_ids: Dictionary = {}) -> void:
	_crisis_ids = crisis_ids
	_major_ids = major_ids
	var single: bool = cards.size() == 1
	hint_label.text = HINT_TEXT_SINGLE if single else HINT_TEXT
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", FS_HINT)
	hint_label.add_theme_color_override("font_color", Color(Palette.TEXT_DIM))

	cards_row.add_theme_constant_override("separation", CARD_GAP)

	for child in cards_row.get_children():
		child.queue_free()

	# 只有一张卡（危机无可回避 / Major 大议）时：左右各垫一个同权伸缩件，
	# 让卡保持与双卡时相同的宽度并居中，避免一张卡横向铺满整个版面。
	if single:
		cards_row.add_child(_make_side_spacer())

	# 注意：_build_event_card 内部会自己 add_child（卡片必须先入树，_ready 才会建出内容容器）
	for ev in cards:
		_build_event_card(ev)

	if single:
		cards_row.add_child(_make_side_spacer())

## 单卡时的侧边留白件（不响应鼠标，只参与伸缩分配）
func _make_side_spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.size_flags_stretch_ratio = SINGLE_CARD_SIDE_RATIO
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp

# ================= 事件卡 =================

func _build_event_card(event: Dictionary) -> Control:
	var card = NotchCardScript.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.build(FS_TITLE, CARD_HEIGHT)
	card.set_meta("event", event)
	# 卡片配色按事件类型分三档：描边与标题同色系
	var eid := str(event.get("id", ""))
	var title_col: String = Palette.AMBER
	if _crisis_ids.has(eid):
		# 危机：红色描边 + 红色标题
		card.set_border_colors(Palette.RUST, Palette.RUST_HOVER)
		title_col = Palette.RUST
	elif _major_ids.has(eid):
		# 大议：同样是红色描边 + 红色标题，但额外带一圈外发光（光晕取 RUST_HOVER）。
		# 大议历来是单卡独占呈上，不会与危机卡同屏，红与红之间无需靠色相区分，光晕即是标记。
		card.set_border_colors(Palette.RUST, Palette.RUST_HOVER, true)
		title_col = Palette.RUST
	card.pressed.connect(_on_card_pressed.bind(card))
	cards_row.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", CARD_SEP)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.get_content().add_child(vbox)

	# 顶部伸缩 spacer，把内容压到垂直居中
	var sp_top := Control.new()
	sp_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sp_top)

	# 标题：事件名（居中大字）。颜色跟随卡片类型（日常琥珀 / 危机红 / 大议亮金）
	var title := Label.new()
	title.text = event.get("title", "事件")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", FS_TITLE)
	title.add_theme_color_override("font_color", Color(title_col))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# 描述：事件背景梗概（居中灰字）
	var desc := Label.new()
	desc.text = event.get("background", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", FS_DESC)
	desc.add_theme_color_override("font_color", Color(Palette.TEXT_DIM))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc)

	# 底部伸缩 spacer
	var sp_bot := Control.new()
	sp_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sp_bot)

	# 卡底目标行：只对君主当前目标判定（2026-09-10 需求）
	# 两案都与目标无关时不加这一行，卡片高度由伸缩件自然撑满
	var goal_chip := _build_goal_chip(event)
	if goal_chip != null:
		vbox.add_child(goal_chip)

	return card

# ================= 卡底目标行 =================

## 目标值小标签：名称 + ▲ / ▼（不给数值、不分强弱）。
## ▲ 有方案能推进 ｜ ▼ 无方案推进但有方案拖累 ｜ ▲▼ 两案方向相反 ｜ 都无则不显示。
## 目标未选（调试/异常）或与目标无关时返回 null，调用方跳过该行。
func _build_goal_chip(event: Dictionary) -> Control:
	var goal_state: String = str(GameState.selected_goal.get("state", ""))
	if goal_state == "":
		return null
	var dirs: Dictionary = Trend.event_dirs(event, goal_state)
	var up: bool = bool(dirs["up"])
	var down: bool = bool(dirs["down"])
	if not up and not down:
		return null
	var chip := AssetChip.make(str(GameState.ASSET_LABELS.get(goal_state, "")), up, down)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return chip

# ================= 交互 =================

func _on_card_pressed(card) -> void:
	event_chosen.emit(card.get_meta("event"))
