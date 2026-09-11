import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const path = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.xlsx";
const temp = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.tmp.xlsx";
const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(path));
const sheet = wb.worksheets.getItem("数值编辑");

const cols = {
  treasury: 7, population: 8, gdp: 9, military: 10, territory: 11,
  civilian_support: 12, noble_support: 13, radiation_risk: 14, plague_progress: 15,
  agrarian_support: 16, guild_support: 17, fuel_reserve: 18, wealth_gap: 19,
  literacy_rate: 20, female_literacy: 21, legitimacy: 22, labor_health: 23,
  female_support: 24, technology: 25
};

const plans = [
  ["major_treasury_coup", "国库之火", "goal_treasury", "treasury", 1000, "guard_treasury", "亲自守卫国库", "majesty", {full:{treasury:-100,population:0,gdp:0,military:-60,territory:0,civilian_support:80,noble_support:-40,legitimacy:80}, partial:{treasury:-130,military:-80,civilian_support:40,noble_support:-60,legitimacy:40}, fail:{treasury:-180,military:-120,civilian_support:-40,noble_support:-100,legitimacy:-60}}],
  ["major_treasury_coup", "国库之火", "goal_treasury", "treasury", 1000, "open_treasury", "打开国库赈济城市", "influence", {full:{treasury:-200,civilian_support:150,noble_support:-150,legitimacy:50}, partial:{treasury:-160,civilian_support:80,noble_support:-120,legitimacy:20}, fail:{treasury:-120,civilian_support:-80,noble_support:-80,legitimacy:-80}}],
  ["major_treasury_coup", "国库之火", "goal_treasury", "treasury", 1000, "burn_ledgers", "焚毁账册与财富凭证", "insight", {full:{treasury:-200,gdp:-100,noble_support:-100,legitimacy:80}, partial:{treasury:-160,gdp:-80,noble_support:-80,legitimacy:20}, fail:{treasury:-100,gdp:-50,noble_support:-60,legitimacy:-100}}],
  ["major_guild_revolt", "繁荣的城门", "goal_gdp", "gdp", 1000, "suppress_guild", "调军镇压商业联盟", "majesty", {full:{gdp:-120,military:-80,civilian_support:-40,noble_support:40,legitimacy:100}, partial:{gdp:-160,military:-120,civilian_support:-80,noble_support:20,legitimacy:40}, fail:{gdp:-200,military:-150,civilian_support:-120,noble_support:-40,legitimacy:-80}}],
  ["major_guild_revolt", "繁荣的城门", "goal_gdp", "gdp", 1000, "grant_autonomy", "承认城市自治", "influence", {full:{gdp:-40,civilian_support:80,noble_support:-40,legitimacy:100}, partial:{gdp:-70,civilian_support:30,noble_support:-80,legitimacy:40}, fail:{gdp:-150,civilian_support:-60,noble_support:-100,legitimacy:-80}}],
  ["major_guild_revolt", "繁荣的城门", "goal_gdp", "gdp", 1000, "enter_workshop", "亲自进入主工坊救灾", "insight", {full:{gdp:-100,population:-40,civilian_support:150,labor_health:100,technology:40}, partial:{gdp:-150,population:-60,civilian_support:80,labor_health:50,technology:20}, fail:{gdp:-200,population:-100,civilian_support:-80,labor_health:-100,technology:-30}}],
  ["major_final_invasion", "最后的入侵", "goal_military", "military", 700, "march_to_battle", "亲自出征迎敌", "majesty", {full:{military:-160,territory:60,civilian_support:100,legitimacy:100}, partial:{military:-180,territory:20,civilian_support:40,legitimacy:40}, fail:{military:-200,territory:-100,civilian_support:-80,legitimacy:-80}}],
  ["major_final_invasion", "最后的入侵", "goal_military", "military", 700, "hold_capital", "死守都城", "insight", {full:{military:-100,territory:0,civilian_support:40,legitimacy:80}, partial:{military:-150,territory:-80,civilian_support:-20,legitimacy:20}, fail:{military:-200,territory:-150,civilian_support:-100,legitimacy:-100}}],
  ["major_final_invasion", "最后的入侵", "goal_military", "military", 700, "lure_enemy", "诱敌深入后决战", "insight", {full:{military:-120,territory:100,civilian_support:60,legitimacy:80}, partial:{military:-160,territory:40,civilian_support:20,legitimacy:20}, fail:{military:-200,territory:-80,civilian_support:-80,legitimacy:-80}}],
  ["major_population_disaster", "没有空位的城市", "goal_population", "population", 600, "enter_disaster_zone", "亲自进入灾区", "influence", {full:{population:-60,treasury:-80,civilian_support:200,labor_health:40,legitimacy:60}, partial:{population:-100,treasury:-120,civilian_support:120,labor_health:-20,legitimacy:30}, fail:{population:-150,treasury:-100,civilian_support:-60,labor_health:-80,legitimacy:-60}}],
  ["major_population_disaster", "没有空位的城市", "goal_population", "population", 600, "requisition_grain", "强行征粮维持秩序", "majesty", {full:{population:-40,treasury:40,military:-60,civilian_support:-80,legitimacy:80}, partial:{population:-80,treasury:20,military:-100,civilian_support:-120,legitimacy:30}, fail:{population:-150,military:-150,civilian_support:-200,legitimacy:-100}}],
  ["major_population_disaster", "没有空位的城市", "goal_population", "population", 600, "open_royal_granaries", "打开宫廷与贵族粮仓", "insight", {full:{population:-30,treasury:-150,civilian_support:150,noble_support:-200,legitimacy:100}, partial:{population:-60,treasury:-180,civilian_support:100,noble_support:-150,legitimacy:40}, fail:{population:-120,treasury:-80,civilian_support:-80,noble_support:-100,legitimacy:-100}}],
  ["major_frontier_revolt", "地图的尽头", "goal_territory", "territory", 400, "march_frontier", "亲自前往最远边疆镇压", "majesty", {full:{territory:-40,military:-100,civilian_support:80,legitimacy:80}, partial:{territory:-80,military:-150,civilian_support:20,legitimacy:30}, fail:{territory:-150,military:-200,civilian_support:-80,legitimacy:-100}}],
  ["major_frontier_revolt", "地图的尽头", "goal_territory", "territory", 400, "grant_frontier_autonomy", "承认地方自治", "influence", {full:{territory:-20,civilian_support:100,noble_support:-80,legitimacy:60}, partial:{territory:-50,civilian_support:50,noble_support:-120,legitimacy:20}, fail:{territory:-120,civilian_support:-80,noble_support:-150,legitimacy:-100}}],
  ["major_frontier_revolt", "地图的尽头", "goal_territory", "territory", 400, "cross_unknown_border", "继续向未知之地远征", "majesty", {full:{territory:100,military:-150,treasury:-100,legitimacy:80}, partial:{territory:40,military:-180,treasury:-150,legitimacy:20}, fail:{territory:-80,military:-200,treasury:-200,legitimacy:-80}}]
];

function rowFor(p, tier) {
  const [eventId, title, goalId, triggerState, triggerValue, planId, planName, ability, deltaByTier] = p;
  const deltas = deltaByTier[tier];
  const row = Array(26).fill(null);
  row[0] = eventId; row[1] = title; row[2] = "major"; row[3] = planId; row[4] = planName; row[5] = ability; row[6] = tier;
  for (const [key, value] of Object.entries(deltas)) row[cols[key]] = value;
  return row;
}

const rows = [];
for (const p of plans) {
  rows.push(rowFor(p, "full"));
  rows.push(rowFor(p, "partial"));
  rows.push(rowFor(p, "fail"));
}
sheet.getRange("A366:Z410").values = rows;
wb.recalculate();
const check = await wb.inspect({ kind: "table", sheetId: "数值编辑", range: "A366:Z410", tableMaxRows: 4, tableMaxCols: 26, maxChars: 5000 });
console.log(check.ndjson);
const output = await SpreadsheetFile.exportXlsx(wb);
await output.save(temp);
console.log(`EXPORTED ${temp}`);
