# Ascension candidate v1 — full frozen matrix

> Public evidence is path-portable, not byte-identical original audit input.
> `evidence/public-proof.json` records original and public artifact hashes and every
> changed payload hash. Only local home and macOS per-user temporary-root prefixes
> were replaced with `${LOCAL_HOME}` / `${LOCAL_TMP}`, including nested gzip;
> gameplay bytes otherwise compare equal. Tar member counts remain 1,894 / 116;
> the release capture retains all 722 JSONL lines. Gzip streams were recompressed
> and affected tar sizes updated. Original bytes were backed up outside Git in
> ignored `.tools/scratch` before replacement. All embedded manifests, row hashes,
> fingerprints and capture/hash-chain digests identify **unmodified originals**,
> not these public copies. The PASS results below apply to those originals only;
> public copies are summary/proof evidence, not certified hash-chain replay inputs.
> `index.json` archive paths are relative to that index. The standalone release
> capture was sanitized by the same transformation. Scans of all public payloads,
> including nested gzip, found no local absolute-path or credential-pattern hits;
> no credential-like values were redacted.

**Rules matrix gate: PASS. Independent raw-log audit: PASS.**

462/462 scheduled rows: {'victory': 93, 'defeat': 369}. Unresolved: 0.
Held-out rank/ship witnesses: 36/36. Forecast checks: 81547; zero mismatches required.
Separate original-release A0 parity: PASS (24 rows).

## Held-out tactical wins (out of four original codes)

| Rank | Cartographer | Hollow Choir | Palimpsest |
|---|---:|---:|---:|
| A0 | 3/4 | 2/4 | 1/4 |
| A1 | 2/4 | 2/4 | 1/4 |
| A2 | 2/4 | 2/4 | 1/4 |
| A3 | 1/4 | 2/4 | 1/4 |
| A4 | 1/4 | 2/4 | 2/4 |
| A5 | 1/4 | 2/4 | 2/4 |
| A6 | 1/4 | 2/4 | 2/4 |
| A7 | 2/4 | 2/4 | 2/4 |
| A8 | 2/4 | 2/4 | 1/4 |
| A9 | 2/4 | 2/4 | 1/4 |
| A10 | 2/4 | 2/4 | 1/4 |
| A11 | 2/4 | 2/4 | 1/4 |

## Ship-specific A0 versus A11 (held-out tactical)

| Ship | A0/A11 wins | Median all-fight turns A0→A11 | Median matched Area 3 turn delta | Median minimum-positive hull A0→A11 | Diverged paths |
|---|---:|---:|---:|---:|---:|
| cartographer | 3/2 | 3.0→3.0 | 0 | 14.0→15.0 | 1/4 |
| hollow_choir | 2/2 | 6.0→7.0 | 0 | 28.5→34.0 | 0/4 |
| palimpsest | 1/1 | 4.0→4.0 | 0.0 | 10.0→8.5 | 1/4 |

Per-code outcome/reach/final hull/minimum-positive hull/total turns pairs are in `report.json` → `ship_A0_A11_trends`.
A11 equal-state per-attack pressure is +0 in Area 1; Area 2 normal +1/+2/+3 at turns 1/3/9, elite/guardian another +1; Area 3 normal +1/+2/+3, elite another +1, guardian another +2. A0 adds zero. Frozen modifier source and independent rules fixtures establish mechanics; observed diverged voyages do not.

Earlier defeats censor fights and shorten total turns. Encounter matches and minimum hull trends are descriptive, not mechanical monotonicity proofs or human win odds.
No rule changes, buffs, alternate policies, extra seeds, or retuning were used. Headless results do not establish rendered UI, live MCP, audio or exported-app behavior.

## Reproducibility and exact raw evidence

`winning-witnesses.json`: 36 full winning rows with source paths and hashes. `report.json`: every planned row including unresolved, per-tier/ship/rank/policy metrics, comparable fights and paths. `independent-audit.json`: independent raw-log/commands/fingerprints/identity checks.
`manifest.json` pins the complete dependency closure, original policy, generated adapter, observer, design, runner and engine bytes/version. `rows/*` retains commands, stdout/stderr, result and quality. Compact archives exclude all save directories. Original-release parity and its original capture hash remain a separate archive.

Candidate fingerprint: `fc454e1a1ef46005f2fbea2bb7ad5a0a25bf76893630504cdf4b2fa23f7db32a`.
Unit/reporter smoke exact exit is in `analysis-tools/unit-smoke.log`. Matrix phase receipts and launch commands are retained. No full suite or release packaging was run by this lane.
