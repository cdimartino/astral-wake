#!/usr/bin/env python3
"""Summarize completed baseline JSONL without treating missing/error runs as losses."""
import collections
import json
import pathlib
import sys


def report(path):
    records = [json.loads(line) for line in pathlib.Path(path).read_text().splitlines()]
    metadata = records[0]["metadata"]
    rows = [row for row in records if "status" in row]
    key = lambda row: (row["seed"], row["character"], row.get("unlocks"), row["policy"])
    planned = {key(row) for row in metadata["planned"]}
    actual = [key(row) for row in rows]
    if len(set(actual)) != len(actual) or not set(actual) <= planned:
        raise ValueError("Duplicate or unplanned result")
    counts = collections.Counter(row["status"] for row in rows)
    print(f'Revision: `{metadata["revision"]}`; engine: `{metadata["engine"]}`')
    print(f"\nCompleted {len(rows)}/{len(planned)} cases; missing {len(planned - set(actual))}.")
    print(f"Statuses: {dict(sorted(counts.items()))}")
    summary = next((r["summary"] for r in records if "summary" in r), None)
    if summary:
        print(f'Wall time: {summary["wall_seconds"]} seconds.')
    print("\n| Ship | Tier | Policy | Wins | Defeats | Errors | Unfinished | Timeout | Missing |")
    print("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    for ship, tier, policy in sorted({(r["character"], r["unlocks"], r["policy"]) for r in metadata["planned"]}):
        group = [r for r in rows if (r["character"], r["unlocks"], r["policy"]) == (ship, tier, policy)]
        count = collections.Counter(r["status"] for r in group)
        expected = sum((r["character"], r["unlocks"], r["policy"]) == (ship, tier, policy) for r in metadata["planned"])
        values = [count[s] for s in ("victory", "defeat", "error", "unfinished", "timeout")]
        print(f"| {ship} | {tier} | {policy} | " + " | ".join(map(str, values + [expected - len(group)])) + " |")


if __name__ == "__main__":
    report(sys.argv[1])
