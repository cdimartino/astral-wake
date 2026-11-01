# Route and flat-defense primitives (#16 prerequisite, first slice)

**Fixture only. Neither #14 nor #16 is complete.** The 72 production base cards,
144 authored branches, existing role assignments, reward generation 0/1 and
production pools are unchanged. Six actual prototype definitions live exclusively
in `tests/route_effect_fixtures.gd`: Survey Spike, Cross Current, Heat Sink,
Thermal Lance, Parry Filament and Refracted Fang. Living Atlas already has its
separate existing engine fixture. **Phase Radiator (`cooling_ward`) and Interception
Loom (`redirect_retaliation`) are deferred**, including their source latches,
enemy-phase damage/recipient semantics, save validation and native counters. They
are not registered as dormant placeholders or claimed as implemented cards.

## Closed authoring contract

`scripts/route_effects.gd` owns runtime definition validation and pure conditional
evaluation. The raw content validator mirrors this allowlist:

| Field | Accepted shape | Timing |
| --- | --- | --- |
| `ward` | integer 0..99 | flat additive ward after Cadence's existing local calculation |
| `conditional_damage` | `{type: "novel_route", amount: 1..99}` | exact ordered route unused by **any committed command** this turn |
| `conditional_damage` | `{type: "route_strain_two", amount: 1..99}` | at least one routed organ had **exactly 2** strain at command entry; pays once |
| `conditional_ward` | `{type: "prism_other_foe", amount: 1..99}` | route contains organ **identity** `prism`, with another living foe at command entry |
| `route_cooling` | `{type: "three_first", amount: 1}` | exactly three organs: cool the first after route strain |

No arbitrary predicate, script, threshold, organ socket, event binding, resource
refund or generic mutation language is accepted. Conditional damage requires
positive **printed** damage and attack kind: it cannot turn zero-damage utility
into an attack. Multiple qualifying strain-two organs do not multiply the bonus.

Validate the full route before effects: neither vent nor post-route cooling can
authorize a saturated route. Capture plain unconditional damage/heal/disruption
first; conditional damage is then added before resources, passives, powerups and
ordered organs. Strain checks precede vent; the Prism predicate precedes damage,
so killing the other foe during this command does not revoke eligibility. The
global existing ledger includes utility, installation and earlier attacks, treats
reversal as a different route, and resets at the existing player-turn boundary.

Printed and conditional ward are neither copyable payload nor organ-amplified.
Cadence still fills only room up to 3 in existing ward; flat card ward is added
**after** that calculation. Ward 8 plus Heat Sink's 5 becomes 13. There is no new
global ward cap or disruption/redirection defense-cap change. Ward cannot pay
after a lethal route penalty, even if the same command kills the final foe.

`command_cooling` is the sum of actual strain removed by vent and post-route
cooling, not attempted cooling or net strain change. A legitimate vent removal
followed by route strain and another removal counts both effects; a first-free
route starting at zero removes zero. Automatic end-turn cooling is excluded.
This value is preview accounting only in this slice: it triggers **no new engine**.

## Evolution, persistence, inspection and compatibility

Only printed `ward` joins the evolution stat allowlist (integer 0..99). Conditional
descriptors and route-cooling descriptors cannot be replaced through branch stats.
Authored ward is an explicit replacement, with no legacy increment. Legacy ward
receives **no invented bonus**; positive ward also prevents a ward-only legacy card
from receiving an invented first-free strain benefit. All existing 72 cards retain
their exact arithmetic. Printed ward has a stat badge and Ward keyword help;
prototype descriptions state conditions and timing. Preview exposes
`flat_ward_requested`, `flat_ward_applied`, `conditional_damage`, `command_cooling`
for new-effect cards, and compact native text shows applied/requested ward and
actual cooling. Legacy result dictionaries receive no additional fields, preserving
the existing 432 frozen full-result/state comparisons without rebaselining.

There is no new persisted field, source type or latch: run schema remains **6**,
store envelope **1**. Existing counters, dormant Install definitions and migration
guards are unchanged. Raw save validation uses the same effective-definition
validator as resolution; pending chooser guards already cover the complete
effective definition. Preview/selected confirmation still run the same copied-state
resolver. `route_effects.gd` joins manual source fingerprints; same-HEAD dirty-byte
resume/replay rejection is tested alongside the existing authoritative modules.

## Exact test and native fixture workflow

From this worktree, use isolated scratch storage, not a player save:

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
export TMPDIR="$(mktemp -d /private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/route-review.XXXXXX)/"
python3 tests/route_effects_validator_test.py
"$GODOT_BIN" --headless --path . --script tests/route_effects_test.gd
"$GODOT_BIN" --headless --path . --script tests/route_effects_ui_test.gd
GODOT_BIN="$GODOT_BIN" bash tools/check.sh
export ASTRAL_SAVE_DIR="$TMPDIR/native-demo"
"$GODOT_BIN" --path . --script tests/route_effect_demo.gd
```

Native demo is explicitly labelled fixture-only, with real prototype names/effects,
two normal Cinder Mites, ward **8**, strain `[2,1,0,0,0,0]`, ordinary CP and legal
routes. No production cheat hook is added. Initial hand: Heat Sink, Thermal Lance,
Survey Spike, Cross Current, Refracted Fang; Parry Filament is in the draw pile.

Suggested lead captures (restart with a **fresh** scratch save directory for each):

1. Heat Sink through Hush (index 4 / T): capture preview **Ward 5/5 · Cool 2**,
   confirm with Space, capture actual ward **13**. Echo instead still grants only 5.
2. Thermal Lance through Lens (index 0 / Q): entry strain 2 adds 6, then Lens +3,
   giving 18 before enemy mitigation. Heat Sink first lowers that entry strain,
   so a later Thermal Lance no longer qualifies merely because strain used to be 2.
3. Cross Current through Lens–Fork–Echo (indices 0,1,2 / Q,W,E): capture actual
   cooling 1 and first organ's unchanged net strain; a saturated first organ remains
   illegal. Survey Spike on Hush gets +5 only if no earlier command used Hush.
4. Refracted Fang through Prism (index 5 / Y) while both foes live gives 4 ward;
   the same route against a lone foe gives none. Inspect card descriptions/keyword
   help and preview at 1440×900 and 1100×720.

The UI test checks native scene nodes at both sizes, not a human visual/playtest
claim. Close the native window, then remove only your named scratch directory when
finished. Fixtures do not resume in the production entry point; do not put fixture
saves in your real save location. There is no new art or balance evidence here.
