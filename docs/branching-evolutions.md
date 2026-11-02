# Branching evolutions — infrastructure slice (#15)

Historical 72-card authoring record. The [production expansion candidate](cartographer-expansion.md)
adds nine cards / eighteen branches using this same stat/flag allowlist, and
versions the content pool in run schema 7. No original branch is changed.

All 72 production cards now have two authored choices: [Cartographer](cartographer-evolutions.md),
[Palimpsest](palimpsest-evolutions.md) and the [Choir candidate](choir-evolutions.md).
All base definitions and existing legacy outcomes remain unchanged. Authoring
coverage alone does not complete #15: independent Choir review, native/manual
evidence and broader counterfactual/playability comparisons remain required.

## Identity and rules

- Base instances are level 0 with absent/empty `evolution`. Upgraded instances are
  level 1 with `evolution: "legacy"` or an authored branch ID. Choices are per UID,
  mutually exclusive, permanent for the run, and cannot be upgraded again.
- `effective_card(instance)` deep-copies base content and applies authored stat
  **replacements**, never the generic bonus afterwards. It removes branch
  definitions from the result. Resolution, affordability, previews, copyable printed
  payload, text, card faces and policies share this normalizer.
- `evolve_card(uid, branch_id)` re-resolves the owned UID and validates eligibility,
  identity and available payment before committing. Empty/unknown/foreign branches
  never choose a default. `modify_card(index)` remains compatible for unbranched
  cards and removal; branched cards return “Evolution choice required.”
- The native workshop shows before text/stats and both alternatives with full
  effective text, CP and service price. Closing/canceling returns to the card chooser
  without payment; canceling the service returns to recovery/shop. Confirmation
  pays once. Combat route previews use the selected effective definition.

Run schema **5**, save/trace envelopes **1**: explicit old-schema migrations assign
reserved `legacy` to missing level-1 identities in deck, all five combat zones and
`last_command.card`, preserving recorded base/resolved payloads. Level 0 stays
eligible, even when branches are later authored. Old pending selection guards are
validated **before** migration, then effective definitions and guards refresh.
Current-schema missing/foreign/mismatched identities and fractional levels/UIDs
are rejected before integer restoration; corrupt primary saves may recover only
validated backups. Live combat zones/last command must match the deck. Completed
battle snapshots may predate a later deck removal/evolution.

## Minimal authored schema

```json
"evolutions": [
  {"id":"impact", "name":"Prototype Impact", "description":"Deal 13 damage.", "stats":{"damage":13}},
  {"id":"flow", "name":"Prototype Flow", "description":"Deal 10 damage. Draw 1 command.", "stats":{"damage":10,"draw":1}}
]
```

Exactly two distinct non-reserved IDs; exactly `id`, `name`, `description`, `stats`
per branch. `stats` is a nonempty flat replacement dictionary allowing only
`cost`, `damage`, `heal`, `vent`, `disrupt`, `draw`, `trace`, `resonance`, `ward`.
Numeric fields are integers only, 0–99; cost stays 1–2, Trace 0–6 only on Palimpsest, Resonance 0–3
only on Choir. Attack/repair branches retain positive primary payload. The content
validator rejects duplicate JSON keys and duplicate/reserved branch IDs.
The only additional branch fields are strictly boolean `retain`, `exhaust` and
`first_free`, replacing inherited values (including explicit false), not stacking.
Effective Install plus Exhaust is rejected. Selections/engines remain inherited.
The [fixture-only route-defense prerequisite](route-defense-primitives.md) adds
explicit printed ward replacement (0–99), without a generic legacy ward bonus.
No identity/pool/art changes, nested definitions, scripts, conditional route damage
overrides, conditional ward overrides, route-cooling overrides, refunds or new
triggers. Those typed base effects remain inherited. Wider authoring requires a separately reviewed
supported primitive/schema extension rather than arbitrary data injection.

## Safe demonstrations

The native `tests/evolution_demo.gd` uses actual production cards (Cartographer by
default, or `-- --ship=palimpsest` / `-- --ship=hollow_choir`) at a labelled recovery
counterfactual; see each production document for review and
primary fresh-expedition instructions. The older fixture driver below remains
available solely for infrastructure regression tests.

From this worktree, always use a **new scratch directory**, never a player save:

```sh
GODOT=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
DEMO=$(mktemp -d "$TMPDIR/astral-evolution-demo.XXXXXX")
ASTRAL_SAVE_DIR="$DEMO" "$GODOT" --path . --script tests/evolution_demo.gd
```

Choose a production starter card in the recovery workshop. Needle is base 9 →
Sunpoint 12 versus Held Dawn 9/Retain. The demo refuses an existing save. Fake
fixture definitions are never registered by this demo or production expeditions.

For guarded manual commands, use the fixture adapter, not the production driver:

```sh
SESSION="$TMPDIR/astral-evolution-session-$(uuidgen)"
"$GODOT" --headless --path . --script tests/evolution_driver.gd -- \
  --session="$SESSION" --start=A1B2C3 --ship=cartographer --unlocks=0
```

Copy a UID, branch ID and current `expect` from inspection, then pass a command via
`--resume=true --command='JSON'`:

```json
{"op":"modify","uid":1,"branch":"flow","expect":{"step":0,"state":"COPY_LATEST_HASH"}}
```

Missing branch is allowed only for unbranched compatibility. Inspection exposes
effective before/after definitions; the journal records the chosen definition.
Replay using a fresh `--session` and `--replay="$SESSION/trace.json"`.
Fingerprints include `scripts/evolutions.gd`; mismatched authoritative sources refuse
resume/replay independently of Git revision.

## Tests and policy boundary

`tests/evolutions_test.gd`, `tests/evolutions_ui_test.gd` and
`tests/evolution_replay_test.py` cover fixtures, raw validation/migration, all zones,
last-command payloads, pending guards, backup recovery, explicit API/manual choices,
CP/preview, cancel/payment and node-level UI. `tests/effective_card_test.gd` retains
all 432 frozen production outcome cases and exact old arithmetic for all 72 cards.
The UI test is not graphical readability evidence or an audited player expedition.

Intrinsic base-card rankings are unchanged. The named `cartographer-branches-v1`
policy now explicitly scores effective branches into stable UID mappings; see the
production document for weights and limitations. `Policy.modify(explicit_branches)`
still accepts explicit mappings. Public game APIs still fail choice-required on
missing identities; they never default to the first branch. Historical balance
results remain historical and were not recomputed for this changed policy/content.

### Historical infrastructure validation (2026-10-31, before production authoring)

- Latest bounded rerun: 14 targeted scripts/process suites passed, including rules
  (11,543 checks), effective definitions (2,087 checks / 432 frozen cases), evolution
  fixtures (104), chooser UI (7), zones, selections, Install, seeds, manual replay,
  last command, card effects and all three separate-process replay suites. Direct
  Godot tests used the absolute bundled engine path above and `--audio-driver Dummy`;
  all saves/artifacts were isolated under temporary directories. Catalog validation
  also passed, rejecting 66 malformed mutations. `first_free` overrides are explicitly
  rejected, not interpreted as an authored route-strain effect.
- **No complete full-suite pass claimed.** A `tools/check.sh` attempt passed all
  preceding checks through normal intro, then the unchanged intro skip test asserted
  `Skip must finish promptly` and hung; it was terminated. Its audio smoke and final
  tactical policy command were not reached. A subsequent full attempt timed out
  after 1,200 seconds, with the last completed result being the evolution UI test.
  Some native/headless runs emitted audio resource-leak warnings at shutdown.
- The native demo was smoke-started headlessly, not audited graphically. No new
  expedition population, human readability or production branch balance evidence.
