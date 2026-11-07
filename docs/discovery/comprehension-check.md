# Comprehension check: organs, routing, and terms

Purpose: test hypotheses H1 and H4 from `organ-legibility-brief.md` before any engine or UI change. Owner decision Q7 ("both"): this is the playtest-build half. The wider beta is in `beta-feedback-form.md`.

## Participants

- Five people who have never played Astral Wake. Exclude anyone who saw the Cody feedback or the guide.
- Record each participant's ID (P1–P5), not their name.

## Build

- The current build (no reduced start). Do not change the game for this session.
- Start each session with the Cartographer, the "Choose your vessel" screen, and the opening encounter, unaided.

## Protocol (about 30 minutes)

1. **Unaided play (15 min).** Ask the participant to play the opening encounter and the first battle. Do not explain organs, Disrupt, or Strain. Note every question they ask, and every time they hover a tooltip or the guide.
2. **Recall questions (5 min).** Ask each question below without showing the screen. Record the answer verbatim. Score against the rubric.
3. **Routing task (5 min).** Show a board with a hand card and ask the participant to choose a route and target. Note the route they choose and the reason they give.
4. **Think-aloud on Disrupt (5 min).** Show the Disrupt term in a preview and ask what it does. Record the verbatim answer.

## Recall questions and rubric

Score 2 = correct and specific, 1 = partly right, 0 = wrong or "don't know".

| # | Question | Correct answer (score 2) |
| --- | --- | --- |
| R1 | What does Disruption do? | Reduces an enemy's next attack. Shared cap: disruption plus redirection prevent at most half the attack. Expires after the enemy phase. |
| R2 | What does Strain do? | An organ's load. At capacity it cannot be used until it cools. |
| R3 | What happens if you route through the same organ twice? | It is not allowed. Each organ appears at most once. |
| R4 | What does Trace do (Palimpsest)? | A resource gained by Scribe and spent by Recall or Rewrite. |
| R5 | What does Resonance do (Hollow Choir)? | Builds when you change command kind; spent by Crescendo, Cadence, or Concert. |
| R6 | Which organ splits damage on the Cartographer? | Fork (half damage to every other enemy). |
| R7 | What does a splitter do on the Palimpsest when you have fewer than 2 Trace? | It adds +2 damage instead of splitting (Splice). |

Interpretation: R7 tests the splitter's resource gate, which the brief flags as one extra term per ship.

## Routing task

Board: a Cartographer battle with a hand card that deals damage, with the Lens, Fork and Echo organs unlocked (Lens–Fork–Echo path).

- Ask: "Which organs would you route this card through, and why?"
- Record: the route chosen, whether it was legal, and whether the stated reason matches the game's effect.
- Count the attempts it took to get a legal route.

## Measures

For each participant:
- Recall score out of 14 (R1–R7 × 2).
- Routing: legal first attempt (yes/no), number of attempts.
- Questions asked during unaided play, grouped by term.
- Time to the first routed command.

## Decision rule (proposed, for the owner)

- If the median recall score is at least 10 of 14 and at least 4 of 5 participants answer R1 with score 2, the current terms are adequate and the Q6 renames can be limited to Disrupt and Redirect.
- If R1 scores are below 2 for three or more participants, Q6 renames and the glossary entry for Disruption are a priority.
- Five participants is a small sample. Treat results as a signal, not a measurement.

## Output

Write results to `docs/discovery/comprehension-results.md` with the participant table, quotes, and the decision-rule outcome.
