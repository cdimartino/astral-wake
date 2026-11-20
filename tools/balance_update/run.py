"""Run paired, isolated headless policy experiments. No player profiles or live game."""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = json.loads((HERE / "design.json").read_text())
RULES = {"control":"6a2e1c47f52d9f86651f69d5bc73be0b52a18258cdd914be9041f26b767cebe0",
         "trial-a":"377318e9e4081bd55d8b03bf45d60d7ed29824ae22bfdff449906f32f745989a",
         "trial-b":"7cc5f9376f5203c47bd8a16e93d5739ba64c4b14c67eecfbc060d90f0801fdd7"}
POLICY_SHA = "36f580bfdbaa2155e8413ff34a2820b64bd63572262ffc2ffd97caa2f1f92eea"
SHIPS = {"palimpsest":"trial-a","hollow_choir":"trial-b"}
FILES = ["scripts/"+name+".gd" for name in ("game","seed_engine","reward_distribution","evolutions","save_store","install_engines","route_effects","known_selections")] + ["tests/playthrough.gd","data/catalog.json","project.godot"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cases():
    ps = SPEC["legacy_policies"]
    modern = SPEC["modern"]
    # Interleave matched arms and cohorts, completing comparable seed blocks early.
    for i in range(max(map(len,modern.values()))):
        for p in ("tactical","balanced","aggressive","starter_only"):
            for cohort in ("legacy","fresh","full"):
                if cohort=="legacy":
                    if i>=len(SPEC["legacy"]) or p not in ps: continue
                    seed,tier,family=SPEC["legacy"][i],0,i
                else:
                    if p not in SPEC["modern_policies"]: continue
                    row=modern[cohort][i]
                    seed,tier,family=row["seed"],row["tier"],row["family"]
                for ship, trial in SHIPS.items():
                    for arm in ("control",trial):
                        yield dict(cohort=cohort,seed=seed,tier=tier,family=family,policy=p,ship=ship,arm=arm)


def pins(scratch, engine, observer):
    hashes = {arm:{f:sha(scratch/arm/f) for f in FILES} for arm in RULES}
    for arm, vals in hashes.items():
        assert vals["scripts/game.gd"]==RULES[arm] and vals["tests/playthrough.gd"]==POLICY_SHA
        assert all(v==hashes["control"][f] for f,v in vals.items() if f!="scripts/game.gd")
    for f,h in json.loads((scratch/"control-fingerprints.json").read_text()).items():
        assert hashes["control"][f]==h
    return {"files":hashes,"observer":sha(observer),"design":sha(HERE/"design.json"),
            "engine":subprocess.check_output([engine,"--version"],text=True).strip(),"engine_sha":sha(engine)}


def records(text, key):
    return [json.loads(l[len(key)+1:]) for l in text.splitlines() if l.startswith(key+" ")]


def normalized(result):
    return {k:v for k,v in result.items() if k not in ("save_directory","wall_seconds","case","returncode")}


def check(c, res, fights, d, rescue=False):
    p = c["policy"]
    assert res["seed"]==c["seed"] and res["character"]==c["ship"]
    assert res["policy"]==("tactical" if p=="starter_only" else p) and res["no_bonuses"]==(p=="starter_only")
    assert res["profile_unlocks"]==res["pool_tier"]==c["tier"]
    assert res["content_pool_revision"]==res["reward_generation"]==1
    assert res["seeded"]==(c["cohort"]!="legacy") and res["rng_version"]==int(c["cohort"]!="legacy")
    if not rescue:
        assert res["mode"] in ("defeat","victory")
    assert Path(res["save_directory"])==d/"save"
    assert sum(f["end_turns"] for f in fights)==res["turns"]
    assert sum(f["won"] for f in fights)==res["battles"]
    assert sum(f["counts"].get("plays",0) for f in fights)==res["cards_played"]
    assert all(0<=f["min_hull"]<=min(f["entry_hull"],f["exit_hull"]) for f in fights)
    assert len({(f["region"],f["node"]) for f in fights})==len(fights)
    assert all(f["turns"] in (f["end_turns"],f["end_turns"]+1) for f in fights)


def run(c, scratch, engine, observer, out):
    label = "-".join(map(str,[c["arm"],c["cohort"],c["seed"],c["ship"],c["policy"]]))
    d = out/label
    d.mkdir()
    save = d/"save"
    prefix = "seed" if c["cohort"]=="legacy" else "code"
    p = c["policy"]
    cmd = [str(engine),"--headless","--path",str(scratch/c["arm"]),"--script",str(observer),"--",
           "--allow-defeat",f"--{prefix}={c['seed']}",f"--character={c['ship']}",
           f"--policy={'tactical' if p=='starter_only' else p}",f"--unlocks={c['tier']}",
           "--hp-scale=1","--content-pool=1",f"--save-dir={save}"]
    if p=="starter_only": cmd.append("--no-bonuses")
    env = {**os.environ,"ASTRAL_SAVE_DIR":str(save),"BALANCE_ARM":c["arm"],
           "BALANCE_DIAGNOSTIC":c.get("diagnostic",""),"BALANCE_SWITCH_AT":c.get("switch_at",""),"BALANCE_CONTROL_RULES":str(scratch/"control/scripts/game.gd")}
    (d/"command.json").write_text(json.dumps(cmd))
    proc = subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=900)
    log = proc.stdout+proc.stderr
    (d/"log").write_text(log)
    assert proc.returncode in (0,2) and "SCRIPT ERROR" not in log and "ERROR:" not in log, (label,proc.returncode,log[-1500:])
    result, = records(log,"PLAYTHROUGH")
    fights = records(log,"FIGHT")
    check(c,result,fights,d,"switch_at" in c)
    row = dict(c,result=normalized(result),fights=fights,offers=records(log,"OFFER"))
    (d/"row.json").write_text(json.dumps(row,separators=(",",":")))
    return label,result["mode"],len(fights)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scratch",type=Path,required=True)
    ap.add_argument("--engine",type=Path,default=ROOT/".tools/Godot.app/Contents/MacOS/Godot")
    ap.add_argument("--jobs",type=int,default=6)
    ap.add_argument("--observer",type=Path,default=HERE/"observer.gd")
    ap.add_argument("--out",required=True,help="New directory name below scratch/experiment")
    ap.add_argument("--cases",type=Path,help="Explicit diagnostic case list")
    a=ap.parse_args()
    scratch, engine = a.scratch.resolve(), a.engine.resolve()
    assert Path(a.out).name==a.out and 1<=a.jobs<=8
    planned = json.loads(a.cases.read_text()) if a.cases else list(cases())
    out = scratch/"experiment"/a.out
    out.mkdir()
    # Immutable copy: labels always map to the exact script that ran.
    obs = out/"observer.gd"
    obs.write_bytes(a.observer.read_bytes())
    pin = pins(scratch,engine,obs)
    (out/"manifest.json").write_text(json.dumps({"pins":pin,"planned":planned},indent=2))
    from concurrent.futures import as_completed
    with ThreadPoolExecutor(a.jobs) as pool:
        pending = [pool.submit(run,c,scratch,engine,obs,out) for c in planned]
        for f in as_completed(pending):
            try: print(*f.result(),flush=True)
            except Exception as exc: print("ERROR",repr(exc),flush=True)
    assert pin==pins(scratch,engine,obs),"Input changed during run"
    assert len(list(out.glob("*/row.json")))==len(planned),"Incomplete rows"

if __name__=="__main__":
    main()
