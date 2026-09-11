import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const src = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.xlsx";
const out = "C:/Users/maodr/Desktop/Herstory/outputs/state_config/N_事件全量表_原子朋克文案_V1.2.xlsx";
const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(src));
const sheet = wb.worksheets.getItem("State词典");

const rows = [
  ["treasury", 200, 0, 99999],
  ["population", 300, 0, 9999],
  ["gdp", 500, 0, 9999],
  ["military", 200, 0, 700],
  ["territory", 150, 0, 400],
  ["civilian_support", 55, 0, 100],
  ["noble_support", 50, 0, 100],
  ["radiation_risk", 20, 0, 100],
  ["plague_progress", 0, 0, 10],
  ["agrarian_support", 50, 0, 100],
  ["guild_support", 50, 0, 100],
  ["fuel_reserve", 400, 0, 999],
  ["wealth_gap", 40, 0, 100],
  ["literacy_rate", 20, 0, 100],
  ["female_literacy", 8, 0, 100],
  ["legitimacy", 50, 0, 100],
  ["labor_health", 60, 0, 100],
  ["female_support", 45, 0, 100],
  ["technology", 20, 0, 100],
];

sheet.getRange("E2:G20").values = rows.map(([, init, min, max]) => [init, min, max]);
sheet.getRange("E2:G20").format.numberFormat = "0";

// 补足农业公司和隐藏 State 的直接反馈；只填空白单元，不覆盖已有事件数值。
const numSheet = wb.worksheets.getItem("数值编辑");
const used = numSheet.getUsedRange();
const values = used.values;
const header = values[0];
const col = Object.fromEntries(header.map((v, i) => [String(v), i]));
const additions = {
  "canal_split": {"agrarian_support": {"full": 15, "partial": 8, "fail": -10, "ignored": -5}},
  "silent_fields": {"agrarian_support": {"full": 18, "partial": 8, "fail": -12, "ignored": -8}},
  "grain_hoarding": {"agrarian_support": {"full": 12, "partial": 6, "fail": -10, "ignored": -8}},
  "stop_husk_field": {"agrarian_support": {"full": 18, "partial": 8, "fail": -12, "ignored": -8}},
  "iron_plow": {"agrarian_support": {"full": 15, "partial": 7, "fail": -10, "ignored": -6}},
  "border_tariff": {"agrarian_support": {"full": 8, "partial": 4, "fail": -8, "ignored": -5}, "guild_support": {"full": 10, "partial": 5, "fail": -8, "ignored": -5}},
  "north_settlement": {"agrarian_support": {"full": 12, "partial": 6, "fail": -10, "ignored": -6}, "population": {"full": 35, "partial": 15, "fail": -20, "ignored": -15}},
  "riverbank_settlement": {"agrarian_support": {"full": 10, "partial": 5, "fail": -8, "ignored": -5}, "population": {"full": 30, "partial": 12, "fail": -20, "ignored": -15}},
  "eastern_tax_registry": {"agrarian_support": {"full": 8, "partial": 4, "fail": -8, "ignored": -5}, "legitimacy": {"full": 10, "partial": 5, "fail": -8, "ignored": -5}},
  "admin_audit": {"legitimacy": {"full": 10, "partial": 5, "fail": -8, "ignored": -5}},
  "frontier_towers": {"military": {"full": 45, "partial": 20, "fail": -30, "ignored": -20}, "territory": {"full": 12, "partial": 5, "fail": -10, "ignored": -8}},
  "frontier_beacon": {"military": {"full": 35, "partial": 15, "fail": -25, "ignored": -15}},
  "border_survey_team": {"territory": {"full": 10, "partial": 5, "fail": -8, "ignored": -6}}
};
const noTreasury = new Set(["border_survey_team", "frontier_beacon", "midwife_station", "riverbank_settlement", "north_settlement", "empress_work_badges", "women_night_read", "soul_rite"]);
for (let r = 1; r < values.length; r++) {
  const eid = values[r][col["event_id"]];
  const tier = values[r][col["tier"]];
  if (noTreasury.has(eid)) values[r][col["treasury"]] = null;
  const eventAdd = additions[eid];
  if (!eventAdd) continue;
  for (const [state, tierValues] of Object.entries(eventAdd)) {
    const c = col[state];
    if (c === undefined) continue;
    const v = values[r][c];
    if (v === null || v === "") values[r][c] = tierValues[tier] ?? null;
  }
}
used.values = values;
wb.recalculate();
const check = await wb.inspect({ kind: "table", sheetId: "State词典", range: "A1:G20", include: "values", tableMaxRows: 20, tableMaxCols: 7 });
console.log(check.ndjson);
const xlsx = await SpreadsheetFile.exportXlsx(wb);
await fs.mkdir("C:/Users/maodr/Desktop/Herstory/outputs/state_config", { recursive: true });
await xlsx.save(out);
await fs.writeFile("state_config_inspect.txt", check.ndjson, "utf8");
