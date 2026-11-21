# Paired balance experiments (headless Godot rules)

This experiment compares **two independent one-rule changes** against one frozen control. A is Palimpsest's +3 primary-only damage from an exactly-six-Trace damaging Recall; B is the Hollow Choir **card** Crescendo's +4 on a three-point Concert spend. The patches do not compose in these runs.

## Recorded evidence

The 112 official pairs contain 3,522 fights. A left legacy tactical Palimpsest at **1/6**; the modern fresh tactical gain (3/8→4/8) and full balanced loss (1/8→0/8) occurred in different strata. Switching A on only at the original loss rescued **one of ten** selected encounters, full tactical 0420OB, without converting that expedition into a victory. B's tactical matched medians were **8→8 legacy, 7→7 fresh and 8→8 full**: no stratum met the −15% tempo criterion. Its full tactical win gain (6/8→7/8) did not rescue the original loss when replayed from its exact entry.

- [Official comparisons](evidence/official.md) and [exact-entry loss replays](evidence/exact-entry.json); [portable raw official archive](evidence/official.jsonl.gz) also includes the calibration, negative controls, the 48 normalized original review terminals, and both original engine pilot logs.
- Diagnostic [splash-corrected policy](evidence/splashfix.md) and [bounded two-command policy](evidence/visible2.md); [portable diagnostic archive](evidence/diagnostics.jsonl.gz).

To validate delivered files without Godot or original scratch directories:

```sh
python3 tools/balance_update/archive.py audit tools/balance_update/evidence/official.jsonl.gz
python3 tools/balance_update/archive.py audit tools/balance_update/evidence/diagnostics.jsonl.gz
```

## Reproduce the input snapshots

Requires Python 3, Git with object `97df64187053f44307d6fb2e8c23e8c593abac82`, and the repository's pinned Godot 4.7.2. Run from the project root with a **new** scratch directory. No profile is read from the player's save location.

```sh
T=tools/balance_update
S="$(mktemp -d)/balance"
GODOT="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
python3 "$T/prepare.py" "$S"
python3 "$T/run.py" --scratch "$S" --engine "$GODOT" --out official --jobs 4
python3 "$T/analyze.py" "$S/experiment/official" --strict --output "$S/official.json"
```

`prepare.py` archives only the full rules dependency read set, catalog, frozen playthrough, and project configuration. It creates three separate Godot project roots and applies exactly `trial-a.patch` or `trial-b.patch` to the respective copies. These are rules projects, not runnable UI builds. No balance patch is installed into the working game. The runner checks SHA-256 values up front and again at completion, saves a frozen copy of the external observer, checks each result's encoded pool/profile/options and combat accounting, and requires a complete set of terminal rows. Default engine location is macOS-specific; `--engine` accepts an explicit path. Keep normal Python assertions enabled.

The archived original 72-case review, if available, can optionally be supplied as `analyze.py --prior /path/to/review` (the directory containing `matrix.jsonl` and `middle.jsonl`). Verification compares every deterministic terminal field, including deck/evolutions, itinerary, checkpoints, actions and options. The main experiment reruns every affected case to obtain fight telemetry; it does not impute unobserved fights from older rows.

## Design and measurements

- See **design.json** for the precommitted codes: six historical numeric seeds × both affected ships × four original policies, and eight new families per fresh/full tier × both ships × balanced/tactical. Each case has one control and one ship-specific trial: **112 pairs / 224 runs**. Numeric and six-character seed APIs differ; fresh/full codes use disjoint families beyond the published 0–29 and encode their own tier. Legacy starts at profile tier zero. Starter-only is **tactical plus `--no-bonuses`**, not balanced.
- Main scorer is the exact inherited `tests/playthrough.gd` planner. It scores map, combat, reward, recovery, event, shops and evolution decisions. `observer.gd` observes its actual choice, then inspects only visible pre-action inputs and committed outcomes. It neither changes the policy's target-kill heuristic nor selects from future draws. All rows use the same external script on their own `--path`.
- One fight is identified by seed/ship/policy, region, region identity, node, kind and **ordered opening enemy IDs+HP**. A missing fight is not a zero-turn fight. We report all-fight medians, matched medians (also both-clear subset), within-pair changes and Area 3 separately. “Turns” = final active one-based player turn; “end_turns” = enemy phases actually resolved; the latter sum to the official run total. Relative gate: at least **15% lower median turns** on matched fights. Medians of two samples and the median of paired differences/ratios are reported separately.
- Minimum hull includes actual per-hit dips before repair/emergency; end-of-run hull is not a substitute. Counters include gross Trace/Resonance spent by organ and card, applied healing/ward, damage absorbed/disrupted/redirected, interrupts, exact threshold plays, and the eligible marginal damage after armor, splash and target-HP clipping. Each qualifying command checks the reconstructed applied primary/aggregate against the actual commit. Bonuses that cross lethal are target kills, not automatic evidence a lost battle was rescued.
- Crescendo reward offers/picks count reward screens only. Opening cards and actual in-combat draw events count toward draws (a retained card is not a redraw); plays and full spends count only the specific owned card, distinct from the organ and other Concert cards. Event grants, if any, can yield draws without a reward pick.
- Row reports distinguish losses revisited, losses bypassed, different-entry clears and opposite terminal outcomes. A win from different earlier choices does not establish the original losing encounter was rescued. Exact-entry replays below compare all previous fights including action hashes and visible opening-state signatures before allowing the trial to turn on.

## Optional diagnostic policies — never pool with official rows

```sh
python3 "$T/diagnostic.py" "$S"
python3 "$T/auxiliary.py" "$S"
E="$S/experiment"
python3 "$T/run.py" --scratch "$S" --engine "$GODOT" --observer "$E/diagnostic.gd" --cases "$E/splashfix-cases.json" --out splashfix --jobs 3
python3 "$T/run.py" --scratch "$S" --engine "$GODOT" --observer "$E/diagnostic.gd" --cases "$E/visible2-bounded.json" --out visible2 --jobs 3
python3 "$T/run.py" --scratch "$S" --engine "$GODOT" --observer "$E/calibration.gd" --cases "$E/calibration-cases.json" --out calibration --jobs 2
python3 "$T/run.py" --scratch "$S" --engine "$GODOT" --cases "$E/sentinel-cases.json" --out sentinel --jobs 2
python3 "$T/rescue.py" "$E/official" --output "$E/exact-cases.json"
python3 "$T/run.py" --scratch "$S" --engine "$GODOT" --cases "$E/exact-cases.json" --out exact --jobs 3
python3 "$T/rescue.py" "$E/official" --verify "$E/exact" --output "$S/rescue.json"
```

`splashfix` awards the existing +12 kill term only if actual primary damage kills the selected foe. `visible2` uses that scorer and considers two committed commands from the **currently visible hand**: up to three first actions (best immediate, largest resource bank, best differently indexed card), then the best legal second action discounted to 80%; encounter finishes get a large terminal bonus. It re-plans after real commits. The model copies public tactical inputs, supplies an empty draw pile, overrides drawing to do nothing and receives no random stream or seed. Printed draw value remains part of the inherited utility calculation. It gives no credit for guessed future cards. Beam limits and heuristic values mean this is diagnostic, not optimal play.

Both diagnostics use tactical behavior elsewhere; splashfix covers six legacy seeds plus the first fresh/full pair per ship, visible2's bounded subset covers the first two legacy seeds plus the first fresh/full seed per ship. Calibration restores the original incorrect kill condition in that same one-command visible model; compare terminal summaries and every fight against official cold pilots. Negative-control sentinels execute all three Cartographer arms and nonmatching Palimpsest/Choir arms on one damage-only seed; other unaffected cases are identical by guard scope, not extra played observations.

## Portable evidence

```sh
python3 "$T/archive.py" pack "$S/raw-evidence.jsonl.gz" "$E/official" "$E/splashfix" "$E/visible2" "$E/calibration" "$E/sentinel" "$E/exact"
python3 "$T/archive.py" audit "$S/raw-evidence.jsonl.gz" --summary "$S/recomputed.json"
python3 "$T/test_tools.py"
```

The gzip JSONL holds manifest, scorer source and SHA, each deterministic raw row, normalized actual argv and required environment, and complete engine logs with the local save path replaced. It includes no saves, draw order, RNG state, local path, or credentials. Audit re-parses the logs, checks arm/option/fight accounting and computes the paired summaries without a Godot install. Exit timing and wall seconds are descriptive, never balance metrics. Seeded policy runs are not live MCP playthroughs or human success estimates.
