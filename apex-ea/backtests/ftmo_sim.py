"""Replay FTMO 2-step challenges from every trading day in a daily equity log.

Rules applied (FTMO standard 2-step, as of this writing - verify on ftmo.com):
  phase 1 target +10%, phase 2 target +5%, no time limit
  max daily loss: equity >= day-start balance - 5% of initial balance
  max loss:       equity >= 90% of initial balance
  min 4 trading days (days with at least one entry) per phase
EA sizing is a % of balance, so each phase is scale-free: it starts from that
day's balance and is judged in percent.
Intraday: the log has the day's LOWEST equity; a breach is checked before the
target on the same day (conservative).
"""
import csv, sys, statistics
from datetime import date

def load(path):
    rows = []
    for r in csv.DictReader(open(path)):
        rows.append(dict(d=date.fromisoformat(r["date"].replace(".", "-")),
                         sb=float(r["start_bal"]), me=float(r["min_eq"]),
                         eb=float(r["end_bal"]), n=int(r["entries"])))
    return rows

def phase(rows, i, target):
    """-> (status, end_index). status: pass / daily / maxloss / open"""
    init = rows[i]["sb"]
    tdays = 0
    for j in range(i, len(rows)):
        r = rows[j]
        if r["me"] < r["sb"] - 0.05 * init:
            return "daily", j
        if r["me"] < 0.90 * init:
            return "maxloss", j
        tdays += 1 if r["n"] > 0 else 0
        if r["eb"] >= (1 + target) * init and tdays >= 4:
            return "pass", j
    return "open", len(rows) - 1

def run(path):
    rows = load(path)
    res = []
    for i in range(len(rows)):
        s1, j1 = phase(rows, i, 0.10)
        if s1 != "pass":
            res.append(("P1 " + s1, None))
            continue
        if j1 + 1 >= len(rows):
            res.append(("P2 open", None)); continue
        s2, j2 = phase(rows, j1 + 1, 0.05)
        if s2 != "pass":
            res.append(("P2 " + s2, None))
            continue
        res.append(("PASS", (rows[j1]["d"] - rows[i]["d"]).days,
                    (rows[j2]["d"] - rows[j1 + 1]["d"]).days))
    finished = [r for r in res if not r[0].endswith("open")]
    passed = [r for r in res if r[0] == "PASS"]
    fails = {}
    for r in finished:
        if r[0] != "PASS":
            fails[r[0]] = fails.get(r[0], 0) + 1
    p1 = [r[1] for r in passed]; p2 = [r[2] for r in passed]
    print(f"\n{path}")
    print(f"  start days {len(res)}, finished {len(finished)}, "
          f"PASSED BOTH {len(passed)} = {100*len(passed)/max(1,len(finished)):.0f}% of finished")
    print(f"  failures: {fails or 'none'}")
    if passed:
        print(f"  phase 1 days to pass: median {statistics.median(p1):.0f}, "
              f"fastest {min(p1)}, slowest {max(p1)}")
        print(f"  phase 2 days to pass: median {statistics.median(p2):.0f}, "
              f"fastest {min(p2)}, slowest {max(p2)}")
        print(f"  total, median: {statistics.median([a+b for a,b in zip(p1,p2)]):.0f} calendar days")
    # worst intraday equity vs the daily rule, across the whole log
    worst = max((r["sb"] - r["me"]) / r["sb"] * 100 for r in rows)
    print(f"  worst single-day equity drop: {worst:.2f}% of that day's balance (FTMO limit 5%)")
    # challenges started in Aug / Sep 2026
    recent = [(rows[i]["d"], res[i][0]) for i in range(len(rows)) if rows[i]["d"] >= date(2026, 8, 1)]
    if recent:
        print("  starts in Aug-Sep 2026:", {k: sum(1 for _, s in recent if s == k) for k in sorted({s for _, s in recent})})

for p in sys.argv[1:]:
    run(p)
