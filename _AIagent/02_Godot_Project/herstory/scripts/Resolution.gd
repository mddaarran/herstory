class_name Resolution
## Resolution：骰子判定（纯规则，不碰 UI）
##
## 规则：2d6 + 能力修正；三档分界按主策划案 7.1（2026-09-02 定稿）
##   标准档（difficulty = 0）：2,3,4,5 | 6,7,8 | 9,10,11,12
##     失败      total <  6
##     有条件成功 6 <= total <  9
##     完全成功  total >= 9
##   概率 27.8% | 44.4% | 27.8%
##
## 难度 difficulty 是本事件的静态属性（写死在 events.json，运行时不变），
## 只调整本事件的成功门槛，不改骰值：
##   事件门槛 = 全局默认 + difficulty（difficulty 越大越难）
##
## 【门槛归事件、能力加骰面】2026-09-10 定稿
## 判定式：2d6 + 能力修正 >= 事件门槛
##   total = roll + modifier，与门槛比对。
## 门槛表达「这件事本身有多难」，与君主能力无关；能力修正加在骰面上。
## 因此 UI 一律显示**事件门槛**（玩家看得见页面上自己的骰面与修正，可自行核对）。
##
## 不引入任何「净难度折算／钳制」：那会让 UI 显示的门槛与判定真正生效的门槛
## 不一致（显示需 10、实际按 7 判），玩家无法复核，是最坏的一种不透明。
## 能力过强导致某档消失属于成长的自然结果，由事件难度分档（daily -3~+1 /
## crisis +1~+2 / major +3）与抽取权重承担，不在判定层兜底。

const TIER_FAIL := "fail"
const TIER_PARTIAL := "partial"
const TIER_FULL := "full"

## 标准档的全局默认门槛
const BASE_PARTIAL := 6
const BASE_FULL := 9

const TIER_NAMES := {
	TIER_FAIL: "失败",
	TIER_PARTIAL: "有条件成功",
	TIER_FULL: "完全成功",
}

## UI 显示用长名
const TIER_LONG_NAMES := {
	TIER_FAIL: "大失败",
	TIER_PARTIAL: "有条件成功",
	TIER_FULL: "大成功",
}

## 事件门槛（不含玩家能力修正）：完全成功 / 有条件成功。
## 这是事件的静态属性，同一事件下每个方案看到的门槛都一样。
static func thresholds_for(difficulty: int) -> Dictionary:
	return {
		"partial_at": BASE_PARTIAL + difficulty,
		"full_at": BASE_FULL + difficulty,
	}

static func resolve(dice: Array, modifier: int, difficulty: int = 0) -> Dictionary:
	var roll: int = int(dice[0]) + int(dice[1])
	var total: int = roll + modifier
	var th: Dictionary = thresholds_for(difficulty)
	var partial_at: int = int(th["partial_at"])
	var full_at: int = int(th["full_at"])
	var tier: String = TIER_FAIL
	if total >= full_at:
		tier = TIER_FULL
	elif total >= partial_at:
		tier = TIER_PARTIAL
	return {
		"dice": dice,
		"modifier": modifier,
		"roll": roll,
		"total": total,
		"tier": tier,
		"partial_at": partial_at,
		"full_at": full_at,
	}
