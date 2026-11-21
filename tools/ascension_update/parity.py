#!/usr/bin/env python3
"""Stratified original-release A0 parity, separate from the new-code matrix."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import gzip
import json
from pathlib import Path
import shutil
from run import HERE, ROOT, dump, run_case, sha, verify

CAPTURE = ROOT/'tools/balance_update/evidence/release-720.jsonl.gz'
# All 3 ships × both pool tiers × all 4 historical policies, family zero.
# Selected without using outcomes. Historical no-bonuses used BALANCED combat.
EXCLUDED = ['save_directory','wall_seconds']
ADDITIVE = ['ascension_rank','modifier_revision','rules_revision','min_positive_hull','quality','path_taken']


def selected(capture):
    with gzip.open(capture,'rt') as f:
        data=[json.loads(l) for l in f]
    metadata=data[0]['metadata']
    rows=[r for r in data[1:] if r.get('family')==0 and 'result' in r]
    assert len(rows)==24
    return metadata,rows


def normalize(result):
    return {k:v for k,v in result.items() if k not in EXCLUDED+ADDITIVE}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('candidate',type=Path)
    p.add_argument('directory',type=Path,help='new parity-only scratch')
    p.add_argument('--jobs',type=int,default=4)
    a=p.parse_args()
    if not 1<=a.jobs<=4: raise ValueError('Workers must be 1..4')
    candidate,d=a.candidate.resolve(),a.directory.resolve()
    fingerprint=verify(candidate)
    # Keep original matrix untouched; copy only the immutable candidate inputs.
    d.mkdir(parents=True,exist_ok=False)
    shutil.copytree(candidate/'project',d/'project',ignore=shutil.ignore_patterns('.godot'))
    for name in ('manifest.json','design.json','runner.py'):
        shutil.copyfile(candidate/name,d/name)
    verify(d)
    meta,old=selected(CAPTURE)
    plans=[]
    for r in sorted(old,key=lambda r:(r['character'],r['unlocks'],r['policy'])):
        c=dict(id=f"parity-{r['character']}-{r['unlocks']}-{r['policy']}",
               code=r['seed'],tier=r['unlocks'],ship=r['character'],rank=0,
               policy='balanced' if r['policy']=='no-bonuses' else r['policy'],
               no_bonuses=r['policy']=='no-bonuses',cohort='historical-parity',arm='parity',phase='parity')
        plans.append((c,r))
    dump(d/'parity-plan.json',dict(capture_sha256=sha(CAPTURE),old_metadata=meta,
                                 old_rows=[r for c,r in plans],planned=[c for c,r in plans],
                                 excluded_fields=EXCLUDED,additive_fields=ADDITIVE,
                                 candidate_fingerprint=fingerprint,parity_runner_sha256=sha(Path(__file__))))
    # Non-rule inputs must match the frozen release identities, not just values.
    manifest=json.loads((d/'manifest.json').read_text())
    for name,digest in meta['sha256'].items():
        if name!='scripts/game.gd' and manifest['source_sha256'][name]!=digest:
            raise ValueError('Old parity dependency mismatch: '+name)
    if manifest['engine_version']!=meta['engine']: raise ValueError('Engine version mismatch')
    rows={}
    with ThreadPoolExecutor(a.jobs) as pool:
        fs={pool.submit(run_case,c,d,fingerprint,900):c for c,r in plans}
        for f in as_completed(fs):
            row=f.result(); rows[row['case']['id']]=row
            print(row['case']['id'],row['status'],flush=True)
    comparisons=[]
    for c,oldrow in plans:
        row=rows[c['id']]
        prior=normalize(oldrow['result'])
        current=normalize(row.get('result',{}))
        diffs={k:dict(old=prior.get(k),candidate=current.get(k)) for k in sorted(prior.keys()|current.keys()) if prior.get(k)!=current.get(k)}
        comparisons.append(dict(id=c['id'],status=row['status'],returncode=row['returncode'],differences=diffs,match=not diffs and row['status'] in ('victory','defeat')))
    verify(d)
    result=dict(capture_sha256=sha(CAPTURE),candidate_fingerprint=fingerprint,
                excluded_fields=EXCLUDED,additive_fields=ADDITIVE,comparisons=comparisons,
                passed=all(r['match'] for r in comparisons),
                limitation='Terminal/deck/powerups/actions/checkpoints parity only; capture has no per-action trace or complete reward choices. Not old dependency reuse; candidate rules intentionally differ.')
    dump(d/'parity-report.json',result)
    print('PARITY',sum(c['match'] for c in comparisons),'/',len(comparisons),flush=True)
    raise SystemExit(0 if result['passed'] else 1)

if __name__=='__main__': main()
