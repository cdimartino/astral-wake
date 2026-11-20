"""Compact stable summary; full row-level evidence is in the portable archive."""
import argparse
from collections import Counter
import json
from pathlib import Path
from analyze import load, summarize


def report(directory, partial=False):
    rows,m=load(directory,not partial)
    groups=summarize(rows)
    lines=[f"# {directory.name}: {len(rows)} of {len(m['planned'])} rows",
        "", "Headless paired policy tests. Counts in each cell are control → single-rule trial.",
        "", "| Seed stratum | Ship | Policy | Pairs | Victories | Area 3 reached | Median fight turns: all | Matched median (n; change) | Area 3 matched | Win-run median minimum hull |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    def show(x):
        return "—" if x is None else f"{x:g}"
    def two(a,b):
        return f"{show(a)}→{show(b)}"
    def metric(g,k):
        return two(g["control"][k],g["trial"][k])
    for g in groups:
        t=g["tempo"]; p=t["matched"]; late=g["late_tempo"]["matched"]
        lines.append(f'| {g["cohort"]} | {g["ship"]} | {g["policy"]} | {g["pairs"]} | {metric(g,"victories")} | {metric(g,"reached_region3")} | {two(*t["all_fights"]["med"])} | {two(*p["med"])} ({p["n"][0]}; {show(p["pct"])}%) | {two(*late["med"])} ({late["n"][0]}) | {metric(g,"med_win_min_hull")} |')
    lines+=["","## Mechanism/exposure",
            "", "Threshold = damaging six-Trace Recall (A) or three-Resonance **card** Crescendo (B). Effective = at least one more actual damage after defenses and HP clipping, versus old rule on the exact selected move. Final-kill count is a marginal selected-target kill, not a saved encounter.",
            "", "| Stratum | Ship / policy | Reward offers → picks (C/T) | Crescendo draw / play (C/T) | Threshold plays C→T | Effective trial plays | Added actual damage | Marginal target kills |",
            "|---|---|---:|---:|---:|---:|---:|---:|"]
    for g in groups:
        c,t=g['control'],g['trial']; a,b=c["counts"],t["counts"]
        shop=f"{c['reward_offers']}→{c['reward_picks']} / {t['reward_offers']}→{t['reward_picks']}" if g['ship']=='hollow_choir' else '—'
        draw=f"{a.get('crescendo_draws',0)}/{a.get('crescendo_plays',0)} · {b.get('crescendo_draws',0)}/{b.get('crescendo_plays',0)}" if g['ship']=='hollow_choir' else '—'
        lines.append(f"| {g['cohort']} | {g['ship']} / {g['policy']} | {shop} | {draw} | {two(a.get('threshold',0),b.get('threshold',0))} | {b.get('eligible_effective',0)} | {b.get('effective_bonus_damage',0)} | {b.get('bonus_target_kills',0)} |")
    lines+=["","## Terminal flips","","| Ship, cohort, policy | Seed | Result | Original losing encounter in normal trial | Different route branch? |","|---|---|---|---|---|"]
    for g in groups:
        for s in g["seeds"]:
            if s["result"][0]==s["result"][1]: continue
            lines.append(f'| {g["ship"]}, {g["cohort"]}, {g["policy"]} | {s["seed"]} | {"→".join(s["result"])} | {s["loss_test"]} | {"yes" if s["actual_route_branch_differed"] else "no"} |')
    lines+=["", "Exact-entry replays, when run, are reported separately. A changed victory is not by itself a rescue of the old losing encounter.",""]
    return "\n".join(lines)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("directory",type=Path)
    p.add_argument("--partial",action="store_true");p.add_argument("--output",type=Path,required=True)
    a=p.parse_args();a.output.write_text(report(a.directory.resolve(),a.partial))
