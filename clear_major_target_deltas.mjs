import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const path = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.xlsx";
const temp = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.tmp.xlsx";
const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(path));
const sheet = wb.worksheets.getItem("数值编辑");

// Major rows are ordered as 3 treasury plans, 3 GDP plans, 3 military plans,
// 3 population plans and 3 territory plans. Clear only each triggering asset.
sheet.getRange("H366:H374").values = Array.from({length: 9}, () => [null]);
sheet.getRange("J375:J383").values = Array.from({length: 9}, () => [null]);
sheet.getRange("K384:K392").values = Array.from({length: 9}, () => [null]);
sheet.getRange("I393:I401").values = Array.from({length: 9}, () => [null]);
sheet.getRange("L402:L410").values = Array.from({length: 9}, () => [null]);

wb.recalculate();
const check = await wb.inspect({kind: "table", sheetId: "数值编辑", range: "A366:L410", tableMaxRows: 45, tableMaxCols: 12, maxChars: 6000});
console.log(check.ndjson);
const output = await SpreadsheetFile.exportXlsx(wb);
await output.save(temp);
console.log(`EXPORTED ${temp}`);
