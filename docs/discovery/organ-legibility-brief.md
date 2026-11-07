# Opportunity brief: organ and routing legibility

Status: evidence gathered; hypotheses drafted for review, none adopted. Owner: product discovery. Date: 2026-11-07.

## Summary

The organ and routing system is the game's identity, but a new player must decode it before making a useful choice. Evidence shows:

1. **Vocabulary is larger than the guide's glossary.** The catalog uses about 55 mechanical or organ terms. The guide defines about 30 of them. Several frequent terms have no glossary entry (see Term inventory).
2. **Organs are uneven in use.** The simulator uses every organ, but some are rarely routed (Prism 2.6–4.2% of organ-steps, Cadence 6.6–9.5%, Palimend 6.5–11.6%). Those organs are candidates for merging or cutting, but usage by a heuristic bot is not evidence of player comprehension.
3. **Routes are short in practice.** Single-organ routes make up 22–43% of played commands; three-organ routes 40–68%. This matters for the proposed 2–3 organ start (see Risks).
4. **Cody's confusion is about Disrupt.** He guessed it lowers enemy damage. The guide defines it with a shared defense cap, so the gap is in-game surfacing and terminology, not missing documentation. We did not verify the in-game tooltip text.
5. **The six-organ count is hardcoded in about a dozen places**, across rules, save validation, and UI.

## Evidence

### Organ inventory (from `data/catalog.json`, `docs/ships.md`)

18 organ types: six per ship. Each ship has its own graph (`data/catalog.json`, `edges`):

| Ship | Organs (route index 0–5) | Edges |
| --- | --- | --- |
| Cartographer | lens, fork, echo, mend (Suture), hush, prism | ring + 3 cross-links |
| Palimpsest | scribe, splice, recall, palimend, redact, rewrite | ring + 3 chords |
| Hollow Choir | conductor, chorus, crescendo, rest, dissonance, cadence | ring + 3 chords |

### Organ usage (simulator, 60 runs)

Source: `docs/discovery/organ-usage-runs.json`, produced by `tests/discovery/organ_usage.gd`, aggregated by `tests/discovery/aggregate_organ_usage.py`. Ten seeds (1–10) per ship and policy, balanced and tactical, defeats allowed. Share is of organ-steps.

| Ship / policy | Runs wins | Organ usage (share of organ-steps) | Route length 1 / 2 / 3 |
| --- | --- | --- | --- |
| Cartographer / balanced | 5/10 | Echo 32.0, Lens 24.8, Fork 17.2, Suture 16.9, Hush 6.5, Prism 2.6 | 28 / 5 / 67% |
| Cartographer / tactical | 8/10 | Echo 31.7, Suture 20.1, Lens 18.8, Fork 14.6, Hush 10.5, Prism 4.2 | 26 / 10 / 64% |
| Palimpsest / balanced | 1/10 | Scribe 29.8, Splice 20.6, Recall 17.6, Redact 13.5, Rewrite 12.0, Palimend 6.5 | 22 / 10 / 68% |
| Palimpsest / tactical | 5/10 | Scribe 28.4, Splice 17.6, Recall 16.0, Redact 16.2, Palimend 11.6, Rewrite 10.2 | 29 / 8 / 62% |
| Hollow Choir / balanced | 5/10 | Crescendo 25.0, Dissonance 19.5, Chorus 18.1, Rest 16.8, Conductor 14.1, Cadence 6.6 | 40 / 14 / 46% |
| Hollow Choir / tactical | 9/10 | Crescendo 25.1, Dissonance 21.8, Rest 19.8, Chorus 14.2, Cadence 9.5, Conductor 9.6 | 43 / 17 / 40% |

Limits:
- The bot picks routes with a fixed scoring function (`tests/playthrough.gd`). Usage reflects the scoring, not human choice.
- Ten seeds per cell. Treat differences under about 5 points as noise.
- Win rates are not balance evidence; see #22.

### Term inventory

Method: keyword search across all 549 catalog text fields (`description`, `name`, `verb`), and comparison with terms defined in `docs/gameplay.md`. Counts are regex matches, so they are approximate.

Terms used most in the catalog, with glossary status:

| Term | Catalog uses | Defined in guide glossary? |
| --- | ---: | --- |
| Trace | 48 | Yes |
| Cool / cooling | 37 | Explained in body text, not a glossary entry |
| Disrupt / disruption | 26 | Yes |
| Link / sever / severed | 58 combined | Yes (Sever) |
| Resonance | 23 | Yes |
| Strain | 17 | Yes |
| Enemy phase | 12 | Used in guide body text, no glossary entry |
| Rewrite | 8 | Organ table only |
| Echo, Lens, Fork, Suture, Hush, Prism | 3–7 each | Organ table only |
| Concert, Crescendo, Cadence, Conductor, Chorus, Dissonance | 3–6 each | Organ table only |
| Redirect / redirection | 4 | Yes |
| Thorn, Bloom | 6, 2 | No (enemy names) |
| Recall, Scribe, Splice, Redact, Palimend | 1–4 each | Organ table only |
| Overload, interrupt, memory, margin, blank | 1 each | No |

Observations:
- Terms defined only in an organ table are visible only while hovering the organ, not in the glossary.
- "Rest" appears as both a card name and a plain verb in text, which may confuse matching.
- "Enemy phase" and "Overload" are game concepts with no glossary entry.

### Engine and UI coupling

Places that assume six organs (`grep` of `scripts/`):
- Rules: `scripts/game.gd:258` (strain array of 6), `:294` (`node >= 6` validation), `:470` and `:686` (loops over 6), `:642` (strain targets), `:1064` and `:1086` (save validation requires 6).
- UI: `scripts/main.gd:17–18` (keys Q W E R T Y), `:666`, `:708`, `:734`, `:744`, `:988` (six-slot layout and forecast arrays), `scripts/organ_circuit.gd:7` (fixed `POSITIONS` for six nodes).
- Tests: `tests/organ_routing_test.gd` (six-organ loops).

Spike estimate (rough, not measured): the rules change is contained, around 8 edits plus save migration. The UI change touches the console layout, key bindings, and anatomy view. Expect one to two days of focused work for the rules and saves, plus UI design time. Treat this as an order-of-magnitude guess until a real spike.

## Route-space spike (H3 result)

Script: `tests/discovery/route_spike.py`. It enumerates legal routes under the engine's rule (distinct organs, consecutive organs joined by an open edge). It ignores strain, enemies, and capacity, so it measures only the route space.

| Organ set | Max route length | Legal routes | By length (1/2/3) | Distinct organ sets |
| --- | --- | ---: | --- | ---: |
| Two organs (one edge) | 2 | 4 | 2 / 2 | 3 |
| Three-organ ring | 3 (current) | 15 | 3 / 6 / 6 | 7 |
| Three-organ ring | 2 (Q2 answer) | 9 | 3 / 6 | 6 |
| Cartographer first three (Lens, Fork, Echo) | 2 | 7 | 3 / 4 | 5 |
| Cartographer first three | 3 | 9 | 3 / 4 / 2 | 6 |
| Full six-organ ship | 3 (current) | 60–66 | | 28–33 |
| Full six-organ ship | 2 | 24 | 6 / 18 | 15 |

Findings:
- The Q2 cap of two cuts a three-organ ring from 15 routes to 9 (about 40%).
- A two-organ start has four legal routes under either rule. That is very thin for a deck-building game.
- A three-organ start with the current three-organ rule keeps 15 routes, about a quarter of the full ship.
- The spike does not test strain, capacity, enemy pressure, or the real validator in Godot. It is a route-count measure only.

Implication: the owner's Q2 answer (cap at two) and the Q3 direction ("one core organ plus one or two others") together imply a two-organ start for some ships, which this spike rates as not viable. Decision needed: minimum starting organs (three, not two), and whether the cap stays at two for a three-organ start. Reported in Inbox thread msg_01M6VM4PZ42HAC35G8FPSGNSAV.

## Hypotheses (drafted for review, not adopted)

H1. A three-term glossary surfaced in the UI (Disrupt, Strain, Trace) would let a new player describe what Disrupt does after the first encounter. *Test:* a comprehension check with new players (not yet available).

H2. Organs routed in under about 7% of steps under the balanced policy (Prism 2.6%, Hush 6.5%, Palimend 6.5%, Cadence 6.6%) are candidates for merging. Tactical runs show Palimend and Cadence higher (11.6% and 9.5%), so the signal is policy-sensitive. *Test:* compare win rates with and without each organ in the simulator; check for sensitivity to the policy.

H3. Starting with 2–3 organs would make routing a sequence choice rather than a set choice. With the current 1–3 organ route rule, three organs means every route can use all of them. *Test:* simulate a three-organ ring and count distinct legal routes.

H4. Keyword tooltips alone will not fix comprehension if terms also differ across ships (for example, Trace versus Resonance versus Recall). *Test:* a term audit with real players.

## Risks

- **Route space with 2–3 organs.** The current route rule (one to three distinct organs, following connections) means a three-organ ring offers few distinct routes. The change may need a different route rule, and that is a design decision, not a UI change. (H3)
- **1.0 scope.** Engine and UI work for variable organ counts competes with #14–#22 and with the save reliability issue (#47).
- **Save compatibility.** Battle state stores six strain slots; saves need a migration path.
- **Evidence.** The usage data comes from a heuristic bot. The only human playtest is one player.

## Decisions (answered 2026-11-07 in Inbox thread msg_01M6VM4PZ42HAC35G8FPSGNSAV)

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Does the reduced 2–3 organ start ship in 1.0? | Commit to 1.0 now. Note: the route spike (H3) has not run; it is the first engineering task and gates Q2's implementation. |
| Q2 | Route rule with 2–3 organs? | **Revised 2026-11-07:** the two-organ cap is withdrawn. Routes allow three organs (the current rule). Supersedes the earlier answer. |
| Q3 | Starting organs per ship? | **Revised:** minimum three organs per ship. One core organ is shared across all ships, plus two distinct organs per ship. Core organ not yet chosen. |
| Q4 | What unlocks organs in-run? | Bosses, elites, and shops. |
| Q5 | Low-usage organs (Prism, Hush, Cadence, Palimend)? | Keep until playtests confirm the signal. |
| Q6 | Fixing confusing terms? | Combine: rename the worst, add an in-game glossary, improve tooltips. |
| Q7 | Comprehension data before 1.0? | Both: a short comprehension check in a playtest build, and a wider beta with feedback forms. |
| Q8 | Existing saves? | Migrate saves. |

Core-role options (per-ship core with a shared role), from `data/catalog.json` organ text:

| Shared role | Cartographer | Palimpsest | Hollow Choir | Usage (balanced / tactical) |
| --- | --- | --- | --- | --- |
| Splitter (damage to other enemies) | Fork: half damage to every other enemy | Splice: at 2+ Trace, split at half; else +2 damage | Chorus: at 2+ Resonance, split at half; else +1 damage | Fork 17.2 / 14.6%; Splice 20.6 / 17.6%; Chorus 18.1 / 14.2% |
| Disruptor (defense) | Hush: +2 disruption | Redact: 1–3 disruption, costs Trace | Dissonance: 1 + Resonance disruption | Hush 6.5 / 10.5%; Redact 13.5 / 16.2%; Dissonance 19.5 / 21.8% |

Recommended shared role: splitter. The three organs are the most-routed in their ships, so a splitter core anchors each ship's identity. The cost: Splice and Chorus add a resource gate that Fork does not have, which is one more term to teach. Disruptor is the alternative, but Hush is the least-routed Cartographer organ.

Splitter confirmed by owner (Inbox, 2026-11-07). Draft starting sets for review (not adopted):

| Ship | Core (splitter) | Distinct organ 1 | Distinct organ 2 | Shape of start | Legal routes (max 3) |
| --- | --- | --- | --- | --- | ---: |
| Cartographer | Fork | Lens | Echo | Path: Lens–Fork–Echo (Lens and Echo not directly linked) | 9 |
| Palimpsest | Splice | Scribe (generates Trace) | Recall (spends Trace for damage) | Triangle: every pair linked | 15 |
| Hollow Choir | Chorus | Conductor (generates Resonance) | Cadence (spends Resonance for ward) | Triangle: every pair linked | 15 |

Notes on the draft:
- The Cartographer's first attacking route in the guide is Lens, then Fork, then Echo. This start keeps that route.
- The Palimpsest and Hollow Choir starts form triangles, so routes have the most freedom. Each includes a generator, a splitter, and a spender, a loop the owner can teach in one sentence.
- Open risk: the splitter's resource gate (Splice at 2+ Trace; Chorus at 2+ Resonance) competes with the spender for the same resource. The comprehension check should test it.
- The other three organs per ship stay in the unlock pool (bosses, elites, shops). Unlock order is not yet designed.

Deferred until after testing (owner, 2026-11-07): (a) whether the splitter and spender should compete for the same resource on Palimpsest and Hollow Choir; (b) unlock order for the three non-starting organs per ship.

Answered 2026-11-07 (Inbox thread msg_01M6VM4PZ42HAC35G8FPSGNSAV):
- Comprehension check: run with the beta build, not now (defer).
- Term fixes: start everything now (renames, glossary entries, tooltips, in-game glossary). In progress.

Drafted artifacts (not implemented):
- `comprehension-check.md`: five-player protocol, recall rubric, decision rule (Q7).
- `term-audit.md`: missing glossary entries, organ verb candidates, consistency issues (Q6).
- `beta-feedback-form.md`: wider beta questionnaire (Q7).

Open items: Q2 interpretation (confirm with owner); per-ship starting organ picks (Q3); a spike result for H3 before committing the route design.

## Next steps

1. Run the three-organ route spike (H3) before committing to the scope.
2. Run a term-comprehension check with at least five new players when a build is available.
3. Decide on low-usage organs after the spike and any playtest.
