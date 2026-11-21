# Predeclared Ascension candidate experiment

This lane owns only this directory and unique temporary scratch. It does not
change production, `tests/playthrough.gd`, legacy experiments, saves, or balance.
Headless policy outcomes are **not** human win odds, rendered UI evidence, or a
blind MCP expedition.

## Design and sequence

`design.json` is the outcome-independent predeclaration: 432 primary runs
(6 codes × 3 ships × 12 ranks × tactical/aggressive) plus 30 tactical
`--no-bonuses` controls (2 calibration codes × 3 ships × 5 checkpoints).
“aggressive” is the existing damage-first policy. The no-bonus policy is the
existing tactical policy with between-fight bonuses skipped, repairs retained.
No policy functions are edited; only lab unlock/start identity and observation
fields are inserted into a scratch copy of the frozen driver.

Codes come from SHA256 of the fixed labels in the design, reduced into the
six-character code space and with low two pool bits set to fresh=0/full=3.
No code was selected by a gameplay outcome. Unit tests verify disjointness from
the old 30-family baseline and all modern legacy-trial codes.

1. `calibration-checkpoints`: **90** rows: 60 primary + 30 no-bonus,
   grouped in A0, A3, A6, A9, A11 order (at most four concurrent processes).
2. Stop for coordinator review; then `calibration-intermediates`: 84 primary.
3. Stop for coordinator permission; then `holdouts`: 288 primary.

The CLI requires explicit coordinator signals and prior phase completion. These
are audit records, not a security boundary: do not pass permission you did not
receive. No retuning in this lane. If holdout outcomes are seen and rules change,
predeclare new holdouts before running them. All A0 rows rerun: no implicit old
A0 reuse. New-code A0 is **not proof of historical A0 parity**; matching old
release input/dependency comparisons are a separate stratified gate.

## Reproduction

```sh
python3 -m unittest discover -s tools/ascension_update -p 'test_*.py' -v
python3 tools/ascension_update/run.py plan
python3 tools/ascension_update/run.py freeze /absolute/new/scratch \
  --implementation-ready 'coordinator signal/reference'
python3 tools/ascension_update/run.py run /absolute/new/scratch \
  --phase calibration-checkpoints --jobs 4 --rules-ready 'coordinator signal/reference'
python3 tools/ascension_update/report.py /absolute/new/scratch
```

Freeze copies the transitive literal `res://` dependency closure and original
policy plus the generated adapter and observer. It fingerprints every copied
input, the design, and runner. The signed macOS Godot binary stays in its app
bundle (moving its executable alone can trigger AMFI); exact binary SHA and
version are pinned. Verify rejects changed frozen inputs/binary before launch
and after each rank block. Source worktree edits do not alter frozen candidates.
No full game suite is run by this lane.

Each row gets a new isolated save directory, command+environment, separate
stdout/stderr, terminal result, fights, quality errors, fingerprint, exit, and
elapsed time. Timeouts and errors retain rows/logs and prevent phase completion.
Resume reuses exactly identified existing rows, including losses. It never
silently retries an error or overwrites any row; repairs require a new declared
scratch candidate. Logs retain action digests and fight entry signatures without
reading hidden draw order or RNG state. The six explicit seed codes are lab
inputs, not live blind-run disclosures.

`report.json` covers all planned rows (including missing/unresolved), wins and
reach per tier/cohort/policy/ship/rank, final/min-positive hull, fight turns,
paired A0 encounter/equal-visible-entry deltas, path divergence, missing held-out
tactical wins, and new aggressive wins needing explanation. Encounter matches
are not full equal-state mechanical tests. The minimum-positive-hull sample is
from action boundaries plus ordered presentation hull/heal cues; defeat zero is
excluded. Inherited driver validates every post-action state. Observer compares
chosen preview damage with resolved command damage. No hidden-information
planner, buff, alternate diagnostic policy, or tuning is introduced.

## Original-release A0 parity

`parity.py` preselects **24 family-zero** rows: all three ships, both tiers, all
four historical policy labels from the preserved `release-720.jsonl.gz`. Unlike
the new no-bonus controls, historical `no-bonuses` used **balanced** combat; this
is reproduced explicitly. It verifies old non-rules dependency hashes and engine
version, copies the frozen candidate into parity-only scratch, and writes the
old capture SHA/metadata/rows and selected plan before launching. Do not run this
while all four matrix workers are active.

```sh
python3 tools/ascension_update/parity.py /absolute/candidate /absolute/new/parity-scratch --jobs 4
```

Comparison excludes exactly `wall_seconds`, `save_directory`, and these new
observation/identity fields: `ascension_rank`, `modifier_revision`,
`rules_revision`, `min_positive_hull`, `quality`, `path_taken`. Every other field,
including outcome, reach, deck/evolutions, powerups, actions, turns, cards,
checkpoints, pool/RNG/policy identities, must match. The old capture does not
contain the entire reward sequence or a per-action trace, so terminal parity
cannot establish equality of unrecorded intermediate offers.

## Coordinator-authorized holdout checkpoint subset

After reviewing calibration and a successful parity24, the coordinator authorized
only the **120 original held-out checkpoint rows**, leaving all intermediates
blocked. `holdout_checkpoints.py` selects that subset by existing IDs from the
unchanged frozen design. It requires matching successful parity, preserves the
candidate fingerprint, and records the authorization/helper hash and subset
before execution. This does not redefine the 432-run main plan or mark missing
intermediate rows complete. It never generates more seeds.

```sh
python3 tools/ascension_update/holdout_checkpoints.py /absolute/candidate \
  --parity /absolute/parity-scratch/parity-report.json \
  --authorization 'coordinator checkpoint-only permission' --jobs 4
```

Report distinguishes checkpoint-only coverage/gate from the full ladder gate.
Neither can pass on missing rows or missing required tactical wins.

## Completion, independent audit and compact evidence

After the coordinator authorized the remaining 252 original intermediate rows,
run the two original phases in order: `calibration-intermediates`, then
`holdouts`. The latter reuses the 120 exact checkpoint rows already present;
no original row, loss or code is replaced.

```sh
python3 tools/ascension_update/finalize.py /absolute/candidate \
  --parity /absolute/parity-scratch --out tools/ascension_update/evidence
```

`audit.py` is an independently implemented path, importing neither runner nor
reporter. It compares raw stdout terminal/fight/action/identity records against
each stored row and original plan, checks full 462 coverage, commands and
isolation, rank/pool/policy, actual process exit, all 36 required tactical
witnesses, paired damage-first anomalies and every frozen hash. Its own focused
fixture establishes that a tampered raw terminal is rejected. This is an
independent algorithmic audit, not an assertion that another reviewer approved.

`finalize.py` saves all 36 exact winning rows (first victory in the original
predeclared order), ship-specific paired A0/A11 outcome/hull/turn trends and
limits, a concise Markdown aggregate, audit JSON, and two compact archives.
Matrix commands/logs/rows/fingerprints/frozen source and analysis tooling go in
one archive; parity24 and the untouched original capture go in a separate one.
**All save directories and `.godot` caches are excluded.** The archive index
contains exact checksums and byte counts. Archive metadata is deterministic;
a focused test verifies byte reproducibility and save exclusion. This is evidence
archiving, not release packaging.
