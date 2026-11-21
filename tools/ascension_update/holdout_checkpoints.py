#!/usr/bin/env python3
"""Authorized checkpoint-only subset of the ORIGINAL predeclared holdouts."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
from run import CHECKPOINTS, dump, run_case, sha, verify


def planned(directory):
    spec=json.loads((directory/'design.json').read_text())
    cases=[c for c in spec['planned'] if c['cohort']=='holdout' and c['rank'] in CHECKPOINTS]
    assert len(cases)==120 and all(c['arm']=='primary' for c in cases)
    return cases


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory',type=Path)
    p.add_argument('--parity',required=True,type=Path,help='Successful parity-report.json')
    p.add_argument('--authorization',required=True)
    p.add_argument('--jobs',type=int,default=4)
    a=p.parse_args()
    if not 1<=a.jobs<=4: raise ValueError('Workers must be 1..4')
    d=a.directory.resolve()
    fingerprint=verify(d)
    parity=json.loads(a.parity.read_text())
    if not parity['passed'] or parity['candidate_fingerprint']!=fingerprint:
        raise ValueError('Matching successful historical A0 parity required')
    if not (d/'calibration-checkpoints.complete.json').exists():
        raise ValueError('Calibration checkpoints incomplete')
    cases=planned(d)
    dump(d/'holdout-checkpoints.launch.json',dict(planned=cases,fingerprint=fingerprint,
         authorization=a.authorization,parity_report=str(a.parity.resolve()),parity_report_sha256=sha(a.parity),
         subset_runner_sha256=sha(Path(__file__)),jobs=a.jobs,
         scope='120 original holdout checkpoint rows only; intermediate ranks remain blocked'))
    rows=[]
    for rank in CHECKPOINTS:
        block=[c for c in cases if c['rank']==rank]
        pending=[]
        for c in block:
            path=d/'rows'/c['id']/'row.json'
            if path.exists():
                row=json.loads(path.read_text())
                if row['case']!=c or row['fingerprint']!=fingerprint: raise ValueError('Existing row mismatch')
                rows.append(row)
            else: pending.append(c)
        with ThreadPoolExecutor(a.jobs) as pool:
            fs=[pool.submit(run_case,c,d,fingerprint,900) for c in pending]
            for f in as_completed(fs):
                row=f.result(); rows.append(row)
                print(row['case']['id'],row['status'],flush=True)
        verify(d)
        if any(r['status'] not in ('victory','defeat') for r in rows):
            raise ValueError('Unresolved row: inspect before proceeding')
    dump(d/'holdout-checkpoints.complete.json',dict(fingerprint=fingerprint,rows=len(rows)))

if __name__=='__main__': main()
