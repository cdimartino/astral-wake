# Cartographer expansion candidate (#16; NOT ready to close)

Manual evidence: [Attempt A — labelled recovery continuation](cartographer-expansion-attempt-a.md)
and [Attempt B — Interception](cartographer-expansion-attempt-b.md). Both exact
replays and independent evidence assessments passed within their documented limits.
The user authorized provisional shared-art shipping; new-artwork acceptance and
remaining #16 criteria stay open.

Nine production cards / eighteen authored branches, with no new resolver effect.
Existing 72 bases, 144 branches, starters, enemies, powerups, nominal rarity
weights, pity, prices and metaprogression are unchanged. New cards require no
discovery unlock. Palimpsest and Choir receive none of them.

## Content and branch contract

| Card | Base | Branch A | Branch B |
| --- | --- | --- | --- |
| Survey Spike | common, 1 CP, attack 8; unused ordered route +5 | damage 11 | damage 8, Retain |
| Cross Current | uncommon, 1 CP, attack 7; exactly three organs cool first by 1 after strain | damage 10 | damage 7, flat ward 4 |
| Living Atlas | rare, 2 CP, Install novel-route later-damage engine, cap 6 | cost 1 | cost 2, immediate flat ward 5 |
| Heat Sink | common, 1 CP, vent 1, flat ward 5 | vent 2, ward 5 | vent 1, ward 8 |
| Thermal Lance | uncommon, 1 CP, attack 9; routed entry-strain exactly 2 adds 6 | damage 12 | damage 9, vent 1 |
| Phase Radiator | rare, 2 CP, Install first later command cooling ≥2 actually removed strain each player turn: ward 5 | cost 1 | cost 2, immediate flat ward 5 |
| Parry Filament | common, 1 CP, disruption 3, flat ward 5 | disruption 6, ward 3 | disruption 3, ward 8 |
| Refracted Fang | uncommon, 1 CP, attack 9; Prism plus another entry-live foe: ward 4 | damage 12 | damage 9, unconditional ward 3 (7 group / 3 lone) |
| Interception Loom | rare, 2 CP, Install once/enemy phase after positive redirect: extra hit 6 to same recipient | cost 1 | cost 2, immediate flat ward 5 |

Branches replace only existing printed stats/booleans. They inherit the entire
conditional descriptor, engine identity, threshold and cap. No nested override
language. Full effective descriptions, intrinsic flags, keyword help, stat badges,
preview, UID-owned counters and payment remain authoritative.

Novelty uses **every committed command's exact ordered route**, including utility
and installation, resetting each player turn. Atlas rewards a novel damaging
attack only after it resolves; stacks affect later attacks. Thermal checks entry
strain **before its own vent**, never historical strain or post-command strain.
Prism's condition checks another foe before damage; ward is flat, not Echo-scaled.
Cooling observes actual vent plus post-route removals, excluding end-turn cooling.
Retaliation is separately armor/exposed-mitigated, cannot redirect/recurse, and
cannot retarget a dead recipient. Existing defense caps/latches are unchanged.

Atlas is damage **scaling**. Radiator is **prevention/enabler**, Loom **enabler**,
not falsely tagged printed damage scaling. Cross Current's primary is enabler;
Survey/Thermal/Fang attack; Heat Sink/Parry prevention.

## Save and deterministic pool versioning

Run schema **7**, store envelope still **1**. `content_pool_revision` is independent
of `reward_generation` (0 uniform / 1 constrained rarity+pity).

* Fresh runs, including numeric fixture API: content **1**, catalog **81**.
* Authentic older runs: explicit migration to content **0**, original **72**;
  keep their reward generation, pending stock/prices/choices, RNG and future pool.
* Old pending selection guards are validated **before** adding the field, then
  rebound. Schema-7 missing/fractional/bool/unsupported fields are rejected, not
  defaulted. A content-0 deck/reward/shop cannot contain revision-1 cards.
* All generated reward/shop/event cards pass ship, unlock and content filtering
  before distribution. Public reward/shop acquisition also rejects out-of-pool
  IDs atomically before spending. Run history and manual/baseline metadata include
  content revision. Resume cannot mix pool revisions, even with revision permission.
* Missing `introduced_revision` means old content 0. The Python raw catalog gate
  requires an integer (not bool or float), 0..1. JSON runtime validation also rejects
  malformed/fractional/out-of-range values before integer restoration.

`tests/content_pool_legacy_oracle.json` was captured by running the standalone
`tests/content_pool_oracle.gd` against a detached **df3e6c5** project, not the
candidate: 12 histories, 96 future reward+shop cycles, both RNG APIs, both reward
generations, all ships, exact stock/prices/pity/RNG. The original 432 full combat
fingerprints iterate an explicit frozen 72-ID list; no hashes are regenerated or
silently truncated. New definitions are tested separately. Historical distribution
sampling explicitly uses pool 0; expansion evidence is labelled pool 1.

## Scripted package evidence — NOT drafted expeditions

`tests/cartographer_package_evidence.gd` and
`docs/baselines/content1-packages.json`: 42 completed encounters, production
definitions/owned UIDs, ordinary CP/strain/enemies, fixed ten-card test decks and
fixed opening hands. Three packages, each with and without its rare, versus two
Cinder Mites and Unhatched Sun; hybrid without rare; repeat each with no relic,
Hermit Knot and Pilgrim Spine. No altered enemy stats, forced wins or player buffs.
Engine cases explicitly pay 2 CP to install first, then use the named preview
heuristic. This scripted setup is **not** evidence that the automated policy
discovers or drafts a build. A `reward` outcome means encounter cleared, not a
full expedition victory.

No-relic outcomes (hull / enemy phases+current player turn):

| Package | Group with rare | Group without | Boss with rare | Boss without |
| --- | --- | --- | --- | --- |
| Survey | 88 / 3 | 86 / 2 | 69 / 7 | 99 / 10 |
| Thermal | 88 / 3 | 85 / 2 | 100 / 10 | 84 / 9 |
| Interception | 100 / 4 | 100 / 3 | 94 / 13 | 100 / 12 |
| Hybrid, no rare | — | 100 / 3 | — | 88 / 9 |

These are not matched-random-deck causal estimates. All nine cards are actually
used across the cases. Atlas boss log reaches +6 and remains capped, reducing
turns but not guaranteeing better hull. Radiator boss repeatedly earns exactly
5 ward on qualifying cooling commands; its empty-strain group setup gives no
such payout. Loom adds a real 6-damage redirected hit against the group; the boss
case earns no retaliation and setup delays general attacks. Thus incorrect setup
can make a deck slower, not automatically stronger. Common attacks/defense work
without the rares. The original heuristic-only pass declined installs despite a
positive setup score; the final evidence therefore labels setup as authored.

Across the relic comparisons the recorded commands include one-, two- and
three-organ routes (not an assumption that three organs are always best).
Inspect the JSON per-relic rows rather than pooling their outcomes.

`cartographer_expansion_test.gd` additionally proves branch advantages: attack
output versus Retain/ward/actual cooling; Parry reaches interruption 5 versus
additional ward; deep vent removes 4 versus 2 when two organs start at 2.
Each quick Install fits **two** later 1-CP commands where guarded setup fits only
one. Conversely, with only the Install available in hand, hull 3 facing attack 6,
the guarded setup survives while quick setup dies: spare CP cannot manufacture
an unheld defense card. With no incoming damage the ward is wasted and quick setup
has real extra command capacity. No engine cap/type evolves.

## Policy and full-run smoke

`cartographer-content1-setup-v1` is a small named heuristic, **not** a planner:
existing preview damage/ward/cooling/conditional outputs plus modest setup
valuation; Loom gets no setup value against a lone target, and imminent lethal
suppresses setup value. Reward/branch scoring recognizes ward, conditions and
installation. It can still undervalue setup or waste ward; scripted evidence is
not presented as automated build discovery. Pool-0 policy versions remain intact.

Numeric seed **424242**, tactical, discovery 0, pool 1 completed normally:
victory, 22 battles, 71 turns, 414 actions, hull 76. It drafted Survey Spike,
Parry Filament and Refracted Fang without requiring a rare installation. CI's
existing smoke seed is retained, not replaced with a cherry-picked new seed.
This is one smoke case, not a new win-rate baseline.
Raw result and matching source fingerprints: `docs/baselines/content1-smoke.json`.
Reports were generated before the candidate commit; precommit HEAD is recorded
where applicable, and the thirteen SHA256s identify the actual tested candidate
bytes (including policy and evidence scripts), not a historical baseline.

## Validation record and attempt warnings

Godot **4.7.2.stable.official.ed1daf0bf**, absolute main-worktree binary, isolated
approved scratch storage. Complete `tools/check.sh` exited **0**, with every
script reached, **UI_FAILURE_COUNT 0 / UI_GEOMETRY_PASS 16060**, normal/skip intro,
native CoreAudio smoke and the final 424242 victory. The log was inspected for
script/parse errors, not merely its shell exit status. Original 432 fingerprints
remain unchanged; distribution regression has 489,068 checks. Final targeted
expansion refinement: **459 checks / 0 failures**; 27 native-node definitions at
both sizes pass. The full run included the preceding 453-check version; the last
six assertions strengthen real follow-up attacks, wasted ward and scarce-hand
lethal setup, then were rerun separately. Python baseline tooling: **9 tests pass**.
All 42 scripted encounters completed, with all thirteen report fingerprints checked
against candidate bytes. Native evolved Thermal (1440x900) and quick Interception
(1100x720) demo launches exited normally, not human visual signoff.

Logs are under `/private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/`:

| Log suffix | Earlier attempt / resolution |
| --- | --- |
| `issue16-check.log` | stopped at historical 36-pair test; production now has 45; original fingerprints retained |
| `issue16-check2.log` | manual environment numeric JSON equality; normalize integral JSON numbers before comparing metadata |
| `issue16-check3.log` | oracle canonical JSON float representation; expected data normalized, **not** regenerated/rebaselined |
| `issue16-check4.log` | edited running shell script caused an offset/command error; subsequent checks ran stable script bytes |
| `issue16-check5.log` | eight duplicated new artwork crops exposed catalog-index clamp; explicit shared slots added; original 72 still unique |
| `issue16-check-final.log` | shell exited 0 despite UI smoke parse error; **not accepted as pass**, indentation fixed |
| `issue16-check-complete.log` | complete accepted run described above; actual UI geometry success verified |

Existing exit-time ObjectDB/resource diagnostics remain in evolution, Palimpsest,
Choir and reward-distribution UI suites (counts vary). They are not claimed fixed
or warning-free. New expansion node/rules tests and both native demo launches
reported no failures. No push, PR, merge or issue closure is part of this candidate.

## Post-review archive eligibility fix

The independent review of `79bed51` found that current-schema completed combat
snapshots validated card identities but not their content pool. The follow-up
checks every archived combat-zone instance (including installed source instances)
and `last_command.card` against the run's ship/content revision. It deliberately
does **not** require completed records to match the current deck: removal and
evolution after battle remain legitimate. No resolver, reward, pool generation,
card definition or migration behavior is changed.

`cartographer_expansion_test.gd` now has **543 checks**, including **20 raw
current-schema archive records**: 13 invalid records rejected (all five zones,
foreign ships, last-command-only corruption, and an actual installed engine with
source/counter metadata) and seven valid records preserved exactly (both pool
revisions, completed records predating removal/evolution, removed installed source
and installed source predating evolution). Each raw case uses a fresh save with
no backup or migration that could conceal rejection. Targeted compatibility still
passes 2,339 checks / the unchanged 432 fingerprints, plus 12 histories / 96
future reward/shop/RNG cycles. The existing package/smoke reports above remain
the **79bed51 historical candidate evidence**; they are not regenerated or
relabeled for this validation-only fix. Frozen detached manual sessions are not
touched, and no new manual expedition is required by this fix.

Follow-up `tools/check.sh` completed with exit **0**, using the same absolute
Godot binary and approved isolated scratch storage. Its log is
`/private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/issue16-archive-fix-check.log`.
All stages reached UI geometry **PASS / 0 failures**, both intro checks, CoreAudio
smoke and the existing automated 424242 smoke (victory, hull 76, pool 1). Log
inspection found no script/parse errors. The full run included the 539-check
archive suite; the final additional evolved-installed-source case and refinement
of the removed-source fixture were rerun separately at **543 / 0 failures**.
Standard rules/raw-save regression also passed **11,579 / 0** independently.
Existing exit-time ObjectDB/resource diagnostics remain in evolution, Palimpsest,
Choir, reward-distribution and enemy-tactics UI tests; no warning-free claim.

## Native test-deck workflow and human acceptance still needed

No image generation was requested or performed. All nine use existing licensed
original **card-atlas** slots: Survey 0 (Needle), Cross 21 (Winter Needle),
Atlas 29 (Star Chart), Heat 2 (Cold Breath), Thermal 11 (Wake Lance),
Radiator 33 (Deep Winter), Parry 3 (Quiet Pulse), Fang/Loom 18 (Mirror Cut).
The renderer explicitly honors these original slots instead of clamping catalog
indices ≥72 to the last illustration. These are **shared-art prototypes, NOT nine distinct illustrations**.
Art-manifest counts still correctly describe the original illustrations. Distinct
art acceptance remains OPEN unless the lead explicitly accepts reuse.

Use a fresh scratch directory for each launch, never a player save:

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
export TMPDIR="$(mktemp -d /private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/content1-review.XXXXXX)/"
export ASTRAL_SAVE_DIR="$TMPDIR/survey-demo"
"$GODOT_BIN" --path . --script tests/cartographer_expansion_demo.gd -- --package=survey
# New save directory each time: --package=thermal, interception, hybrid.
# Add --small for 1100x720; default native size is 1440x900.
# Add --evolution=0 or --evolution=1 for explicit authored branch test decks.
```

Survey: Install on Hush, then attack on a different route; inspect UID stack,
repeat-route denial and +6 cap. Thermal: compare Lance through entry-strain-2
Lens before versus after Heat Sink; inspect actual cooling and Radiator's latch.
Interception: compare Fang through Prism with two foes versus last foe; Loom
requires a positive redirect, not merely existing ward. Inspect full tooltips,
ward/cooling preview and evolved rules at **both** window sizes. Node tests are
not a human visual signoff.

**Concrete decision for the human reviewer:** with Lens at strain 2 and both
Lance and Heat Sink available, choose immediate +6 Lance damage versus cooling
first for ward/safe future access. Record the actual forecast, decision and result;
do not claim the scripted test's decision was human-authored evidence.

After the candidate is frozen, the lead still owes **two full manual attempts**
with distinct intended build goals (for example Survey and Thermal/Interception),
including a missing-desired-rare adaptation if not offered. Start real pool-1
discovery-0 practice, not the test-deck entry:

```sh
"$GODOT_BIN" --headless --path . --script tools/manual_replay.gd -- \
  --session="$TMPDIR/manual-survey" --start=0093CG --ship=cartographer --unlocks=0
```

Confirm `state.content_pool_revision: 1` independently of
`state.reward_generation: 1`. Use `docs/manual-replay.md` for guarded manual
commands/resume/replay. Second attempt needs another fresh session directory.
Do not edit source between frozen-candidate start and replay.

**Open gates:** two full human attempts, native visual/decision record, independent
implementation review, package evidence/balance audit, shared-art acceptance.
This implementation is a candidate, not permission to close #16 or merge it.
