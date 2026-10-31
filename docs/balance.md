# Difficulty tuning

## Pressure and counterplay

- Attacks deal 1.6 times their normalized authored damage, rounded up. Area strength is now 1.0 / 1.4 / 1.8 instead of 1.0 / 1.3 / 1.6. Legacy geographic scaling is removed before applying the expedition's area strength.
- Each attack gains another point for every four elapsed combat turns. This discourages indefinite repair farming; the complete amount appears in the next intent and uses the same preview/resolution path.
- Opening-area enemy hull is unchanged. The main pressure comes from surviving enemy phases rather than longer health bars.
- Mute Bell, White Noise, Lost Paragraph, Tuning Fork and Hushed Chord have twice their previous disruption. The shared half-attack prevention cap still applies, and defenses expire each phase. Timing and target selection matter.
- Elite/boss rewards offer two cards and two unowned powerups, with only one discovery taken. Shops offer two cards and two powerups within the existing six-slot layout. Many Pockets still adds a card choice.
- Recovery values remain 30 at recovery sites and 25 between areas. Spending a recovery on evolution therefore has a meaningful hull cost under the increased pressure.

## Reproduce the checks

```sh
bash tools/check.sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/playthrough.gd -- --seed=424242 --character=cartographer --allow-defeat
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/playthrough.gd -- --seed=424242 --character=cartographer --policy=aggressive --allow-defeat
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/playthrough.gd -- --seed=424242 --character=cartographer --no-bonuses --allow-defeat
```

Repeat with `palimpsest` and `hollow_choir`, and different seeds. Balanced is the existing greedy policy that values repair and prevented attacks alongside damage. Aggressive values only immediate damage and strain efficiency, while retaining the same between-battle choices. No-bonuses skips discoveries, shops, events and evolution, but still uses recovery repairs. `--allow-defeat` treats a genuine defeat as a completed experiment; invalid actions and unfinished runs still fail.

These policies compare decision sensitivity, not human win rates. The rules regression includes an otherwise lethal attack where selecting disruption survives and selecting damage loses, visible escalation across every enemy/area, and exclusive bonus selection.

`--policy=tactical` additionally weighs repair and attack prevention against current hull and incoming damage, and scores commands per command point. This is useful for ships with expensive resource-spending commands.

## Seeded results

These measurements are from the difficulty pass **before** the enemy-identity changes described in [the field guide](enemies.md). Tactical weaknesses and deterministic enemy targeting change current run outcomes and RNG consumption.

For fresh profiles on seeds **424242, 101, 2026**, across all three ships:

| Policy | Expedition wins | Outcome |
| --- | --- | --- |
| Balanced | 2 / 9 | Every run reached at least area 2; Cartographer won seeds 424242 and 101 with 62 and 41 hull. |
| Aggressive | 0 / 9 | Every run died in area 1. |
| No bonuses (424242 only) | 0 / 3 | All ships lost in areas 2–3. |

Before tuning, the baseline Cartographer policy on 424242 won with 99 hull. The same balanced policy now wins with 62. The other ships' greedy-policy losses are useful difficulty signals, not proof that their optimal play cannot win.

The tactical policy won Hollow Choir seeds 424242 and 101 with 82 and 77 hull, and lost 2026 in area 3. Palimpsest reached areas 2–3 but lost all three tactical runs; its multi-command Trace planning remains a priority for human playtesting.

## Enemy-identity pass

All 36 authored enemies now have different mechanical pattern signatures; validation rejects profiles that differ only in names or numbers. The [field guide](enemies.md) documents their counters. Regression tests cover phase windows, route weaknesses, interruption thresholds, drain prevention, saturation-dependent attacks, deterministic targeting, saved intents, and visible explanations.

On seed 424242 with the new rules, the Cartographer's original balanced policy loses in area 3, while the tactical policy completes the expedition with 79 hull. The same seed's aggressive policies died in area 1 for all three ships in the comparison run. This gives a concrete decision-sensitive regression rather than requiring every policy to win.
