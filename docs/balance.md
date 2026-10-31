# Difficulty tuning

## Manual evidence tooling (issue #22, first slice)

[The guarded JSON manual driver](manual-replay.md) records stable card-instance
choices, ordered routes, explicit guarded enemy targets, before/after state and
RNG, effective card definitions, revision/content identity, and separate errors.
It supports deterministic replay and isolated save/resume, not a gameplay policy
or a graphical UX test. Multi-ship/profile baselines, metric reports, authored
expansion scenarios and graphical manual expeditions remain future issue #22 work.

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
