import json, re
from pathlib import Path

src = Path(r"C:\Users\maodr\.codex\attachments\9dcc3c3a-8ab3-440a-91ad-ee45fae8f8d0\pasted-text.txt")
out = Path("new_daily_events.json")
text = src.read_text(encoding="utf-8")
lines = [re.sub(r"\s+$", "", x.strip()) for x in text.splitlines() if x.strip()]
starts = [i for i, line in enumerate(lines) if re.match(r"^\d+\. `", line)]
blocks = [lines[start:starts[n+1] if n+1 < len(starts) else len(lines)] for n, start in enumerate(starts)]
state_map = {"财政":"treasury", "GDP":"gdp", "人口":"population", "军力":"military", "领土":"territory", "农业支持":"agrarian_support", "公会支持":"guild_support", "旧姓支持":"noble_support", "平民支持":"civilian_support", "合法性":"legitimacy", "土地风险":"radiation_risk", "劳工健康":"labor_health", "火籽储备":"fuel_reserve", "锈病进度":"plague_progress"}
def effects(s):
    result = {}
    for label, key in state_map.items():
        m = re.search(re.escape(label) + r"\s*([+-]\d+)", s)
        if m: result[key] = int(m.group(1))
    return result
events = []
for block in blocks:
    m = re.match(r"^\d+\. `([^`]+)`｜([^｜]+)｜(daily)", block[0])
    if not m: continue
    ev = {"id":m.group(1), "title":m.group(2), "type":"daily", "background":"", "plans":[], "ignored":{"text":"","chronicle":"","effects":{}}, "difficulty":0, "weight":1, "cooldown":3}
    i = 1
    if i < len(block): ev["background"] = block[i]; i += 1
    while i < len(block):
        line = block[i]
        if line.startswith("方案一：") or line.startswith("方案二："):
            name, ability = line.split("｜", 1)
            plan = {"name":name.split("：",1)[1], "ability":ability, "direction":"即时解决当前冲突，但需要承担相应的政治或资源代价。", "effects":{}, "chronicle":{}}
            i += 1
            for tier, label in [("full","完全成功："),("partial","有条件成功："),("fail","失败：")]:
                if i < len(block) and block[i].startswith(label):
                    raw = block[i][len(label):]
                    plan["effects"][tier] = effects(raw)
                    plan["chronicle"][tier] = raw
                    i += 1
            ev["plans"].append(plan)
            continue
        if line.startswith("不作为："):
            ev["ignored"]["text"] = line.split("：",1)[1]
            ev["ignored"]["chronicle"] = ev["ignored"]["text"]
            i += 1
            continue
        m2 = re.match(r"难度([+-]?\d+)，权重(\d+)，冷却(\d+)", line)
        if m2: ev["difficulty"], ev["weight"], ev["cooldown"] = map(int, m2.groups())
        i += 1
    events.append(ev)
out.write_text(json.dumps(events, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"events":len(events),"ids":[e["id"] for e in events]},ensure_ascii=False))
