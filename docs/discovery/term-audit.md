# Term audit and proposed glossary (Q6 draft)

Status: draft for review. Nothing here is implemented. Renames change catalog text and tests, so they wait for the comprehension check (`comprehension-check.md`) unless the owner decides otherwise.

Sources: `data/catalog.json` (organ and card text), `docs/gameplay.md` (glossary at the "Terms" table, and body text).

## 1. Terms already defined in the guide

These have glossary entries. The problem is visibility in play, not missing docs. Fix with tooltips and the in-game glossary.

| Term | Guide status | Action |
| --- | --- | --- |
| Disruption | Glossary and body text | Keep name. Add an in-game tooltip with the shared cap in one sentence. |
| Redirection | Glossary | Keep name. Tooltip only. |
| Strain / capacity | Glossary | Keep. |
| Vent / cooling | Glossary | Keep. |
| Link / sever | Glossary | Keep. |
| Trace | Glossary | Keep. |
| Resonance | Glossary | Keep. |
| Ward | Glossary | Keep. |
| Split damage | Glossary | Keep. Organ text should say "split damage", not "divide", for the Fork (see section 3). |

## 2. Terms used in play but missing from the glossary

Proposed entries (plain-language, one line each):

| Term | Where it appears | Proposed glossary entry |
| --- | --- | --- |
| Enemy phase | Enemy intention text; guide body | After you end your turn: enemies act, organs cool, and you draw for the next turn. |
| Overload | Enemy intent (e.g. Ash Cantor's Cough) | Extra damage per saturated (full) organ when the attack lands. |
| Interrupt / threshold | Interruptible enemy actions | Meet the shown disruption during that turn to cancel the action. |
| Mark | Enemy intent ("repeated route costs hull") | A penalty for repeating your last exact route. |
| Saturated / full | Organs at capacity | An organ at capacity. It cannot take another command until it cools. |
| Resource gate (Splice, Chorus) | Organ text: "at 2 or more Trace / Resonance" | Splits damage only at the stated resource amount; otherwise adds a small bonus. |

## 3. Organ names and verbs

Some organ verbs do not describe what the organ does. Candidates to change, with reasons:

| Organ | Current verb | Issue | Candidate |
| --- | --- | --- | --- |
| The Fork | "Divide" | Says nothing about damage | "Split" (matches the glossary term) |
| The Hush | "Silence" | Reads as "remove" or "mute" | "Dampen" (adds disruption) |
| The Prism | "Refract" | Accurate but unfamiliar | Keep; the description explains it |
| Echo (Cartographer) | "Resound" | Vague | "Amplify" |
| Recall (Palimpsest) | "Recall" | Matches the card name, so organ and card read the same | Keep if the organ is "Recall"; rename the card if the two must differ |
| Rest (Choir) | "Breathe" | "Rest" also reads as a turn action | Rename to "Settle" or similar |

## 4. Consistency issues

- "Disrupt" appears as a noun in the preview strip ("Disrupt: ...") and as "disruption" in the guide. Use "Disruption" everywhere.
- Organ text uses "add" and "gain" for the same mechanic in different places. Pick one per kind (resource gained = "gain"; damage or healing added = "add").
- Card names double as organ names (Recall, Scribe, Splice). Renaming either side should be done once for both.

## 5. What not to change

- Keep the Q/W/E/R/T/Y routing keys and the ring layout until the spike and comprehension results are in.
- Keep the splitter mechanic. The owner chose it; only its text may change.

## Proposed next steps

1. Owner review of sections 2–3.
2. If the comprehension check (R1 scores) shows a problem, implement the approved renames and glossary entries in a single change touching `data/catalog.json`, `docs/gameplay.md`, and UI tooltips. Run `bash tools/check.sh` and the content validator.
