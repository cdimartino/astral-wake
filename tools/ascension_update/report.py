#!/usr/bin/env python3
"""Report complete coverage and unresolved cases, never silently exclude losses."""
import argparse
from collections import Counter
import json
from pathlib import Path
from statistics import median
from run import CHECKPOINTS, SHIPS, dump, sha


def med(values):
    return median(values) if values else None


def summarize(directory):
    spec = json.loads((directory/'design.json').read_text())
    loaded = {}
    for path in sorted((directory/'rows').glob('*/row.json')):
        row = json.loads(path.read_text())
        key = row['case']['id']
        if key in loaded:
            raise ValueError('Duplicate '+key)
        loaded[key] = row
    planned = {c['id']:c for c in spec['planned']}
    if set(loaded)-set(planned):
        raise ValueError('Unplanned rows')
    for key, row in loaded.items():
        if row['case'] != planned[key]:
            raise ValueError('Plan mismatch '+key)
    fingerprints = {r['fingerprint'] for r in loaded.values()}
    if len(fingerprints)>1:
        raise ValueError('Mixed candidate fingerprints')
    clean = [r for r in loaded.values() if r['status'] in ('victory','defeat')]
    table = []
    for cohort in ('calibration','holdout'):
        for tier in (0,3):
            for ship in SHIPS:
                for rank in range(12):
                    for policy, arm in [('tactical','primary'),('aggressive','primary'),('tactical','no-between-bonuses')]:
                        group = [r for r in clean if all(r['case'][k] == v for k,v in dict(cohort=cohort,tier=tier,ship=ship,rank=rank,policy=policy,arm=arm).items())]
                        if not group: continue
                        fights = [f for r in group for f in r['fights']]
                        table.append(dict(cohort=cohort,tier=tier,ship=ship,rank=rank,policy=policy,arm=arm,
                                          runs=len(group), wins=sum(r['status']=='victory' for r in group),
                                          area_reach=dict(Counter(str(r['result']['region']) for r in group)),
                                          median_final_hull=med([r['result']['hull'] for r in group]),
                                          min_positive_hull=min(r['result']['min_positive_hull'] for r in group),
                                          median_fight_turns=med([f['turns'] for f in fights]),
                                          fight_turns=[f['turns'] for f in fights]))
    key = lambda c: tuple(c[k] for k in ('code','ship','policy','arm','rank'))
    index = {key(r['case']):r for r in clean}
    comparisons, new_aggressive_wins = [], []
    for row in clean:
        c = row['case']
        if c['rank'] == 0: continue
        base = index.get(key(dict(c,rank=0)))
        if not base: continue
        if c['policy']=='aggressive' and row['status']=='victory' and base['status']!='victory':
            new_aggressive_wins.append(c['id'])
        # Node+area+roster is an encounter match; same entry signature is stronger.
        matchkey = lambda f: json.dumps([f['region'],f['area'],f['node'],f['kind'],f['roster']],sort_keys=True)
        before = {matchkey(f):f for f in base['fights']}
        pairs = [(before[matchkey(f)],f) for f in row['fights'] if matchkey(f) in before]
        exact = [(a,b) for a,b in pairs if a['entry_signature']==b['entry_signature']]
        comparisons.append(dict(id=c['id'],checkpoint=c['rank'] in CHECKPOINTS,
                                path_diverged=base['result']['path_taken']!=row['result']['path_taken'],
                                all_fights_A0=len(base['fights']),all_fights_rank=len(row['fights']),
                                encounter_matches=len(pairs),equal_visible_entry_matches=len(exact),
                                paired_turn_deltas=[b['turns']-a['turns'] for a,b in pairs],
                                area2_paired_turn_deltas=[b['turns']-a['turns'] for a,b in pairs if b['region']==2],
                                area3_paired_turn_deltas=[b['turns']-a['turns'] for a,b in pairs if b['region']==3],
                                equal_entry_turn_deltas=[b['turns']-a['turns'] for a,b in exact],
                                paired_hull_damage_deltas=[b['hull_damage']-a['hull_damage'] for a,b in pairs]))
    missing_wins = []
    for ship in SHIPS:
        for rank in range(12):
            if not any(r['case']['cohort']=='holdout' and r['case']['ship']==ship and r['case']['rank']==rank and r['case']['policy']=='tactical' and r['status']=='victory' for r in clean):
                missing_wins.append(dict(ship=ship,rank=rank))
    unresolved = [{'id':c['id'],'status':loaded.get(c['id'],{}).get('status','not-run')} for c in spec['planned'] if loaded.get(c['id'],{}).get('status') not in ('victory','defeat')]
    ship_trends=[]
    for cohort in ('calibration','holdout'):
        for ship in SHIPS:
            paired=[]
            for row in clean:
                c=row['case']
                if c['cohort']!=cohort or c['ship']!=ship or c['policy']!='tactical' or c['arm']!='primary' or c['rank']!=11: continue
                base=index.get(key(dict(c,rank=0)))
                if not base: continue
                fields=('mode','region','hull','min_positive_hull','turns','battles')
                paired.append(dict(code=c['code'],tier=c['tier'],A0_id=base['case']['id'],A11_id=c['id'],
                                   A0={k:base['result'][k] for k in fields},A11={k:row['result'][k] for k in fields},
                                   path_diverged=base['result']['path_taken']!=row['result']['path_taken']))
            all0=[f['turns'] for pair in paired for f in loaded[pair['A0_id']]['fights']]
            all11=[f['turns'] for pair in paired for f in loaded[pair['A11_id']]['fights']]
            cmp=[c for c in comparisons if c['id'] in {p['A11_id'] for p in paired}]
            ship_trends.append(dict(cohort=cohort,ship=ship,paired=paired,
                                    median_all_fight_turns_A0=med(all0),median_all_fight_turns_A11=med(all11),
                                    median_encounter_paired_turn_delta=med([d for c in cmp for d in c['paired_turn_deltas']]),
                                    median_area3_encounter_paired_turn_delta=med([d for c in cmp for d in c['area3_paired_turn_deltas']]),
                                    path_divergence_count=sum(p['path_diverged'] for p in paired),
                                    caveat='Earlier defeats shorten voyages and censor fights; matched encounters and hull deltas are not equal-state mechanical monotonicity tests.'))
    checkpoint_wins=[]
    for cohort in ('calibration','holdout'):
        for rank in CHECKPOINTS:
            for ship in SHIPS:
                rr=[r for r in clean if r['case']['cohort']==cohort and r['case']['rank']==rank and r['case']['ship']==ship and r['case']['policy']=='tactical' and r['case']['arm']=='primary']
                checkpoint_wins.append(dict(cohort=cohort,rank=rank,ship=ship,runs=len(rr),wins=sum(r['status']=='victory' for r in rr)))
    checkpoint_missing=[x for x in checkpoint_wins if x['cohort']=='holdout' and x['wins']==0]
    checkpoint_unresolved=[x for x in unresolved if planned[x['id']]['rank'] in CHECKPOINTS]
    return dict(ship_A0_A11_trends=ship_trends,checkpoint_tactical_wins=checkpoint_wins,checkpoint_missing_heldout_wins=checkpoint_missing,
                checkpoint_unresolved=checkpoint_unresolved,checkpoint_gate_passed=not checkpoint_unresolved and not checkpoint_missing and not new_aggressive_wins,
                report_generator_sha256=sha(Path(__file__)),planned=len(planned),recorded=len(loaded),counts=dict(Counter(r['status'] for r in loaded.values())),
                fingerprints=sorted(fingerprints),unresolved=unresolved,table=table,comparisons=comparisons,
                missing_heldout_tactical_wins=missing_wins,unexplained_new_aggressive_wins=new_aggressive_wins,
                gate_passed=not unresolved and not missing_wins and not new_aggressive_wins,
                caveats=['Headless rules only; not rendered/MCP play or human win rates.',
                         'Diverged routes are not mechanical monotonicity tests.',
                         'Equal visible entry signature excludes hidden future draws/RNG; not proof of full equal state.',
                         'Min positive hull samples action boundaries and ordered hull cues; excludes zero at defeat.'])

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory',type=Path)
    a=p.parse_args()
    report=summarize(a.directory.resolve())
    dump(a.directory/'report.json',report)
    print(json.dumps({k:report[k] for k in ('planned','recorded','counts','gate_passed')},indent=2))
