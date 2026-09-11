# -*- coding: utf-8 -*-
"""
analyze_goal.py —— 读 _sim2.gd 导出的 sim_goal_*.csv，回答「玩到结局要几年」。

用法：python analyze_goal.py <csv路径>

输出：按目标×策略的局长度分布（达成率 / 中位数 / 均值 / P25 / P75 / 最长），
      并把结构化结果写 <前缀>_summary.json 供出图。纯标准库。
"""
import csv
import json
import statistics as st
import sys
from collections import defaultdict

STRATS = ["random", "crisis_first", "first_only", "goal_greedy"]
STRAT_CN = {"random": "随机选卡", "crisis_first": "优先危机",
            "first_only": "只选第一张", "goal_greedy": "追目标"}


def pct(x, n):
    return 0.0 if n == 0 else 100.0 * x / n


def q(xs, p):
    """分位数（线性插值）"""
    if not xs:
        return 0
    s = sorted(xs)
    if len(s) == 1:
        return s[0]
    k = (len(s) - 1) * p
    lo, hi = int(k), min(int(k) + 1, len(s) - 1)
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "sim_goal"
    rows = list(csv.DictReader(open(path, "r", encoding="utf-8")))
    for r in rows:
        for k in ("rounds", "reached", "target", "end_value", "crisis_appeared",
                  "crisis_resolved", "force_dodge", "ability_points", "insight",
                  "influence", "majesty", "uniq_events", "total_events"):
            r[k] = int(r[k])

    by = defaultdict(list)
    for r in rows:
        by[(r["goal_id"], r["strategy"])].append(r)
    goals = [g for g, _ in by]
    goals = sorted({g for g, _ in by})

    print("=" * 96)
    print("单局长度：从开局到大议结算，要几年（= 事件处理次数，每轮处置 1 张）")
    print("=" * 96)
    print(f"{'目标':<22}{'策略':<14}{'达成率':>8}{'中位':>7}{'均值':>7}{'P25':>6}{'P75':>6}"
          f"{'最长':>6}{'未达成':>8}{'卡面数':>8}")

    out = {"rows": [], "by_goal": {}}
    for g in goals:
        for s in STRATS:
            rs = by.get((g, s), [])
            if not rs:
                continue
            reached = [r["rounds"] for r in rs if r["reached"]]
            rate = pct(len(reached), len(rs))
            cards = st.mean([r["total_events"] for r in rs]) if rs else 0
            rec = {
                "goal": g, "strategy": s, "n": len(rs),
                "reach_rate": round(rate, 1),
                "median": round(st.median(reached), 1) if reached else 0,
                "mean": round(st.mean(reached), 1) if reached else 0,
                "p25": round(q(reached, 0.25), 1) if reached else 0,
                "p75": round(q(reached, 0.75), 1) if reached else 0,
                "max": max(reached) if reached else 0,
                "cards": round(cards, 1),
            }
            out["rows"].append(rec)
            print(f"{g:<22}{STRAT_CN[s]:<14}{rate:>7.1f}%{rec['median']:>7.1f}{rec['mean']:>7.1f}"
                  f"{rec['p25']:>6.1f}{rec['p75']:>6.1f}{rec['max']:>6}{100 - rate:>7.1f}%{cards:>8.1f}")

    # 汇总：只看达成局
    print("\n只看达成结局的局（未达成不计入）：")
    print(f"{'目标':<22}{'策略':<14}{'局数':>7}{'最快':>7}{'中位':>7}{'最慢':>7}{'大成功局%':>11}")
    for g in goals:
        for s in STRATS:
            rs = [r for r in by.get((g, s), []) if r["reached"]]
            if not rs:
                print(f"{g:<22}{STRAT_CN[s]:<14}{0:>7}{'-':>7}{'-':>7}{'-':>7}{'-':>11}")
                continue
            yrs = [r["rounds"] for r in rs]
            full = pct(sum(1 for r in rs if r["major_tier"] == "full"), len(rs))
            print(f"{g:<22}{STRAT_CN[s]:<14}{len(rs):>7}{min(yrs):>7}{round(st.median(yrs), 1):>7}"
                  f"{max(yrs):>7}{full:>10.1f}%")

    # 全体（跨目标）总览
    print("\n按策略总览（5 个目标合并，只算达成局）：")
    print(f"{'策略':<14}{'达成率':>9}{'中位年数':>10}{'均值年数':>10}{'最短-最长':>14}{'平均卡面数':>12}")
    for s in STRATS:
        rs = [r for r in rows if r["strategy"] == s]
        done = [r["rounds"] for r in rs if r["reached"]]
        if not done:
            continue
        print(f"{STRAT_CN[s]:<14}{pct(len(done), len(rs)):>8.1f}%{st.median(done):>10.1f}"
              f"{st.mean(done):>10.1f}{str(min(done)) + '-' + str(max(done)):>14}"
              f"{st.mean([r['total_events'] for r in rs]):>12.1f}")
        out.setdefault("by_strategy", {})[s] = {
            "reach_rate": round(pct(len(done), len(rs)), 1),
            "median": round(st.median(done), 1),
            "mean": round(st.mean(done), 1),
            "min": min(done), "max": max(done),
            "cards": round(st.mean([r["total_events"] for r in rs]), 1),
        }

    # 目标缺口 vs 达成速度
    print("\n目标缺口与达成速度（策略=追目标）：")
    print(f"{'目标':<22}{'初值':>7}{'目标值':>8}{'缺口':>7}{'中位年数':>10}{'每年推进':>10}")
    for g in goals:
        rs = [r for r in by.get((g, "goal_greedy"), []) if r["reached"]]
        if not rs:
            print(f"{g:<22}{'-':>7}{'-':>8}{'-':>7}{'未达成':>10}")
            continue
        init, tgt = rs[0]["target"], rs[0]["target"]
        med = st.median([r["rounds"] for r in rs])
        print(f"{g:<22}{'?':>7}{tgt:>8}{'?':>7}{med:>10.1f}{'?':>10}")

    with open(path.replace(".csv", "") + "_summary.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("\n汇总已写入 " + path.replace(".csv", "") + "_summary.json")


if __name__ == "__main__":
    main()
