# Bounded active Install primitives (#14, fourth slice)

Fixture-only: all 72 production cards and reward pools remain unchanged. #14 is
**not complete**. There is no generic effects interpreter, triggered damage,
CP refund, third-kind sequence, production engine card, or balance claim.

## Typed authoring and timing

An Install definition may have exactly `engine: {type, cap}`:

- `type: "novel_route"`, integral `cap: 1..6`: after a qualifying attack on an
  ordered route not used by **any committed command** this player turn, gain one
  combat-long stack. Every later damaging attack gets +1 base runtime damage per
  stack, before organs and after the copyable `plain_payload` snapshot.
- `type: "other_exhaust"`, integral `cap: 1..5`: once per player turn, another
  card UID exhausting grants flat additive ward 3 and one capped damage stack.
  At stack cap the ward still pays. Echo does not amplify ward; existing Cadence,
  mitigation/disruption limits and ward consumption are unchanged.

No unknown options, scripts, fractional caps or other types are accepted. The
existing identity **and display-name** duplicate rejection still applies. Untyped
legacy Install definitions remain valid and dormant.

Damage bonuses use entry-active sources/stacks, not stacks earned by the same
command. A qualifying attack has positive pre-mitigation damage (including existing
conditional/resource buffs); armor reducing actual damage to zero still qualifies.
Utility damage, including organ-generated damage, never qualifies or gets stacks.
Rewrite cannot recursively copy stacks: only unconditional effective printed
payload is copied. Installation never observes its own command's exhausts or
attack, though older installed sources can observe that command.

The global per-turn ordered-route ledger includes pre-install utility commands and
installation itself. Reverse routes differ; repeats get old bonuses but no new
route stack. Invalid commands, preview simulations, chooser staging and cancellation
change no live ledger or counters. Successful confirmation commits exactly once.

Exhausts are observed in actual move order: selected victims in descriptor order,
then the played source's own Exhaust. "Another" is relative to the installed source
UID, not the currently played command. Double exhaust in one command still pays
each Exhaust engine only once. Feasibility enumeration and `Selections.move` have
no triggers. Awards occur after command effects and actual zone moves, before draw
and combat-end transition. Final-kill exhaust can pay; a lethal route penalty never
pays passives or revives the player. Existing death precedence remains unchanged.

## Persistence and inspection

Run revision **4**, store envelope still 1. `battle.engine_routes` stores unique
ordered routes (at most 156 possible one-to-three distinct organ sequences).
`battle.engine_counters` contains exactly one record per typed installed source:
`{source_uid, type, stacks, used, turn}`. `turn` must equal current battle turn;
source/type/cap must match the effective installed definition. Unknown fields,
duplicates, dangling sources, fractions, malformed routes, out-of-range stacks and
altered types/turns are rejected before integer restoration, with verified backup
fallback. Validation also applies to nonempty post-combat battle bookkeeping.

End turn clears routes and `used`, updates counter turns before any new player
actions, and preserves stacks. Reload, pending chooser, preview and cancel do not
reset anything. New combat clears installs, stacks, latches and routes.

Revisions 2/3 explicitly migrate to empty counters/ledger; truly unversioned saves
retain earlier zones/CP migration. Old files carrying new fields are rejected, not
silently repaired. Valid old pending-choice guards are checked before migration
then rebound to the additive schema; malformed pending metadata is still validated
raw. Historical route usage cannot be reconstructed, so migrated ledgers start empty.

Installed inspection shows source name/UID, stack/cap, next later-attack bonus and
used-this-turn status at both supported window sizes. Untyped entries still say
dormant. Keyword help describes the bounded effects. Headless node assertions are
not native graphical-legibility or human-playtest evidence.

The 432 frozen legacy fingerprints remain unchanged. Besides prior exclusions,
the baseline asserts empty `engine_counters` and **exactly `[route]`** in the new
global ledger before omitting those additive fields. The ledger cannot be asserted
empty: every committed legacy command must record its route. No pre-existing
result/state/RNG fields are omitted or rebaselined.

Manual journal environment fingerprints include the authoritative `game.gd`,
`known_selections.gd` (already covered), `install_engines.gd`, `seed_engine.gd`,
`save_store.gd` and catalog, in addition to HEAD/Godot identity. Dirty engine or
selection modules at the same HEAD reject both resume and replay before save writes.
`tests/install_engine_replay_test.py "$GODOT_BIN"` checks real nine-entry Atlas /
Furnace counter-bearing journals across separate processes, including pending
selection resume, exact full-state/RNG/result replay, and dirty-source rejection
using disposable project copies. Older incomplete environment headers fail closed;
there is no journal fingerprint migration that silently blesses changed rules.

## Native fixture choices (no production demo hook)

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
export TMPDIR="$(mktemp -d /private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/engines-review.XXXXXX)/"
export ASTRAL_SAVE_DIR="$TMPDIR/title-save"
export ASTRAL_SKIP_INTRO=1
"$GODOT_BIN" --headless --path . --script tests/install_engines_test.gd
"$GODOT_BIN" --path . --script tests/install_engines_test.gd -- --demo
```

The demo runs assertions then opens an uninstalled fixture battle. UID 1 = Atlas,
2 = Furnace, 3 = Ten (10 damage), 4 = Double Exhaust (choose another hand UID),
5 = Ten. Select Atlas, route **R/index 3**, Space: installs with zero stacks.
Select Ten UID 3, route **T/index 4**, Space: 10 damage, Atlas stack 1.
Select Furnace UID 2, route **Y/index 5**, Space: installs; Atlas stays 1.
Inspect Installed: Atlas +1/6, Furnace +0/5 available. End Turn.
Demo-only visible intrinsic Retain keeps Double Exhaust UID 4 and Ten UID 5 in hand.
Select Double Exhaust UID 4, route **R/index 3**, choose Ten UID 5 and confirm:
victim then source exhaust, ward +3 exactly once,
Furnace +1/5 used. Later Ten on T deals 12 (two engines); that novel route earns
Atlas's next stack only after damage. Repeating T gets existing stacks but no new
Atlas stack. Use Q/Lens or E/Echo to see bonuses scaled by organs; their final
damage is deliberately not the neutral 10/11/12 example. The 5000-hull fixture
target starts idle; subsequent turns use its normal intents.

Only `tests/install_engine_fixtures.gd` registers these definitions. Close the window
to exit. This validates primitives, not normal card availability or balance.
