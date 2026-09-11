# -*- coding: utf-8 -*-
from openpyxl import load_workbook

PATH = r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Event_Config\事件库配置表_事件库规划_V1.0.xlsx"
OUT = r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Event_Config\_verify.txt"

wb = load_workbook(PATH)
lines = []
for name in wb.sheetnames:
    ws = wb[name]
    lines.append(f"[{name}] rows={ws.max_row} cols={ws.max_column}")

ws = wb["事件规划"]
lines.append("--- 事件规划 前12行(前6列) ---")
for row in ws.iter_rows(min_row=1, max_row=13, values_only=True):
    lines.append(" | ".join("" if v is None else str(v) for v in row[:6]))

ws3 = wb["存量事件"]
lines.append("--- 存量事件 全部 ---")
for row in ws3.iter_rows(min_row=1, max_row=ws3.max_row, values_only=True):
    lines.append(" | ".join("" if v is None else str(v)[:40] for v in row))

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("VERIFY OK")
