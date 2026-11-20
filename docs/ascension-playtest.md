# Ascension 11 playtest

**Balance gate passed.** The original A0–A11 curve had a held-out tactical win
for every ship at every rank, with no tuning or ship buffs needed.

## What changes

- Win an ordinary expedition at rank N to unlock N+1 **on that ship**, up to
  A11. Losing, abandoning or winning seeded practice does not unlock a rank.
- A0 remains the default and is always available. Select an unlocked rank
  before starting; changing ships cannot retain a rank that ship has not earned.
- Ship setup shows the new modifier and a cumulative Rules panel. The active
  rank appears during play and in outcomes/history.
- Seeded practice keeps the selected rank through retry and save/resume.
  Exact replay identity includes ship, seed, rank and rules/modifier versions.
- Existing expeditions without Ascension fields remain A0. A retained,
  explicitly ordinary modern victory can grant A1 once; uncertain numeric-seed
  history is not treated as evidence of an earned unlock.
- Cocoon text now distinguishes creation from its two subsequent enemy phases
  and shows the remaining countdown. Hatch timing is unchanged.

## The ladder

Each step retains the preceding ones. Bonuses apply to visible attack damage
before the usual defenses; they do not increase enemy HP or change rewards.

| Rank | Added rule |
|---|---|
| A0 | Existing rules |
| A1 | Area 3 attacks +1 |
| A2 | Area 2 attacks +1 |
| A3 | Area 3 attacks another +1 from turn 5 |
| A4 | Area 2 attacks another +1 from turn 5 |
| A5 | Area 3 attacks another +1 from turn 9 |
| A6 | Area 2 attacks another +1 from turn 9 |
| A7 | Area 3's turn-5 bonus begins on turn 3 |
| A8 | Area 2's turn-5 bonus begins on turn 3 |
| A9 | Area 3 elite/guardian attacks another +1 |
| A10 | Area 2 elite/guardian attacks another +1 |
| A11 | Area 3 guardian attacks one final +1 |

Area 1 is unchanged at every rank. At A11 the premium caps at +3 per ordinary
Area 2/3 attack, +4 for late-area elites and the Area 2 guardian, and +5 for
the final guardian. Encounter type controls the premium, including spawned
enemies. The existing turn-pressure calculation still applies independently.

The update does not buff Palimpsest, weaken Cartographer, raise enemy hull,
or stack the rejected Recall and Crescendo-organ trials.

## Balance evidence

The full frozen matrix resolved **462/462** runs: **93 victories, 369 defeats,
no errors or timeouts**. All 216 damage-first runs and all 30 runs using
tactical combat without between-fight bonuses lost. The independent audit
found no mismatch in 81,547 forecast/resolution checks. On four predeclared
held-out seeds per ship, tactical wins were:

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

Routes and choices can diverge after an extra point of damage, so small-sample
wins need not decrease monotonically with rank. Equal-state fixtures separately
establish that the mechanical attack premium never decreases. These are policy
tests, not human win rates. See the [full results](../tools/ascension_update/OUTCOMES.md)
and [public evidence index](../tools/ascension_update/evidence/index.json).
The public archives redact local path prefixes. Audit fingerprints refer
to the unmodified originals, not the published copies.

All 24 historical A0 comparisons matched the previous release's recorded
gameplay results, including actions, turns, decks, evolutions and powerups.
Only non-gameplay timing/path fields and additive observer/version fields were
excluded. The historical capture and expected combat hashes were not replaced.

A fresh blind live A11 Choir voyage lost in Area 1 after five battles won and
25 enemy phases, at normal speed throughout. The advertised Second Eyelid
purchase charged 75 salvage correctly. Because the run did not reach Area 2
or a Cocoon, it does not establish live premium/countdown behavior. Separate
controlled fixtures checked ordinary A10→A11 unlock, the A11 cap, practice
no-unlock, duplicate protection and seeded retry/save/resume; those artificial
completions are not earned victories.

## Audio decision

Keep the Living Hull mix, editable composer pack and Sound Desk unchanged.
The narrow repeat-discard prototype attenuated zero cues: the flagged peak
came chiefly from leading phase/attack sounds rather than overlapping repeated
discards. A lower peak in another take was scheduling variation, not a treatment
result.

The recorder measures pre-master audio. Default-level listening excerpts apply
the documented 50% master gain; they are calculated post-master files, not
hardware-output captures. Default and maximum test captures did not clip.
No measurement guarantees comfort at every playback volume. Repeated vent/plasma,
guardian and dense-combat cases remain outside this narrow audio experiment.

See the [approved design and 100 considered options](ascension-update-design.md).

## macOS playtest build

`dist/Astral-Wake-Ascension-11-macOS.zip` · SHA-256
`8ccb0bb911a626b97b729ad025ce4e59c80c1d338ed27746dd9357d2f4fa7b66`.
This is a local playtest export, not an installation or a public release.
The signature and ZIP integrity passed verification. The replacement app's
actual selector was inspected with fresh and eligible test profiles. The
packaged game passed A0/A11 attack arithmetic and mitigation checks, and
the shipped executable preserved the exact public A11 checkpoint through
save, quit, relaunch and continue in an isolated profile.
