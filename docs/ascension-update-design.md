# Astral Wake next pass: Ascension without making the base game harder

> Approved design record, not a release note. The 100 options below were considered; only the selected scope is being implemented. Ascension balance qualification is pending. The audio experiment subsequently found no eligible repeated-discard overlap, so the existing mix remains unchanged.

## Recommendation

Ship an optional **Ascension ladder from 0 through 11**, fix the Ember Cocoon countdown copy, and test a narrow audio treatment. Keep the base game, Cartographer reference, existing Crescendo sidegrade, regional scores, composer pack and live Sound Desk intact. Do not ship 100 changes; use the list below to select and reject alternatives. Funded Redact is the only ship-rule reserve worth reopening in this pass, and gets a separate trial **only** if Palimpsest cannot meet the Ascension gate. No stacking to rescue a failed result.

### What the evidence says

- The 720-case rules-revision-1 matrix finished with 178 victories and no timeouts: tactical 121/180, balanced 57/180, damage-first and starter-only each 0/180. Tactical by ship: Cartographer 49/60, Choir 51/60, Palimpsest 21/60. These are policy outcomes, not human odds. The historical starter-only arm used balanced combat.
- The latest two Cartographer pairs held tactical combat constant. Both expeditions won with normal between-fight choices and both lost in Area 3 when those choices were skipped, despite taking repairs. Discovery tiers are **not** Ascension; the two tiers also use different RNG inputs.
- The latest live Palimpsest lost in Area 1 to Ash Cantor after five wins and 22 enemy phases. The opening ran at 1×; the rest was accelerated. Tested Recall, named purchase and evolution worked. One defeat is not proof that Ash Cantor is overtuned. The Cocoon concern is ambiguous wording, not a demonstrated timer bug.
- Counting only combats that look similar can hide route changes. Prior Choir card and organ trials did not shorten matched fights reliably. Separate Redact 3→4 trial had legacy tactical wins 1/6→4/6 and one same-entry Area 3 rescue, but no extra wins in four modern holdouts. Neither result justifies a global change.
- Fresh Glass Beyond capture: map −24.3 LUFS-I / −14.6 dBTP, travel/combat −24.1 LUFS-I / −6.8 dBTP, no clipping. The approximately 8 dB peak jump and brief 2–5 kHz concentration suggest auditioning the turn change at 12.8–13.3 s. The title capture was silent but separate; it does not prove a smooth handoff. No digital measurement guarantees comfort for a listener at any playback volume.

## Proposed update

**Ascension 0 stays the default.** Progression is per ship: win an ordinary expedition at rank N to unlock N+1, up to **Ascension 11**. An A11 victory is recorded as the capstone, not an A12 unlock. No unlock for loss, abandonment, or seeded practice; duplicate completion cannot advance twice. On existing profiles only, recognize a retained history victory with explicit ordinary-run provenance and a valid ship for A1; ambiguous older records are not guessed. Backfill once, independently of the size-limited history. Players may choose any unlocked rank, go back down, and preview both the cumulative rules and the difference from the previous rank. No new rewards are exclusive to rank.

**First curve to test, not final damage values.** Each rank retains all preceding modifiers. Apply these only to damage-dealing attack intents, after base scaling and before normal mitigation. Every step changes a real, named encounter condition; late areas and dangerous routes carry the pressure, not bigger health bars.

| Rank | New pressure above the prior rank |
|---|---|
| A0 | Current rules, unchanged |
| A1 | Area 3 attacks gain +1 damage |
| A2 | Area 2 attacks gain +1 damage |
| A3 | Area 3 attacks gain another +1 at combat turn 5 and later |
| A4 | Area 2 attacks gain another +1 at turn 5 and later |
| A5 | Area 3 attacks gain another +1 at turn 9 and later |
| A6 | Area 2 attacks gain another +1 at turn 9 and later |
| A7 | The Area 3 turn-5 bonus now starts on turn 3 |
| A8 | The Area 2 turn-5 bonus now starts on turn 3 |
| A9 | Attacks by enemies in Area 3 elite and guardian encounters gain +1 |
| A10 | Attacks by enemies in Area 2 elite and guardian encounters gain +1 |
| A11 | Attacks by enemies in the Area 3 guardian encounter gain one final +1 |

At A11 that caps the per-attack premium at +3 in ordinary late-area fights, +4 in late-area elites and the Area 2 guardian, and +5 in the Area 3 guardian. Use encounter classification, not the attacking enemy's ID, so spawns follow the same rule. Area 1, enemy hull, healing, marks, interrupts, reward pools, opening decks and base scaling remain unchanged. Include the bonus in the visible intent consumed by preview and resolution; no hidden second hit. Calibrate the full ladder first. If a band is too punishing, try at most one softer curve per failing band (e.g. narrower encounter coverage or later onset), keeping each rank distinct, A0 identical, and A11 the cap. Then validate on unseen matched seeds. If the full ladder still fails, deliver the independent clarity changes and a separate labeled Ascension test build/report, not a shorter ladder presented as the requested update.

**Implementation boundaries.** Start with `scripts/game.gd` `new_run`, `_intent_for`, `_finish_run`, `_valid_profile`, `_valid_run`: add validated per-ship unlocks and an immutable run/history rank and modifier revision, distinct from rules/content/RNG IDs. Missing old fields mean A0 and must not rewrite an old pending selection guard, checkpoint or intent. Explicit invalid combinations fail validation. Keep six-character seeds unchanged; exact practice identity is code + ship + rank + rules/modifier revision. Seed entry uses the chosen unlocked rank but grants no advancement. Record rank and rules in the run summary/history and keep rank when retrying a seeded run; do not claim an old rules version is exactly replayable when it isn't. Ordinary starts and the unchanged 720-matrix path default to A0. Do not mutate the user's active save; replacement still requires in-game confirmation.

In `scripts/main.gd`, show rank and unlock reason alongside ship setup, with a keyboard-accessible selector covering 0–11 that fits the existing layout. Show active rank in voyage, history and terminal records; guard seeded input, ship changes and replace confirmation so they cannot apply an ineligible or different rank. Use `scripts/mcp_controller.gd` to advertise the visible, revision-checked control with labeled options and public rank/history/unlocks; never expose token, seed, RNG, or newly hidden gameplay data. No new public debug unlock. Relabel the incubator intent as spawning a cocoon and show the cocoon's actual remaining enemy phases from the timer. A fresh cocoon hatches at the end of the second **subsequent** enemy phase, not its creation phase; do not change hatch timing or whether disruption delays it.

**Audio lane.** In the `scripts/hull_audio.gd` live cue path and editable bank/mix data, first reproduce the turn-change cluster and correlate real cue timing with mixer samples before attributing it. Test *one* candidate: reduce second and later overlapping short effects by about 3 dB within a 250 ms cluster for the specifically identified cue family; do not apply to the first attack/impact, shield confirmation, movie, music or region transitions. If a stable culprit cannot be isolated, keep the existing mix and report it. Keep stable cue IDs, bus controls, live overrides, audition/solo and active highlighting; do not bake a new score or change the master default. Compare untreated and candidate level-matched excerpts at normal speed including title→map, Glass Beyond turn change, vent and plasma repeats, guardian cue and a dense multi-target fight. No change ships on meters alone if it makes cues harder to identify or a listener finds it harsh; if subjective review is unavailable, deliver the paired excerpts and keep the current audio pending review.

## 100 options considered

**Build** = included subject to gates above. **Trial** = only the explicitly bounded experiment above. **Reserve** = plausible but not this release. **Hold** = deliberately avoid for now. Alternatives are not cumulative.

### 01–10 · Progression and identity
1. **Build:** Unlock each next rank by winning the preceding rank on that ship.
2. **Build:** Keep A0 selectable and the default even after an unlock.
3. **Build:** Show locked-rank requirements before starting a voyage.
4. **Build:** Give clearly attributable historical ordinary wins A1 credit once.
5. **Build:** Keep the chosen rank stable across pause, save, resume and seeded retry.
6. **Build:** Record rank and modifier revision separately from discovery and RNG.
7. **Build:** Allow practice at an unlocked rank without awarding rank progression.
8. **Hold:** Unlock higher ranks on defeat; it blurs the meaning of Ascension.
9. **Reserve:** Add a cosmetic mark for clearing the top rank on every ship.
10. **Hold:** Gate best cards behind high rank; this entangles power and difficulty.

### 11–20 · Difficulty curve
11. **Trial:** Introduce the ordinary attack premium in Area 3 before extending it to Area 2.
12. **Trial:** Add two late-fight thresholds, keeping enemy hull unchanged.
13. **Trial:** Move the first threshold forward at mid-high ranks so slow routes feel pressure earlier.
14. **Trial:** Reserve the last three steps for elite/guardian pressure, with A11 targeting the final guardian.
15. **Trial:** If a band is too steep, narrow its attack coverage or defer its onset without creating identical ranks.
16. **Reserve:** Offer tougher optional branches that leave safe routes available.
17. **Reserve:** Rotate an ascended guardian behavior rather than an HP multiplier.
18. **Hold:** Raise enemy hull globally; fights already risk running long.
19. **Hold:** Reduce starting hull; compounds the observed Palimpsest opening risk.
20. **Hold:** Raise shop prices by rank; it may weaken the decisions already separating wins from losses.

### 21–30 · Palimpsest
21. **Trial:** Funded Redact 3→4 alone if Palimpsest blocks the release gate; keep as a separate result.
22. **Hold:** Reintroduce full-Trace Recall +3; prior wins did not support adoption.
23. **Reserve:** Show which incoming intent the fourth point of disruption would interrupt.
24. **Reserve:** Add a bank-versus-spend practice encounter based on a verified late loss.
25. **Reserve:** Explain when Splice has no eligible second target before confirmation.
26. **Reserve:** Show the last remembered printed payload in the ship panel.
27. **Reserve:** Give a named opening event a choice between repair and a Trace-oriented draft.
28. **Reserve:** Audit Ash Cantor's counterplay across several opening rosters before retuning.
29. **Reserve:** Compare a more reliable early repair draft without changing the starter deck.
30. **Hold:** Grant free Trace at the start of every fight; it weakens resource timing.

### 31–40 · Hollow Choir and Cartographer
31. **Build:** Preserve the existing Crescendo card crossover; do not call it a pacing fix.
32. **Hold:** Add the tested Crescendo organ bonus; matched medians did not improve.
33. **Reserve:** Count turns where Choir has effectively stabilized but cannot close the fight.
34. **Reserve:** Show a phrase-reset warning before a same-kind command spends nothing.
35. **Reserve:** Add a phrase practice puzzle contrasting setup with an immediate attack.
36. **Reserve:** Audit late healing loops separately from enemy animations and total turns.
37. **Reserve:** Make a closing attack a draft trade against sustain, not a straight upgrade.
38. **Build:** Use unchanged Cartographer as the reference for every rank comparison.
39. **Reserve:** Explain post-mitigation target and splash damage separately on Fork.
40. **Hold:** Nerf Cartographer based on win rates alone; the reference is useful.

### 41–50 · Combat clarity and correctness
41. **Build:** State explicitly that a newly spawned Cocoon gets two subsequent enemy phases.
42. **Build:** Show the live Cocoon countdown rather than a static description.
43. **Build:** Include the rank premium in the visible attack intent and its explanation.
44. **Reserve:** Clarify the exact order when two enemies act and the first strains an organ.
45. **Reserve:** Separate mark damage from ordinary incoming damage in the phase recap.
46. **Reserve:** Distinguish interruption from ordinary disruption in the combat log.
47. **Reserve:** Show precisely which connection a sever can disable when known.
48. **Reserve:** Explain why redirect had no legal recipient when that occurs.
49. **Reserve:** Flag ward wasted to cap before committing a tempting route.
50. **Hold:** Add a best-route button; teaching a decision is preferable to making it.

### 51–60 · Rewards, events and economy
51. **Build:** Leave discovery unlock timing, pity, pricing and reward RNG independent of rank.
52. **Reserve:** Compare which reward decisions preceded strong recoveries in paired logs.
53. **Reserve:** Show how an evolution changes one current role before purchase.
54. **Reserve:** Add a named card-removal alternative to one repair-oriented event.
55. **Reserve:** Add a low-cost partial repair where a full repair is often wasted.
56. **Reserve:** Test a visible opportunity cost for replacing transition repair with an evolution.
57. **Reserve:** Identify events rarely seen in actual routes before authoring replacements.
58. **Reserve:** Add one event exposing the upcoming tradeoff rather than giving a free reward.
59. **Hold:** Guarantee an excellent reward after the first elite; keep drafting uncertain.
60. **Hold:** Remove unpopular choices based on the baseline bot alone.

### 61–70 · Encounters, content and variety
61. **Reserve:** Count enemy and event repeats on comparable route lengths.
62. **Reserve:** Test a second counterplay pattern for an overrepresented early roster.
63. **Reserve:** Vary mixed support/attacker pairings before inventing larger stats.
64. **Reserve:** Give rebuild-heavy groups a clearer interrupt teaching encounter.
65. **Reserve:** Compare guardian recoveries as genuine branches, not guaranteed safety.
66. **Reserve:** Add a memorable non-combat Glass Beyond encounter if route logs show a gap.
67. **Reserve:** Surface enemy memory notes after first contact, not before discovery.
68. **Reserve:** Create a cocoon-splitting challenge for players who already know the timer.
69. **Hold:** Add a fourth area before the three-area ladder is validated.
70. **Hold:** Replace authored encounters with blind procedural mixes.

### 71–80 · Audio comfort and cue meaning
71. **Trial:** Attenuate later overlapping cues in the identified turn-change family.
72. **Build:** Preserve the leading attack, shield catch and impact cue identities.
73. **Build:** Measure the actual title→map handoff as one recording.
74. **Build:** Audition vent and plasma repetition at 1×, separate from acceleration effects.
75. **Build:** Keep music, combat, interface and master sliders independent.
76. **Build:** Verify live bank swapping, mute/solo and cue highlighting still work.
77. **Reserve:** Add a soft-transient preset if listener preferences diverge consistently.
78. **Reserve:** Test a narrower spectral cut only after isolating the offending patch.
79. **Hold:** Add a blanket limiter or lower master volume based on one unclipped excerpt.
80. **Hold:** Normalize away the intended silence and contrast of the title and exploration.

### 81–90 · Practice, visible UI and accessibility
81. **Build:** Put rank and its actual rule in ship selection without hiding seed or ship controls.
82. **Build:** Show active rank in voyage, outcome and history so screenshots and logs make sense.
83. **Build:** Advertise visible rank selection through the existing revision-checked MCP actions.
84. **Reserve:** Add a board diagram showing what an interrupted turn protected.
85. **Reserve:** Offer a contained, non-saving past-turn practice scene after defeat.
86. **Reserve:** Let players reread the final incoming threats beside the defeat reason.
87. **Reserve:** Add text hints independent of sounds for important successful actions.
88. **Reserve:** Combine simultaneous secondary-hit labels in reduced motion.
89. **Reserve:** Add a short plain-language summary of the current area's tactical pressures.
90. **Hold:** Speed up all animations to mask lengthy fights; measure both problems separately.

### 91–100 · Verification, safeguards and delivery
91. **Build:** Freeze reviewed A0 outcomes and verify same inputs remain deterministic.
92. **Build:** Match A0 through A11 by seed, ship, profile and policy; use fresh isolated saves.
93. **Build:** Test both low-quality and tactical decisions across the ladder.
94. **Build:** Require a documented victory for every ship at every shipping rank.
95. **Build:** Check old saves during battle, pending choice and between areas.
96. **Build:** Report rank reach, hull, turns, outcomes, frame/audio caveats and timeouts separately.
97. **Build:** Audit headless rules, rendered UI and exported-app startup as separate claims.
98. **Reserve:** Capture a persistent in-game statistics panel after its measures prove useful.
99. **Hold:** Optimize tuning against a favorable handpicked seed or discard losing rows.
100. **Hold:** Publish a ranked update before closing its compatibility and winnability gates.

## Verification and delivery gates

1. **Rules and save/UI owner:** Add focused fixtures for unchanged A0, rank availability per ship, seeded/ordinary outcomes, duplicate completion, old-history backfill, A10→A11 and no A12, invalid saved ranks, and every pressure breakpoint (including turns 2/3/4/5/8/9, normal/elite/guardian and Area 1 exclusion). Check that every step adds actual pressure in at least one equal-state fixture and never lowers an equal-state attack. Verify hatchling and multi-enemy intents, visible/preview/commit damage parity with mitigation, Cocoon spawn/countdown/hatch/first attack, and old pending guards. Test save-title-resume and same-rank retry at low and high ranks. Extend blind MCP tests and real stdio integration; validate keyboard/focus and layout at both sizes including A10 and A11. Run `ASTRAL_AUDIO_DRIVER=Dummy bash tools/check.sh` and `python3 tests/mcp_integration.py --godot .tools/Godot.app/Contents/MacOS/Godot` (also visible for the new setup/history screen). Fresh save directories only. Validate A0 with stratified deterministic rows from the 720 capture; if A0 differs outside additive display/metadata, stop and diagnose before broadening the matrix.
2. **Balance owner:** Freeze engine, policy, modifier table, seeds and run fingerprints. On all three ships, use two calibration codes (fresh and full) and four disjoint held-out codes (two per tier) at ranks 0–11 with tactical and damage-first policies: **432 scheduled primary runs** for one full curve. Run the calibration first, inspecting A0/A3/A6/A9/A11 before filling in intermediate ranks. Also check tactical combat with no between-fight bonuses on the two calibration codes at those five checkpoints (30 extra runs). Keep rank out of seed/RNG initialization; select a winning route through visible choices only. Report per rank/ship wins, area reach, final and minimum positive hull, per-fight turns for all and comparable fights, diverged paths and unresolved rows. Use equal-state tests for mechanical monotonicity, not an assumption that every diverged voyage must have a worse outcome. Require a documented held-out tactical win **for each ship at every rank through A11**, no unexplained new damage-first wins against paired A0, and no state/forecast regressions. Report whether matched trajectories actually got more demanding at the checkpoints, without inferring human win rates. Retune failed bands on calibration first; if results from holdouts have already been seen, predeclare fresh holdouts and rerun changed ranks plus adjacent boundaries and A11 on that matched set. If only Palimpsest fails, prefer softening rank pressure before a standalone funded-Redact trial; no change to Palimpsest at A0.
3. **Live verification owner:** On the final candidate, finish one isolated blind A11 voyage using an eligible test profile. Separately verify ordinary A10→A11 unlock and the A11 cap through the real completion path in a controlled fixture; check seeded completion gives no unlock and verify final-rank selection and save/resume through the live UI. Compare a normal-speed attack and Cocoon countdown with committed results, and record accelerated portions if used. No reroll to select a successful live outcome; the held-out rules wins are a separate gate. Verify the exported app with its own isolated saves, checksum, startup and rank metadata; do not install, publish or alter the user's profiles.
4. **Audio owner:** Compare the same scripted visible actions and alignment across baseline/candidate, at normal defaults and max configured settings. Report integrated loudness, true/sample peak, clipping and short-band energy at the flagged spot; target at least 2 dB lower local peak in the identified overlap at default settings without materially changing the isolated first cue or map loudness. Flag baseline overload if stress tests find it; don't quietly fix a broader mix in this pass. Include playback-level caveats and a blind A/B listening check at a comfortable level. Neither a short capture nor no clipping equals universal comfort. If treatment misses the mechanical or listening gate, keep the audio unchanged.
5. **Handoff:** Deliver a new versioned macOS playtest ZIP, concise change log, rank-by-ship results and reproducible cases, and paired lossless listening excerpts in the existing playtest Inbox. Preserve prior playable and composer artifacts. Identify rejected trials explicitly; no push/merge or silent change to the previous build. Begin work only after this plan is approved.