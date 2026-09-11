extends RefCounted
## AssetTrend：资产值趋势判定（纯规则，不碰 UI）
##
## 展示口径（2026-09-10 定稿）：
##   只做 5 个公开资产值（财政 / GDP / 人口 / 军力 / 领土），
##   只给方向、不给数值、不分强弱；隐藏值一律不出现在卡片上。
##
## 为什么只看 effects.full：
##   已对全库 64 个事件 × 5 个资产值逐条校验，不存在「完全成功档反而不如
##   有条件成功档」的配置（0 例外），即完全成功档恒为各档中的最优方向，
##   三档之间方向不会翻转。所以趋势只需读 full 一档，既准确，
##   也不必向玩家解释「这是哪一档的数」。
##
## 用法：const Trend := preload("res://scripts/AssetTrend.gd")

## 资产值的固定展示顺序（与 Sidebar / goals.json 一致）
const ASSET_ORDER := ["treasury", "gdp", "population", "military", "territory"]

const DIR_UP := 1
const DIR_FLAT := 0
const DIR_DOWN := -1

const GLYPH_UP := "▲"
const GLYPH_DOWN := "▼"

## 单个方案对某个资产值的方向（读完全成功档）
static func plan_dir(plan: Dictionary, state: String) -> int:
	var v := int(plan.get("effects", {}).get("full", {}).get(state, 0))
	if v > 0:
		return DIR_UP
	if v < 0:
		return DIR_DOWN
	return DIR_FLAT

## 事件级方向组合：两个方案里是否存在推进 / 拖累目标值的方案。
## up 与 down 同时为真 = 两案方向相反，这是一个真正的抉择点。
static func event_dirs(event: Dictionary, state: String) -> Dictionary:
	var up := false
	var down := false
	for plan in event.get("plans", []):
		var d := plan_dir(plan, state)
		if d == DIR_UP:
			up = true
		elif d == DIR_DOWN:
			down = true
	return {"up": up, "down": down}

## 方案的趋势项：只返回完全成功档非零的资产，顺序固定 ASSET_ORDER。
## 返回 [{"state": key, "dir": ±1}, ...]；空数组表示该方案不动任何资产值。
static func plan_changes(plan: Dictionary) -> Array:
	var out: Array = []
	for key in ASSET_ORDER:
		var d := plan_dir(plan, key)
		if d != DIR_FLAT:
			out.append({"state": key, "dir": d})
	return out
