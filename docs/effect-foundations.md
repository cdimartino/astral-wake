# Effect foundations (#14 / #15)

The first slice consolidated existing behavior. The second adds dormant combat
zones, Retain and Install identity storage, but no production cards, branches,
passives, counters, triggers or selection subsystem. Both issues remain open.

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
  Upgrades and the existing manual journal format remain unchanged.

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
JSON SHA-256 fingerprints are pinned separately per ship in the test; generated
run identity and wall clocks are omitted. After integration with PR28, only its
three additive presentation event kinds (`discard_card`, `draw_card`, `shuffle`)
are omitted from the legacy result fingerprint. The original hashes are unchanged;
every gameplay state/RNG field and every pre-existing result/event remain compared.
The zones slice additionally asserts empty `exhausted`, `installed`,
`installed_sources`, and `temporary_retain` fields before omitting exactly these
fields and `schema_revision` from the legacy fingerprint. No RNG is omitted.
`tests/card_piles_test.gd` independently checks the new pile events. This is rules compatibility evidence,
not a new full-expedition balance population or a human playtest.

Run with `GODOT_BIN=/absolute/path/to/Godot bash tools/check.sh`, or run the two
tests directly using `Godot --headless --path . --script tests/<name>.gd`.

## Dormant zones and Retain contract

`battle` partitions the expedition deck's exact UID/id/level instances across
`hand`, `draw`, `discard`, `exhausted`, and `installed`. Last-command snapshots
are history, not a sixth ownership zone. New fights copy the full expedition
deck and clear all combat-local zone/retain/source bookkeeping. Nothing here
removes cards from the expedition deck or changes the 72 existing definitions.

Optional authored definition fields (read through `effective_card`):

- `retain: bool`: intrinsic Retain on this card only, not an instruction to select
  other cards. Retained cards remain in stable hand order across discard and use
  the existing ten-card cap. The normal five cards are drawn subject to room.
- `exhaust: bool`: the played card enters `exhausted` before command-driven draw.
- `install: String`: nonempty lowercase alphanumeric/underscore identity. The
  played card enters `installed` before draw and creates exactly one minimal
  `installed_sources` record: `{source_uid, identity}`. Install and Exhaust are
  mutually exclusive. Duplicate identity **or effective display name** is rejected
  before any CP/resource/strain/pile/event mutation, with no stacking override.
  Costs and attack/repair/utility kinds are otherwise unchanged.

Install is **storage and identity only**, not an active passive. Passive activation,
source-linked counters, triggers and stacking policies need a separately reviewed
next slice; there is intentionally no generic effects interpreter here.

`retain_card(uid)` explicitly marks one current hand UID in `temporary_retain`
for the next end-turn discard. Duplicate marking is idempotent. It has no UI or
selection command yet and chooses nothing implicitly. The mark expires at that
boundary even if the card also has intrinsic Retain. Playing the marked card
consumes the mark before drawing, so self-redraw cannot revive it. Invalid UID
requests change nothing. A ten-retained-card hand performs no draw, shuffle, RNG
call or phantom draw event. Dedicated-zone moves emit `zone_card`, never an
ordinary `discard_card`; existing presentation handles both using distinct zones.

### Save revision and inspection

The envelope remains `SaveStore.VERSION = 1`. Nonempty runs now require
`schema_revision = 2`. After store read and **before** numeric restoration, truly
unversioned legacy runs gain the revision and four empty combat fields. Legacy
expansion/CP migration applies only to those unversioned runs. Legacy files with
any new combat bookkeeping but no revision are rejected rather than repaired.
Current-schema missing/malformed fields and unknown revisions fail validation and
can fall back to the verified backup. Migration neither shuffles nor consumes RNG;
numeric legacy and split-stream modern RNG are preserved. New fields require
integer UIDs before restoration, current-hand-only unique retain marks, five-zone
conservation, and one-to-one installed source/identity matching. No counters are
defined by this slice.

The existing draw/discard pile controls also inspect Exhausted and Installed
counts/contents. Installed inspection explicitly says dormant and displays identity
and source UID. Hand faces show `[R]`, and deck inspection shows `RETAINED` for
intrinsic or currently marked copies. Draw inspection remains sorted, never draw
order. Headless tests assert node text/connections, **not** graphical legibility,
animation quality or human playtest evidence.
The existing keyword tooltip/glossary from #32 also explains Retain (including
temporary marks), Exhaust and dormant Install, using effective definitions.

### Test fixture demo (not production gameplay)

Only `tests/card_zone_fixtures.gd` registers the new authored fixture definitions;
no production cheat, catalog entry, reward or hidden demo hook exists. Run from
the worktree, with a fresh approved temporary directory (the script creates its
own isolated saves beneath `TMPDIR`):

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
export TMPDIR="$(mktemp -d /private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/zones-review.XXXXXX)/"
"$GODOT_BIN" --headless --path . --script tests/card_zones_test.gd
"$GODOT_BIN" --path . --script tests/card_zones_test.gd -- --demo
```

The second command runs assertions then leaves the fixture battle visible. Inspect
all four pile buttons, dormant Install identity/source UID, and intrinsic/temporary
`[R]` hand markers. End Turn demonstrates Retain. Close the window to exit. This is
a rules/UI fixture, not evidence about normal card availability or game balance.
