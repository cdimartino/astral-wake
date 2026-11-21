# Balance playtest build · rules revision 1

**Crescendo rewards a full spend.** A player starting a new Hollow Choir
voyage can choose Bright Canon for a reliable attack or draft the Crescendo
card for a prepared burst. Both cost 2 CP. Before organs and enemy defenses,
at 0/1/2/3 Resonance actually spent, Bright Canon deals **12/14/16/18**
and Crescendo deals **10/12/14/20**. Both still gain the usual healing.
The +4 applies to the card, not the identically named organ. It does not
improve healing or increase the base that a command remembers. The normal
kind-repeat reset happens before Concert. The upgrade choices and 40-salvage
price floor remain; there is no new card to unlock.

**Cadence tells the truth before you commit.** With enough Resonance, it adds
3, 1 or 0 ward when starting at 0, 2 or 3 ward respectively. The compact
forecast now reports the actual total across organ, printed and install
effects. It also reports zero if Cadence spends the resource but the ward
cap is already reached. The same value is available to live clients as
`ward_gained`.

**Choices are easier to execute.** Travel and inspect-only destinations are
separate live actions with public node IDs. A shop purchase names the item or
service, the price after discounts, and its slot even after another item
sells. The shop explains which purchases happen immediately and when a deck
service charges salvage.

**What did not change:** enemy HP, incoming damage scaling, starting hull,
reward generation, the three starting decks, powerup stacking, Cartographer
and Palimpsest mechanics. The Crescendo change cannot be credited with
shortening voyages just because a full-spend card deals more damage. The
[100 design options](balance-update-options.md) are not 100 buffs.

## Compatibility and local build

New expeditions pin `rules_revision=1`; saves lacking the pin keep the
original rules. Loading an old expedition does not reroll its map, cards or
shops. Continuing an old Choir expedition still gives 16 damage on a
full-spend base Crescendo before organs/mitigation. Recorded history pins
the rules used. Manual journals remain tied to their original source
fingerprints; a different build is not an exact replay of an old journal.

The local macOS candidate is `dist/Astral-Wake-Balance-Playtest-macOS.zip`
(SHA-256 `7607cc986ffaa7994e68e28d3c5da4dcb8162c8def73d4d8a7651eb4c00cdd07`).
The exported pack independently returned 20 damage on the new rules, 16
on the legacy rules, and +1 capped Cadence ward. The signed app booted
through the real live bridge in an isolated profile. This is a local test
build, not an installed or published release.

## Playtest findings

The [paired comparison table](../tools/balance_update/evidence/official.md)
contains 224 completed rules runs (112 control/trial pairs). The 48 legacy
control rows reproduced the earlier review's deterministic results. The
modern fresh- and full-discovery cohorts used different predeclared seeds;
compare the two builds *within* each cohort, not as a before/after test of
unlocks. These are policy results, not human win rates.

**Crescendo is a sidegrade, not a pacing fix.** On all six original Choir
tactical seeds, both arms won 4/6. Of 113 encounters matched by map node and
roster, 111 took the same number of turns; two took longer and none got
shorter. The median stayed at eight turns, missing the preregistered 15%
reduction. This was not simply because the card never showed up: the trial
saw 326 draws of Crescendo, nine plays, and four qualifying full spends.
Those added 16 effective damage without converting any primary hit into a
kill. A damaging full spend is a real reason to draft the card; on its own,
it is not an answer to slow Choir endgames.

That conclusion also held on the modern tactical seeds: fresh stayed
7/8 wins and seven turns per matched fight; full discovery went 6/8 → 7/8
wins but stayed at eight turns. The extra win is not a pacing effect.

Moving the premium onto the Crescendo **organ** instead of the card was
tested separately, not stacked with it. Across 16 paired expeditions the
median per-encounter percentage change was zero for 141 same-path/roster
matches. Original tactical wins stayed 4/6, with one win and one loss
swapping seeds. A stronger but more frequently activated bonus still
didn't reliably shorten fights; that organ change is not in the build.

**Keep Recall unchanged in this candidate.** On the six original Palimpsest
tactical seeds, the +3 primary damage experiment won the same single voyage
as control (11057); median turns per matched encounter remained 4.5. It can
matter: on modern full-discovery code 0420OB, switching it on only at the
entrance of a previously lethal Area 3 encounter changed a loss into a
clear. The full voyage still lost under both rules. Conversely, on fresh
code 02VDB4 the trial won a voyage the control lost, but replaying the
original lethal encounter with the bonus enabled still lost: neither replay
spent 6 Trace there. A different voyage outcome alone does not identify the
decision responsible.

**Most promising next Palimpsest experiment: spend Trace on defense.** In a
separate trial, paying 1 Trace at Redact applied 4 disruption instead of 3.
It changed the legacy tactical result from 1/6 to 4/6; balanced and
damage-first remained 0/6. The four modern tactical holdouts did not gain
a win: fresh stayed 2/2, fully discovered stayed 1/2. In a constructed
Drowned Catalogue encounter, the extra point crossed Remember's real
interrupt threshold and prevented a lethal mark. That is evidence of a
useful decision, not proof it caused the three full-voyage wins. Testing
the original loss on seed 424242 was more informative: starting with the
same enemies, hand and 59 hull, standard tactical play lost on turn 5;
the Redact trial cleared on turn 8 with 24 hull. No action was interrupted
in that particular fight; more disruption and the opportunity to repair
both mattered. The balanced-policy replay still lost. This alternative
is **not** in the attached build.

**What was observed through the live interface:** a fresh Hollow Choir lost
in Area 1 after five battles won and 22 enemy phases. Its 75 staged commands
all produced the forecast ward change, including 11 positive gains. It did
not play the named Crescendo card. The voyage validates the forecast and
controls, not the frequency of a perfect Concert. The first nine commands
were at normal speed; the rest used accelerated presentation in that same
isolated expedition.

Palimpsest also lost in Area 1, on destination 10 after six battles won
and 21 enemy phases. In a normal-speed decision against Arc Herald,
Revision Spike via Scribe → Splice forecast 9 damage with 2 Trace banked;
adding Recall spent the Trace, forecast 13, and reduced the Herald from 90
to 77 HP. All 75 ward deltas matched here too. Neither final voyage reached
a shop. A separate preliminary shop visit confirmed the named upgrade
charged 35 salvage only after the player chose Keen Margin. Neither these
two defeats nor the accelerated presentation is an estimate of human
difficulty or play time.

## Release candidate: 720 expeditions

**178 victories, 542 defeats.** All 720 scheduled cases reached a terminal
state: no timeouts, errors, unfinished expeditions or retries. Each cell
below reports victories out of 30 expeditions at that discovery tier.

| Ship | Discoveries | Damage-first | Starter-only¹ | Balanced | Tactical |
|---|---|---:|---:|---:|---:|
| Cartographer | Fresh | 0 | 0 | 18 | 27 |
| Cartographer | Full | 0 | 0 | 14 | 22 |
| Palimpsest | Fresh | 0 | 0 | 1 | 10 |
| Palimpsest | Full | 0 | 0 | 1 | 11 |
| Hollow Choir | Fresh | 0 | 0 | 11 | 28 |
| Hollow Choir | Full | 0 | 0 | 12 | 23 |

¹ The baseline runner's `--no-bonuses` uses balanced combat choices but
skips discoveries, shops, events and evolutions; it still takes repairs.

Every ship has a reproducible fresh-profile win where the other three
policies lost on the same seed: Cartographer on `0093CG` (58 turns),
Palimpsest on `00KBE0` (104), and Choir on `0093CG` (159).
Palimpsest remains the hardest ship for these policies. The gap between
tactical (121/180) and damage-first (0/180) supports leaving enemy scaling
alone. It does not tell us how often people will win or isolate a particular
card choice as the cause.

The [public capture](../tools/balance_update/evidence/release-720.jsonl.gz)
uses the published 30-family plan, content pool 1, Godot 4.7.2, four
workers, a 240-second per-case limit and a fresh save for every case.
The ordered plan, row identities, terminal outcomes and all five source
hashes were checked against the runner and candidate. The frozen rules
project was a minimal snapshot: its Git base alone is not its build identity.
Machine-local path prefixes were redacted for publication; gameplay rows
are unchanged. The [publication proof](../tools/ascension_update/evidence/public-proof.json)
records both the original and public checksums.
This is a candidate-only release check; use the 112 paired comparisons
above, not the difference against an older 720-case total, to judge the
individual changes.

## Regression checks

- `ASTRAL_AUDIO_DRIVER=Dummy bash tools/check.sh` — exit 0, including
  save/evolution, historic rules fingerprints, UI geometry, ward/choice
  regressions, audio and a completed Cartographer victory. Godot emitted
  resource-cleanup diagnostics on some UI test exits; no script errors
  or failed assertions in the completed run.
- `python3 tests/mcp_integration.py --godot .tools/Godot.app/Contents/MacOS/Godot`
  — exit 0, including preview purity, revision/busy handling, hidden-state
  filtering, subscription notifications and shutdown.
- Export: macOS application signature and ZIP integrity verified; playable
  app startup and rules arithmetic checked against the exported package.
