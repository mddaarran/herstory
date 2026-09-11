# -*- coding: utf-8 -*-
"""
N_事件全量表_原子朋克文案_V1.2.xlsx  ->  herstory/data/events.json  (V2 生成器)

相对 V1 的变化（2026-09-03 与主策确认）：
  1. difficulty 提升为事件级必填（读「文字内容」U 列），方案级不再携带
  2. weight 读「文字内容」V 列（日常=1 全等权；危机基础=1）
  3. cooldown 读「文字内容」W 列（日常 3；危机 6）
  4. 危机触发改为「门槛二选一 + 权重跳变」：trigger.type=any(conditions 恰两条)，
     过线后权重按 trigger_weight(=20) 参与统一池竞争；被不作为后升至 25（运行时）
  5. 删除旧 trigger_chance 字段
  6. 锈病(作物 plague_progress) 与 疫病(人的病) 分家：plague_rounds 更名为 flu_raiding；
     flu_raiding 触发门槛改为人的健康/社会面（labor_health / civilian_support），不再看作物锈病
"""
import json
import os
import openpyxl

XLSX = os.environ.get("HERSTORY_EVENTS_XLSX", r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Numbers\N_事件全量表_原子朋克文案_V1.2.xlsx")
OUT = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory\data\events.json"
STATE_CONFIG_OUT = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory\data\state_config.json"

# 「数值编辑」H..Z 列 -> State key
STATE_COLS = {
    "H": "treasury", "I": "population", "J": "gdp", "K": "military", "L": "territory",
    "M": "civilian_support", "N": "noble_support", "O": "radiation_risk", "P": "plague_progress",
    "Q": "agrarian_support", "R": "guild_support", "S": "fuel_reserve", "T": "wealth_gap",
    "U": "literacy_rate", "V": "female_literacy", "W": "legitimacy", "X": "labor_health",
    "Y": "female_support", "Z": "technology",
}

# 「文字内容」列映射（A..T 原有文案 + U/V/W 新增事件级属性）
TXT = {
    "event_id": "A", "title": "B", "type": "C", "background": "D",
    "p1_id": "E", "p1_name": "F", "p1_ability": "G", "p1_dir": "H",
    "p1_full": "I", "p1_partial": "J", "p1_fail": "K",
    "p2_id": "L", "p2_name": "M", "p2_ability": "N", "p2_dir": "O",
    "p2_full": "P", "p2_partial": "Q", "p2_fail": "R",
    "ig_text": "S", "ig_chronicle": "T",
    "difficulty": "U", "weight": "V", "cooldown": "W",
    "trigger_a_stat": "X", "trigger_a_operator": "Y", "trigger_a_value": "Z",
    "trigger_b_stat": "AA", "trigger_b_operator": "AB", "trigger_b_value": "AC",
    "trigger_weight": "AD", "unlocks": "AE",
}

# 危机「门槛二选一」触发（stat 与阈值）。锈病=作物(plague_progress)；疫病=人(labor_health/civilian)
CRISIS_TRIGGER = {
    "husk_blight": {  # 火穗生锈（作物锈病）
        "type": "any",
        "conditions": [
            {"stat": "radiation_risk", "min": 50},
            {"stat": "plague_progress", "min": 5},
        ],
    },
    "fuel_demand": {  # 火籽分配之争（农业支持低公司施压 + 储备丰足分配之争）
        "type": "any",
        "conditions": [
            {"stat": "agrarian_support", "max": 42},
            {"stat": "fuel_reserve", "min": 500},
        ],
    },
    "furnace_crack": {  # 火籽炉开裂（技术到位该换炉 + 公会不支持、拖延换炉）
        "type": "any",
        "conditions": [
            {"stat": "literacy_rate", "min": 30},
            {"stat": "guild_support", "max": 35},
        ],
    },
    "fuel_smuggle": {  # 火籽走私（贫富分化严重 + 旧姓低支持）
        "type": "any",
        "conditions": [
            {"stat": "wealth_gap", "min": 55},
            {"stat": "noble_support", "max": 40},
        ],
    },
    "flu_raiding": {  # 坊区时疫（人的疫病，与作物锈病分家）
        "type": "any",
        "conditions": [
            {"stat": "labor_health", "max": 45},
            {"stat": "civilian_support", "max": 40},
        ],
    },
    "border_pay": {  # 女子军队同工同酬
        "type": "any",
        "conditions": [
            {"stat": "legitimacy", "max": 44},
            {"stat": "female_support", "max": 38},
        ],
    },
}
TRIGGER_WEIGHT = 20  # 过线后危机权重（统一池竞争用）；被不作为后由运行时升至 25

# 合法能力 ID（与主策三项能力对齐：洞察/驭人/威仪）
VALID_ABILITIES = ("insight", "influence", "majesty")


def cell(ws, col, row):
    v = ws["%s%d" % (col, row)].value
    if v is None:
        return None
    if isinstance(v, str):
        v = v.strip()
        if v == "" or v in ("#N/A", "#NAME?", "#REF!", "#VALUE!"):
            return None
        return v
    return v


def read_number_sheet(ws):
    """{event_id: {title,type,plans:[...],ignored, _order}}"""
    events = {}
    for r in range(3, ws.max_row + 1):
        eid = cell(ws, "A", r)
        if not eid:
            continue
        ev = events.setdefault(eid, {"title": cell(ws, "B", r), "type": cell(ws, "C", r),
                                     "plans": [], "ignored": None, "_order": []})
        tier = cell(ws, "G", r)
        effects = {}
        for col, key in STATE_COLS.items():
            v = cell(ws, col, r)
            if v is None:
                continue
            iv = int(v)
            if iv == 0:
                continue
            effects[key] = iv
        if tier == "ignored":
            ev["ignored"] = effects
            continue
        pid = cell(ws, "D", r)
        ability = cell(ws, "F", r)
        if pid not in ev["_order"]:
            ev["_order"].append(pid)
            ev["plans"].append({"id": pid, "ability": ability, "effects": {}})
        plan = ev["plans"][ev["_order"].index(pid)]
        plan["ability"] = ability or plan["ability"]
        plan["effects"][tier] = effects
    return events


def read_text_sheet(ws):
    """{event_id: {title,type,background,plans:[...],ignored, difficulty,weight,cooldown}}"""
    out = {}
    for r in range(2, ws.max_row + 1):
        eid = cell(ws, TXT["event_id"], r)
        if not eid:
            continue
        ev = {"title": cell(ws, TXT["title"], r),
              "type": cell(ws, TXT["type"], r),
              "background": cell(ws, TXT["background"], r),
              "difficulty": cell(ws, TXT["difficulty"], r),
              "weight": cell(ws, TXT["weight"], r),
              "cooldown": cell(ws, TXT["cooldown"], r),
              "plans": [], "ignored": {}}
        for n in ("1", "2"):
            name = cell(ws, TXT["p%s_name" % n], r)
            if name is None:
                continue
            # ability 的权威来源：文字内容 G（方案1）/ N（方案2）列
            ev["plans"].append({
                "name": name,
                "ability": cell(ws, TXT["p%s_ability" % n], r),
                "direction": cell(ws, TXT["p%s_dir" % n], r) or "",
                "chronicle": {
                    "full": cell(ws, TXT["p%s_full" % n], r) or "",
                    "partial": cell(ws, TXT["p%s_partial" % n], r) or "",
                    "fail": cell(ws, TXT["p%s_fail" % n], r) or "",
                },
            })
        ev["ignored"] = {"text": cell(ws, TXT["ig_text"], r) or "",
                         "chronicle": cell(ws, TXT["ig_chronicle"], r) or ""}
        if ev["type"] == "crisis":
            trigger_conditions = []
            for stat_key, op_key, value_key in (("trigger_a_stat", "trigger_a_operator", "trigger_a_value"), ("trigger_b_stat", "trigger_b_operator", "trigger_b_value")):
                stat = cell(ws, TXT[stat_key], r)
                op = cell(ws, TXT[op_key], r)
                value = cell(ws, TXT[value_key], r)
                if stat and op and value is not None:
                    trigger_conditions.append({op: int(value), "stat": stat})
            # 单门槛亦可（>=1），不再强制二选一两条
            if len(trigger_conditions) >= 1:
                ev["trigger"] = {"type": "any", "conditions": trigger_conditions}
            # 过线权重（未过线 weight=0，过线后按 trigger_weight 竞争）
            tw = cell(ws, TXT["trigger_weight"], r)
            if tw is not None:
                ev["trigger_weight"] = int(tw)
            # 解锁下一条危机（完成本危机后，解锁 unlocks 指向的下一条的触发门槛）
            ul = cell(ws, TXT["unlocks"], r)
            if ul:
                ev["unlocks"] = ul
        out[eid] = ev
    return out


def read_state_config(ws):
    """State词典 A:G -> runtime state_config.json"""
    config = {}
    for r in range(2, ws.max_row + 1):
        key = cell(ws, "A", r)
        if not key:
            continue
        initial = cell(ws, "E", r)
        minimum = cell(ws, "F", r)
        maximum = cell(ws, "G", r)
        if not all(isinstance(v, (int, float)) for v in (initial, minimum, maximum)):
            raise ValueError("State词典存在未填写或非数字配置: %s" % key)
        config[key] = {"initial": int(initial), "min": int(minimum), "max": int(maximum)}
    return config


def build():
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    nums = read_number_sheet(wb["数值编辑"])
    txts = read_text_sheet(wb["文字内容"])
    buckets = {"daily": [], "crisis": [], "major": []}
    missing_text = []
    for eid, num in nums.items():
        tx = txts.get(eid)
        # major_ 前缀事件：文案在「Major事件文案」sheet，尚未接入 sync，暂跳过（避免无文案空事件污染 daily）
        if eid.startswith("major_") and tx is None:
            continue
        if tx is None:
            missing_text.append(eid)
        etype = num["type"] or (tx or {}).get("type") or "daily"

        plans = []
        for idx, plan in enumerate(num["plans"]):
            t = tx["plans"][idx] if tx and idx < len(tx["plans"]) else {}
            # ability 优先取文字内容（权威），其次数值编辑，最后兜底 insight（避免 null 进 GDScript 强类型）
            ability = t.get("ability") or plan["ability"] or "insight"
            plans.append({
                "id": plan["id"],
                "name": t.get("name", plan["id"]),
                "ability": ability,
                "direction": t.get("direction", ""),
                "effects": {k: plan["effects"].get(k, {}) for k in ("full", "partial", "fail")},
                "chronicle": t.get("chronicle", {"full": "", "partial": "", "fail": ""}),
            })

        ev = {
            "id": eid,
            "title": (tx or {}).get("title") or num["title"],
            "background": (tx or {}).get("background", ""),
            "difficulty": int(tx.get("difficulty")) if tx and tx.get("difficulty") is not None else 0,
        }
        if etype in ("daily", "crisis"):
            ev["weight"] = int(tx["weight"]) if tx and tx.get("weight") is not None else 1
            ev["cooldown"] = int(tx["cooldown"]) if tx and tx.get("cooldown") is not None else (3 if etype == "daily" else 6)
        if etype == "crisis":
            ev["trigger"] = (tx or {}).get("trigger") or CRISIS_TRIGGER.get(eid, {"type": "any", "conditions": []})
            ev["trigger_weight"] = (tx or {}).get("trigger_weight", TRIGGER_WEIGHT)
            if (tx or {}).get("unlocks"):
                ev["unlocks"] = tx["unlocks"]
        ev["plans"] = plans

        if num["ignored"] is not None:
            ig = {"text": "", "chronicle": ""}
            if tx:
                ig = {"text": tx["ignored"].get("text", ""),
                      "chronicle": tx["ignored"].get("chronicle", "")}
            ig["effects"] = num["ignored"]
            ev["ignored"] = ig

        buckets[etype].append(ev)

    return {"daily": buckets["daily"], "crisis": buckets["crisis"], "major": buckets["major"]}, nums, txts, missing_text


def main():
    doc, nums, txts, missing_text = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    state_config = read_state_config(wb["State词典"])
    with open(STATE_CONFIG_OUT, "w", encoding="utf-8") as f:
        json.dump(state_config, f, ensure_ascii=False, indent=2)
        f.write("\n")
    lines = ["OK -> " + OUT]
    bad_ability = []
    for etype in ("daily", "crisis", "major"):
        for ev in doc[etype]:
            for p in ev["plans"]:
                if p["ability"] not in VALID_ABILITIES:
                    bad_ability.append("%s/%s=%s" % (ev["id"], p["id"], p["ability"]))
    if bad_ability:
        lines.append("!! 非法 ability: " + ",".join(bad_ability))
    for etype in ("daily", "crisis", "major"):
        lines.append("[%s] %d" % (etype, len(doc[etype])))
        for ev in doc[etype]:
            lines.append("  %-16s diff=%-2s w=%-2s cd=%-2s plans=%d trigger=%s" % (
                ev["id"], ev.get("difficulty"), ev.get("weight", "-"),
                ev.get("cooldown", "-"), len(ev["plans"]),
                "Y" if "trigger" in ev else "-"))
    if missing_text:
        lines.append("!! 无文案: " + ",".join(missing_text))
    with open(r"C:\Users\maodr\Desktop\Herstory\_AIagent\05_Tools\_sync_out.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
