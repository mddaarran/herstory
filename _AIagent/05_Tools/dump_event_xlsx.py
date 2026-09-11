# -*- coding: utf-8 -*-
"""把 N_事件全量表 全量 dump 成文本，供 AI 阅读（只读，不改 Excel）。"""
import sys
import openpyxl

SRC = r"C:\Users\maodr\Desktop\Herstory\_AIagent\01_Game_Design\Numbers\N_事件全量表_V1.1.xlsx"
OUT = r"C:\Users\maodr\Desktop\Herstory\_AIagent\05_Tools\_event_xlsx_dump.txt"

wb = openpyxl.load_workbook(SRC, data_only=True)
lines = []
for ws in wb.worksheets:
    lines.append("=" * 80)
    lines.append("SHEET: %s  (dims=%s  max_row=%d max_col=%d)" % (ws.title, ws.dimensions, ws.max_row, ws.max_column))
    lines.append("=" * 80)
    for r in range(1, ws.max_row + 1):
        vals = []
        for c in range(1, ws.max_column + 1):
            v = ws.cell(row=r, column=c).value
            if v is None:
                continue
            v = str(v).replace("\n", "\\n")
            col = openpyxl.utils.get_column_letter(c)
            vals.append("%s%d=%s" % (col, r, v))
        if vals:
            lines.append("R%-4d| %s" % (r, " | ".join(vals)))
    lines.append("")

txt = "\n".join(lines)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(txt)
print("written", OUT, len(txt), "chars")
