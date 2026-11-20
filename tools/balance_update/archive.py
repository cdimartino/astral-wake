"""Export/re-audit a portable gzip JSONL of exact argv, isolated env and raw output; no saves."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
from analyze import check_options, key, load, summarize
from run import HERE, RULES, POLICY_SHA, cases, check, normalized, records, sha


def line(f, value):
    f.write(json.dumps(value,separators=(",",":"))+"\n")


def pack(output, directories, prior=None, pilots=None):
    with gzip.open(output,"wt",encoding="utf-8",compresslevel=9) as f:
        line(f,{"format":"astral-balance-paired-v1","variables":{"$GODOT":"pinned binary","$SCRATCH":"disposable experiment root"}})
        if prior:
            reference=[]
            for name in ("matrix.jsonl","middle.jsonl"):
                for entry in (prior/name).read_text().splitlines():
                    old=json.loads(entry)
                    if old["character"]=="cartographer": continue
                    reference.append({"case":old["case"],"terminal":normalized(old)})
            line(f,{"reference":"legacy","inputs":{n:sha(prior/n) for n in ("matrix.jsonl","middle.jsonl")},"rows":reference})
        if pilots:
            pr=[]
            for name in ("pilot-fresh","pilot-full"):
                log=(pilots/name/"log").read_text()
                r,=records(log,"PLAYTHROUGH")
                log=log.replace(r["save_directory"],f"$SCRATCH/experiment/{name}/save")
                assert "/Users/" not in log and "/var/folders/" not in log
                pr.append({"case":name,"log":log})
            line(f,{"reference":"pilots","rows":pr})
        for e in directories:
            rows,m=load(e,True)
            obs=(e/"observer.gd").read_text()
            line(f,{"group":e.name,"manifest":m,"observer_source":obs})
            portable=Path("$SCRATCH/experiment")/e.name
            for file in sorted(e.glob("*/row.json")):
                d=file.parent
                row=json.loads(file.read_text())
                cmd=json.loads((d/"command.json").read_text())
                cmd[0]="$GODOT"
                cmd=[arg.replace(str(e.parents[1]),"$SCRATCH") for arg in cmd]
                check_options(cmd,portable,portable/d.name,row)
                log=(d/"log").read_text().replace(str(d/"save"),str(portable/d.name/"save"))
                env={"BALANCE_ARM":row["arm"],"BALANCE_DIAGNOSTIC":row.get("diagnostic",""),
                     "BALANCE_SWITCH_AT":row.get("switch_at",""),"ASTRAL_SAVE_DIR":str(portable/d.name/"save")}
                if env["BALANCE_SWITCH_AT"]: env["BALANCE_CONTROL_RULES"]="$SCRATCH/control/scripts/game.gd"
                for ln in log.splitlines():
                    assert not ln or ln.startswith(("Godot Engine ","PROGRESS ","PLAYTHROUGH ","FIGHT ","OFFER ","RESCUE ")), ln[:80]
                assert "/Users/" not in log and "/var/folders/" not in log
                line(f,{"group":e.name,"case":d.name,"argv":cmd,"env":env,"row":row,"log":log})
    return audit(output)


def audit(archive):
    manifests,rows,refs={},{},{}
    with gzip.open(archive,"rt") as f:
        assert json.loads(next(f))["format"]=="astral-balance-paired-v1"
        for ln in f:
            item=json.loads(ln)
            if "reference" in item:
                assert item["reference"] not in refs
                refs[item["reference"]]=item
                continue
            group=item["group"]; e=Path("$SCRATCH/experiment")/group
            if "manifest" in item:
                assert group not in manifests and hashlib.sha256(item["observer_source"].encode()).hexdigest()==item["manifest"]["pins"]["observer"]
                manifests[group]=item["manifest"]; rows[group]={}; continue
            r=item["row"]; d=e/item["case"]
            assert item["env"]["BALANCE_ARM"]==r["arm"] and item["env"]["ASTRAL_SAVE_DIR"]==str(d/"save")
            assert item["env"]["BALANCE_DIAGNOSTIC"]==r.get("diagnostic","")
            assert item["env"]["BALANCE_SWITCH_AT"]==r.get("switch_at","")
            check_options(item["argv"],e,d,r)
            result,=records(item["log"],"PLAYTHROUGH")
            assert normalized(result)==r["result"]
            assert records(item["log"],"FIGHT")==r["fights"] and records(item["log"],"OFFER")==r["offers"]
            check(r,result,r["fights"],d,"switch_at" in r)
            k=key(r),r["arm"]; assert k not in rows[group]; rows[group][k]=r
    out={}
    for group,m in manifests.items():
        planned=m["planned"]
        if group=="official": assert planned==list(cases()),"Official archive manifest differs from pre-registered design"
        assert m["pins"]["design"]==sha(HERE/"design.json") and m["pins"]["engine"]=="4.7.2.stable.official.ed1daf0bf"
        for arm,expected in RULES.items():
            assert all(v==m["pins"]["files"]["control"][name] for name,v in m["pins"]["files"][arm].items() if name!="scripts/game.gd")
            assert m["pins"]["files"][arm]["scripts/game.gd"]==expected
            assert m["pins"]["files"][arm]["tests/playthrough.gd"]==POLICY_SHA
        assert len(planned)==len(rows[group]) and set((key(c),c["arm"]) for c in planned)==set(rows[group])
        assert all(all(rows[group][key(c),c["arm"]][f]==v for f,v in c.items()) for c in planned)
        out[group]={"rows":len(planned),"groups":summarize(rows[group])}
    if refs:
        assert "official" in rows
        by_case={(r["seed"],r["ship"],r["policy"]):r for (k,arm),r in rows["official"].items() if arm=="control"}
        if "legacy" in refs:
            prior=refs["legacy"]["rows"]
            keys={tuple(r["case"]) for r in prior}
            expected={k for k in by_case if isinstance(k[0],int)}
            assert keys==expected and len(prior)==len(keys)
            assert all(by_case[tuple(r["case"])]["result"]==r["terminal"] for r in prior)
            out["official"]["old_review_terminal_matches"]=len(keys)
        if "pilots" in refs:
            pilots=refs["pilots"]["rows"]
            assert {p["case"] for p in pilots}=={"pilot-fresh","pilot-full"} and len(pilots)==2
            for p in pilots:
                r,=records(p["log"],"PLAYTHROUGH")
                assert by_case[r["seed"],r["character"],r["policy"]]["result"]==normalized(r)
            out["official"]["uninstrumented_pilot_matches"]=len(pilots)
    def same_trace(a,b): return all(a[k]==b[k] for k in ("result","fights","offers"))
    if "sentinel" in rows:
        for (k,arm),r in rows["sentinel"].items():
            assert same_trace(r,rows["sentinel"][k,"control"]),"Unaffected trace changed"
    if "calibration" in rows and "official" in rows:
        for k,r in rows["calibration"].items():
            assert same_trace(r,rows["official"][k]),"Visible-state calibration differs"
    if "official" in rows:
        verified=set()
        for g,rs in rows.items():
            for (k,arm),r in rs.items():
                if "switch_at" not in r: continue
                b=rows["official"][k,"control"]
                assert (k,arm) not in verified; verified.add((k,arm))
                orig,trial=b["fights"][-1],r["fights"][-1]
                assert not orig["won"] and trial["switched"] and r["fights"][:-1]==b["fights"][:-1]
                assert all(orig[x]==trial[x] for x in ("path","region","kind","node","roster","entry_signature","prior_actions"))
    return out


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    sp=p.add_subparsers(dest="cmd",required=True)
    a=sp.add_parser("pack");a.add_argument("archive",type=Path);a.add_argument("directories",type=Path,nargs="+");a.add_argument("--prior",type=Path);a.add_argument("--pilots",type=Path)
    a=sp.add_parser("audit");a.add_argument("archive",type=Path);a.add_argument("--summary",type=Path)
    a=p.parse_args()
    out=pack(a.archive,[e.resolve() for e in a.directories],a.prior,a.pilots) if a.cmd=="pack" else audit(a.archive)
    if getattr(a,"summary",None): a.summary.write_text(json.dumps(out,indent=2)+"\n")
    print({g:x["rows"] for g,x in out.items()},"archive SHA256",sha(a.archive))
