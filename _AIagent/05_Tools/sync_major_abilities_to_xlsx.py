from pathlib import Path
import openpyxl

path = Path(r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Numbers\N_事件全量表_原子朋克文案_V1.2.xlsx")
wb = openpyxl.load_workbook(path)

# The dedicated major-event sheet stores one row per major plan.
ws = wb.worksheets[3]
updates = {
    "lure_enemy": "influence",
    "cross_unknown_border": "insight",
}
changed = []
for row in range(2, ws.max_row + 1):
    plan_id = ws.cell(row, 8).value
    if plan_id in updates:
        cell = ws.cell(row, 10)
        if cell.value != updates[plan_id]:
            changed.append((plan_id, cell.value, updates[plan_id]))
            cell.value = updates[plan_id]

if not changed:
    print("No major ability changes were needed.")
else:
    wb.save(path)
    print("Updated:", changed)
