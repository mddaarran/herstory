class_name Chronicler
## Chronicler：史官反馈文本取回与终局结语判定（纯逻辑，不碰 UI）

const VERDICT_FIXED := "fixed"      # 循环被修正
const VERDICT_CONTINUE := "continue" # 循环继续
const VERDICT_ACCEL := "accelerate"  # 循环加速
const VERDICT_BROKEN := "broken"     # 循环断裂

const VERDICT_NAMES := {
	VERDICT_FIXED: "循环被修正",
	VERDICT_CONTINUE: "循环继续",
	VERDICT_ACCEL: "循环加速",
	VERDICT_BROKEN: "循环断裂",
}

const VERDICT_TEXTS := {
	VERDICT_FIXED: "史官落笔：粮食与火穗在这一年取得了暂时的平衡。丰年将至，万灯未熄，而土地终于有了一口气。后世将记得，一位女帝在丰收与灯火之间，选择了让循环慢下来。",
	VERDICT_CONTINUE: "史官落笔：国家维持着繁荣，代价被推迟到下一代。灯火依旧通明，土地却已在暗处积攒着疲惫。后世将记得，这位女帝延续了循环，却没有终结它。",
	VERDICT_ACCEL: "史官落笔：短期的发展被推到了极致，长期的风险也随之加深。火籽炉彻夜轰鸣，田垄在灰白斑块下喘息。后世将记得，这位女帝把循环推得更快、更亮、也更险。",
	VERDICT_BROKEN: "史官落笔：粮食、能源与社会秩序出现了重大崩溃。万灯熄灭，田野荒芜。后世将记得，这位女帝的统治终结了一场循环——以最沉重的方式。",
}

## 终局结语判定：依据隐藏数值与人口综合状态
func judge_verdict() -> String:
	var gs := GameState
	if gs.population <= 1000 or gs.radiation_risk >= 90 or gs.civilian_support <= 25:
		return VERDICT_BROKEN
	if gs.radiation_risk <= 40 and gs.civilian_support >= 50 and gs.population >= 1150:
		return VERDICT_FIXED
	if gs.radiation_risk >= 70 or (gs.military >= 600 and gs.radiation_risk >= 55):
		return VERDICT_ACCEL
	return VERDICT_CONTINUE

func major_ending_text(event: Dictionary, plan: Dictionary, tier: String, title: String) -> String:
	var event_title := str(event.get("title", "终局事件"))
	var plan_name := str(plan.get("name", "未知方案"))
	var outcome := str(plan.get("chronicle", {}).get(tier, "局势走向了无法挽回的结局。"))
	var death_cause := str(plan.get("death_cause", "君主最终归于寂静。"))
	return "[color=#899f92]在[/color] [color=#ffb648]「%s」[/color][color=#899f92]的局面下，[/color]\n\n[color=#899f92]君主选择了[/color] [color=#ffb648]「%s」[/color][color=#899f92]。%s[/color]\n\n[color=#d4553a]%s[/color]\n\n[color=#899f92]因此，后世称她为[/color] [font_size=64][color=#ffb648]「%s」[/color][/font_size][color=#899f92]。[/color]" % [event_title, plan_name, outcome, death_cause, title]

func base_title_for_goal(goal: Dictionary) -> String:
	match str(goal.get("state", "")):
		"treasury": return "富甲天下型君主"
		"gdp": return "百业兴旺型君主"
		"military": return "兵锋所向型君主"
		"population": return "生聚民安型君主"
		"territory": return "开疆拓土型君主"
	return "无名之君"
