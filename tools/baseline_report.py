#!/usr/bin/env python3
"""Summarize completed baseline JSONL without treating missing/error runs as losses."""
import collections
import sys
from baseline import load_capture


def report(path):
    metadata, rows, summary = load_capture(path)
    key = lambda row: (row["seed"], row["character"], row.get("unlocks"), row["policy"])
    planned = {key(row) for row in metadata["planned"]}
    actual = [key(row) for row in rows]
    if len(set(actual)) != len(actual) or not set(actual) <= planned:
        raise ValueError("Duplicate or unplanned result")
    counts = collections.Counter(row["status"] for row in rows)
    print(f'Revision: `{metadata["revision"]}`; engine: `{metadata["engine"]}`')
    print(f"\nRecorded {len(rows)}/{len(planned)} cases; missing {len(planned - set(actual))}.")
    print(f"Statuses: {dict(sorted(counts.items()))}")
    if summary:
        print(f'Wall time (this invocation only): {summary["wall_seconds"]} seconds.')
    else:
        print("INTERRUPTED / INCOMPLETE: no final summary; missing cases have no recorded outcome, not timeouts or defeats.")
    if "resume" in metadata:
        resume = metadata["resume"]
        print(f'Resume: {resume["inherited_rows"]} retained rows; revision relationship: {resume["revision_relationship"]}.')
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
