#!/usr/bin/env python3
"""Independent raw-log audit. Does not import the runner or aggregate reporter."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(directory):
    manifest=json.loads((directory/'manifest.json').read_text())
    fingerprint=digest(directory/'manifest.json')
    errors=[]
    def check(condition,message):
        if not condition: errors.append(message)
    for name,h in manifest['files'].items():
        path=directory/name
        check(path.is_file() and digest(path)==h,'frozen file '+name)
    check(digest(Path(manifest['engine_path']))==manifest['engine_sha256'],'engine fingerprint')
    plan=json.loads((directory/'design.json').read_text())['planned']
    check(len(plan)==462,'plan row count')
    check(sum(c['arm']=='primary' for c in plan)==432,'primary count')
    check(sum(c['no_bonuses'] for c in plan)==30,'no-bonus count')
    check(len({c['id'] for c in plan})==462,'unique IDs')
    check(len({c['code'] for c in plan})==6,'seed count')
    paths=list((directory/'rows').glob('*/row.json'))
    check(len(paths)==462,'recorded row count')
    check({p.parent.name for p in paths}=={c['id'] for c in plan},'exact planned coverage')
    counts={};winners=[];forecasts=0
    for c in plan:
        folder=directory/'rows'/c['id']; path=folder/'row.json'
        if not path.exists():
            errors.append('missing '+c['id']);continue
        row=json.loads(path.read_text());result=row.get('result',{})
        check(row.get('case')==c,c['id']+' case identity')
        check(row.get('fingerprint')==fingerprint,c['id']+' fingerprint')
        stdout=(folder/'stdout.log').read_text();stderr=(folder/'stderr.log').read_text()
        check(not any(t in stdout+stderr for t in ('SCRIPT ERROR','ERROR:')),c['id']+' engine error log')
        parse=lambda prefix:[json.loads(l[len(prefix)+1:]) for l in stdout.splitlines() if l.startswith(prefix+' ')]
        terminals=parse('PLAYTHROUGH');fights=parse('FIGHT');actions=parse('ACTION');identities=parse('IDENTITY')
        check(terminals==[result],c['id']+' raw terminal equality')
        check(fights==row.get('fights'),c['id']+' raw fights equality')
        expected=dict(ascension_rank=c['rank'],modifier_revision=1,rules_revision=1,pool_tier=c['tier'],policy=c['policy'],no_bonuses=c['no_bonuses'])
        check(identities==[expected],c['id']+' initial raw identity')
        for key,value in dict(seed=c['code'],character=c['ship'],ascension_rank=c['rank'],modifier_revision=1,
                              pool_tier=c['tier'],profile_unlocks=c['tier'],policy=c['policy'],no_bonuses=c['no_bonuses'],
                              seeded=True,rng_version=1,content_pool_revision=1,reward_generation=1).items():
            check(result.get(key)==value,c['id']+' result '+key)
        check(row.get('returncode')==0,c['id']+' process exit')
        check(row.get('status')==result.get('mode') and row.get('status') in ('victory','defeat'),c['id']+' terminal status')
        check(not row.get('quality_errors'),c['id']+' quality errors')
        counts[row.get('status','missing')]=counts.get(row.get('status','missing'),0)+1
        q=result.get('quality',{})
        check(q.get('forecast_mismatches')==0,c['id']+' forecast mismatch')
        check(q.get('forecast_checks')==result.get('cards_played'),c['id']+' forecast coverage')
        forecasts+=q.get('forecast_checks',0)
        check(sum(f['end_turns'] for f in fights)==result.get('turns'),c['id']+' fight turns')
        check(sum(f['won'] for f in fights)==result.get('battles'),c['id']+' fight wins')
        check(sum(f['plays'] for f in fights)==result.get('cards_played'),c['id']+' fight plays')
        check(len(actions)==result.get('cards_played',0)+result.get('turns',0),c['id']+' raw action coverage')
        check(sum(a['selection'].get('end_turn',False) for a in actions)==result.get('turns'),c['id']+' raw end-turn coverage')
        check(result.get('save_directory')==str(folder/'save'),c['id']+' isolated save path')
        command=json.loads((folder/'command.json').read_text())
        argv=command['argv'];env=command['env']
        for arg in ('--code='+c['code'],'--character='+c['ship'],'--policy='+c['policy'],'--unlocks='+str(c['tier']),'--content-pool=1','--hp-scale=1','--save-dir='+str(folder/'save')):
            check(arg in argv,c['id']+' command '+arg)
        check(('--no-bonuses' in argv)==c['no_bonuses'],c['id']+' command no bonuses')
        check(env.get('ASCENSION_RANK')==str(c['rank']) and env.get('ASTRAL_SAVE_DIR')==str(folder/'save'),c['id']+' environment identity')
        if c['cohort']=='holdout' and c['policy']=='tactical' and row.get('status')=='victory': winners.append(c)
    missing=[]
    for ship in ('cartographer','hollow_choir','palimpsest'):
        for rank in range(12):
            if not any(c['ship']==ship and c['rank']==rank for c in winners):missing.append(dict(ship=ship,rank=rank))
    check(not missing,'missing heldout tactical witnesses')
    # Independently inspect paired new damage-first victories.
    rows={c['id']:json.loads((directory/'rows'/c['id']/'row.json').read_text()) for c in plan if (directory/'rows'/c['id']/'row.json').exists()}
    index={(c['code'],c['ship'],c['policy'],c['arm'],c['rank']):rows.get(c['id']) for c in plan}
    new_aggressive=[]
    for c in plan:
        row=rows.get(c['id']);base=index.get((c['code'],c['ship'],c['policy'],c['arm'],0))
        if c['policy']=='aggressive' and c['rank']>0 and row and base and row['status']=='victory' and base['status']!='victory': new_aggressive.append(c['id'])
    check(not new_aggressive,'new paired aggressive victories')
    return dict(passed=not errors,errors=errors,planned=len(plan),recorded=len(paths),counts=counts,
                forecast_checks=forecasts,candidate_fingerprint=fingerprint,
                missing_heldout_tactical_wins=missing,new_aggressive_wins=new_aggressive,
                audit_sha256=digest(Path(__file__)),method='Independent raw stdout/command/identity/fingerprint audit; no reporter or runner imports')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);a=p.parse_args()
    d=a.directory.resolve();result=audit(d)
    (d/'independent-audit.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['passed'] else 1)
