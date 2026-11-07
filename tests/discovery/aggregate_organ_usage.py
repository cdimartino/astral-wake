"""Aggregate organ-usage runs from tests/discovery/organ_usage.gd output.

Usage: python3 tests/discovery/aggregate_organ_usage.py docs/discovery/organ-usage-runs.json
"""
import json
import sys
from collections import Counter, defaultdict

runs = json.load(open(sys.argv[1]))
agg = defaultdict(lambda: {"runs": 0, "wins": 0, "uses": [0] * 6, "len": [0] * 4,
                           "names": None, "defeats": Counter()})
for r in runs:
    a = agg[(r["character"], r["policy"])]
    a["runs"] += 1
    a["wins"] += r["mode"] == "victory"
    a["uses"] = [x + y for x, y in zip(a["uses"], r["organ_uses"])]
    a["len"] = [x + y for x, y in zip(a["len"], r["route_len_hist"])]
    a["names"] = r["organ_names"]
    if r["mode"] == "defeat":
        a["defeats"][r["region"]] += 1
for (c, p), a in sorted(agg.items()):
    tot = sum(a["uses"])
    lt = sum(a["len"])
    print(f"\n{c} / {p}: runs={a['runs']} wins={a['wins']} defeats_by_region={dict(a['defeats'])}")
    for n, u in zip(a["names"], a["uses"]):
        print(f"  {n:12s} {u:6d}  {100 * u / tot:5.1f}% of organ-steps")
    print(f"  route length 1/2/3: {a['len'][1]}/{a['len'][2]}/{a['len'][3]} "
          f"({100 * a['len'][1] / lt:.0f}/{100 * a['len'][2] / lt:.0f}/{100 * a['len'][3] / lt:.0f}%)")
