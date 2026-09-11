import re, json
root = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory"
files = ["scripts/Main.gd","scripts/GameState.gd","scripts/EventManager.gd","scripts/Resolution.gd","scripts/Chronicler.gd"]
lines = []
for f in files:
    raw = open(root+"/"+f, encoding="utf-8").read()
    code = re.sub(r"#.*$", "", raw, flags=re.M)
    o = len(re.findall(r"[\(\[\{]", code))
    cl = len(re.findall(r"[\)\]\}]", code))
    funcs = re.findall(r"^func (\w+)", raw, re.M)
    lines.append("%s : paren_balance=%d funcs=%d" % (f, o-cl, len(funcs)))

# verify no references to removed _log_entry / log_view
main = open(root+"/scripts/Main.gd", encoding="utf-8").read()
for removed in ["_log_entry", "_clear_log", "log_view"]:
    if removed in main:
        lines.append("REGRESSION: '%s' still referenced" % removed)

# verify events.json still parseable
d = json.load(open(root+"/data/events.json", encoding="utf-8"))
for e in d["daily"]+[d["crisis"], d["major"]]:
    for p in e["plans"]:
        assert "ability_modifier" in p, "missing ability_modifier"
        assert p["ability"] in ("insight","persuasion","majesty"), "bad ability"
lines.append("events.json : OK plans=%d" % sum(len(e["plans"]) for e in d["daily"]+[d["crisis"], d["major"]]))

# verify project.godot
pg = open(root+"/project.godot", encoding="utf-8").read()
for key in ("window/size/viewport_width=1920", "window/size/viewport_height=1080"):
    assert key in pg, "missing %s" % key
lines.append("project.godot : viewport fixed")

open(root+"/_check.txt","w",encoding="utf-8").write("\n".join(lines))