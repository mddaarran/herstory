import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const src = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.xlsx";
const events = JSON.parse(await fs.readFile("new_daily_events.json", "utf8"));
const out = "C:/Users/maodr/Desktop/Herstory/outputs/imported_events/N_事件全量表_原子朋克文案_V1.2.xlsx";
const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(src));
const textSheet = wb.worksheets.getItem("文字内容");
const numSheet = wb.worksheets.getItem("数值编辑");
const stateCols = ["treasury","population","gdp","military","territory","civilian_support","noble_support","radiation_risk","plague_progress","agrarian_support","guild_support","fuel_reserve","wealth_gap","literacy_rate","female_literacy","legitimacy","labor_health","female_support","technology"];
const textStart = textSheet.getUsedRange().rowCount + 1;
const textRows = events.map(e => {
  const p1 = e.plans[0], p2 = e.plans[1];
  return [e.id,e.title,e.type,e.background,`${e.id}_p1`,p1.name,p1.ability,p1.direction,p1.chronicle.full,p1.chronicle.partial,p1.chronicle.fail,`${e.id}_p2`,p2.name,p2.ability,p2.direction,p2.chronicle.full,p2.chronicle.partial,p2.chronicle.fail,e.ignored.text,e.ignored.chronicle,e.difficulty,e.weight,e.cooldown];
});
textSheet.getRangeByIndexes(textStart - 1, 0, textRows.length, 23).values = textRows;
const numStart = numSheet.getUsedRange().rowCount + 1;
const numRows = [];
for (const e of events) {
  for (const [pi, p] of e.plans.entries()) {
    for (const tier of ["full","partial","fail"]) {
      const row = [e.id, null, null, `${e.id}_p${pi+1}`, null, null, tier];
      for (const key of stateCols) row.push(p.effects[tier]?.[key] ?? null);
      numRows.push(row);
    }
  }
  const row = [e.id, null, null, null, null, null, "ignored"];
  for (const key of stateCols) row.push(e.ignored.effects?.[key] ?? null);
  numRows.push(row);
}
numSheet.getRangeByIndexes(numStart - 1, 0, numRows.length, 26).values = numRows;
const last = numStart + numRows.length - 1;
for (let r = numStart; r <= last; r++) {
  numSheet.getRange(`B${r}`).formulas = [[`=VLOOKUP(A${r},'文字内容'!$A$2:$W$60,2,FALSE)`]];
  numSheet.getRange(`C${r}`).formulas = [[`=VLOOKUP(A${r},'文字内容'!$A$2:$W$60,3,FALSE)`]];
  numSheet.getRange(`E${r}`).formulas = [[`=IF(D${r}="","",IFERROR(VLOOKUP(D${r},'文字内容'!$E$2:$G$60,2,FALSE),VLOOKUP(D${r},'文字内容'!$L$2:$N$60,2,FALSE)))`]];
  numSheet.getRange(`F${r}`).formulas = [[`=IF(D${r}="","",IFERROR(VLOOKUP(D${r},'文字内容'!$E$2:$G$60,3,FALSE),VLOOKUP(D${r},'文字内容'!$L$2:$N$60,3,FALSE)))`]];
}
wb.recalculate();
const check = await wb.inspect({kind:"table", sheetId:"数值编辑", range:`A${numStart}:G${numStart+6}`, include:"values,formulas", tableMaxRows:7, tableMaxCols:7});
console.log(check.ndjson);
await fs.mkdir("C:/Users/maodr/Desktop/Herstory/outputs/imported_events", {recursive:true});
const xlsx = await SpreadsheetFile.exportXlsx(wb);
await xlsx.save(out);
