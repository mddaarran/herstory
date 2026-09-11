import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";
const input = await FileBlob.load("C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_V1.1.xlsx");
const wb = await SpreadsheetFile.importXlsx(input);
console.log((await wb.inspect({kind:"workbook,sheet,table",maxChars:12000,tableMaxRows:8,tableMaxCols:12,tableMaxCellChars:120})).ndjson);
for (const s of wb.worksheets.items) { const u=s.getUsedRange(); console.log("SHEET",s.name,"USED",u?.address); if(u) console.log((await wb.inspect({kind:"table",sheetId:s.name,range:u.address,tableMaxRows:8,tableMaxCols:16,maxChars:12000,tableMaxCellChars:120})).ndjson); }
