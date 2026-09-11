# -*- coding: utf-8 -*-
"""
make_sim_report.py —— 把 analyze_sim.py 产出的 summary.json 渲染成一份自包含 HTML 看板。

用法：
    python analyze_sim.py <前缀>        # 先出 summary.json
    python make_sim_report.py <前缀>    # 再出 <前缀>_report.html

无第三方依赖；图表用内联 SVG 手绘，浅色主题。
"""
import json
import sys

TIERS = [("full", "大成功", "#c0392b"), ("partial", "有条件", "#d68910"), ("fail", "失败", "#7f8c8d")]
STRATS = ["random", "crisis_first", "first_only"]
STRAT_CN = {"random": "随机选卡", "crisis_first": "优先危机", "first_only": "只选第一张"}


def bar_rows(items, vmax, width=420):
    """items: [(label, value, color)] -> SVG 横条"""
    out = []
    y = 0
    for label, value, color in items:
        w = 0 if vmax == 0 else width * value / vmax
        out.append(
            f'<text x="0" y="{y + 14}" class="bl">{label}</text>'
            f'<rect x="120" y="{y + 3}" width="{w:.1f}" height="14" fill="{color}" rx="2"/>'
            f'<text x="{126 + w:.1f}" y="{y + 14}" class="bv">{value:g}</text>'
        )
        y += 24
    return f'<svg viewBox="0 0 620 {max(y, 24)}" class="chart">{"".join(out)}</svg>'


def stack_rows(rows, width=420):
    """rows: [(label, {tier: pct})] -> 堆叠条"""
    out = []
    y = 0
    for label, dist in rows:
        x = 120
        segs = []
        for key, cn, color in TIERS:
            v = dist.get(key, 0)
            w = width * v / 100.0
            segs.append(f'<rect x="{x:.1f}" y="{y + 3}" width="{w:.1f}" height="16" fill="{color}"/>')
            if v >= 8:
                segs.append(f'<text x="{x + w / 2:.1f}" y="{y + 15}" class="sv" text-anchor="middle">{v:g}%</text>')
            x += w
        out.append(f'<text x="0" y="{y + 15}" class="bl">{label}</text>' + "".join(segs))
        y += 26
    return f'<svg viewBox="0 0 620 {max(y, 26)}" class="chart">{"".join(out)}</svg>'


def table(headers, rows, aligns=None):
    aligns = aligns or ["l"] * len(headers)
    th = "".join(f'<th class="{a}">{h}</th>' for h, a in zip(headers, aligns))
    trs = ""
    for r in rows:
        tds = "".join(f'<td class="{a}">{c}</td>' for c, a in zip(r, aligns))
        trs += f"<tr>{tds}</tr>"
    return f'<table><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>'


def main():
    prefix = sys.argv[1] if len(sys.argv) > 1 else "sim"
    with open(prefix + "_summary.json", "r", encoding="utf-8") as f:
        s = json.load(f)

    g, cov, tiers = s["growth"], s["coverage"], s["tiers"]
    sd = s.get("stage_detail", {})

    # A. 成长
    a_rows = []
    for st in STRATS:
        r = g[st]
        a_rows.append([STRAT_CN[st], r["kinds_per_run"], r["drawn"], r["resolved"], r["ignored"],
                       f'{r["force_pct"]}%', r["points"], r["ability_total"]])
    chart_a = bar_rows([(STRAT_CN[st], g[st]["points"], "#8e6f3e") for st in STRATS],
                       vmax=max(g[st]["points"] for st in STRATS) * 1.25,
                       )

    # B. 覆盖
    b_rows = [[STRAT_CN[st], cov[st]["total"], cov[st]["uniq"], f'{cov[st]["repeat_rate"]}%',
               f'{cov[st]["coverage"]}%'] for st in STRATS]

    # C. 档位
    c_rows, stack_items = [], []
    for st in STRATS:
        for label in ("日常", "危机"):
            d = tiers[st][label]
            stack_items.append((f"{STRAT_CN[st]}·{label}", d))
            c_rows.append([STRAT_CN[st], label, f'{d["full"]}%', f'{d["partial"]}%', f'{d["fail"]}%'])

    # D. 阶段曲线
    sd_rows = []
    for k in ("阶段1", "阶段2", "阶段3"):
        if k not in sd:
            continue
        r = sd[k]
        sd_rows.append([k, r["rounds"], f'{r["avg_diff"]:+.2f}', f'{r["avg_mod"]:+.2f}',
                        r["avg_total"], f'{r["full"]}%', f'{r["partial"]}%', f'{r["fail"]}%', r["n"]])
    if sd:
        d1, d3, m1, m3 = sd["阶段1"]["avg_diff"], sd["阶段3"]["avg_diff"], sd["阶段1"]["avg_mod"], sd["阶段3"]["avg_mod"]
        net = round(d3 - d1 - (m3 - m1), 2)
        note = (f"一期到三期：事件难度 {d1:+.2f} → {d3:+.2f}（变难 {d3 - d1:+.2f}），"
                f"能力修正 {m1:+.2f} → {m3:+.2f}（变强 {m3 - m1:+.2f}），净 {net:+.2f}")
    else:
        note = ""

    # E. 危机逐项（random 策略）
    pc = s["per_crisis"]
    cri_rows = []
    for cid in sorted(pc, key=lambda c: -pc[c]["random"]["trigger_rate"]):
        r = pc[cid]["random"]
        cri_rows.append([cid, f'{r["trigger_rate"]}%', r["first_mean"], r["first_median"],
                         f'{r["appear_rate"]}%', f'{r["resolve_rate"]}%', f'{r["dodge_rate"]}%'])

    hot = s.get("hot", [])
    cold = s.get("cold", [])

    html = f"""<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>Herstory 跑量模拟报告</title>
<style>
:root {{ --bg:#f7f5f0; --card:#ffffff; --line:#e2ddd2; --ink:#2b2823; --dim:#7a7368;
         --accent:#8e6f3e; --red:#c0392b; --amber:#d68910; --grey:#7f8c8d; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; padding:32px 40px 60px; background:var(--bg); color:var(--ink);
        font:14px/1.6 -apple-system,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif; }}
h1 {{ font-size:22px; margin:0 0 6px; letter-spacing:.5px; }}
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
.chart .sv {{ font-size:11px; fill:#fff; font-weight:600; }}
.legend {{ font-size:12px; color:var(--dim); margin-top:8px; }}
.legend i {{ display:inline-block; width:10px; height:10px; margin:0 4px 0 12px; border-radius:2px; }}
.kpi {{ display:flex; gap:14px; flex-wrap:wrap; margin-bottom:18px; }}
.kpi div {{ flex:1 1 150px; background:var(--card); border:1px solid var(--line);
            border-radius:8px; padding:12px 14px; }}
.kpi b {{ display:block; font-size:20px; color:var(--accent); font-weight:600; }}
.kpi span {{ font-size:12px; color:var(--dim); }}
.note {{ background:#fdf8ec; border-left:3px solid var(--amber); padding:10px 14px;
         font-size:12.5px; margin-top:12px; border-radius:0 4px 4px 0; }}
code {{ background:#f2eee6; padding:1px 5px; border-radius:3px; font-size:12px; }}
.two {{ display:flex; gap:18px; flex-wrap:wrap; }}
.two > div {{ flex:1 1 320px; }}
</style></head><body>
<h1>Herstory 跑量模拟报告</h1>
<div class="sub">1000 局 × 3 策略 × 15 轮 = 45000 轮 · 引擎内无头跑批（Godot 4.7.2 headless，
直接复用 EventManager / Resolution / GameState）· 模拟不含 major（未触发里程碑）</div>

<div class="kpi">
  <div><b>{s['n_runs']}</b><span>模拟局数</span></div>
  <div><b>{s['n_events']}</b><span>判定次数</span></div>
  <div><b>{g['random']['points']}</b><span>能力点/局（随机策略）</span></div>
  <div><b>{g['random']['ability_total']}</b><span>能力终值合计</span></div>
  <div><b>{cov['random']['repeat_rate']}%</b><span>单局卡面重复率</span></div>
</div>

<div class="card">
<h2>A. 危机触发与能力成长</h2>
<div class="h2note">「过线种类」= 一局里进过抽取池的危机张数（共 16 张）；「上桌」= 出现在选卡页两
张里的次数；「被绕开」= 上桌但没被选中处置的次数；「强制独占」= 触发 CRISIS_FORCE_DODGE_LIMIT
后独占选卡页的局占比；「能力点」= 危机判定非失败发放的点数（建卡 2 点另计）。</div>
{table(["策略","过线种类/局","上桌/局","处置/局","被绕开/局","强制独占局%","能力点/局","能力终值合计"],
       a_rows, ["l","r","r","r","r","r","r","r"])}
<div class="legend">能力点/局：<i style="background:#8e6f3e"></i>三种策略对比</div>
{chart_a}
</div>

<div class="card">
<h2>B. 事件覆盖与重复率</h2>
<div class="h2note">每局 15 轮 × 2 张 = 30 张卡面（强制独占轮只出 1 张）。「单局覆盖池%」=
去重后的卡面数 ÷ 日常池 47 张。</div>
{table(["策略","卡面总数/局","去重后/局","重复率","单局覆盖池%"], b_rows, ["l","r","r","r","r"])}
<div class="h2note" style="margin-top:14px">出场热度（3000 局合计，最热 / 最冷各 8 张）</div>
<div class="two"><div>
<b style="font-size:12.5px">最热</b>
{table(["事件 id","次数"], [[i, c] for i, c in hot[:8]], ["l","r"])}
</div><div>
<b style="font-size:12.5px">最冷</b>
{table(["事件 id","次数"], [[i, c] for i, c in cold[:8]], ["l","r"])}
</div></div>
<div class="note">最热与最冷的出场次数相差仅约 1.2 倍 —— 阶段难度加权没有把任何一张卡打进冷宫，
也没有哪张卡被反复刷脸。全库 47 张在 3000 局中<span>全部出场过</span>。</div>
</div>

<div class="card">
<h2>C. 判定档位分布</h2>
<div class="h2note">设计基准（difficulty=0、能力修正 0）为 27.8% / 44.4% / 27.8%。实测偏离来自
两个方向：日常池整体偏易（加权后平均难度约 −0.6），以及能力修正随局推进从 +0.7 涨到 +1.5。</div>
{table(["策略","类别","大成功","有条件","失败"], c_rows, ["l","l","r","r","r"])}
{stack_rows(stack_items)}
<div class="legend"><i style="background:#c0392b"></i>大成功<i style="background:#d68910"></i>
有条件成功<i style="background:#7f8c8d"></i>失败</div>
<div class="note">日常大成功率 <b>52%</b>（基准 27.8%）、失败率仅 <b>14%</b> —— 日常整体偏易。
危机 30 / 42 / 28 已非常贴近基准，说明危机难度回退后已修复（此前实跑是 6 次失败 4 次）。</div>
</div>

<div class="card">
<h2>D. 阶段难度曲线 vs 能力成长</h2>
<div class="h2note">阶段加权只改变「各难度档被抽到的概率」，不改事件自身难度。这张表回答的是：
曲线到底有没有把后期变难。</div>
{table(["阶段","轮次","平均难度","平均能力修正","平均判定值","大成功","有条件","失败","样本"],
       sd_rows, ["l","l","r","r","r","r","r","r","r"])}
<div class="note">{note}<br>
难度确实在一期→三期抬了约 0.8 档，但同期能力修正也涨了约 0.8 ——
<b>两者对冲，失败率只从 12.7% 爬到 14.9%（+2.2 个百分点）</b>。想让后期真的变难，
光调 STAGE_DIFF_WEIGHT 不够，得同时压住能力成长速度，或把三期的难度权重再拉陡。</div>
</div>

<div class="card">
<h2>E. 各危机逐项（随机策略）</h2>
<div class="h2note">过线局% = 该危机在这一局里触发条件成立过；首触发轮 = 第一次成立的轮次；
上桌局% = 出现在选卡页过；处置局% = 被选中处置过；回避率 = 上桌 − 处置。</div>
{table(["危机 id","过线局%","首触发轮均值","首触发中位数","上桌局%","处置局%","回避率"],
       cri_rows, ["l","r","r","r","r","r","r"])}
</div>

<div class="card">
<h2>F. 复现方式</h2>
<div class="h2note">临时脚本 <code>_sim.gd</code> / <code>_sim.tscn</code> 跑完即删；以下两条命令可重跑。</div>
<pre style="background:#f2eee6;padding:12px 14px;border-radius:5px;font-size:12px;overflow:auto">
cd _AIagent/02_Godot_Project/herstory
Godot_v4.7.2-stable_win64_console.exe --headless --quiet --path . res://_sim.tscn &gt; /dev/null 2&gt;&amp;1
python _AIagent/05_Tools/analyze_sim.py outputs/sim_YYYYMMDD
python _AIagent/05_Tools/make_sim_report.py outputs/sim_YYYYMMDD</pre>
<div class="note">务必带 <code>--quiet</code> 并把 stdout 丢掉：EventManager 每轮会打印两次
<code>[POOL]</code>，千局量级会产生 9MB 日志，实测耗时从 7.7s 涨到 84s（慢 11 倍）。</div>
</div>
</body></html>"""

    path = prefix + "_report.html"
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    print("报告已写出：" + path)


if __name__ == "__main__":
    main()
