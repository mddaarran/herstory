# -*- coding: utf-8 -*-
"""
analyze_sim.py —— 读 _sim.gd 导出的三份 CSV，输出跑量测试的汇总指标。

用法：
    python analyze_sim.py [前缀]
    例：python analyze_sim.py C:/Users/maodr/Desktop/Herstory/outputs/sim_20260910

输入（由 Godot headless 模拟导出）：
    <前缀>_events.csv   每轮一行（判定明细）
    <前缀>_runs.csv     每局一行（汇总）
    <前缀>_crisis.csv   每局×每个过线危机一行

输出：三大块指标打印到 stdout，并把结构化结果写 <前缀>_summary.json 供出图用。
纯标准库实现，不需要 pandas / numpy。
"""
import csv
import json
import statistics as st
import sys
from collections import Counter, defaultdict

TIERS = ["full", "partial", "fail"]
STRATS = ["random", "crisis_first", "first_only"]


def read_csv(path):
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def pct(x, n):
    return 0.0 if n == 0 else 100.0 * x / n


def mean(xs):
    return sum(xs) / len(xs) if xs else 0.0


def median(xs):
    return st.median(xs) if xs else 0.0


def fmt_dist(counter, n):
    """把 Counter 转成 {tier: 百分比}"""
    return {t: round(pct(counter.get(t, 0), n), 1) for t in TIERS}


def main():
    prefix = sys.argv[1] if len(sys.argv) > 1 else "sim"
    events = read_csv(prefix + "_events.csv")
    runs = read_csv(prefix + "_runs.csv")
    crises = read_csv(prefix + "_crisis.csv")

    for row in runs:
        for k in ("rounds", "crisis_drawn", "crisis_resolved", "crisis_ignored",
                  "force_dodge", "ability_points", "insight", "influence",
                  "majesty", "uniq_events", "total_events"):
            row[k] = int(row[k])
    for row in events:
        for k in ("round", "is_crisis", "other_is_crisis", "mod", "d1", "d2",
                  "diff", "total", "partial_at", "full_at"):
            row[k] = int(row[k])
    for row in crises:
        for k in ("first_trigger_round", "rounds_in_pool", "times_appeared", "times_resolved"):
            row[k] = int(row[k])

    by_strat_runs = defaultdict(list)
    for r in runs:
        by_strat_runs[r["strategy"]].append(r)
    by_strat_ev = defaultdict(list)
    for e in events:
        by_strat_ev[e["strategy"]].append(e)
    by_strat_cr = defaultdict(list)
    for c in crises:
        by_strat_cr[c["strategy"]].append(c)

    out = {"prefix": prefix, "n_runs": len(runs), "n_events": len(events)}

    # ================= A. 危机触发与能力成长 =================
    print("=" * 78)
    print("A. 危机触发与能力成长")
    print("=" * 78)
    print(f"{'策略':<14}{'过线种类/局':>11}{'上桌/局':>9}{'处置/局':>9}{'被绕开/局':>10}"
          f"{'强制独占局%':>12}{'能力点/局':>10}{'能力终值':>9}")
    a = {}
    for s in STRATS:
        rs = by_strat_runs[s]
        crs = by_strat_cr[s]
        kinds = mean([len([c for c in crs if c["run_id"] == r["run_id"]]) for r in rs])
        row = {
            "kinds_per_run": round(kinds, 2),
            "drawn": round(mean([r["crisis_drawn"] for r in rs]), 2),
            "resolved": round(mean([r["crisis_resolved"] for r in rs]), 2),
            "ignored": round(mean([r["crisis_ignored"] for r in rs]), 2),
            "force_pct": round(pct(sum(1 for r in rs if r["force_dodge"] > 0), len(rs)), 1),
            "force_avg": round(mean([r["force_dodge"] for r in rs]), 2),
            "points": round(mean([r["ability_points"] for r in rs]), 2),
            "ability_total": round(mean([r["insight"] + r["influence"] + r["majesty"] for r in rs]), 2),
        }
        a[s] = row
        print(f"{s:<14}{row['kinds_per_run']:>11.2f}{row['drawn']:>9.2f}{row['resolved']:>9.2f}"
              f"{row['ignored']:>10.2f}{row['force_pct']:>11.1f}%{row['points']:>10.2f}"
              f"{row['ability_total']:>9.2f}")
    out["growth"] = a

    # 能力点分布
    print("\n能力点获取分布（每局拿到几点，建卡固定 2 点另计）：")
    print(f"{'策略':<14}" + "".join(f"{'≥' + str(k) + '点局%':>10}" for k in range(0, 6)))
    for s in STRATS:
        rs = by_strat_runs[s]
        cells = "".join(f"{pct(sum(1 for r in rs if r['ability_points'] >= k), len(rs)):>9.1f}%" for k in range(0, 6))
        print(f"{s:<14}{cells}")

    # 各危机详情
    print("\n各危机逐项（过线率 = 该局进过池；处置率 = 被点开处置过）：")
    print(f"{'危机 id':<24}{'策略':<14}{'过线局%':>9}{'首触发轮均值':>13}{'首触发中位':>11}{'上桌局%':>9}{'处置局%':>9}{'回避率':>9}")
    per_crisis = defaultdict(dict)
    for s in STRATS:
        crs = by_strat_cr[s]
        n_run = len(by_strat_runs[s])
        ids = sorted({c["crisis_id"] for c in crs})
        for cid in ids:
            rows = [c for c in crs if c["crisis_id"] == cid]
            firsts = [c["first_trigger_round"] for c in rows]
            rec = {
                "trigger_rate": round(pct(len(rows), n_run), 1),
                "first_mean": round(mean(firsts), 2),
                "first_median": round(median(firsts), 1),
                "appear_rate": round(pct(sum(1 for c in rows if c["times_appeared"] > 0), n_run), 1),
                "resolve_rate": round(pct(sum(1 for c in rows if c["times_resolved"] > 0), n_run), 1),
            }
            rec["dodge_rate"] = round(rec["appear_rate"] - rec["resolve_rate"], 1)
            per_crisis[cid][s] = rec
            print(f"{cid:<24}{s:<14}{rec['trigger_rate']:>8.1f}%{rec['first_mean']:>13.2f}"
                  f"{rec['first_median']:>11.1f}{rec['appear_rate']:>8.1f}%{rec['resolve_rate']:>8.1f}%"
                  f"{rec['dodge_rate']:>8.1f}%")
    out["per_crisis"] = per_crisis

    # ================= B. 事件覆盖与重复率 =================
    print("\n" + "=" * 78)
    print("B. 事件覆盖与重复率")
    print("=" * 78)
    print(f"{'策略':<14}{'抽卡总数/局':>12}{'去重后/局':>11}{'重复率':>9}{'单局覆盖池%':>12}{'全库出场%':>11}")
    b = {}
    daily_ids = {e["event_id"] for e in events if not e["is_crisis"]}
    for s in STRATS:
        rs = by_strat_runs[s]
        evs = by_strat_ev[s]
        seen = Counter(e["event_id"] for e in evs)
        n_daily = len([i for i in seen if i in daily_ids])
        row = {
            "total": round(mean([r["total_events"] for r in rs]), 2),
            "uniq": round(mean([r["uniq_events"] for r in rs]), 2),
            "repeat_rate": round(mean([1 - r["uniq_events"] / max(r["total_events"], 1) for r in rs]) * 100, 1),
            "coverage": round(mean([r["uniq_events"] for r in rs]) / max(len(daily_ids), 1) * 100, 1),
            "lib_used": round(pct(n_daily, len(daily_ids)), 1),
        }
        b[s] = row
        print(f"{s:<14}{row['total']:>12.2f}{row['uniq']:>11.2f}{row['repeat_rate']:>8.1f}%"
              f"{row['coverage']:>11.1f}%{row['lib_used']:>10.1f}%")
    out["coverage"] = b

    # 事件出场热度（全策略合计）
    print(f"\n日常事件出场热度（全 3 策略 {len(runs)} 局合计，池内共 {len(daily_ids)} 张）：")
    all_seen = Counter(e["event_id"] for e in events if not e["is_crisis"])
    hot = all_seen.most_common()
    print("  出场最多 8 张：" + "  ".join(f"{i}({c})" for i, c in hot[:8]))
    print("  出场最少 8 张：" + "  ".join(f"{i}({c})" for i, c in hot[-8:]))
    zero = sorted(daily_ids - set(all_seen))
    print(f"  从未出场：{len(zero)} 张" + (f" → {', '.join(zero[:12])}" if zero else ""))
    out["hot"] = hot[:10]
    out["cold"] = hot[-10:]
    out["never_seen"] = zero

    # ================= C. 判定档位分布 =================
    print("\n" + "=" * 78)
    print("C. 判定档位分布（%）")
    print("=" * 78)
    print(f"{'策略':<14}{'类别':<8}{'大成功':>9}{'有条件':>9}{'失败':>9}{'样本':>9}")
    c = {}
    for s in STRATS:
        evs = by_strat_ev[s]
        for label, flt in (("日常", lambda e: not e["is_crisis"]),
                           ("危机", lambda e: e["is_crisis"])):
            sub = [e for e in evs if flt(e)]
            cnt = Counter(e["tier"] for e in sub)
            c.setdefault(s, {})[label] = fmt_dist(cnt, len(sub))
            print(f"{s:<14}{label:<8}" + "".join(f"{pct(cnt.get(t, 0), len(sub)):>8.1f}%" for t in TIERS)
                  + f"{len(sub):>9}")
    out["tiers"] = c

    # 按阶段分（阶段1: 1-5轮 / 阶段2: 6-10 / 阶段3: 11-15）
    print("\n日常事件按阶段（策略=random）：")
    print(f"{'阶段':<10}{'轮次':<10}{'大成功':>9}{'有条件':>9}{'失败':>9}{'样本':>9}")
    stage_tiers = {}
    for si, (lo, hi) in enumerate([(1, 5), (6, 10), (11, 15)], start=1):
        sub = [e for e in by_strat_ev["random"] if not e["is_crisis"] and lo <= e["round"] <= hi]
        cnt = Counter(e["tier"] for e in sub)
        stage_tiers[f"阶段{si}"] = fmt_dist(cnt, len(sub))
        print(f"{'阶段' + str(si):<10}{str(lo) + '-' + str(hi):<10}"
              + "".join(f"{pct(cnt.get(t, 0), len(sub)):>8.1f}%" for t in TIERS) + f"{len(sub):>9}")
    out["stage_tiers"] = stage_tiers

    # 阶段曲线是否真的变难：难度上升量 vs 能力成长量（两者对冲时曲线被吃掉）
    print("\n阶段难度曲线 vs 能力成长（策略=random，日常）：")
    print(f"{'阶段':<10}{'轮次':<8}{'平均难度':>10}{'平均能力修正':>14}{'平均判定值':>12}{'大成功':>9}{'失败':>9}{'样本':>9}")
    stage_detail = {}
    for si, (lo, hi) in enumerate([(1, 5), (6, 10), (11, 15)], start=1):
        sub = [e for e in by_strat_ev["random"] if not e["is_crisis"] and lo <= e["round"] <= hi]
        cnt = Counter(e["tier"] for e in sub)
        rec = {
            "rounds": f"{lo}-{hi}",
            "avg_diff": round(mean([e["diff"] for e in sub]), 2),
            "avg_mod": round(mean([e["mod"] for e in sub]), 2),
            "avg_total": round(mean([e["total"] for e in sub]), 2),
            **fmt_dist(cnt, len(sub)),
            "n": len(sub),
        }
        stage_detail[f"阶段{si}"] = rec
        print(f"{'阶段' + str(si):<10}{rec['rounds']:<8}{rec['avg_diff']:>10.2f}{rec['avg_mod']:>14.2f}"
              f"{rec['avg_total']:>12.2f}{rec['full']:>8.1f}%{rec['fail']:>8.1f}%{rec['n']:>9}")
    d1 = stage_detail["阶段1"]["avg_diff"]
    d3 = stage_detail["阶段3"]["avg_diff"]
    m1 = stage_detail["阶段1"]["avg_mod"]
    m3 = stage_detail["阶段3"]["avg_mod"]
    print(f"  → 一期到三期：事件难度 {d1:+.2f} → {d3:+.2f}（变难 {d3 - d1:+.2f}），"
          f"能力修正 {m1:+.2f} → {m3:+.2f}（变强 {m3 - m1:+.2f}），"
          f"净效果 {d3 - d1 - (m3 - m1):+.2f}")
    out["stage_detail"] = stage_detail

    # 按难度档
    print("\n按事件难度档（策略=random，日常）：")
    print(f"{'difficulty':<12}{'大成功':>9}{'有条件':>9}{'失败':>9}{'样本':>9}")
    diff_tiers = {}
    for d in sorted({e["diff"] for e in by_strat_ev["random"] if not e["is_crisis"]}):
        sub = [e for e in by_strat_ev["random"] if not e["is_crisis"] and e["diff"] == d]
        cnt = Counter(e["tier"] for e in sub)
        diff_tiers[str(d)] = fmt_dist(cnt, len(sub))
        print(f"{d:<12}" + "".join(f"{pct(cnt.get(t, 0), len(sub)):>8.1f}%" for t in TIERS) + f"{len(sub):>9}")
    out["diff_tiers"] = diff_tiers

    # major 解析值（difficulty=+3，模拟不含 major，这里按 2d6 分布直接算）
    print("\n大议 major（difficulty=+3，模拟未含，按 2d6 理论值）：")
    print(f"{'能力修正':<10}{'大成功':>9}{'有条件':>9}{'失败':>9}")
    major_tbl = {}
    counts = {s: sum(1 for a in range(1, 7) for b in range(1, 7) if a + b == s) for s in range(2, 13)}
    for mod in range(0, 7):
        f = p = fl = 0
        for s, n in counts.items():
            t = s + mod
            if t >= 12:
                f += n
            elif t >= 9:
                p += n
            else:
                fl += n
        major_tbl[str(mod)] = {"full": round(pct(f, 36), 1), "partial": round(pct(p, 36), 1), "fail": round(pct(fl, 36), 1)}
        print(f"{'+' + str(mod):<10}" + "".join(f"{major_tbl[str(mod)][k]:>8.1f}%" for k in ("full", "partial", "fail")))
    out["major_table"] = major_tbl

    # ================= 终局 State =================
    print("\n" + "=" * 78)
    print("D. 15 轮终局数值（均值，三种策略）")
    print("=" * 78)
    keys = ["treasury", "gdp", "population", "military", "territory",
            "civilian_support", "noble_support", "radiation_risk", "plague_progress",
            "agrarian_support", "guild_support", "fuel_reserve", "wealth_gap",
            "literacy_rate", "legitimacy", "labor_health", "technology"]
    print(f"{'字段':<20}" + "".join(f"{s:>14}" for s in STRATS))
    finals = {}
    for k in keys:
        vals = {s: round(mean([int(r[k]) for r in by_strat_runs[s]]), 1) for s in STRATS}
        finals[k] = vals
        print(f"{k:<20}" + "".join(f"{vals[s]:>14.1f}" for s in STRATS))
    out["finals"] = finals

    with open(prefix + "_summary.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"\n汇总已写入 {prefix}_summary.json")


if __name__ == "__main__":
    main()
