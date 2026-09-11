import re
root = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory"
files = ["scripts/Main.gd","scripts/GameState.gd","scripts/EventManager.gd","scripts/Resolution.gd","scripts/Chronicler.gd"]
result = []
for f in files:
    c = open(root+"/"+f, encoding="utf-8").read()
    o = len(re.findall(r"[\(\[\{]", c))
    cl = len(re.findall(r"[\)\]\}]", c))
    funcs = len(re.findall(r"^\s*func ", c, re.M))
    result.append("%s : balance=%d funcs=%d" % (f, o-cl, funcs))
# 关键 API 引用检查
main = open(root+"/scripts/Main.gd", encoding="utf-8").read()
checks = {
  "GameState.roll_d6": "roll_d6" in open(root+"/scripts/GameState.gd",encoding="utf-8").read(),
  "GameState.apply_effects": "func apply_effects" in open(root+"/scripts/GameState.gd",encoding="utf-8").read(),
  "EventManager.PHASE_CRISIS": "PHASE_CRISIS" in open(root+"/scripts/EventManager.gd",encoding="utf-8").read(),
  "EventManager.current_draw": "current_draw" in open(root+"/scripts/EventManager.gd",encoding="utf-8").read(),
  "Resolution.resolve": "static func resolve" in open(root+"/scripts/Resolution.gd",encoding="utf-8").read(),
  "Resolution.TIER_NAMES": "TIER_NAMES" in open(root+"/scripts/Resolution.gd",encoding="utf-8").read(),
  "Chronicler.judge_verdict": "func judge_verdict" in open(root+"/scripts/Chronicler.gd",encoding="utf-8").read(),
  "Chronicler.VERDICT_NAMES": "VERDICT_NAMES" in open(root+"/scripts/Chronicler.gd",encoding="utf-8").read(),
  "Chronicler.VERDICT_TEXTS": "VERDICT_TEXTS" in open(root+"/scripts/Chronicler.gd",encoding="utf-8").read(),
}
result.append("--- API refs in Main.gd ---")
for k,v in checks.items():
    ok = (k.split(".")[0].lower() in main.lower()) and v
    result.append("%s : %s" % (k, "OK" if ok else "MISSING"))
open(root+"/_check2.txt","w",encoding="utf-8").write("\n".join(result))
