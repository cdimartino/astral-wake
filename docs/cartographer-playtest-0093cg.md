# Cartographer evolutions: primary manual rules test

This is limited first-ship merge evidence, not proof that all 36 evolution pairs
are balanced. Every gameplay decision was manually selected through the guarded
headless driver; this was not a graphical expedition or automated policy run.

## Reproduction and outcome

- Frozen revision: `e76a85a83f858e2730d804020f6c26f12050596d`.
- Practice code `0093CG`, Cartographer, profile/discovery pool 0; region IDs 2/4/1.
- Genuine victory: 22 encounters, 52 end turns / 74 player turns, final guardian
  defeated on player turn 10. Minimum committed hull 37; final hull 100/100,
  salvage 120, 16 cards, 11 explicitly evolved copies.
- Lead replay verified all 368 successful commands and one preserved capacity
  rejection in a fresh session, with the identical final rules-state hash.
- Final state hash: `4f6e19746cf40ef4ce1b585bceefcdcfef33d373cf22e00939d4088a40f25e5c`.
- Trace SHA-256: `da23182c06131069ab5635a1f2741a9ad5fc899af83986a185d31d081074570d`.

[Encounter forecasts, all selections, completion reports and final assessment](https://github.com/cdimartino/astral-wake/pull/40#issuecomment-6552767981)
are published on PR #40. Local `trace.json`, `narrative.md`, `summary.json`, and
the step-134 checkpoint remain under the session directory
`cartographer-evolutions-primary-e76a85a` in the approved OpenCode temporary folder.
The original primary was not restarted, edited or replaced.

## Supported findings

- Still Pulse crossed interruption thresholds its damage sibling would miss.
- Cooling branches reopened legal organ routes; Brief Refrain changed CP sequencing.
- Hybrid damage/repair and concentrated healing supported recovery under pressure.
- Repair remained meaningful: the player selected 23 actual repair at hull 77
  instead of taking another evolution.
- Native production workshop comparisons were separately inspected at 1440×900
  and 1100×720. Small-window Cold Breath choices require vertical scrolling.

## Attribution and coverage limits

- One practiced seed, one ship and one itinerary are not a win-rate estimate.
- An initial transport-formatting error exposed an audit draw-order field once.
  The player disclosed not using it and corrected filtering; that disclosure is
  not independently provable. This was **not a clean blinded information trial**.
- All elites were avoided. Amber Sight, First Light, Pilgrim Spine, Wide Lung,
  Patient Heart and Soft Copper confound evolution-specific attribution.
- No Exhaust evolution was played. Retain superiority and the extra disruption
  from Deafening Noise remain unestablished.
- Routed repair is not the evolution's isolated contribution: Closed Wound's
  observed 24 repair includes powerup/organ effects; its sibling yields 19 on
  that same uncapped route. One 9-repair result includes 7 command repair plus
  2 after-combat Patient Heart repair.

Independent evidence review passed this limited merge gate; it did not recommend
blanket enemy nerfs, a forced-win target, or declaring all pairs balanced.

## Follow-up experiments

Preserve the primary. From its pre-choice step-134 recovery checkpoint at hull 85,
compare separately labelled repair (+15 actual hull), UID 12 Kind Reflection, and
UID 12 Cruel Reflection continuations through the next two encounters. Record
minimum hull, enemy phases, capped repair, kill timing and CP use. A later Deep
Breath / Last Breath guardian comparison should measure Exhaust's lost future
circulation. These are follow-ups, not counterfactual results already obtained.
