import fs from "node:fs/promises";

const path = "C:/Users/maodr/Desktop/Herstory/_AIagent/02_Godot_Project/herstory/data/major_events.json";
const data = JSON.parse(await fs.readFile(path, "utf8"));
const targetByGoal = {
  goal_treasury: "treasury",
  goal_gdp: "gdp",
  goal_military: "military",
  goal_population: "population",
  goal_territory: "territory",
};

for (const event of data.events ?? []) {
  const lockedState = targetByGoal[event.goal_id];
  if (!lockedState) continue;
  for (const plan of event.plans ?? []) {
    for (const tier of ["full", "partial", "fail"]) {
      if (plan.effects?.[tier]) delete plan.effects[tier][lockedState];
    }
  }
}

await fs.writeFile(path, JSON.stringify(data, null, 2) + "\n", "utf8");
console.log(`UPDATED ${path}`);
