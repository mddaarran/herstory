# -*- coding: utf-8 -*-
"""
make_goal_report.py —— 把 _sim2.gd 的 sim_goal_*.csv 渲染成 HTML 看板（单局长度专题）。

用法：python make_goal_report.py <csv路径>
无第三方依赖；图表内联 SVG 手绘，浅色主题。
"""
import csv
import statistics as st
import sys
from collections import defaultdict

STRATS = ["random", "crisis_first", "first_only", "goal_greedy"]
STRAT_CN = {"random": "随机选卡", "crisis_first": "优先危机",
            "first_only": "只选第一张", "goal_greedy": "追目标"}
GOAL_CN = {"goal_treasury": "财政 1000", "goal_gdp": "GDP 1000",
           "goal_population": "人口 600", "goal_military": "军力 700",
           "goal_territory": "领土 400"}
INIT = {"treasury": 500, "gdp": 500, "population": 300, "military": 200, "territory": 150}


def q(xs, p):
    if not xs:
        return 0
    s = sorted(xs)
    if len(s) == 1:
        return s[0]
    k = (len(s) - 1) * p
    lo, hi = int(k), min(int(k) + 1, len(s) - 1)
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def table(headers, rows, aligns=None):
    aligns = aligns or ["l"] * len(headers)
    th = "".join(f'<th class="{a}">{h}</th>' for h, a in zip(headers, aligns))
    trs = "".join("<tr>" + "".join(f'<td class="{a}">{c}</td>' for c, a in zip(r, aligns)) + "</tr>" for r in rows)
    return f'<table><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>'


def bars(items, vmax, width=380, color="#8e6f3e", unit="年"):
    out, y = [], 0
    for label, value in items:
        w = 0 if vmax == 0 else width * value / vmax
        out.append(f'<text x="0" y="{y+14}" class="bl">{label}</text>'
                   f'<rect x="150" y="{y+3}" width="{w:.1f}" height="14" fill="{color}" rx="2"/>'
                   f'<text x="{156+w:.1f}" y="{y+14}" class="bv">{value:g}{unit}</text>')
        y += 24
    return f'<svg viewBox="0 0 620 {max(y,24)}" class="chart">{"".join(out)}</svg>'


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "sim_goal"
    rows = list(csv.DictReader(open(path, "r", encoding="utf-8")))
    for r in rows:
        for k in ("rounds", "reached", "target", "end_value", "ability_points",
                  "insight", "influence", "majesty", "total_events", "crisis_resolved"):
            r[k] = int(r[k])

    by = defaultdict(list)
    for r in rows:
        by[(r["goal_id"], r["strategy"])].append(r)
    goals = sorted({r["goal_id"] for r in rows})

    # 主表：目标 × 策略
    main_rows = []
    for g in goals:
        for s in STRATS:
            rs = by.get((g, s), [])
            if not rs:
                continue
            done = [r["rounds"] for r in rs if r["reached"]]
            rate = 100.0 * len(done) / len(rs)
            med = round(st.median(done), 1) if done else 0
            main_rows.append([GOAL_CN.get(g, g), STRAT_CN[s], f"{rate:.1f}%",
                              med if done else "—",
                              f"{q(done,0.25):.0f}~{q(done,0.75):.0f}" if done else "—",
                              max(done) if done else "—",
                              round(st.mean([r["total_events"] for r in rs]), 1)])

    # 每年推进速度（追目标）
    speed_rows = []
    for g in goals:
        rs = [r for r in by.get((g, "goal_greedy"), []) if r["reached"]]
        if not rs:
            continue
        state = rs[0]["state"]
        init, tgt = INIT[state], rs[0]["target"]
        med = st.median([r["rounds"] for r in rs])
        per = (tgt - init) / med
        y15, y20 = init + per * 15, init + per * 20
        ok15 = "✓" if y15 >= tgt else f"✗ 差 {tgt - y15:.0f}"
        speed_rows.append([GOAL_CN.get(g, g), init, tgt, int(tgt - init), f"{med:.0f}",
                           f"{per:.1f}", f"{y15:.0f}", f"{y20:.0f}", ok15])

    # 策略总览
    ov_rows = []
    for s in STRATS:
        rs = [r for r in rows if r["strategy"] == s]
        done = [r["rounds"] for r in rs if r["reached"]]
        ov_rows.append([STRAT_CN[s], f"{100.0*len(done)/len(rs):.1f}%",
                        round(st.median(done), 1) if done else "—",
                        min(done) if done else "—", max(done) if done else "—",
                        round(st.mean([r["total_events"] for r in rs]), 1),
                        round(st.mean([r["insight"]+r["influence"]+r["majesty"] for r in rs]), 2)])

    chart_items = []
    for g in goals:
        a = [r["rounds"] for r in by.get((g, "random"), []) if r["reached"]]
        b = [r["rounds"] for r in by.get((g, "goal_greedy"), []) if r["reached"]]
        chart_items.append((f"{GOAL_CN.get(g,g)} 随机", round(st.median(a), 1) if a else 0))
        chart_items.append((f"{GOAL_CN.get(g,g)} 追目标", round(st.median(b), 1) if b else 0))

    html = f"""<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>Herstory 单局长度模拟报告</title>
<style>
:root {{ --bg:#f7f5f0; --card:#fff; --line:#e2ddd2; --ink:#2b2823; --dim:#7a7368;
         --accent:#8e6f3e; --red:#c0392b; --amber:#d68910; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; padding:32px 40px 60px; background:var(--bg); color:var(--ink);
       font:14px/1.6 -apple-system,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif; }}
h1 {{ font-size:22px; margin:0 0 6px; }}
.sub {{ color:var(--dim); font-size:12.5px; margin-bottom:26px; }}
.card {{ background:var(--card); border:1px solid var(--line); border-radius:8px;
        padding:20px 22px; margin-bottom:18px; }}
h2 {{ font-size:15px; margin:0 0 4px; padding-bottom:8px; border-bottom:1px solid var(--line); }}
.h2note {{ color:var(--dim); font-size:12px; margin:8px 0 14px; }}
table {{ border-collapse:collapse; width:100%; font-size:13px; margin-top:6px; }}
th,td {{ padding:6px 10px; border-bottom:1px solid #f0ece4; text-align:left; }}
th {{ color:var(--dim); font-weight:600; font-size:12px; background:#fbf9f5; }}
td.r,th.r {{ text-align:right; }}
tbody tr:hover {{ background:#faf7f1; }}
.chart {{ width:100%; height:auto; margin:6px 0 2px; }}
.chart .bl {{ font-size:12px; fill:#2b2823; }}
.chart .bv {{ font-size:11.5px; fill:#7a7368; }}
.note {{ background:#fdf8ec; border-left:3px solid var(--amber); padding:10px 14px;
        font-size:12.5px; margin-top:12px; border-radius:0 4px 4px 0; }}
.warn {{ background:#fbecea; border-left-color:var(--red); }}
.kpi {{ display:flex; gap:14px; flex-wrap:wrap; margin-bottom:18px; }}
.kpi div {{ flex:1 1 150px; background:var(--card); border:1px solid var(--line);
           border-radius:8px; padding:12px 14px; }}
.kpi b {{ display:block; font-size:20px; color:var(--accent); font-weight:600; }}
.kpi span {{ font-size:12px; color:var(--dim); }}
code {{ background:#f2eee6; padding:1px 5px; border-radius:3px; font-size:12px; }}
</style></head><body>
<h1>单局长度：玩到结局要几年</h1>
<div class="sub">5 个目标 × 4 种策略 × 500 局 = {len(rows)} 局 · 结束条件为「达成君主目标 → 触发大议 → 处置大议 → 结局」·
轮数上限 40（到点未达成记为未达成）· 引擎内无头跑批</div>

<div class="kpi">
  <div><b>{int(round(st.median([r['rounds'] for r in rows if r['strategy']=='goal_greedy' and r['reached']]),0))}</b><span>追目标玩家中位年数</span></div>
  <div><b>{int(round(st.median([r['rounds'] for r in rows if r['strategy']=='random' and r['reached']]),0))}</b><span>随机玩家中位年数</span></div>
  <div><b>{sum(1 for r in rows if r['strategy']=='random' and r['reached'])/max(sum(1 for r in rows if r['strategy']=='random'),1)*100:.0f}%</b><span>随机玩家达成结局的比例</span></div>
  <div><b>{round(st.mean([r['total_events'] for r in rows if r['strategy']=='goal_greedy']),0):.0f}</b><span>追目标单局卡面数</span></div>
</div>

<div class="card">
<h2>A. 各目标 × 各策略的局长度</h2>
<div class="h2note">「年数」= 事件处理次数（每轮处置 1 张，最后一年处置大议）。
P25~P75 = 中间一半局落在的区间。「卡面数」= 单局见过的事件卡总数（含被不作为的那一半）。</div>
{table(["目标","策略","达成率","中位年数","P25~P75","最长","卡面数"], main_rows,
       ["l","l","r","r","r","r","r"])}
{bars(chart_items, vmax=40, unit=" 年")}
<div class="note"><b>追目标</b>（会看角标、专挑能推进目标的卡的玩家）13~23 年；
<b>随机选卡</b> 27~34 年，且有 20~80% 的局根本走不到结局。差了一倍还多。</div>
</div>

<div class="card">
<h2>B. 每年推进速度 —— 目标值该定多少</h2>
<div class="h2note">用「追目标」策略的中位年数反推每年的资产推进量，再看 15 / 20 年能走到哪。
主策划案的单局设计意图是 12~15 轮。</div>
{table(["目标","初值","现目标","缺口","中位年数","每年推进","15年可达","20年可达","15年能否达标"],
       speed_rows, ["l","r","r","r","r","r","r","r","l"])}
<div class="note warn">财政 1000 / GDP 1000 / 人口 600 三个目标<b>按 15 年设计是准的</b>（13 / 14 / 15 年）。
<b>军力 700 与领土 400 定高了</b>：军力 15 年只能走到约 557（21 年才够），领土 15 年只到约 313（需要 23 年）。
要么把目标降到 军力 ≈550 / 领土 ≈310，要么给这两个值补推进幅度更大的事件 —— 领土每年只推进 10.9，
是所有目标里最慢的（日常事件对领土的正值均值仅 17.5）。</div>
</div>

<div class="card">
<h2>C. 策略总览</h2>
<div class="h2note">能力终值 = 建卡 2 点 + 危机成长；局越长，拿到的点数越多。</div>
{table(["策略","达成率","中位年数","最短","最长","平均卡面数","能力终值均值"], ov_rows,
       ["l","r","r","r","r","r","r"])}
<div class="note">反直觉的一点：<b>随机玩家的能力终值（9.39）远高于追目标玩家（6.32）</b>——
因为局长 30 年、危机判定机会多，能力一路涨到接近上限 10。追目标玩家 17 年就结束了，只来得及拿 4.3 点。
也就是说「玩得好」反而会让能力成长这条线显得更短。</div>
</div>

<div class="card">
<h2>D. 复现方式</h2>
<pre style="background:#f2eee6;padding:12px 14px;border-radius:5px;font-size:12px;overflow:auto">
cp _AIagent/05_Tools/sim_godot/_sim2.gd _sim2.tscn _AIagent/02_Godot_Project/herstory/
cd _AIagent/02_Godot_Project/herstory
Godot_v4.7.2-stable_win64_console.exe --headless --quiet --path . res://_sim2.tscn &gt; /dev/null 2&gt;&amp;1
python _AIagent/05_Tools/analyze_goal.py outputs/sim_goal_YYYYMMDD.csv
python _AIagent/05_Tools/make_goal_report.py outputs/sim_goal_YYYYMMDD.csv</pre>
<div class="note">⚠️ 模拟脚本每局开头<b>必须调 <code>_em.reset()</code></b>。漏掉的话 EventManager 的
冷却 / 危机状态会跨局累积，第二局起开局即空池（第一轮就抽不出卡），结果全是 1 轮且达成率 0 —— 我踩过。</div>
</div>
</body></html>"""

    out = path.replace(".csv", "") + "_report.html"
    open(out, "w", encoding="utf-8").write(html)
    print("报告已写出：" + out)


if __name__ == "__main__":
    main()
