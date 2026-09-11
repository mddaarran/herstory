# -*- coding: utf-8 -*-
"""
N_事件全量表_V1.1.xlsx  ->  herstory/data/events.json

合并规则（与用户 2026-09-02 确认）：
  1. plan_id  以「数值编辑」表为准（权威）
  2. 文案     以「文字内容」表为准，按 (event_id, 方案出现顺序, tier) 挂载，不依赖 plan_id 匹配
     因为两表的 plan_id 不同，只能按位置对应
  3. 只同步「数值编辑」里配了数值的事件（本次 = 10 个）
  4. weight / cooldown / trigger 等 Excel 未提供的字段走 EXTRA 兜底

只读 Excel，不写 Excel。
"""
import json
import os
import openpyxl
from openpyxl.utils import get_column_letter

XLSX = r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Numbers\N_事件全量表_V1.1.xlsx"
OUT = r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory\data\events.json"

# 「数值编辑」H..Z 列 -> State key（表头第 1 行）
# 2026-09-03：新增 Z 列 technology（科技水平），工程侧 GameState 需同步支持
STATE_COLS = {
    "H": "treasury",
    "I": "population",
    "J": "gdp",
    "K": "military",
    "L": "territory",
    "M": "civilian_support",
    "N": "noble_support",
    "O": "radiation_risk",
    "P": "plague_progress",
    "Q": "agrarian_support",
    "R": "guild_support",
    "S": "fuel_reserve",
    "T": "wealth_gap",
    "U": "literacy_rate",
    "V": "female_literacy",
    "W": "legitimacy",
    "X": "labor_health",
    "Y": "female_support",
    "Z": "technology",
}

# 「文字内容」列
TXT = {
    "event_id": "A", "title": "B", "type": "C", "background": "D",
    "p1_id": "E", "p1_name": "F", "p1_ability": "G", "p1_dir": "H",
    "p1_full": "I", "p1_partial": "J", "p1_fail": "K",
    "p2_id": "L", "p2_name": "M", "p2_ability": "N", "p2_dir": "O",
    "p2_full": "P", "p2_partial": "Q", "p2_fail": "R",
    "ig_text": "S", "ig_chronicle": "T",
}

# Excel 未提供的字段兜底
# 说明：weight / cooldown / trigger 在 Excel 全量表中没有列，属于工程侧配置。
#   老事件沿用 events.json 既有值；新增事件一律 weight=20 / cooldown=3，待主策回填。
#   trigger 按「隐藏值区间 + 多条件组合」设计，禁用单一阈值（主策划案要求）。
EXTRA = {
    "canal_split":     {"weight": 25, "cooldown": 3},
    "silent_fields":   {"weight": 25, "cooldown": 3},
    "grain_hoarding":  {"weight": 25, "cooldown": 3},
    "lamp_festival":   {"weight": 20, "cooldown": 3},
    "stop_husk_field": {"weight": 20, "cooldown": 3},
    "open_school":     {"weight": 20, "cooldown": 3},
    "child_labor":     {"weight": 20, "cooldown": 3},
    "women_night_read": {"weight": 20, "cooldown": 3},
    "widow_field":      {"weight": 20, "cooldown": 3},
    "soul_rite":        {"weight": 20, "cooldown": 3},
    "refugee_city":     {"weight": 20, "cooldown": 3},
    "furnace_upgrade":  {"weight": 20, "cooldown": 3},
    "border_pay":       {"weight": 20, "cooldown": 3},
    "iron_plow":        {"weight": 20, "cooldown": 3},
    # ---- 新增危机事件（2026-09-03）----
    "furnace_crack": {
        "trigger": {
            "type": "all",
            "conditions": [
                {"stat": "labor_health", "max": 45},
                {"stat": "radiation_risk", "min": 50},
            ],
            "chain_events": [],
        },
        "trigger_chance": 0.35,
    },
    "fuel_smuggle": {
        "trigger": {
            "type": "any",
            "conditions": [
                {"stat": "fuel_reserve", "max": 300},
                {"stat": "noble_support", "max": 40},
            ],
            "chain_events": [],
        },
        "trigger_chance": 0.35,
    },
    "plague_rounds": {
        "trigger": {
            "type": "any",
            "conditions": [
                {"stat": "plague_progress", "min": 4},
                {"stat": "labor_health", "max": 40},
            ],
            "chain_events": [],
        },
        "trigger_chance": 0.4,
    },
    "husk_blight": {
        "trigger": {
            "type": "any",
            "conditions": [
                {"stat": "radiation_risk", "min": 60},
                {"stat": "plague_progress", "min": 6},
            ],
            "chain_events": ["silent_fields"],
        },
        "trigger_chance": 0.4,
    },
    "fuel_demand": {
        "trigger": {
            "type": "any",
            "conditions": [
                {"stat": "fuel_reserve", "max": 250},
                {"stat": "plague_progress", "min": 5},
            ],
            "chain_events": [],
        },
        "trigger_chance": 0.35,
    },
    "autumn_council": {
        "trigger": {
            "type": "milestone",
            "note": "预言或君主目标阶段达成后强制出现，机制随预言系统设计后回填",
        },
    },
}


def cell(ws, col, row):
    v = ws["%s%d" % (col, row)].value
    if v is None:
        return None
    if isinstance(v, str):
        v = v.strip()
        if v == "" or v == "#N/A":
            return None
        return v
    return v


def read_number_sheet(ws):
    """返回 {event_id: {order, type, title, plans:[{id,ability,effects:{tier:{}}}], ignored:effects or None}}"""
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
                # Excel 里显式填 0 = 该 State 本档无变化，不写进 json
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
    """返回 {event_id: {title, background, plans:[{name,direction,chronicle:{}}], ignored:{text,chronicle}}}"""
    out = {}
    for r in range(2, ws.max_row + 1):
        eid = cell(ws, TXT["event_id"], r)
        if not eid:
            continue
        ev = {"title": cell(ws, TXT["title"], r),
              "type": cell(ws, TXT["type"], r),
              "background": cell(ws, TXT["background"], r),
              "plans": [], "ignored": {}}
        for n in ("1", "2"):
            name = cell(ws, TXT["p%s_name" % n], r)
            if name is None:
                continue
            ev["plans"].append({
                "name": name,
                "direction": cell(ws, TXT["p%s_dir" % n], r) or "",
                "chronicle": {
                    "full": cell(ws, TXT["p%s_full" % n], r) or "",
                    "partial": cell(ws, TXT["p%s_partial" % n], r) or "",
                    "fail": cell(ws, TXT["p%s_fail" % n], r) or "",
                },
            })
        ev["ignored"] = {"text": cell(ws, TXT["ig_text"], r) or "",
                         "chronicle": cell(ws, TXT["ig_chronicle"], r) or ""}
        out[eid] = ev
    return out


def build():
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    nums = read_number_sheet(wb["数值编辑"])
    txts = read_text_sheet(wb["文字内容"])

    buckets = {"daily": [], "crisis": [], "major": []}
    missing_text = []
    for eid, num in nums.items():
        tx = txts.get(eid)
        if tx is None:
            missing_text.append(eid)
        etype = num["type"] or (tx or {}).get("type") or "daily"

        plans = []
        for idx, plan in enumerate(num["plans"]):
            t = tx["plans"][idx] if tx and idx < len(tx["plans"]) else {}
            plans.append({
                "id": plan["id"],
                "name": t.get("name", plan["id"]),
                "ability": plan["ability"],
                "direction": t.get("direction", ""),
                "effects": {k: plan["effects"].get(k, {}) for k in ("full", "partial", "fail")},
                "chronicle": t.get("chronicle", {"full": "", "partial": "", "fail": ""}),
            })

        ev = {
            "id": eid,
            "title": (tx or {}).get("title") or num["title"],
            "background": (tx or {}).get("background", ""),
        }
        if etype == "daily":
            ev["weight"] = EXTRA.get(eid, {}).get("weight", 20)
            ev["cooldown"] = EXTRA.get(eid, {}).get("cooldown", 3)
        ev["plans"] = plans

        if num["ignored"] is not None:
            ig = {"text": "", "chronicle": ""}
            if tx:
                ig = {"text": tx["ignored"].get("text", ""),
                      "chronicle": tx["ignored"].get("chronicle", "")}
            ig["effects"] = num["ignored"]
            ev["ignored"] = ig

        for key in ("trigger", "trigger_chance"):
            if key in EXTRA.get(eid, {}):
                ev[key] = EXTRA[eid][key]

        buckets[etype].append(ev)

    doc = {"daily": buckets["daily"], "crisis": buckets["crisis"], "major": buckets["major"]}
    return doc, nums, txts, missing_text


def main():
    doc, nums, txts, missing_text = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("OK ->", OUT)
    print("daily=%d crisis=%d major=%d" % (len(doc["daily"]), len(doc["crisis"]), len(doc["major"])))
    for etype in ("daily", "crisis", "major"):
        for ev in doc[etype]:
            ps = " / ".join("%s(%s)" % (p["id"], p["ability"]) for p in ev["plans"])
            nz = sum(1 for p in ev["plans"] for t in ("full", "partial", "fail") if p["effects"].get(t))
            print("  [%-6s] %-18s %-28s plans=%d effects=%d ignored=%s" % (
                etype, ev["id"], ps, len(ev["plans"]), nz, "ignored" in ev))
    if missing_text:
        print("!! 无文案:", missing_text)


if __name__ == "__main__":
    main()
