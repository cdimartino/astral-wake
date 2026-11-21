"""Validate pairing/legacy parity, compare original losses, and separate fight populations."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
from statistics import median
from run import SHIPS, RULES, POLICY_SHA, cases, check, normalized, records, sha


def key(row):
    return tuple(row[k] for k in ("cohort","family","seed","tier","ship","policy"))


def ident(f):
    return (f["region"],f["area"],f["node"],f["kind"],tuple(tuple(x) for x in f["roster"]))


def med(nums):
    return median(nums) if nums else None


def delta(a,b):
    return round(100*(b-a)/a,2) if a else None


def check_options(cmd, e, d, c):
    prefix="seed" if c["cohort"]=="legacy" else "code"
    policy=c["policy"]
    expected=["--allow-defeat",f"--{prefix}={c['seed']}",f"--character={c['ship']}",
              f"--policy={'tactical' if policy=='starter_only' else policy}",f"--unlocks={c['tier']}",
              "--hp-scale=1","--content-pool=1",f"--save-dir={d/'save'}"]
    if policy=="starter_only": expected.append("--no-bonuses")
    assert cmd[1:7]==["--headless","--path",str(e.parents[1]/c["arm"]),"--script",str(e/"observer.gd"),"--"]
    assert cmd[7:]==expected,(cmd[7:],expected)


def load(e, strict):
    m=json.loads((e/"manifest.json").read_text())
    assert m["pins"]["observer"]==sha(e/"observer.gd")
    for arm, rules in RULES.items():
        assert m["pins"]["files"][arm]["scripts/game.gd"]==rules
        assert m["pins"]["files"][arm]["tests/playthrough.gd"]==POLICY_SHA
    if e.name=="official": assert m["planned"]==list(cases()),"Official manifest differs from pre-registered design"
    assert m["pins"]["engine"]=="4.7.2.stable.official.ed1daf0bf"
    planned={(key(c),c["arm"]):c for c in m["planned"]}
    assert len(planned)==len(m["planned"])
    rows={}
    for file in sorted(e.glob("*/row.json")):
        row=json.loads(file.read_text())
        k=key(row),row["arm"]
        assert k not in rows and k in planned and all(row[f]==v for f,v in planned[k].items())
        cmd=json.loads(file.with_name("command.json").read_text())
        check_options(cmd,e,file.parent,row)
        log=file.with_name("log").read_text()
        assert "SCRIPT ERROR" not in log and "ERROR:" not in log
        r,=records(log,"PLAYTHROUGH")
        assert records(log,"FIGHT")==row["fights"] and records(log,"OFFER")==row["offers"]
        check(row,r,row["fights"],file.parent,"switch_at" in row)
        assert normalized(r)==row["result"]
        rows[k]=row
    if strict: assert set(rows)==set(planned),f"{len(rows)} of {len(planned)} rows"
    return rows,m


def check_prior(rows,prior):
    official={}
    for fn in ("matrix.jsonl","middle.jsonl"):
        for l in (prior/fn).read_text().splitlines():
            r=json.loads(l)
            k=tuple(r["case"])
            assert k not in official
            official[k]=r
    n=0
    for (_,arm),row in rows.items():
        if row["cohort"]!="legacy" or arm!="control": continue
        r=official[(row["seed"],row["ship"],row["policy"])]
        assert r["returncode"]==0 and normalized(r)==row["result"],(row["seed"],row["ship"],row["policy"])
        n+=1
    return n


def tempo(pairs,late):
    all_c,all_t,matched=[],[],[]
    wins_only=[]
    same_path=[]
    same_entry=[]
    exposed=[]
    seed_effects=[]
    for c,t in pairs:
        fc={ident(f):f for f in c["fights"] if not late or f["region"]==3}
        ft={ident(f):f for f in t["fights"] if not late or f["region"]==3}
        all_c.extend(x["turns"] for x in fc.values()); all_t.extend(x["turns"] for x in ft.values())
        local=[]
        for k in fc.keys()&ft.keys():
            pair=(fc[k]["turns"],ft[k]["turns"])
            matched.append(pair);local.append(pair)
            if fc[k]["won"] and ft[k]["won"]: wins_only.append(pair)
            if fc[k].get("counts",{}).get("threshold",0) or ft[k].get("counts",{}).get("threshold",0): exposed.append(pair)
            if fc[k]["path"]==ft[k]["path"]: same_path.append(pair)
            if fc[k]["entry_signature"]==ft[k]["entry_signature"]: same_entry.append(pair)
        if local: seed_effects.append(delta(median(x for x,y in local),median(y for x,y in local)))
    def measures(a,b):
        c,t=med(a),med(b)
        return dict(n=[len(a),len(b)],med=[c,t],pct=delta(c,t))
    def paired(ps):
        a=[x for x,y in ps]; b=[y for x,y in ps]
        return dict(**measures(a,b),median_difference=med([y-x for x,y in ps]),median_paired_pct=med([delta(x,y) for x,y in ps]),shorter_equal_longer=[sum(y<x for x,y in ps),sum(y==x for x,y in ps),sum(y>x for x,y in ps)])
    return dict(all_fights=measures(all_c,all_t),matched=paired(matched),matched_both_clear=paired(wins_only),matched_same_travel=paired(same_path),matched_same_visible_entry=paired(same_entry),matched_with_any_threshold=paired(exposed),median_seed_matched_medians_pct=med(seed_effects))


def stats(rows):
    counts=Counter()
    offers=picks=0
    for row in rows:
        offers+=len(row["offers"]);picks+=sum(o["picked"] for o in row["offers"])
        for f in row["fights"]: counts.update(f["counts"])
    return dict(victories=sum(r["result"]["mode"]=="victory" for r in rows),
                reached_region3=sum(r["result"]["region"]==3 for r in rows),
                med_end_turns=med([r["result"]["turns"] for r in rows]),
                med_win_end_turns=med([r["result"]["turns"] for r in rows if r["result"]["mode"]=="victory"]),
                med_hull=med([r["result"]["hull"] for r in rows]),
                med_run_min_hull=med([min(f["min_hull"] for f in r["fights"]) for r in rows]),
                med_win_min_hull=med([min(f["min_hull"] for f in r["fights"]) for r in rows if r["result"]["mode"]=="victory"]),
                fight_losses_by_region=dict(Counter(str(f["region"]) for r in rows for f in r["fights"] if not f["won"])),
                reward_offers=offers,reward_picks=picks,counts=dict(counts))


def compare(c,t):
    ft={ident(f):f for f in t["fights"]}
    c_lost=next((f for f in c["fights"] if not f["won"]),None)
    cp,tp=(r["fights"][-1]["path"] for r in (c,t))
    path_changed=cp!=tp
    branch_changed=any(x!=y for x,y in zip(cp,tp))
    verdict="no original loss"
    if c_lost:
        f=ft.get(ident(c_lost))
        if not f: verdict="original loss not revisited"
        elif not f["won"]: verdict="same encounter lost"
        elif f["entry_signature"]==c_lost["entry_signature"] and f["prior_actions"]==c_lost["prior_actions"]:
            verdict="same prefix+entry rescued"
        else: verdict="original node cleared with different history"
    return dict(seed=c["seed"],original_losing_node=([c_lost["region"],c_lost["node"]] if c_lost else None),
                result=[c["result"]["mode"],t["result"]["mode"]],final_travel_paths_differ=path_changed,actual_route_branch_differed=branch_changed,loss_test=verdict)


def summarize(rows):
    paired=defaultdict(list)
    for (k,arm),c in rows.items():
        if arm!="control" or c["ship"] not in SHIPS: continue
        t=rows.get((k,SHIPS[c["ship"]]))
        if t:
            assert c.get("diagnostic")==t.get("diagnostic"),"Different scorers cannot form a pair"
            paired[c["cohort"],c["ship"],c["policy"]].append((c,t))
    out=[]
    for (co,ship,p),pairs in sorted(paired.items()):
        cs,ts=zip(*pairs)
        out.append(dict(cohort=co,ship=ship,policy=p,pairs=len(pairs),control=stats(cs),trial=stats(ts),tempo=tempo(pairs,False),late_tempo=tempo(pairs,True),seeds=[compare(c,t) for c,t in pairs]))
    return out


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("directory",type=Path)
    p.add_argument("--prior",type=Path)
    p.add_argument("--strict",action="store_true")
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args(); rows,m=load(a.directory.resolve(),a.strict)
    prior=check_prior(rows,a.prior) if a.prior else None
    out=dict(pins=m["pins"],rows=len(rows),planned=len(m["planned"]),prior_terminal_matches=prior,groups=summarize(rows))
    a.output.write_text(json.dumps(out,indent=2))
    print(f"{len(rows)}/{len(m['planned'])} rows, {sum(g['pairs'] for g in out['groups'])} complete pairs; matched {prior} original summaries")
    for g in out['groups']:
        print(g['cohort'],g['ship'],g['policy'],g['pairs'], f"wins {g['control']['victories']}→{g['trial']['victories']}",
              f"procs {g['control']['counts'].get('threshold',0)}→{g['trial']['counts'].get('threshold',0)}",
              "matched median",g['tempo']['matched']['med'])
