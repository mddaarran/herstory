extends RefCounted
## AssetChip：资产值小标签（原子朋克：深底 + 细黄铜描边 + 收锐边角）
##
## 只表达方向，不写数值、不分强弱：名称 + ▲ / ▼。
## ▲ 与 ▼ 同时出现 = 两个方案对该资产方向相反。
##
## 底色用页面底 Palette.BG，比卡片底更暗 → 读作「内嵌读数」；
## 这样卡片 hover（底色转 CARD_BG_HOVER）时标签依然分得开。
##
## 用法：const AssetChip := preload("res://scripts/ui/AssetChip.gd")
##       parent.add_child(AssetChip.make("财政", true, false))

const Palette := preload("res://scripts/ui/Palette.gd")
const Trend := preload("res://scripts/AssetTrend.gd")

const FS     := 18   # 名称与三角形同号
const PAD_H  := 16
const PAD_V  := 7
const RADIUS := 3    # 原子朋克：边角收锐
const SEP    := 6    # 名称与三角形之间

## up / down 决定三角形与配色；两者都 false 时只出名称（调用方通常不该这么用）
static func make(label_text: String, up: bool, down: bool) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.BG)
	sb.border_color = Color(Palette.BORDER, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = PAD_H
	sb.content_margin_right = PAD_H
	sb.content_margin_top = PAD_V
	sb.content_margin_bottom = PAD_V
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	row.add_child(_label(label_text, Palette.TEXT_DIM))
	if up:
		row.add_child(_label(Trend.GLYPH_UP, Palette.JADE))
	if down:
		row.add_child(_label(Trend.GLYPH_DOWN, Palette.RUST))
	return panel

static func _label(text: String, color: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FS)
	l.add_theme_color_override("font_color", Color(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
