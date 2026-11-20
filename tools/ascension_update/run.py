#!/usr/bin/env python3
"""Predeclared Ascension rules experiment. Never operates on a player profile."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SHIPS = ('cartographer', 'hollow_choir', 'palimpsest')
CHECKPOINTS = (0, 3, 6, 9, 11)
PHASES = ('calibration-checkpoints', 'calibration-intermediates', 'holdouts')
NAMESPACE = 'astral-wake-ascension-2026-11-20-v1'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dump(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def encode(n):
    text = ''
    for _ in range(6):
        n, d = divmod(n, 36)
        text = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'[d] + text
    return text


def seeds():
    # No outcome search: six fixed hash labels, pool encoded by low two bits.
    rows = []
    for cohort, index, tier in [('calibration', 0, 0), ('calibration', 0, 3),
                                ('holdout', 0, 0), ('holdout', 1, 0),
                                ('holdout', 0, 3), ('holdout', 1, 3)]:
        label = f'{NAMESPACE}/{cohort}/{index}/{tier}'
        n = int.from_bytes(hashlib.sha256(label.encode()).digest()[:8], 'big') % (36**6)
        rows.append(dict(cohort=cohort, index=index, tier=tier, code=encode(n-n%4+tier), label=label))
    assert len({r['code'] for r in rows}) == 6
    return rows


def cases():
    rows = []
    for s in seeds():
        for rank in CHECKPOINTS + tuple(n for n in range(12) if n not in CHECKPOINTS):
            phase = 'holdouts' if s['cohort'] == 'holdout' else ('calibration-checkpoints' if rank in CHECKPOINTS else 'calibration-intermediates')
            for ship in SHIPS:
                for policy in ('tactical', 'aggressive'):
                    rows.append(dict(s, rank=rank, ship=ship, policy=policy, no_bonuses=False, phase=phase, arm='primary'))
                if s['cohort'] == 'calibration' and rank in CHECKPOINTS:
                    rows.append(dict(s, rank=rank, ship=ship, policy='tactical', no_bonuses=True, phase=phase, arm='no-between-bonuses'))
    for i, row in enumerate(rows):
        row['id'] = f"{i:03d}-{row['cohort']}-{row['code']}-{row['ship']}-A{row['rank']:02d}-{row['policy']}-{row['arm']}"
    return rows


def design():
    return dict(schema=1, namespace=NAMESPACE, seeds=seeds(), planned=cases(),
                policies='unchanged tests/playthrough.gd tactical and aggressive (damage-first)',
                no_bonuses='unchanged tactical --no-bonuses: skips bonuses, takes repairs',
                content_pool_revision=1, hp_scale=1,
                sequence=list(PHASES), checkpoints=list(CHECKPOINTS), max_workers=4,
                reuse='disabled: all A0 rows rerun under frozen candidate dependencies',
                gates='Held-out tactical win per ship per rank; no unexplained paired new aggressive win; no state/forecast regressions. Policy outcomes, not human odds.')


def adapt(source):
    source = source.replace('extends SceneTree\n', 'extends SceneTree\nvar path_taken := []\nvar min_positive_hull := 999999\nvar quality := {"forecast_checks":0,"forecast_mismatches":0,"state_checks":"inherited after every action","hull_sampling":"action boundaries and ordered hull cues"}\n', 1)
    old = '\tvar beginning=game.new_run(seed_value,character_id)'
    assert source.count(old) == 1, 'Policy contract changed'
    new = '''\tvar ascension_rank=int(OS.get_environment("ASCENSION_RANK"))
\tgame.profile.ascension_unlocks={"cartographer":11,"hollow_choir":11,"palimpsest":11}
\tvar beginning=game.new_run(seed_value,character_id,ascension_rank)'''
    source = source.replace(old, new)
    old = '\tresult.policy=policy'
    assert source.count(old) == 1
    return source.replace(old, '''\tresult.ascension_rank=game.run.get("ascension_rank",-1)
\tresult.modifier_revision=game.run.get("modifier_revision",-1)
\tresult.rules_revision=Game.RULES_REVISION
\tresult.min_positive_hull=min_positive_hull
\tresult.quality=quality
\tresult.path_taken=path_taken
\tresult.policy=policy''')


def dependency_files(root):
    # Transitive static res:// dependencies, including literal content reads.
    pending = ['scripts/game.gd', 'tests/playthrough.gd', 'project.godot']
    found = set()
    while pending:
        name = pending.pop()
        if name in found:
            continue
        path = root/name
        if not path.is_file():
            raise ValueError('Missing dependency: '+name)
        found.add(name)
        if path.suffix == '.gd':
            pending.extend(re.findall(r'["\']res://([^"\']+)["\']', path.read_text()))
    return sorted(found)


def freeze(directory, engine, ready):
    if not ready:
        raise ValueError('Coordinator implementation-ready signal required before freeze')
    directory.mkdir(parents=True, exist_ok=False)
    project = directory/'project'
    names = dependency_files(ROOT)
    before = {n:sha(ROOT/n) for n in names}
    for name in names:
        target = project/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT/name, target)
    if before != {n:sha(ROOT/n) for n in names}:
        raise ValueError('Source changed during freeze')
    generated = project/'tools/ascension_update'
    generated.mkdir(parents=True)
    (generated/'policy.gd').write_text(adapt((project/'tests/playthrough.gd').read_text()))
    shutil.copyfile(HERE/'observer.gd', generated/'observer.gd')
    shutil.copyfile(HERE/'run.py', directory/'runner.py')
    dump(directory/'design.json', design())
    # Preserve the signed macOS app location: relocating its Mach-O alone is killed by AMFI.
    # Its exact bytes are pinned and rechecked before/after each block instead.
    version = subprocess.check_output([str(engine), '--version'], text=True).strip()
    files = {str(p.relative_to(directory)):sha(p) for p in directory.rglob('*') if p.is_file()}
    manifest = dict(schema=1, source_sha256=before, files=files, engine_version=version,
                    engine_path=str(engine), engine_sha256=sha(engine),
                    ready_signal=ready, created_unix=time.time(),
                    claim='Isolated headless rules/policy evidence, not MCP/UI or human win odds')
    dump(directory/'manifest.json', manifest)
    return manifest


def verify(directory):
    m = json.loads((directory/'manifest.json').read_text())
    if sha(m['engine_path']) != m['engine_sha256']:
        raise ValueError('Pinned engine changed')
    for name, digest in m['files'].items():
        if sha(directory/name) != digest:
            raise ValueError('Frozen dependency changed: '+name)
    return sha(directory/'manifest.json')


def records(text, prefix):
    return [json.loads(l[len(prefix)+1:]) for l in text.splitlines() if l.startswith(prefix+' ')]


def validate(case, result, fights, save):
    errors = []
    expected = dict(seed=case['code'], character=case['ship'], policy=case['policy'],
                    no_bonuses=case['no_bonuses'], profile_unlocks=case['tier'], pool_tier=case['tier'],
                    ascension_rank=case['rank'], modifier_revision=1, seeded=True,
                    rng_version=1, content_pool_revision=1, reward_generation=1,
                    save_directory=str(save))
    for key, value in expected.items():
        if result.get(key) != value:
            errors.append(f'{key}: {result.get(key)!r} != {value!r}')
    if result.get('mode') not in ('victory', 'defeat'):
        errors.append('unfinished')
    if sum(f['end_turns'] for f in fights) != result.get('turns'):
        errors.append('fight turn coverage')
    if sum(f['won'] for f in fights) != result.get('battles'):
        errors.append('fight outcome coverage')
    if sum(f['plays'] for f in fights) != result.get('cards_played'):
        errors.append('fight play coverage')
    if result.get('quality', {}).get('forecast_mismatches', 0):
        errors.append('preview/resolution damage mismatch')
    return errors


def run_case(case, directory, fingerprint, timeout):
    out = directory/'rows'/case['id']
    out.mkdir(parents=True, exist_ok=False)
    save = out/'save'
    engine = json.loads((directory/'manifest.json').read_text())['engine_path']
    cmd = [engine, '--headless', '--path', str(directory/'project'),
           '--script', 'tools/ascension_update/observer.gd', '--', '--allow-defeat',
           '--code='+case['code'], '--character='+case['ship'], '--policy='+case['policy'],
           '--unlocks='+str(case['tier']), '--content-pool=1', '--hp-scale=1', '--save-dir='+str(save)]
    if case['no_bonuses']:
        cmd.append('--no-bonuses')
    env = {**os.environ, 'ASTRAL_SAVE_DIR':str(save), 'ASTRAL_AUDIO_DRIVER':'Dummy', 'ASCENSION_RANK':str(case['rank'])}
    dump(out/'command.json', dict(argv=cmd, env={k:env[k] for k in ('ASTRAL_SAVE_DIR','ASTRAL_AUDIO_DRIVER','ASCENSION_RANK')}))
    started = time.monotonic()
    row = dict(case=case, fingerprint=fingerprint, status='error', returncode=None)
    stdout = stderr = ''
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=timeout)
        stdout, stderr = proc.stdout, proc.stderr
        row['returncode'] = proc.returncode
        results = records(stdout, 'PLAYTHROUGH')
        row['fights'] = records(stdout, 'FIGHT')
        row['result'] = results[0] if len(results) == 1 else {}
        row['quality_errors'] = validate(case, row['result'], row['fights'], save)
        if proc.returncode != 0 or 'SCRIPT ERROR' in stdout+stderr or 'ERROR:' in stdout+stderr:
            row['quality_errors'].append('engine or process error')
        row['status'] = row['result'].get('mode', 'error') if not row['quality_errors'] else 'error'
    except subprocess.TimeoutExpired as exc:
        stdout = (exc.stdout or b'').decode(errors='replace')
        stderr = (exc.stderr or b'').decode(errors='replace')
        row['status'] = 'timeout'
    except Exception as exc:
        row['exception'] = repr(exc)
    finally:
        (out/'stdout.log').write_text(stdout)
        (out/'stderr.log').write_text(stderr)
        row['seconds'] = time.monotonic()-started
        dump(out/'row.json', row)
    return row


def run_phase(directory, phase, jobs, timeout, signal):
    if not signal:
        raise ValueError('Explicit coordinator rules-ready signal required')
    if not 1 <= jobs <= 4:
        raise ValueError('Workers must be 1..4')
    fingerprint = verify(directory)
    spec = json.loads((directory/'design.json').read_text())
    # Explicit phases and prior clean completion prevent accidental holdout peeking.
    for earlier in PHASES[:PHASES.index(phase)]:
        receipt = directory/(earlier+'.complete.json')
        if not receipt.exists() or json.loads(receipt.read_text())['fingerprint'] != fingerprint:
            raise ValueError('Prior phase not complete: '+earlier)
    planned = [c for c in spec['planned'] if c['phase'] == phase]
    dump(directory/(phase+'.launch.json'), dict(fingerprint=fingerprint, rules_ready_signal=signal, planned=planned, jobs=jobs))
    rows = []
    # Checkpoint ranks complete in order before the next checkpoint is submitted.
    ranks = CHECKPOINTS if phase == PHASES[0] else sorted({c['rank'] for c in planned})
    for rank in ranks:
        block = [c for c in planned if c['rank'] == rank]
        pending = []
        for c in block:
            file = directory/'rows'/c['id']/'row.json'
            if file.exists():
                row = json.loads(file.read_text())
                if row['fingerprint'] != fingerprint or row['case'] != c:
                    raise ValueError('Incompatible existing row')
                rows.append(row)  # Unresolved rows remain; never silently rerun a loss/error.
            else:
                pending.append(c)
        with ThreadPoolExecutor(jobs) as pool:
            futures = [pool.submit(run_case,c,directory,fingerprint,timeout) for c in pending]
            for f in as_completed(futures):
                row = f.result()
                rows.append(row)
                print(row['case']['id'], row['status'], flush=True)
        verify(directory)
        if any(r['status'] not in ('victory','defeat') for r in rows):
            raise ValueError('Unresolved rows: inspect logs before proceeding')
    dump(directory/(phase+'.complete.json'), dict(fingerprint=fingerprint, rows=len(rows)))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    sub.add_parser('plan')
    f = sub.add_parser('freeze')
    f.add_argument('directory', type=Path)
    f.add_argument('--engine', type=Path, default=ROOT/'.tools/Godot.app/Contents/MacOS/Godot')
    f.add_argument('--implementation-ready', required=True, help='Coordinator signal verbatim/reference')
    r = sub.add_parser('run')
    r.add_argument('directory', type=Path)
    r.add_argument('--phase', choices=PHASES, required=True)
    r.add_argument('--jobs', type=int, default=4)
    r.add_argument('--timeout', type=int, default=900)
    r.add_argument('--rules-ready', required=True)
    a = p.parse_args()
    if a.command == 'plan': print(json.dumps(design(), indent=2))
    elif a.command == 'freeze': freeze(a.directory.resolve(), a.engine.resolve(), a.implementation_ready)
    else: run_phase(a.directory.resolve(), a.phase, a.jobs, a.timeout, a.rules_ready)

if __name__ == '__main__':
    main()
