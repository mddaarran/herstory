import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.xlsx";
const outputPath = "C:/Users/maodr/Desktop/Herstory/_AIagent/01_Game_Design/Numbers/N_事件全量表_原子朋克文案_V1.2.updated.xlsx";

const input = await FileBlob.load(inputPath);
const wb = await SpreadsheetFile.importXlsx(input);

const oldStandard = wb.worksheets.getItemOrNullObject?.("数值基准");
if (oldStandard && !oldStandard.isNullObject) oldStandard.delete();

const existing = wb.worksheets.getItemOrNullObject?.("Major事件文案");
if (existing && !existing.isNullObject) existing.delete();
const sheet = wb.worksheets.add("Major事件文案");
sheet.showGridLines = false;

const headers = [
  "event_id", "event_title", "type", "goal_id", "trigger_state", "trigger_value",
  "background", "plan_id", "plan_name", "ability", "difficulty",
  "full_text", "partial_text", "fail_text",
  "death_cause_full", "death_cause_partial", "death_cause_fail"
];

const events = [
  {
    id: "major_treasury_coup", title: "国库之火", goal: "goal_treasury", state: "treasury", value: 1000,
    background: "国库的数字终于突破了一千。消息传出后，宫廷、贵族与商会同时要求接管财政。入夜，叛军封锁宫门，国库方向升起第一道火光。",
    plans: [
      ["guard_treasury", "亲自守卫国库", "majesty", "0", "君主守住了国库，也击退了第一批叛军。然而火势已经吞没梁柱，她最终倒在坍塌的金库中。", "国库保住了一半，君主却在护送账册时遭到刺伤，伤势恶化而死。", "叛军攻入国库，君主在混乱中被乱军刺杀。", "死于国库火灾后的建筑坍塌。", "护送账册时遭刺伤，伤势恶化而死。", "在国库混战中被乱军刺杀。"],
      ["open_treasury", "打开国库赈济城市", "influence", "0", "粮食与钱币被送入城中，暴动很快平息。君主返回宫殿时，被失去特权的贵族刺杀。", "赈济只够拯救部分街区，城中秩序暂时恢复，但君主在谈判中遭到毒杀。", "国库被洗劫，赈济未能阻止暴动，君主在逃离宫城时被民兵杀死。", "被失去特权的贵族刺杀。", "在宫廷谈判中遭到毒杀。", "逃离宫城时被民兵杀死。"],
      ["burn_ledgers", "焚毁账册与财富凭证", "insight", "0", "账册被火焰吞没，任何人都无法完整接管国库。君主在撤离时死于叛军伏击。", "部分账册被烧毁，但君主也被困在火场中，最终窒息而死。", "焚毁命令未能执行，君主被叛军捕获并处决。", "撤离国库时遭叛军伏击。", "被困火场，最终窒息而死。", "被叛军捕获并处决。"]
    ]
  },
  {
    id: "major_guild_revolt", title: "繁荣的城门", goal: "goal_gdp", state: "gdp", value: 1000,
    background: "城市的工坊昼夜不息，商船挤满港口。但繁荣已经养出了不再愿意服从王权的力量。商会关闭城门，宣布城市只接受自己的法律。",
    plans: [
      ["suppress_guild", "调军镇压商业联盟", "majesty", "0", "军队攻破城门，君主在巡视战后的工坊时遭到商会刺客射杀。", "城市被迫投降，但巷战持续到最后一刻，君主死于流矢。", "军队被困在城中，君主在突围时被叛乱工人杀死。", "巡视战后工坊时遭商会刺杀。", "在持续巷战中被流矢射杀。", "突围时被叛乱工人杀死。"],
      ["grant_autonomy", "承认城市自治", "influence", "0", "自治协议顺利签署，城市重新开放。君主在签约后的庆典上遭到刺杀。", "协议只得到部分承认，君主被激进派商人刺伤，数日后死亡。", "谈判破裂，君主在撤离城市时被暴民围杀。", "在自治协议签署后的庆典上遭刺杀。", "被激进派商人刺伤，数日后死亡。", "撤离城市时被暴民围杀。"],
      ["enter_workshop", "亲自进入主工坊救灾", "insight", "0", "主工坊发生爆炸，君主组织工人撤离后死于第二次爆炸。", "大部分工人获救，君主被坍塌的炉墙重伤，最终不治。", "救援失控，君主与工人一同被埋在废墟之下。", "死于主工坊的第二次爆炸。", "被坍塌的炉墙重伤，最终不治。", "被埋在工坊废墟之下。"]
    ]
  },
  {
    id: "major_final_invasion", title: "最后的入侵", goal: "goal_military", state: "military", value: 700,
    background: "周边国家终于放下彼此的仇恨，组成共同的敌军。她的军队从北境与海岸同时传来警报，战争已经无法避免。",
    plans: [
      ["march_to_battle", "亲自出征迎敌", "majesty", "0", "敌军溃败，君主却在追击残军时被最后一支弩箭射中。", "战役获胜，但君主身受重伤，在军营中死去。", "战线崩溃，君主被敌军包围并当场杀死。", "追击残军时被弩箭射杀。", "在战役胜利后因重伤死于军营。", "战败后被敌军包围并杀死。"],
      ["hold_capital", "死守都城", "insight", "0", "都城守住了，但君主在城墙巡视时被敌军投石击中。", "敌军被挡在城外，君主却在长期围城中因伤病死亡。", "城门被攻破，君主在王宫中被敌军处决。", "巡视城墙时被敌军投石击中。", "在长期围城中因伤病死亡。", "都城陷落后在王宫中被处决。"],
      ["lure_enemy", "诱敌深入后决战", "insight", "0", "敌军落入伏击，君主却在战后遭残余敌军暗杀。", "伏击成功但损失惨重，君主死于战场余波。", "敌军识破计谋，君主在撤退途中被叛将杀死。", "战后遭残余敌军暗杀。", "在战场余波中死亡。", "撤退途中被叛将杀死。"]
    ]
  },
  {
    id: "major_population_disaster", title: "没有空位的城市", goal: "goal_population", state: "population", value: 600,
    background: "全国人口达到前所未有的规模，却也迎来了最严重的灾害。粮仓见底，疫病穿过人口密集的街区，灾民开始冲击官仓与宫门。",
    plans: [
      ["enter_disaster_zone", "亲自进入灾区", "influence", "0", "君主打开救济站并稳定灾区，最终感染疫病而死。", "救出了大部分灾民，但君主在疫区中病重不治。", "灾民冲破护卫，君主在混乱中被踩踏或刺杀。", "感染疫病而死。", "在疫区中病重不治。", "在灾民冲击中被踩踏或刺杀。"],
      ["requisition_grain", "强行征粮维持秩序", "majesty", "0", "主要城市恢复秩序，君主却在返回宫城途中被灾民刺杀。", "粮食被集中起来，但暴动扩散，君主被地方武装伏击。", "征粮激起全面民变，君主被愤怒的人群围杀。", "返回宫城途中被灾民刺杀。", "被地方武装伏击。", "被民变人群围杀。"],
      ["open_royal_granaries", "打开宫廷与贵族粮仓", "insight", "0", "粮食送到灾区，人口危机得到缓解，君主随后被贵族联盟毒杀。", "救济延缓了灾难，但贵族在宫廷宴会上向君主下毒。", "粮仓尚未开启便被贵族控制，君主遭到软禁并杀害。", "被贵族联盟毒杀。", "在宫廷宴会上中毒身亡。", "被贵族软禁后杀害。"]
    ]
  },
  {
    id: "major_frontier_revolt", title: "地图的尽头", goal: "goal_territory", state: "territory", value: 400,
    background: "地图上最后一块空白被填上了。但边疆太长，新的土地拒绝接受旧的旗帜。起义从最远的山口开始，随后蔓延到整条边界。",
    plans: [
      ["march_frontier", "亲自前往最远边疆镇压", "majesty", "0", "边疆军队重新效忠，君主却在返回途中遭到伏击。", "起义被压下，但君主在围城中身受重伤而死。", "边疆军队倒戈，君主被困城中并遭处决。", "返回途中遭边疆叛军伏击。", "在围城中身受重伤而死。", "被倒戈的边疆军队处决。"],
      ["grant_frontier_autonomy", "承认地方自治", "influence", "0", "边疆接受自治协议，君主在签署协议后被中央派刺杀。", "部分地区接受和解，君主在撤离途中遭到伏击。", "中央派与边疆势力同时反对协议，君主在谈判营地中被杀。", "签署自治协议后被中央派刺杀。", "撤离途中遭到伏击。", "在谈判营地中被杀。"],
      ["cross_unknown_border", "继续向未知之地远征", "majesty", "0", "君主越过已知边界，最终在远征中战死。", "远征取得短暂胜利，但补给断绝，君主死于荒野。", "军队在未知土地上溃散，君主失踪，后世只找到她的旗帜。", "在越过边界后的远征中战死。", "补给断绝，死于荒野。", "军队溃散后失踪。"]
    ]
  }
];

const rows = [headers];
for (const e of events) {
  for (const p of e.plans) {
    rows.push([e.id, e.title, "major", e.goal, e.state, e.value, e.background, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9]]);
  }
}

sheet.getRangeByIndexes(0, 0, rows.length, headers.length).values = rows;
sheet.getRange("A1:Q1").format = { fill: "#1F4E78", font: { name: "Arial", size: 10, bold: true, color: "#FFFFFF" }, wrapText: true, verticalAlignment: "center" };
sheet.getRange(`A2:Q${rows.length}`).format = { font: { name: "Arial", size: 10, color: "#222222" }, wrapText: true, verticalAlignment: "top" };
sheet.getRange(`F2:F${rows.length}`).format.numberFormat = "0";
sheet.freezePanes.freezeRows(1);
sheet.getRange(`A1:Q${rows.length}`).format.borders = { preset: "all", style: "thin", color: "#D9E2F3" };
sheet.getRange("A:Q").format.columnWidth = 18;
sheet.getRange("G:G").format.columnWidth = 42;
sheet.getRange("L:Q").format.columnWidth = 42;
sheet.getRange(`A1:Q${rows.length}`).format.autofitRows();

wb.recalculate();
const check = await wb.inspect({ kind: "sheet,table", maxChars: 8000, tableMaxRows: 5, tableMaxCols: 18 });
console.log(check.ndjson);
const preview = await wb.render({ sheetName: "Major事件文案", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile("C:/Users/maodr/Desktop/Herstory/major_events_preview.png", new Uint8Array(await preview.arrayBuffer()));
const output = await SpreadsheetFile.exportXlsx(wb);
await output.save(outputPath);
console.log(`SAVED ${outputPath}`);
