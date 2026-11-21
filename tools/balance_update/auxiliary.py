"""Generate bounded diagnostic calibration and unaffected-ship sentinel cases."""
import argparse
import json
from pathlib import Path
from diagnostic import build
from run import cases


def generate(scratch):
    e=scratch/"experiment"
    all_cases=list(cases())
    # Save budget using a fast damage-only negative-control voyage on each ship.
    sentinel=[]
    for ship in ("cartographer","palimpsest","hollow_choir"):
        for arm in (("control","trial-a","trial-b") if ship=="cartographer" else
                    ("control","trial-b") if ship=="palimpsest" else ("control","trial-a")):
            sentinel.append(dict(cohort="legacy",family=1,seed=777,tier=0,policy="aggressive",ship=ship,arm=arm))
    (e/"sentinel-cases.json").write_text(json.dumps(sentinel,indent=2))
    calibration=[dict(c,diagnostic="visible-uncorrected") for c in all_cases
                 if c["arm"]=="control" and c["policy"]=="tactical" and (
                (c["ship"]=="palimpsest" and c["cohort"]=="fresh" and c["family"]==40) or
                (c["ship"]=="hollow_choir" and c["cohort"]=="full" and c["family"]==60))]
    # Same visible one-ply model as splashfix, but with the ORIGINAL aggregate
    # predicate. Require complete deterministic terminal and fight digest parity.
    script=build(scratch).replace('planner=="splashfix"','planner in ["splashfix","visible-uncorrected"]').replace(
        'if primary>=foe.hp: score+=12','if forecast.damage>=foe.hp: score+=12')
    (e/"calibration.gd").write_text(script)
    (e/"calibration-cases.json").write_text(json.dumps(calibration,indent=2))
    visible=json.loads((e/"visible2-cases.json").read_text())
    bounded=[c for c in visible if c["cohort"]!="legacy" or c["family"] in (0,1)]
    (e/"visible2-bounded.json").write_text(json.dumps(bounded,indent=2))


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("scratch",type=Path)
    generate(p.parse_args().scratch)
