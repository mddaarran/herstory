# -*- coding: utf-8 -*-
"""
2026-09-10 难度改档：daily -3~+1 五档 / crisis +2、+3 / major +3
只改「文字内容」U 列（difficulty）。
"""
import openpyxl, sys

XLSX = r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Numbers\N_事件全量表_原子朋克文案_V1.2.xlsx"

DAILY_TIER = {
    -3: ["pump_instruments", "fuel_crate_patent", "furnace_upgrade", "midwife_station"],
    -2: ["agriculture_new_land", "border_tariff", "empress_work_badges",
         "guild_furnace_technology", "iron_plow", "lamp_festival"],
    -1: ["canal_split", "border_farm_supply", "company_military_rations",
         "frontier_towers", "migration_contract", "refugee_city",
         "retired_furnace_workers", "farm_energy_conflict", "frontier_beacon",
         "grain_hoarding", "guild_worker_shift", "river_tug_toll", "silent_fields"],
    0: ["child_labor", "grain_city_furnaces", "guild_trade_route", "north_settlement",
        "population_labor_draft", "riverbank_settlement", "stop_husk_field",
        "admin_audit", "border_survey_team", "company_tax_sheet", "fuel_for_fields",
        "guild_city_market", "merchant_furnace_banquet", "noble_ancestral_land",
        "noble_marriage_land", "settlement_registry"],
    1: ["noble_customs_gate", "widow_field", "company_radiation_debt",
        "eastern_tax_registry", "mountain_submission", "open_school",
        "soul_rite", "women_night_read"],
}

# crisis：全部在旧值基础上 +1（+1 -> +2，+2 -> +3）
# major：+1（2 -> 3）
CRISIS_SHIFT = 1
MAJOR_SHIFT = 1

wb = openpyxl.load_workbook(XLSX)
ws = wb["文字内容"]

# ---- 1. 收集现有行 ----
rows = {}
for r in range(2, ws.max_row + 1):
    eid = ws.cell(r, 1).value
    if eid:
        rows[str(eid)] = (r, ws.cell(r, 3).value, ws.cell(r, 21).value)

daily_ids = {k for k, v in rows.items() if v[1] == "daily"}
tier_ids = {i for lst in DAILY_TIER.values() for i in lst}

print("Excel daily 条数 =", len(daily_ids), "｜分档表条数 =", len(tier_ids))
only_xlsx = daily_ids - tier_ids
only_tier = tier_ids - daily_ids
if only_xlsx:
    print("！分档表缺少这些 daily：", sorted(only_xlsx))
if only_tier:
    print("！分档表里有 Excel 中不存在的 id：", sorted(only_tier))
if only_xlsx or only_tier:
    sys.exit("分档表与 Excel 不匹配，已中止")

# ---- 2. 写 daily ----
changed = []
for tier, ids in DAILY_TIER.items():
    for eid in ids:
        r, _, old = rows[eid]
        ws.cell(r, 21).value = tier
        changed.append((eid, old, tier))

# ---- 3. 写 crisis / major ----
for eid, (r, etype, old) in rows.items():
    if etype == "crisis":
        new = (int(old) if old is not None else 0) + CRISIS_SHIFT
        ws.cell(r, 21).value = new
        changed.append((eid, old, new))
    elif etype == "major":
        new = (int(old) if old is not None else 0) + MAJOR_SHIFT
        ws.cell(r, 21).value = new
        changed.append((eid, old, new))

wb.save(XLSX)
print("已写回 %s（共 %d 处改动）" % (XLSX, len(changed)))

# ---- 4. 重新 load 验证 ----
wb2 = openpyxl.load_workbook(XLSX)
ws2 = wb2["文字内容"]
from collections import Counter
cnt = {"daily": Counter(), "crisis": Counter(), "major": Counter()}
bad = []
for r in range(2, ws2.max_row + 1):
    eid = ws2.cell(r, 1).value
    if not eid:
        continue
    t = ws2.cell(r, 3).value
    d = ws2.cell(r, 21).value
    cnt.setdefault(t, Counter())[d] += 1
    if t == "daily":
        exp = next((k for k, v in DAILY_TIER.items() if str(eid) in v), None)
        if exp != d:
            bad.append((eid, exp, d))
print("验证 daily :", dict(sorted(cnt["daily"].items())))
print("验证 crisis:", dict(sorted(cnt["crisis"].items())))
print("验证 major :", dict(sorted(cnt["major"].items())))
print("不一致项:", bad if bad else "无")
print("sheet 列表:", wb2.sheetnames)
