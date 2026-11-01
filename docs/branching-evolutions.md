# Branching evolutions — infrastructure slice (#15)

**No production card has authored branches yet.** All 72 retain their exact existing
upgrade arithmetic and access (repair 30 versus evolve at recovery; shop price 35).
No starter buffs, permanent progression, new effects or balance claims are added.
Production authoring is a separate follow-up; #15 remains incomplete.

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
`cost`, `damage`, `heal`, `vent`, `disrupt`, `draw`, `trace`, `resonance`.
Integers only, 0–99; cost stays 1–2, Trace 0–6 only on Palimpsest, Resonance 0–3
only on Choir. Attack/repair branches retain positive primary payload. The content
validator rejects duplicate JSON keys and duplicate/reserved branch IDs.
Base flags/selections/engines remain inherited, not branch-editable in this slice.
No identity/pool/art changes, nested definitions, scripts, conditional route damage,
ward, refunds or new triggers. Wider authoring requires a separately reviewed
supported primitive/schema extension rather than arbitrary data injection.

## Safe fixture demonstrations

From this worktree, always use a **new scratch directory**, never a player save:

```sh
GODOT=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
DEMO=$(mktemp -d "$TMPDIR/astral-evolution-demo.XXXXXX")
ASTRAL_SAVE_DIR="$DEMO" "$GODOT" --path . --script tests/evolution_demo.gd
```

Choose Needle or Hull Stitch in the recovery workshop. Test-only Needle is base
10 → Impact 13 versus Flow 10/draw 1; Stitch is heal 9 versus heal 5/vent 1.
These demonstrate immediate output versus existing draw/cooling at 1 CP, not final
content, dominance analysis or evidence of ship viability. The demo refuses an
existing save; fixtures are never registered in production expeditions.

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

Production policy rankings/decisions are unchanged. `Policy.modify(explicit_branches)`
accepts a UID→branch mapping for fixture simulations; without one authored cards
fail choice-required, never choose the first branch. Production authoring must
explicitly design/test branch ranking and publish separately fingerprinted paired
comparisons. Historical balance results remain historical.

### Candidate validation (2026-10-31)

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
