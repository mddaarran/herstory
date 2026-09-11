import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const src = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.xlsx";
const out = "C:/Users/maodr/Desktop/Herstory/outputs/formula_fixed/N_事件全量表_原子朋克文案_V1.2.xlsx";
const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(src));
const sheet = wb.worksheets.getItem("数值编辑");
const textRows = "'文字内容'!$A$2:$W$31";
const plan1 = "'文字内容'!$E$2:$G$31";
const plan2 = "'文字内容'!$L$2:$N$31";
const last = sheet.getUsedRange().rowCount + 1;
for (let r = 3; r <= last; r++) {
  sheet.getRange(`B${r}`).formulas = [[`=VLOOKUP(A${r},${textRows},2,FALSE)`]];
  sheet.getRange(`C${r}`).formulas = [[`=VLOOKUP(A${r},${textRows},3,FALSE)`]];
  sheet.getRange(`E${r}`).formulas = [[`=IF(D${r}="","",IFERROR(VLOOKUP(D${r},${plan1},2,FALSE),VLOOKUP(D${r},${plan2},2,FALSE)))`]];
  sheet.getRange(`F${r}`).formulas = [[`=IF(D${r}="","",IFERROR(VLOOKUP(D${r},${plan1},3,FALSE),VLOOKUP(D${r},${plan2},3,FALSE)))`]];
}
wb.recalculate();
const check = await wb.inspect({ kind: "table", sheetId: "数值编辑", range: "A1:G12", include: "values,formulas", tableMaxRows: 12, tableMaxCols: 7 });
console.log(check.ndjson);
await fs.mkdir("C:/Users/maodr/Desktop/Herstory/outputs/formula_fixed", { recursive: true });
const xlsx = await SpreadsheetFile.exportXlsx(wb);
await xlsx.save(out);
