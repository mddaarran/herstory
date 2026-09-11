import re, json, os
root = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory"
files = ["scripts/Main.gd","scripts/GameState.gd","scripts/EventManager.gd","scripts/Resolution.gd","scripts/Chronicler.gd"]
lines = ["=== bracket balance ==="]
for f in files:
    c = open(os.path.join(root,f), encoding="utf-8").read()
    o = len(re.findall(r"[\(\[\{]", c))
    cl = len(re.findall(r"[\)\]\}]", c))
    lines.append("%s : balance=%d" % (f, o-cl))

# 关键 API 检查：Main 引用 & 定义必须存在
def fread(p):
    return open(p, encoding="utf-8").read()

main_src = fread(os.path.join(root,"scripts/Main.gd"))
gs_src = fread(os.path.join(root,"scripts/GameState.gd"))
em_src = fread(os.path.join(root,"scripts/EventManager.gd"))
res_src = fread(os.path.join(root,"scripts/Resolution.gd"))
chr_src = fread(os.path.join(root,"scripts/Chronicler.gd"))

# Main 调用的 GameState 成员
checks = [
    ("GameState.round_number", "var round_number" in gs_src),
    ("GameState.treasury", "var treasury" in gs_src),
    ("GameState.population", "var population" in gs_src),
    ("GameState.gdp", "var gdp" in gs_src),
    ("GameState.military", "var military" in gs_src),
    ("GameState.territory", "var territory" in gs_src),
    ("GameState.civilian_support", "var civilian_support" in gs_src),
    ("GameState.noble_support", "var noble_support" in gs_src),
    ("GameState.land_risk", "var land_risk" in gs_src),
    ("GameState.plague_progress", "var plague_progress" in gs_src),
    ("GameState.DEFAULT_ABILITY_MOD", "DEFAULT_ABILITY_MOD" in gs_src),
    ("GameState.civilian_tier_text", "func civilian_tier_text" in gs_src),
    ("GameState.noble_tier_text", "func noble_tier_text" in gs_src),
    ("GameState.land_tier_text", "func land_tier_text" in gs_src),
    ("GameState.blight_omen_text", "func blight_omen_text" in gs_src),
    ("GameState.apply_effects", "func apply_effects" in gs_src),
    ("GameState.reset", "func reset" in gs_src),
    ("GameState.roll_2d6", "func roll_2d6" in gs_src),
    ("GameState.roll_d6", "func roll_d6" in gs_src),
    ("Resolution.resolve", "static func resolve" in res_src),
    ("Resolution.TIER_NAMES", "TIER_NAMES" in res_src),
    ("Resolution.TIER_LONG_NAMES", "TIER_LONG_NAMES" in res_src),
    ("EventManager.PHASE_DAILY", "PHASE_DAILY" in em_src),
    ("EventManager.PHASE_CRISIS", "PHASE_CRISIS" in em_src),
    ("EventManager.PHASE_MAJOR", "PHASE_MAJOR" in em_src),
    ("EventManager.PHASE_ENDING", "PHASE_ENDING" in em_src),
    ("EventManager.phase", "var phase" in em_src),
    ("EventManager.crisis_handled", "crisis_handled" in em_src),
    ("EventManager.major_handled", "major_handled" in em_src),
    ("EventManager.reset", "func reset" in em_src),
    ("EventManager.draw_two_daily", "func draw_two_daily" in em_src),
    ("EventManager.get_crisis_event", "func get_crisis_event" in em_src),
    ("EventManager.get_major_event", "func get_major_event" in em_src),
    ("EventManager.check_progression", "func check_progression" in em_src),
    ("EventManager.current_draw", "var current_draw" in em_src),
    ("Chronicler.judge_verdict", "func judge_verdict" in chr_src),
    ("Chronicler.VERDICT_NAMES", "VERDICT_NAMES" in chr_src),
    ("Chronicler.VERDICT_TEXTS", "VERDICT_TEXTS" in chr_src),
]

lines.append("=== API cross-refs ===")
all_ok = True
for k, ok in checks:
    lines.append("%s : %s" % (k, "OK" if ok else "MISSING"))
    if not ok: all_ok = False

# events.json 结构
ev = json.load(open(os.path.join(root,"data/events.json"), encoding="utf-8"))
lines.append("=== events.json ===")
lines.append("daily count = %d" % len(ev["daily"]))
lines.append("crisis title = %s" % ev["crisis"]["title"])
lines.append("major title = %s" % ev["major"]["title"])
allowed_state_keys = {"treasury","population","gdp","military","territory","civilian_support","noble_support","land_risk","plague_progress"}
for e in ev["daily"] + [ev["crisis"], ev["major"]]:
    for p in e["plans"]:
        if "ability_modifier" not in p:
            lines.append("MISSING ability_modifier: %s/%s" % (e["id"], p["id"])); all_ok=False
        for tier in ("full","partial","fail"):
            eff = p["effects"][tier]
            for key in eff:
                if key not in allowed_state_keys:
                    lines.append("UNKNOWN state key %s in %s/%s/%s" % (key, e["id"], p["id"], tier)); all_ok=False
lines.append("ALL_OK" if all_ok else "HAS_ERRORS")

open(os.path.join(root,"_check3.txt"),"w",encoding="utf-8").write("\n".join(lines))
print("done")
