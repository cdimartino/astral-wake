#!/usr/bin/env python3
"""Publish path-portable evidence; never re-certify original hash chains.

Run from the repository root: python3 tools/ascension_update/public_evidence.py
Original bytes are backed up under ignored .tools/scratch before replacement.
"""
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'tools/ascension_update/evidence'
RELEASE = ROOT / 'tools/balance_update/evidence/release-720.jsonl.gz'
PREFIXES = (
    (rb'/Users/[A-Za-z0-9_.-]+', b'${LOCAL_HOME}'),
    (rb'/home/[A-Za-z0-9_.-]+', b'${LOCAL_HOME}'),
    (rb'(?:/private)?/var/folders/[^/\s]+/[^/\s]+/T', b'${LOCAL_TMP}'),
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def portable(data):
    for pattern, replacement in PREFIXES:
        data = re.sub(pattern, lambda _: replacement, data)
    return data


def transform(data, name, changes):
    if name.endswith('.gz'):
        raw = gzip.decompress(data)
        cooked = transform(raw, name[:-3], changes)
        return data if raw == cooked else gzip.compress(cooked, compresslevel=6, mtime=0)
    cooked = portable(data)
    if cooked != data:
        changes.append(dict(member=name, original_sha256=sha(data), public_sha256=sha(cooked)))
    return cooked


def archive(data, changes):
    target = io.BytesIO()
    count = 0
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as source:
        with gzip.GzipFile(fileobj=target, mode='wb', filename='', mtime=0, compresslevel=6) as gz:
            with tarfile.open(fileobj=gz, mode='w|') as dest:
                for member in source:
                    if not member.isfile():
                        raise ValueError('Expected regular evidence members only')
                    raw = source.extractfile(member).read()
                    cooked = transform(raw, member.name, changes)
                    member.size = len(cooked)
                    dest.addfile(member, io.BytesIO(cooked))
                    count += 1
    result = target.getvalue()
    # Independently compare ordered member names and every decompressed byte.
    with tarfile.open(fileobj=io.BytesIO(data)) as old, tarfile.open(fileobj=io.BytesIO(result)) as new:
        assert old.getnames() == new.getnames()
        for a, b in zip(old, new):
            x, y = old.extractfile(a).read(), new.extractfile(b).read()
            if a.name.endswith('.gz'):
                x, y = gzip.decompress(x), gzip.decompress(y)
            assert portable(x) == y, a.name
    return result, count


def publish():
    paths = [EVIDENCE / 'ascension-v1-matrix.tar.gz', EVIDENCE / 'ascension-v1-parity24.tar.gz', RELEASE, EVIDENCE / 'index.json']
    if 'public_copy_notice' in json.loads(paths[-1].read_text()):
        raise ValueError('Already public: refusing to relabel sanitized bytes as originals')
    scratch = ROOT / '.tools/scratch'
    scratch.mkdir(parents=True, exist_ok=True)
    assert subprocess.run(['git', 'check-ignore', '-q', str(scratch)], cwd=ROOT).returncode == 0, 'Backup must be ignored'
    backup = Path(tempfile.mkdtemp(prefix='public-evidence-originals-', dir=scratch))
    for path in paths:
        dest = backup / path.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        assert dest.read_bytes() == path.read_bytes()
    proof = dict(format=1, scope='Public path-portable copies, not original audit identities',
                 transformations=['Replace local home prefix with ${LOCAL_HOME}', 'Replace macOS per-user temporary root through /T with ${LOCAL_TMP}', 'Recompress changed gzip streams with mtime=0; rewrite tar member sizes only'],
                 digest_policy='All embedded manifest, fingerprint, row, command, capture, file and chain digests describe unmodified originals only. Original audits applied only to those originals. Public copies are not certified replay/hash-chain inputs. This proof certifies byte equality after the declared prefix substitution, including nested gzip; gameplay data is otherwise unchanged.',
                 artifacts=[])
    outputs = {}
    for path in paths[:-1]:
        raw = path.read_bytes()
        changes = []
        if path.name.endswith('.tar.gz'):
            cooked, count = archive(raw, changes)
        else:
            cooked = transform(raw, path.name, changes)
            assert portable(gzip.decompress(raw)) == gzip.decompress(cooked)
            count = len(gzip.decompress(raw).splitlines())
        outputs[path] = cooked
        proof['artifacts'].append(dict(path=path.relative_to(ROOT).as_posix(), original_sha256=sha(raw), public_sha256=sha(cooked), public_bytes=len(cooked), entries=count, changed_payloads=changes, equality_minus_path_prefixes=True))
    index = json.loads(paths[-1].read_text())
    for key in ('candidate_fingerprint', 'finalizer_sha256', 'passed'):
        if key in index:
            index['original_' + key] = index.pop(key)
    for key, path in zip(('matrix', 'parity24'), paths[:2]):
        entry = index[key]
        entry['original_sha256'] = entry['sha256']
        entry.update(path=path.name, sha256=sha(outputs[path]), bytes=len(outputs[path]))
    index['public_copy_notice'] = proof['digest_policy']
    index['public_proof'] = 'public-proof.json'
    outputs[paths[-1]] = (json.dumps(index, indent=2, sort_keys=True) + '\n').encode()
    # Originals all safely backed up before the first replacement.
    for path, data in outputs.items():
        path.write_bytes(data)
    (EVIDENCE / 'public-proof.json').write_text(json.dumps(proof, indent=2, sort_keys=True) + '\n')
    print('Originals backed up in ignored .tools/scratch; public proof:', (EVIDENCE / 'public-proof.json').relative_to(ROOT))


if __name__ == '__main__':
    publish()
