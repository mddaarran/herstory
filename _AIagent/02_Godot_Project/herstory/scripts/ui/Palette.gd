extends RefCounted
## Palette：原子朋克（atomic-punk）调色板 —— 全工程 UI 取色的唯一来源
##
## 用法：const Palette := preload("res://scripts/ui/Palette.gd")  然后 Palette.TEXT
## 意象：深底 + 氧化黄铜描边 + 琥珀高亮 + 青色仪器读数；字体与控件边角收锐。
##
## 留白规则（1:2:1）：控件内 上留白 : 文字 : 下留白 不得紧于 1 : 2 : 1，
##   即 padding >= 0.5 × font_size。本工程统一按 padding = 0.6 × font_size 落地（略松于下限）。

const BG            := "#0c1210"   # 页面底
const PANEL         := "#131b18"   # 侧栏 / 面板底
const CARD_BG       := "#101915"   # 卡片底
const CARD_BG_HOVER := "#18231e"   # 卡片 hover
const BORDER        := "#7d6636"   # 氧化黄铜描边
const BORDER_HOVER  := "#ffb648"   # 琥珀高亮描边
const LINE          := "#22302a"   # 分隔线
const BAR_BG        := "#1a2420"   # 进度条底

const TEXT          := "#e6ece4"   # 主文字（淡磷光）
const TEXT_DIM      := "#8fa093"   # 次要文字
const TEXT_FAINT    := "#5f6f65"   # 三级文字

const AMBER         := "#ffb648"   # 强调：标题 / 资产类
const TEAL          := "#5fd3c4"   # 仪器读数：骰子类
const JADE          := "#6fbf8b"   # 完全成功
const RUST          := "#d4553a"   # 失败
const RUST_HOVER    := "#ff6b52"   # 失败红的高亮档（危机事件卡 hover / 按压）
const BRASS         := "#c9a227"   # 次级强调（旧金色，仅作数值条中位）

## 1:2:1 落地系数：padding = PAD_RATIO × font_size（下限 0.5，本工程取 0.6）
const PAD_RATIO     := 0.6
## 控件最小内边距（左右比上下更宽，保证文本两侧留白常驻可见）
const PAD_SIDE_MIN  := 28.0

## 按字号算留白（不小于下限）
static func pad_for(font_size: float, min_pad: float = 16.0) -> float:
	return maxf(font_size * PAD_RATIO, min_pad)
