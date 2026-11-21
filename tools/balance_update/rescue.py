"""Derive exact-entry followups. No strongest-seed selection or hidden draw data."""
import argparse
import json
from pathlib import Path
from analyze import compare, key, load
from run import SHIPS


def select(official):
    rows,manifest=load(official,False)
    plan=[]
    for c in manifest["planned"]:
        if c["arm"]!="control": continue
        k=key(c)
        base=rows.get((k,"control")); trial=rows.get((k,SHIPS[c["ship"]]))
        if not base or not trial or base["result"]["mode"]!="defeat": continue
        pair=compare(base,trial)
        # A direct test where an original loss was cleared on a changed history
        # or run victory bypassed that loss; also all original Palimpsest tactical
        # losses, the review's target population (even if both runs still lost).
        target=(c["cohort"]=="legacy" and c["policy"]=="tactical" and c["ship"]=="palimpsest")
        changed=(pair["result"][1]=="victory" or pair["loss_test"]=="original node cleared with different history")
        if target or changed:
            r,node=pair["original_losing_node"]
            plan.append(dict(c,arm=SHIPS[c["ship"]],switch_at=f"{r}/{node}"))
    return plan


def verify(official, dirs):
    base,_=load(official,False)
    checked=[]
    for directory in dirs:
        rows,_=load(directory,True)
        for (k,arm),trial in rows.items():
            orig=base[k,"control"]
            target=orig["fights"][-1]
            switched=trial["fights"][-1]
            assert trial["fights"][:-1]==orig["fights"][:-1], "prefix fight log differs"
            assert switched.get("switched") and switched["prior_actions"]==target["prior_actions"] and switched["entry_signature"]==target["entry_signature"]
            assert [switched[f] for f in ("node","kind","roster","region","path")]==[target[f] for f in ("node","kind","roster","region","path")]
            assert not target["won"]
            checked.append(dict(cohort=k[0],seed=k[2],ship=k[4],policy=k[5],arm=arm,switch_at=trial["switch_at"],
                                rescued=switched["won"],threshold_plays=switched["counts"].get("threshold",0),
                                effective_bonus=switched["counts"].get("effective_bonus_damage",0),
                                turns=[target["turns"],switched["turns"]],entry=target["entry_signature"]))
    return checked


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("official",type=Path)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--verify",nargs="+",type=Path)
    p.add_argument("--exclude",nargs="+",type=Path,help="Omit exact cases already scheduled in these manifests")
    a=p.parse_args()
    data=verify(a.official.resolve(),[d.resolve() for d in a.verify]) if a.verify else select(a.official.resolve())
    if a.exclude:
        prior={(key(c),c["arm"],c["switch_at"]) for d in a.exclude for c in json.loads((d/"manifest.json").read_text())["planned"]}
        data=[c for c in data if (key(c),c["arm"],c["switch_at"]) not in prior]
    a.output.write_text(json.dumps(data,indent=2)+"\n")
    print(len(data),"exact-entry checks")
