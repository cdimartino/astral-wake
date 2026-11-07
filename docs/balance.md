# Difficulty tuning

## Latest frozen baseline: all cases recorded, 35 unresolved timeouts

The [completed cumulative report](baselines/issue22-complete-resumed.md) and
[raw JSONL](baselines/issue22-complete-resumed.jsonl) now cover **720/720 planned
cases, zero missing: 141 victories, 544 defeats, 35 timeouts**, no errors or
action-limit unfinished runs. This is complete *record coverage*, not 720 resolved
expeditions: the 35 timeouts are **not losses** and were not retried or resolved.
Earlier interrupted/representative evidence below is preserved as historical;
its “incomplete” statements describe those individual captures, not this new one.

The resume inherited all **354** integration rows unchanged and ran only the
**366** missing cases. Its clean historical measurement revision is
`5a616c60e9380e83d9d8895bfaf6bb361c383d05`, not latest-main gameplay. Engine,
generation, ordered plan, timeout, and all four recorded source fingerprints match
the parent; historical Git objects at both measured revisions were checked against
those hashes. The resumed invocation took **937.623 seconds**, not a measurement
of total experiment time. The 1.30 MB uncompressed capture retains original
metadata, parent hash, per-case results and resume provenance for direct auditing.

Tactical recorded **42/60 Cartographer**, **40/60 Hollow Choir**, and **16/60
Palimpsest** victories across both tiers. These scheduled-case counts are not human
win rates or proof of optimal ship viability. Tactical's higher recorded victory
count than the simpler policies supports keeping decision-sensitive comparisons;
it does not identify which mechanic caused the gap or justify weaker enemies.
Fresh/full tiers use **different seeds and RNG initializations**, so this is not a
discoveries-only ablation. Do not infer a need for next-layer support from these
policy outcomes or replace the original seed-777 loss.

Future comparisons should reuse the published case plan, label changed source
fingerprints, compare paired cases, and keep timeouts separate. Any timeout retry
must be a new labelled runtime experiment, not a replacement of these rows.
Expansion-specific ablations and audited graphical/manual expeditions remain
outstanding; **issue #22 remains open**. No expeditions were run while publishing
this report, and no gameplay or policy code was changed.

Validate and regenerate counts:

```sh
python3 -m unittest discover -s tests -p test_baseline.py
python3 tools/baseline_report.py docs/baselines/issue22-complete-resumed.jsonl
```

Publication validation: **9 baseline tests passed**, including complete-plan/status
counts, inherited row byte equality, resume fingerprints/provenance, tactical
counts, capture hash, and generated report consistency. Historical source hashes
were additionally checked directly against Git objects at both measured revisions.

## Manual evidence tooling (issue #22, first slice)

[The guarded JSON manual driver](manual-replay.md) records stable card-instance
choices, ordered routes, explicit guarded enemy targets, before/after state and
RNG, effective card definitions, revision/content identity, and separate errors.
It supports deterministic replay and isolated save/resume, not a gameplay policy
or a graphical UX test. The separately published multi-ship/profile baseline below
is not a manual replay. Metric reports, authored expansion scenarios and graphical
manual expeditions remain later issue #22 work.

Historical manual seed **777**, Cartographer, lost at region 2 layer 2, turn 29,
hull 0, salvage 91. This was a headless rules run, not graphical UX testing, and
some shifting-index inputs played unintended cards. Preserve that loss; corrected
inputs are a separately labelled counterfactual. Approximate area-1 hull values,
subjective win percentages and the hypothesis that next-layer support was required
are not measured balance evidence. The tactical 424242 win below demonstrates one
feasible policy/seed, not a population win rate. No new balance results or difficulty
recommendation are claimed by this tooling slice.

## Pressure and counterplay

- Attacks deal 1.6 times their normalized authored damage, rounded up. Area strength is now 1.0 / 1.4 / 1.8 instead of 1.0 / 1.3 / 1.6. Legacy geographic scaling is removed before applying the expedition's area strength.
- Each attack gains another point for every four elapsed combat turns. This discourages indefinite repair farming; the complete amount appears in the next intent and uses the same preview/resolution path.
- Opening-area enemy hull is unchanged. The main pressure comes from surviving enemy phases rather than longer health bars.
- Mute Bell, White Noise, Lost Paragraph, Tuning Fork and Hushed Chord have twice their previous disruption. The shared half-attack prevention cap still applies, and defenses expire each phase. Timing and target selection matter.
- Elite/boss rewards offer two cards and two unowned powerups, with only one discovery taken. Shops offer two cards and two powerups within the existing six-slot layout. Many Pockets still adds a card choice.
- Recovery values remain 30 at recovery sites and 25 between areas. Spending a recovery on evolution therefore has a meaningful hull cost under the increased pressure.

## Reproduce the checks

```sh
bash tools/check.sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/playthrough.gd -- --seed=424242 --character=cartographer --allow-defeat
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/playthrough.gd -- --seed=424242 --character=cartographer --policy=aggressive --allow-defeat
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/playthrough.gd -- --seed=424242 --character=cartographer --no-bonuses --allow-defeat
```

Repeat with `palimpsest` and `hollow_choir`, and different seeds. Balanced is the existing greedy policy that values repair and prevented attacks alongside damage. Aggressive values only immediate damage and strain efficiency, while retaining the same between-battle choices. No-bonuses skips discoveries, shops, events and evolution, but still uses recovery repairs. `--allow-defeat` treats a genuine defeat as a completed experiment; invalid actions and unfinished runs still fail.

These policies compare decision sensitivity, not human win rates. The rules regression includes an otherwise lethal attack where selecting disruption survives and selecting damage loses, visible escalation across every enemy/area, and exclusive bonus selection.

`--policy=tactical` additionally weighs repair and attack prevention against current hull and incoming damage, and scores commands per command point. This is useful for ships with expensive resource-spending commands.

## Seeded results

These measurements are from the difficulty pass **before** the enemy-identity changes described in [the field guide](enemies.md). Tactical weaknesses and deterministic enemy targeting change current run outcomes and RNG consumption.

For fresh profiles on seeds **424242, 101, 2026**, across all three ships:

| Policy | Expedition wins | Outcome |
| --- | --- | --- |
| Balanced | 2 / 9 | Every run reached at least area 2; Cartographer won seeds 424242 and 101 with 62 and 41 hull. |
| Aggressive | 0 / 9 | Every run died in area 1. |
| No bonuses (424242 only) | 0 / 3 | All ships lost in areas 2–3. |

Before tuning, the baseline Cartographer policy on 424242 won with 99 hull. The same balanced policy now wins with 62. The other ships' greedy-policy losses are useful difficulty signals, not proof that their optimal play cannot win.

The tactical policy won Hollow Choir seeds 424242 and 101 with 82 and 77 hull, and lost 2026 in area 3. Palimpsest reached areas 2–3 but lost all three tactical runs; its multi-command Trace planning remains a priority for human playtesting.

## Enemy-identity pass

All 36 authored enemies now have different mechanical pattern signatures; validation rejects profiles that differ only in names or numbers. The [field guide](enemies.md) documents their counters. Regression tests cover phase windows, route weaknesses, interruption thresholds, drain prevention, saturation-dependent attacks, deterministic targeting, saved intents, and visible explanations.

On seed 424242 with the new rules, the Cartographer's original balanced policy loses in area 3, while the tactical policy completes the expedition with 79 hull. The same seed's aggressive policies died in area 1 for all three ships in the comparison run. This gives a concrete decision-sensitive regression rather than requiring every policy to win.

## Issue #22 frozen baseline protocol

`tools/baseline.py` runs the existing, unchanged `tests/playthrough.gd` decisions.
These are **automated headless rules expeditions**, not manual or graphical UX tests.
The original manual-input seed-777 loss remains a loss; this harness does not replay,
correct, or replace that expedition. Historical results above are not population
estimates for the present revision.

The published matrix is 30 seed families × 3 ships × 2 discovery tiers × 4 policies
= **720 expeditions**. For family `i = 0..29`, encode
`424240 + 104728*i + tier` as a six-character base36 seed, where tier is 0 (fresh)
or 3 (fully discovered). The JSONL metadata enumerates every exact seed/case before
execution. No seeds are selected or dropped based on outcomes. Modern RNG/generation
version is 1; numeric `--seed` fixtures instead use the legacy generator (version 0)
and must not be pooled with these measurements.

Important: modern practice seeds encode their discovery pool in their low two bits.
`--unlocks=3` alone does **not** make a tier-0 practice seed fully discovered.
The harness sets both the profile and corresponding seed tier, then records effective
`pool_tier`, `profile_unlocks`, and `rng_version` in every successful terminal result.
Tier pairs have different RNG initializations as well as pools: they are not a
controlled discoveries-only ablation. Each ship/policy sees the same seeds within
a tier. No-bonuses means balanced combat with discoveries, shops, events, and
evolution skipped; repair recovery remains enabled. It is not a fourth combat policy.

Reproduce from the revision recorded in the results metadata (use an installed
Godot executable and a **new**, isolated scratch path):

```sh
python3 -m unittest discover -s tests -p test_baseline.py
python3 tools/baseline.py --engine /path/to/Godot --scratch /approved/temp/new-baseline --output /approved/temp/baseline.jsonl --jobs 3
```

Use `--families 1` for a representative 24-case cost measurement. Per-case timeout
defaults to 180 seconds. Saves and stdout/stderr live under scratch, never the
player's save directory. Output is flushed after each case, preserving partial
coverage if interrupted. Each row distinguishes victory, defeat, error, unfinished
(action limit), and timeout. Nonzero exits and Godot script errors are not losses.
The metadata records the revision, dirty status, engine version, and SHA-256 of the
rules, RNG, catalog, and playthrough driver. Generation version describes the current
seed implementation, not a promise of cross-revision content compatibility.

No combat mechanics, enemy stats, or decision scores are changed by this protocol.
Policy quality remains limited: it is greedy, not an expert planner, and cannot by
itself confirm a need for next-layer support or estimate human win rates. Turn-level
decision diagnostics and stable-ID replay belong to the separate trace work.

### Captured baseline evidence (incomplete matrix)

Machine-readable captures:

- [Representative 24-case batch](baselines/issue22-representative.jsonl): rules
  revision `014ad4a63dd5b27677e5be1618ebf15ed6d17f59`, with uncommitted additive
  driver flags recorded by dirty status and file hashes. **3 victories, 19 defeats,
  2 timeouts**, no errors or action-limit unfinished runs. Total wall time
  **245.764 seconds**, three workers, 180-second per-case limit.
- [Attempted full matrix](baselines/issue22-full.jsonl): clean harness revision
  `389382acb5f9b51881e33f9e26fcae01057f4a0a`, identical rules/catalog/RNG and
  driver hashes. **27 recorded / 720 planned**: 3 victories, 21 defeats,
  3 timeouts; **693 missing**. The runner and only its own isolated child
  processes were explicitly stopped after measuring cost. Missing includes
  interrupted in-flight work; no outcome is assigned to it. There is no final
  wall-time summary for this interrupted batch.
- [Timeout stdout/stderr](baselines/issue22-timeouts.json) preserves the available
  progress markers rather than inferring defeat, stalled turn, or cause of death.

Both captures use Godot `4.7.2.stable.official.ed1daf0bf`, generation/RNG v1.
The batches overlapped in wall time, so their timings are not isolated performance
benchmarks. A simple extrapolation of the representative batch is **122.882 minutes**
for 720 cases at three workers; actual cost and timeout incidence can vary.
Increasing timeouts or workers needs a new explicitly labelled measurement.
The full 30-seed-per-ship/profile requirement is **not completed**. The default
harness publishes and can run the entire matrix; metadata lists all 720 cases,
including the ones not executed here. Do not combine duplicate cases across these
two captures or divide victories by 720.

Representative victories were Cartographer tier 3 balanced (44 hull), Cartographer
tier 3 tactical (64 hull), and Hollow Choir tier 0 tactical (77 hull). All use family
0 (`0093CG` fresh / `0093CJ` full). Hollow Choir tier 3 tactical and no-bonuses
timed out in that batch. These are isolated examples, not ship-level win rates.
The same Cartographer tier-3 tactical run was independently repeated twice and
produced identical gameplay result dictionaries after excluding timing/save paths.

Regenerate exact per-ship/tier/policy counts (including missing work):

```sh
python3 tools/baseline_report.py docs/baselines/issue22-representative.jsonl
python3 tools/baseline_report.py docs/baselines/issue22-full.jsonl
```

Validation: baseline unit tests passed; seed tests **364**, balance checks **352**,
and enemy tactics checks **752**, all zero failures; content validation passed,
including rejection of 20 malformed mutations. The additive flags were exercised
with isolated save directories and the deterministic repeat above. No graphical
expedition was performed. The data do **not** establish that next-layer support is
required, prove a ship unviable, or justify changing enemy strength. Preserve the
current enemies and original seed-777 loss; finish the matrix and collect audited
human outcomes before a numerical difficulty target or balance recommendation.

### Interrupted integration capture and missing-only resume

The later integration experiment was cancelled by a server restart. Its
[separate raw capture](baselines/issue22-integration-interrupted.jsonl) is preserved
byte-for-byte, alongside an explicitly [INTERRUPTED report](baselines/issue22-integration-interrupted.md).
It records **354/720 cases: 62 victories, 257 defeats, 35 timeouts, zero errors or
action-limit unfinished results; 366 cases are missing**. Missing means no recorded
outcome, including possible in-flight cancellation, not a timeout or a defeat.
There is no final summary or measured total wall time. The original representative
and 27-row partial captures above remain unchanged; do not combine their duplicate
cases into this measurement.

Integration source revision: `1cd5596a653c7dfe66c3d976f96f88c6c2d61fa1`, clean tree;
Godot `4.7.2.stable.official.ed1daf0bf`; generation v1; four workers; 180-second
per-case timeout. See the report for exact ship/tier/policy counts. These partial,
automated observations do not meet the completed 30-seed requirement or establish
human win rates.

`tools/baseline.py --resume-from CAPTURE` now retains **every recorded row**, including
errors, unfinished outcomes, and timeouts, and schedules **only absent cases**.
It creates a new cumulative JSONL with the original rows unchanged, the complete
plan, parent capture SHA-256, original metadata/revision, current measurement
revision, retained/scheduled counts, and explicit revision relationship. Existing
captures, log directories, and saves are never overwritten or resumed. Interrupted
unrecorded cases start new automated experiments in **new scratch directories**;
this does not restart the original seed-777 expedition.

Resume fails closed unless schema/kind, engine version, generation version, ordered
full plan, all four recorded source SHA-256 values (`scripts/game.gd`,
`scripts/seed_engine.gd`, `data/catalog.json`, `tests/playthrough.gd`), and per-case
timeout match exactly. A differing Git revision additionally requires
`--allow-compatible-revision`; this permission never overrides a fingerprint
mismatch. The historical capture did not fingerprint other files, so compatibility
is limited to that explicitly recorded fingerprint scope, not a universal proof of
identical repositories. Worker count may change and is recorded for the new segment.
Duplicate plans/results, unplanned rows, unknown statuses, malformed JSON, and
inconsistent final summaries are rejected rather than repaired or silently dropped.
Even recorded failures/timeouts are not retried; retry experiments must be separate.

**Current blocker:** latest `origin/main` at follow-up base `c279f1d` has a different
`scripts/game.gd` SHA-256 from this integration measurement. Resume correctly refuses
that tree even with compatible-revision permission. No gameplay files were changed
to bypass this guard. A future authorized run needs an isolated matching-source
checkout with this resume tooling installed, or a separate newly labelled baseline
for the changed rules. Do not mix changed-rule outcomes into this capture.

Compatibility check only (runs engine `--version`, no expeditions or output files):

```sh
python3 tools/baseline.py --engine /path/to/Godot --resume-from docs/baselines/issue22-integration-interrupted.jsonl --allow-compatible-revision --scratch /approved/temp/new-resume-check --output /approved/temp/new-resume-check.jsonl --jobs 4 --timeout 180 --check-resume
```

Once compatibility passes and a run is authorized, omit `--check-resume`, using
fresh scratch/output paths. Default `--families 30` preserves the full 720-case plan;
changing it fails plan validation. Exactly **366** cases would be scheduled from
this capture, not the 35 recorded timeouts or any other recorded outcome. A further
interruption can be resumed from the new cumulative capture under the same checks.
`baseline_report.py` labels absent final summaries as interrupted/incomplete and
reports inherited rows; any resumed wall-time summary covers only that invocation,
not total elapsed time across cancellations. No follow-up full run was launched.

Validation for this follow-up: **8 baseline tests passed**, covering fingerprints,
plan/engine/timeout mismatches, explicit compatible revisions, duplicate/unplanned
rows, skipping all five recorded statuses, retaining failed/timeout rows, new-scratch
protection, check-only behavior, and the preserved capture's counts and byte hash.
