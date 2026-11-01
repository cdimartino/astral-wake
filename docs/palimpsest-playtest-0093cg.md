# Palimpsest evolutions: primary manual rules test

Limited first-ship-content merge evidence, not proof that all 18 sibling pairs are
balanced. Decisions were reported as manually selected through the guarded
headless driver, without policy planning or audit draw-order exposure. A journal
can verify actions, not independently prove the player's decision process. This
was not a graphical expedition, optimal-play demonstration or win-rate estimate.

## Reproduction and outcome

- Frozen revision: `1c93f93`; code `0093CG`, Palimpsest, profile/pool 0, region IDs 2/4/1.
- Genuine defeat in encounter 20: 19 wins and two guardians defeated, 284 card
  plays, 78 end turns, 445 successful commands and eight rejected inputs.
- Final hull 0/96, salvage 3; minimum positive committed hull 7.
- Lead replay verified every successful command and rejection in fresh scratch.
- Final state hash, step 453:
  `cc4f1c41e7f15892446632481554a93868398fe51a3f3998acafaf10f31ce0c4`.
- Trace SHA-256:
  `8220eca79fbe846417a7a73d996f719fcb3e360dd8e6b32a726fb4667f0a8e06`.

[All encounter forecasts, selections and final report](https://github.com/cdimartino/astral-wake/pull/41#issuecomment-6553701552)
are public on PR #41. Local `narrative.md`, `summary.json`, `actualtrace.json` and
checkpoint files remain in `palimpsest-evolutions-primary-1c93f93` under the approved
OpenCode temporary folder. The primary was not restarted or replaced.

## Mechanically legible defeat

Final-turn repair totaled 32, raising hull from 7 to 39. Remaining attacks dealt
21 + 18 = 39, exactly lethal. Scar copied four disruption from Struck Paragraph's
printed eight, not its routed eleven; the later Patch copied four repair from
Scar's printed eight. Patient Heart does not pay on defeat.

An earlier Woven Memory attack calculation was a legal tactical mistake: powerup
bonuses applied before organ-created damage cannot apply retroactively. Correcting
that one mistake is not proven sufficient to win. The eight rejected commands
(four connection, three capacity, one stale target) preserved gameplay state;
they were not eight corruptions or audit failures.

## Branch coverage and attribution limits

Seven alternatives were played: Inscribed Margin 27 times, Deferred Overwrite 19,
Cool Carbon 2, Piercing Revision 14, Silencing Sentence 11, Woven Memory 14 and
Struck Paragraph 1; 196 plays used base cards. Three upgrades cost 35 salvage
each and four were free recovery upgrades. All preserved explicit UID/branch
identity, effective printed-copy payload and Trace bounds 0–6.

Only 7 of 36 alternatives were played; neither Blank Page sibling was acquired,
and the final guardian was not reached. Strong shared powerups, avoided elites,
and tactical/input mistakes limit evolution-specific attribution. This defeat and
the Cartographer victory do not establish relative ship viability or justify
reducing challenge. Native workshop inspection was a separate cancelled recovery
counterfactual at both supported window sizes, not graphical expedition evidence.

Independent assessment passed this limited merge gate without requesting another
run or a balance change. Code review, CI and exact replay are separate gates.

## Preserved follow-ups

Actual wounded-recovery checkpoints remain intact: step 41 at hull 76 selected
20 actual repair; step 367 at hull 57 selected 30. Any later upgrade/sibling arms
must be separately labelled counterfactuals. None were performed for this report.
