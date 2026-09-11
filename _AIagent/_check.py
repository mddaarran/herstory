import json, sys, re

root = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory"
out = []
ok = True

# 1) JSON 结构与内容校验
d = json.load(open(root + r"\data\events.json", encoding="utf-8"))
abilities = {"insight", "persuasion", "majesty"}
for e in d["daily"] + [d["crisis"], d["major"]]:
    for p in e["plans"]:
        if p["ability"] not in abilities:
            out.append("BAD ability %s" % p["ability"]); ok = False
        for tier in ("full", "partial", "fail"):
            if tier not in p["effects"]:
                out.append("BAD effects %s %s %s" % (e["id"], p["id"], tier)); ok = False
            if tier not in p["chronicle"]:
                out.append("BAD chronicle %s %s %s" % (e["id"], p["id"], tier)); ok = False
    if "ignored" in e:
        for k in ("text", "effects", "chronicle"):
            if k not in e["ignored"]:
                out.append("BAD ignored %s %s" % (e["id"], k)); ok = False
out.append("JSON: daily=%d crisis=%s major=%s" % (len(d["daily"]), d["crisis"]["id"], d["major"]["id"]))
out.append("JSON_STRUCT_OK" if ok else "JSON_HAS_ERRORS")

# 2) GDScript 括号平衡 + tab 缩进一致性
files = ["scripts\\GameState.gd", "scripts\\EventManager.gd", "scripts\\Resolution.gd",
         "scripts\\Chronicler.gd", "scripts\\Main.gd", "scenes\\Main.tscn"]
for f in files:
    txt = open(root + "\\" + f, encoding="utf-8").read()
    pairs = [("(", ")"), ("[", "]"), ("{", "}")]
    bal = all(txt.count(a) == txt.count(b) for a, b in pairs)
    tabs = 0; spaces = 0
    for line in txt.splitlines():
        if line.startswith("\t"):
            tabs += 1
        elif line.startswith(" "):
            spaces += 1
    out.append("%s: balance=%s tabs=%d spaces=%d" % (f, bal, tabs, spaces))

# 3) 关键 GDScript API 关键字自检
main = open(root + "\\scripts\\Main.gd", encoding="utf-8").read()
apis = ["RichTextLabel.new()", "bbcode_enabled", "scroll_following", "append_text",
        "autowrap_mode", "TextServer.AUTOWRAP_WORD_SMART", "tooltip_text",
        "pressed.connect", "SIZE_EXPAND_FILL", "HSeparator.new()", "queue_free()"]
missing = [a for a in apis if a not in main]
out.append("Main.gd API missing: %s" % (missing if missing else "none"))

open(root + r"\..\_check_result.txt", "w", encoding="utf-8").write("\n".join(out))
