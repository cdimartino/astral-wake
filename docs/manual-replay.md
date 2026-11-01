# Auditable headless manual commands (issue #22, first slice)

This is a **manual rules-engine driver**, not an automated gameplay policy or a
graphical UX test. It uses the real `Game` and existing practice/legacy seed APIs.
It never chooses cards, routes, enemies, rewards or destinations for you.

The dormant [known-card selection slice](known-card-selections.md) adds guarded
`begin_selection`, `select_uid`, `selection_preview`, `confirm_selection` and
`cancel_selection` commands, with a separate test-only fixture driver/demo.

## Start, inspect, command, resume, replay

Run from the repository root. Set `GODOT` to your engine executable. Each session
gets its own `saves/` and `trace.json`; it does not use your normal save directory
or `ASTRAL_SAVE_DIR`. Choose a **nonexistent** session directory, outside the repo.

```sh
GODOT=.tools/Godot.app/Contents/MacOS/Godot
SESSION="$TMPDIR/astral-manual-example"
"$GODOT" --headless --path . --script tools/manual_replay.gd -- \
  --session="$SESSION" --start=A1B2C3 --ship=cartographer --unlocks=0

# Inspect the existing expedition; never implicitly start/restart it.
"$GODOT" --headless --path . --script tools/manual_replay.gd -- \
  --session="$SESSION" --resume=true
```

The JSON response includes `state`, effective hand definitions keyed by `uid`,
`targets`, and an `expect` object. Copy **both** `expect.step` and `expect.state`
from the latest response into your command. The state hash covers the full
normalized rules state including RNG. For example (replace the placeholder hash):

```json
{"op":"choose_node","node":"r0-l0-c0","expect":{"step":0,"state":"COPY_LATEST_HASH"}}
```

Pass that object as a quoted `--command='JSON'` with `--resume=true`, or put
one object per line in a file and pass `--commands=/absolute/path/commands.jsonl`.
Commands execute in order and **stop on the first error** (exit 1). Blank lines
are ignored. Malformed JSON is a transport error and cannot be committed to the
trace; valid JSON command objects that fail validation/rules are recorded under
`errors`, separately from successful `entries`. Failed attempts advance the guard
step but do not advance gameplay. Inspect again before retrying.

Example combat object (copy actual UID, target and guard from inspection):

```json
{"op":"play","uid":7,"route":[0,3],"target":{"slot":0,"id":"enemy_type_from_targets"},"expect":{"step":1,"state":"COPY_LATEST_HASH"}}
```

`route` is an **ordered** list of zero-based organ indices, not a set. Hand/deck
indices are forbidden: `uid` identifies one owned card instance even after cards
shift. Enemies currently have type IDs, not unique engine UIDs, so targets require
**both** type ID and slot under the exact-state guard. This distinguishes duplicate
enemy types and refuses stale selections after removal/reordering. No automatic
retargeting occurs.

Use `"op":"preview"` with the same combat fields to query the existing preview.
Successful and failed previews change neither game/RNG nor trace/guard. Other ops:

| op | Additional fields |
| --- | --- |
| `modify` | `uid` (stable deck instance ID), explicit `branch` for authored evolutions; optional only for unbranched compatibility |
| `reward` | `choice` (displayed index, `-1` explicitly skips) |
| `buy`, `event` | `choice` (displayed index) |
| `recover` | `choice`: `"repair"` or `"upgrade"` |
| `end_turn`, `continue_region`, `cancel_modify`, `leave`, `abandon` | none |

Every operation requires `expect`. The full snapshot exposes reward/shop/event/map
state; choices use existing Game indices protected by that guard. Inspection does
not itself commit an action. `abandon` is explicit and records the real defeat.

Replay into a fresh scratch directory:

```sh
"$GODOT" --headless --path . --script tools/manual_replay.gd -- \
  --session="$TMPDIR/astral-manual-verification" --replay="$SESSION/trace.json"
```

Replay starts from the recorded explicit seed, ship and discovery tier, feeds the
recorded successes **and errors** through the real adapter/Game, and compares every
before/after snapshot, guard, effective card definition and result. Any divergence
fails rather than silently accepting a different outcome. A verified scratch
session can subsequently be resumed with new explicitly chosen commands.

`--start=legacy:777` preserves the numeric-seed API/RNG for historical experiments;
`--start=777777` is instead a six-character modern practice code. Modern practice
codes already encode the discovery pool, independently of profile `--unlocks=0`
through `3`. Legacy numeric seeds retain their original progression semantics,
but only inside the isolated session. All three existing ship IDs are supported.

## Audit boundaries and limitations

The [Cartographer candidate](cartographer-evolutions.md) includes an actual-production
native recovery demo and separate counterfactual driver. Use this document's
production driver for the primary fresh expedition, not a counterfactual adapter.
The authoritative evolution module is included in replay source fingerprints.
The fixture-only route/ward prerequisite also fingerprints `scripts/route_effects.gd`;
changing it at the same HEAD rejects resume/replay rather than blessing dirty rules.

- The trace records revision, SHA-256 fingerprints of resolver/RNG/save/content
  sources, Godot version, seed, ship, unlocks, and normalized initial state. Each
  snapshot retains the route-region order, map/encounter enemy IDs, card piles,
  RNG generation version/streams (or legacy string RNG state), and all rules fields.
  Only generated run ID and wall-clock fields (`started_at`, `elapsed_seconds`)
  are omitted. Effective definitions are recorded for committed card plays and
  deck modifications; the after snapshot includes the resulting upgrade level.
- Replay/resume require the recorded revision, source fingerprints and Godot
  version. Unknown revisions are labelled `unknown`; use a Git checkout for
  publishable evidence. Source fingerprints also detect dirty production edits.
- Start/replay refuse existing session directories. Resume requires both the real
  save and matching journal; missing, corrupt, backup-recovered or mismatched saves
  fail, never restart the expedition. Do not run concurrent writers or edit the
  session while it is open. The journal is atomically replaced after each command,
  but save and journal are not a single filesystem transaction: an interrupted
  write can leave a mismatch that deliberately blocks resume. Preserve it for
  diagnosis rather than restarting over it. Journals are not cryptographically
  signed and are not a substitute for code review.
- Full snapshots are intentionally verbose; Godot may also print engine startup
  diagnostics to stdout. Command files are newline-delimited JSON, not a JSON array.
- This slice does **not** produce turn/encounter metric reports, run population
  baselines (see the separately published baseline in `docs/balance.md`), add new
  mechanics, or claim any human difficulty target.
  It preserves the original seed-777 loss; any corrected manual sequence must be
  labelled a separate counterfactual. Issue #22 stays open for later evidence.

Regression: `Godot --headless --path . --script tests/manual_replay_tests.gd`.
`tools/check.sh` includes it; use `GODOT_BIN=/absolute/path/to/Godot` when this
worktree has no bundled engine. Saves and test artifacts stay isolated under TMPDIR.
