# Effect foundations: compatibility slice (#14 / #15)

This slice only consolidates existing behavior. It adds no cards, branches, effects,
zones, evolution identity or save migration. Both issues remain open.

`Game.effective_card(instance)` is the authoritative, detached printed definition:
base catalog fields plus the existing level-1 arithmetic. Every positive damage,
heal, vent and disruption stat gains +3/+2/+1/+1 respectively; zero stays zero.
Only when all four base stats are nonpositive does level 1 spare the first routed
organ's strain. Draw, resource gains, cost and flags do not evolve. Instances keep
their existing `uid`/`id`/`level`; normalization never modifies them or the catalog.

Resolution, affordability, resource/kind checks, card text, UI and manual inspection
use this definition. The frozen playthrough policy uses effective owned instances
for plays, but intentionally evaluates a level-0 definition for its historical
intrinsic removal/upgrade ranking. Changing that ranking is a separate experiment.

## Preserved resolution boundaries

- Validate route and target before any vent or resource changes. A cooling card
  cannot authorize an already saturated organ. Link similarly cannot repair the
  route used to play itself before validation.
- Capture `plain_payload` as unconditional effective damage/heal/disruption before
  copied contributions, resource spending, conditional bonuses, passives or organs.
  Rewrite never copies those runtime buffs, nor recursively amplified results.
- Preserve ordered resource and organ effects, mitigation, CP, strain and link
  timing. Ordinary cards enter discard before drawing, including same-UID self-redraw.
- Preview uses a copied state, with identical results and no RNG/state mutation.
  Saves, upgrades and the existing manual journal format remain unchanged.

## Regression evidence

`tests/effective_card_test.gd` checks all 72 cards at both levels and pins upgraded
Graft Wire, Carbon Breath, First Draft, Borrowed Dawn, Bright Canon and Grand Concert.
It covers failed cooling routes, self-redraw, copied/resource/passive/conditional
payload exclusions, repeated preview purity, and a normalizer override using only
existing fields to detect raw-catalog bypasses in resolution and the manual adapter.
`tests/card_effects_test.gd` similarly overrides effective fields to exercise UI
affordability, selection, cost, text, printed payload and resource badges. A policy
seam also verifies that effective affordability cannot be filtered by raw cost.

`tests/effective_card_baseline.gd` reproduces 432 full-result/full-state fingerprints
captured before production edits on `a382575`: every ship's catalog cards, levels
0/1, and routes `[0]`, `[0,1]`, `[0,1,2]`. Each scenario has two neutral targets,
powerups, prior copyable payload, resources, strain, and real piles/RNG. Canonical
JSON SHA-256 fingerprints are pinned separately per ship in the test; only generated
run identity and wall clocks are omitted. This is rules compatibility evidence,
not a new full-expedition balance population or a human playtest.

Run with `GODOT_BIN=/absolute/path/to/Godot bash tools/check.sh`, or run the two
tests directly using `Godot --headless --path . --script tests/<name>.gd`.
