import os, re, json
root = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory"
result = []

# 1. 去掉注释行的括号后再做 ASCII 配对
def real_balance(path):
    src = open(path, encoding="utf-8").read().splitlines()
    o = cl = 0
    for line in src:
        # 剥掉注释
        hash_pos = -1
        in_str = False
        quote = None
        for i, ch in enumerate(line):
            if in_str:
                if ch == '\\':
                    pass
                elif ch == quote:
                    in_str = False
                continue
            if ch == '"' or ch == "'":
                in_str = True; quote = ch; continue
            if ch == '#':
                hash_pos = i; break
        code = line if hash_pos < 0 else line[:hash_pos]
        for ch in code:
            if ch in "([{": o += 1
            elif ch in ")]}": cl += 1
    return o - cl

for f in ["scripts/Main.gd","scripts/GameState.gd","scripts/EventManager.gd","scripts/Resolution.gd","scripts/Chronicler.gd"]:
    result.append("%s : real_balance=%d" % (f, real_balance(os.path.join(root,f))))

# 2. JSON 校验
ev = json.load(open(os.path.join(root,"data/events.json"), encoding="utf-8"))
allowed = {"treasury","population","gdp","military","territory","civilian_support","noble_support","land_risk","plague_progress"}
ok = True
for e in ev["daily"] + [ev["crisis"], ev["major"]]:
    for p in e["plans"]:
        if "ability_modifier" not in p: result.append("NO modifier %s" % p["id"]); ok=False
        for tier in ("full","partial","fail"):
            for k in p["effects"][tier]:
                if k not in allowed:
                    result.append("BAD key %s in %s/%s/%s" % (k,e["id"],p["id"],tier)); ok=False
result.append("JSON_OK" if ok else "JSON_BAD")

# 3. 关键 type/method 名一致
gs = open(os.path.join(root,"scripts/GameState.gd"), encoding="utf-8").read()
must_have = ["var treasury","var population","var gdp","var military","var territory",
             "var civilian_support","var noble_support","var land_risk","var plague_progress",
             "DEFAULT_ABILITY_MOD","func apply_effects","func reset","func roll_2d6",
             "func civilian_tier_text","func blight_omen_text"]
for m in must_have:
    result.append("GameState.%s : %s" % (m, "OK" if m in gs else "MISS"))

open(os.path.join(root,"_check4.txt"),"w",encoding="utf-8").write("\n".join(result))
print("done")
