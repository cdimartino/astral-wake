#!/usr/bin/env python3
"""Collect all 36 witnesses and archive exact evidence, excluding all saves."""
import argparse
import gzip
import json
from pathlib import Path
from statistics import median
import tarfile
from audit import audit
from report import summarize
from run import HERE, SHIPS, dump, sha, verify


def witnesses(directory):
    spec=json.loads((directory/'design.json').read_text())
    rows={p.parent.name:(p,json.loads(p.read_text())) for p in (directory/'rows').glob('*/row.json')}
    found=[];missing=[]
    for rank in range(12):
        for ship in SHIPS:
            candidates=[c for c in spec['planned'] if c['cohort']=='holdout' and c['rank']==rank and c['ship']==ship and c['policy']=='tactical' and rows.get(c['id'],(None,{}))[1].get('status')=='victory']
            if not candidates:
                missing.append(dict(ship=ship,rank=rank));continue
            c=candidates[0];path,row=rows[c['id']]
            found.append(dict(rank=rank,ship=ship,row_path=str(path.relative_to(directory)),row_sha256=sha(path),row=row))
    return dict(selection='First victorious row in original predeclared order; documentation only, no seed selection or rerun',witnesses=found,missing=missing)


def archive(output, trees, extra=()):
    """Deterministic gzip/tar metadata; saves/cache omitted by component, not suffix."""
    files=[]
    for prefix,root in trees:
        for path in sorted(root.rglob('*')):
            rel=path.relative_to(root)
            if not path.is_file() or any(p in ('save','saves','.godot','__pycache__') for p in rel.parts): continue
            if path.is_symlink(): raise ValueError('Unexpected evidence symlink '+str(path))
            files.append((prefix+'/'+rel.as_posix(),path))
    files.extend(extra)
    with output.open('wb') as target, gzip.GzipFile(filename='',mode='wb',fileobj=target,mtime=0,compresslevel=6) as gz, tarfile.open(fileobj=gz,mode='w|') as tar:
        for name,path in sorted(files):
            info=tar.gettarinfo(str(path),arcname=name)
            info.mtime=0;info.uid=info.gid=0;info.uname=info.gname=''
            with path.open('rb') as content:tar.addfile(info,content)
    with tarfile.open(output,'r:gz') as tar:
        names=tar.getnames()
    if any(part in ('save','saves') for name in names for part in Path(name).parts): raise ValueError('Save in archive')
    return dict(path=output.name,sha256=sha(output),bytes=output.stat().st_size,files=len(files),saves_excluded=True)


def markdown(report,audited,proofs,parity):
    lines=['# Ascension candidate v1 — full frozen matrix','',
           '> Audit PASS and embedded digests apply to unmodified originals only. Public archives replace local path prefixes (including nested gzip), not gameplay data. See `evidence/public-proof.json` for original/public hashes and byte-equivalence proof; public copies are not certified hash-chain replay inputs.', '',
           f"**Rules matrix gate: {'PASS' if report['gate_passed'] else 'FAIL'}. Independent raw-log audit: {'PASS' if audited['passed'] else 'FAIL'}.**",'',
           f"{report['recorded']}/462 scheduled rows: {report['counts']}. Unresolved: {len(report['unresolved'])}.",
           f"Held-out rank/ship witnesses: {len(proofs['witnesses'])}/36. Forecast checks: {audited['forecast_checks']}; zero mismatches required.",
           f"Separate original-release A0 parity: {'PASS' if parity['passed'] else 'FAIL'} (24 rows).",'',
           '## Held-out tactical wins (out of four original codes)','',
           '| Rank | Cartographer | Hollow Choir | Palimpsest |','|---|---:|---:|---:|']
    # Aggregate table is stratified by fresh/full; combine only for this witness table.
    for rank in range(12):
        wins=[sum(x['wins'] for x in report['table'] if x['cohort']=='holdout' and x['rank']==rank and x['ship']==ship and x['policy']=='tactical' and x['arm']=='primary') for ship in SHIPS]
        lines.append('| A%d | %d/4 | %d/4 | %d/4 |'%(rank,*wins))
    lines+=['','## Ship-specific A0 versus A11 (held-out tactical)','',
            '| Ship | A0/A11 wins | Median all-fight turns A0→A11 | Median matched Area 3 turn delta | Median minimum-positive hull A0→A11 | Diverged paths |',
            '|---|---:|---:|---:|---:|---:|']
    for trend in report['ship_A0_A11_trends']:
        if trend['cohort']!='holdout':continue
        pairs=trend['paired']
        w0=sum(p['A0']['mode']=='victory' for p in pairs);w11=sum(p['A11']['mode']=='victory' for p in pairs)
        lines.append(f"| {trend['ship']} | {w0}/{w11} | {trend['median_all_fight_turns_A0']}→{trend['median_all_fight_turns_A11']} | {trend['median_area3_encounter_paired_turn_delta']} | {median([p['A0']['min_positive_hull'] for p in pairs])}→{median([p['A11']['min_positive_hull'] for p in pairs])} | {trend['path_divergence_count']}/{len(pairs)} |")
    lines+=['','Per-code outcome/reach/final hull/minimum-positive hull/total turns pairs are in `report.json` → `ship_A0_A11_trends`.',
            'A11 equal-state per-attack pressure is +0 in Area 1; Area 2 normal +1/+2/+3 at turns 1/3/9, elite/guardian another +1; Area 3 normal +1/+2/+3, elite another +1, guardian another +2. A0 adds zero. Frozen modifier source and independent rules fixtures establish mechanics; observed diverged voyages do not.',
            '', 'Earlier defeats censor fights and shorten total turns. Encounter matches and minimum hull trends are descriptive, not mechanical monotonicity proofs or human win odds.',
            'No rule changes, buffs, alternate policies, extra seeds, or retuning were used. Headless results do not establish rendered UI, live MCP, audio or exported-app behavior.',
            '', '## Reproducibility and exact raw evidence', '',
            '`winning-witnesses.json`: 36 full winning rows with source paths and hashes. `report.json`: every planned row including unresolved, per-tier/ship/rank/policy metrics, comparable fights and paths. `independent-audit.json`: independent raw-log/commands/fingerprints/identity checks.',
            '`manifest.json` pins the complete dependency closure, original policy, generated adapter, observer, design, runner and engine bytes/version. `rows/*` retains commands, stdout/stderr, result and quality. Compact archives exclude all save directories. Original-release parity and its original capture hash remain a separate archive.',
            '', f"Candidate fingerprint: `{audited['candidate_fingerprint']}`.",
            'Unit/reporter smoke exact exit is in `analysis-tools/unit-smoke.log`. Matrix phase receipts and launch commands are retained. No full suite or release packaging was run by this lane.']
    return '\n'.join(lines)+'\n'


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory',type=Path);p.add_argument('--parity',required=True,type=Path);p.add_argument('--out',required=True,type=Path)
    a=p.parse_args();d=a.directory.resolve();par=a.parity.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    if out != HERE/'evidence':
        raise ValueError('Public evidence output must be tools/ascension_update/evidence')
    if (out/'public-proof.json').exists():
        raise ValueError('Already published: restore unmodified original inputs and remove prior public-proof.json before finalizing again')
    verify(d)
    report=summarize(d);dump(d/'report.json',report)
    audited=audit(d);dump(d/'independent-audit.json',audited)
    proofs=witnesses(d);dump(d/'winning-witnesses.json',proofs)
    parity=json.loads((par/'parity-report.json').read_text())
    if parity.get('candidate_fingerprint')!=sha(d/'manifest.json') or len(parity.get('comparisons',[]))!=24 or not all(c['match'] for c in parity['comparisons']):
        raise ValueError('Separate parity24 identity/coverage mismatch')
    summary=markdown(report,audited,proofs,parity)
    (d/'SUMMARY.md').write_text(summary);(HERE/'OUTCOMES.md').write_text(summary)
    # Snapshot current analysis tools independently from the original frozen runner.
    tools=[('analysis-tools/'+p.name,p) for p in HERE.iterdir() if p.is_file() and p.suffix in ('.py','.md','.json','.log','.gd')]
    main_archive=archive(out/'ascension-v1-matrix.tar.gz',[('candidate',d)],tools)
    capture=HERE.parent/'balance_update/evidence/release-720.jsonl.gz'
    parity_archive=archive(out/'ascension-v1-parity24.tar.gz',[('parity24',par)],[('original-release-720.jsonl.gz',capture)])
    gate=report['gate_passed'] and audited['passed'] and parity['passed'] and len(proofs['witnesses'])==36
    index=dict(passed=gate,candidate_fingerprint=sha(d/'manifest.json'),matrix=main_archive,parity24=parity_archive,
               counts=report['counts'],unresolved=len(report['unresolved']),witnesses=len(proofs['witnesses']),
               finalizer_sha256=sha(Path(__file__)))
    dump(out/'index.json',index)
    # Publish explicitly labelled copies; preserve pre-redaction identities separately.
    from public_evidence import publish
    publish()
    print((out/'index.json').read_text(),flush=True)
    if not gate:print('FAILED GATE',json.dumps(dict(audit_errors=audited['errors'],missing=proofs['missing'])),flush=True)
    raise SystemExit(0 if gate else 1)

if __name__=='__main__': main()
