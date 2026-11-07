# Agent playbook: operate the live game

## Connect and orient

Use [the setup guide](mcp.md) to connect the stdio MCP server to a running game.
For an existing player session, get permission before making moves. For testing,
launch a separate instance with a fresh `ASTRAL_SAVE_DIR`. Do not overwrite a
player's saves, enable network forwarding, or put tokens in transcripts.

Discover these tools in your MCP client: `get_state`, `act`, `preview`, and
`wait_for_state`. Read or subscribe to the `astral://state` resource if supported.
An MCP resource notification may not wake an agent in every client; correctness
must not depend on notification delivery.

Call `get_state` first. Tool responses carry an `ok` flag and a `state`; failures
carry an error. Check both the MCP tool's error indicator and the returned flag.
Inspect:

| Field | Use |
| --- | --- |
| `revision` | Optimistic concurrency token for the next action |
| `busy` | Presentation or intro currently blocks actions |
| `ui.screen`, `ui.overlay` | Current screen and modal context |
| `ui.selection` | Selected card, route, target, character, page, view |
| `ui.notice` | Controller feedback, including rejected game actions |
| `run` | Player-visible projection of resolved expedition state |
| `profile` | Progress/settings, with MCP credential redacted |
| `legal_actions` | Currently exposed commands and argument options |

`ui.text` describes currently rendered labels. During animation these may still
show the preceding frame/state; prefer `run` for resolved values. An accepted
control activation does not alone prove your intended game outcome: inspect
`run`, `ui.notice`, and the next available actions.

## Blind-play boundary

The MCP must withhold draw-pile identities/order and RNG internals at the server
boundary, not merely hide them in your displayed summary. Draw counts and other
public information remain useful. Never reconstruct hidden order from seeds,
save files, debugger access, source execution, or another side channel. Knowing
the game's public rules or your owned deck inventory is distinct from knowing
the shuffled draw order.

If a response, preview, error, resource, or event reveals hidden information,
stop treating the run as fully blind and report the leak. Ignoring exposed
values afterward cannot retroactively establish blindness. Version **0.2.0**
exposed raw draw-pile/RNG state; its MCP runs do not establish fully blind play.
Use a build with server-side filtering and leakage regression tests for that
claim. Do not assume the installed v0.2.0 app changes when a source fix is merged.

## Act from discovery, not memorized indices

Each ordinary control action advertises `args.index.options`, containing an
`index`, label, description, and control name. Choose the matching option and
send **that option's index**, not its position in a filtered list. Disabled
controls can leave gaps. Indices are valid only for that state's revision.

```json
{
  "action": "select_card",
  "args": {"index": 0},
  "expected_revision": 42
}
```

This shows the argument shape only: use the action/index/revision returned by
your own current session. `set_setting` instead takes `key` and `value`; discover
its allowlist and types in `legal_actions`. Do not attempt to change MCP secrets
through that command.

After every action, use its returned state. If busy, call `wait_for_state` with
`after_revision` and a bounded `timeout_ms` (maximum 30000). A newer revision can
still be busy; recheck before acting. `result.timed_out` is not completion.
Stop after a reasonable overall deadline and report a stuck animation rather
than waiting forever.

## Complete gameplay workflow

- **Title/character:** discover new/continue actions, select a vessel, inspect
  character details if needed, then begin. Replacing or abandoning an existing
  expedition requires explicit user intent; do not automatically confirm it.
- **Map:** choose from the advertised reachable destination controls. Use option
  descriptions and the map in `run` to reason about encounters.
- **Combat:** select a hand card, build a connected organ route using available
  controls, select a living target, and call `preview`. Read its `ok`, error,
  resource cost, strain, and deterministic forecast fields. Preview deliberately
  omits simulation snapshots, presentation records, event strings, and summaries
  that could reveal future draws. Undo/cancel or change selections
  if necessary. Confirm only when satisfied. Read post-action `run` immediately,
  then wait for animation completion. End turn when strategically appropriate.
- **Rewards/events/shop/recovery:** select the corresponding visible choice,
  purchase, repair, upgrade, skip, or leave action. Handle any follow-up modify
  selection and pagination; do not assume a purchase completes the whole flow.
  Multi-stage known-card choices and evolution confirmation require their own
  advertised selections and confirmation; preview again before committing.
- **Region/ending:** use discovered continuation/title/new-expedition controls.
  Report the actual final mode; do not claim victory from a transient animation.
- **Inspection/settings:** open available help, deck, history, discoveries,
  details, menu, or settings controls. Close overlays before resuming gameplay.

Command names come from the live controller and may evolve with the game.
`legal_actions` is the runtime contract; this guide is not a replacement for it.
If a desired operation is absent, do not invent an action or bypass game rules.
Refresh, check for an overlay/busy state, then report unsupported coverage if
needed. MCP does not expose every OS/window operation or arbitrary state edits.
Seed entry is intentionally not exposed. Draw-pile inspection does not return
card identities: only the public count is available, and a draw-pile overlay
can be closed without exposing its labels.

## Recover safely

- `stale_revision`: refresh and reconsider the move against the changed state.
- `busy`: wait for a newer state, then recheck `busy` and available actions.
- `invalid_args`, `unknown_action`, `unavailable`: inspect the current schema,
  screen, overlay, and selection. Correct the cause; never loop identical calls.
- `unauthorized`: verify local configuration without logging the token.
- `bridge_unavailable`/disconnect during a move: the move may have committed.
  Reconnect and inspect state; never automatically replay it. Transport retry
  caching is connection-local and is not a general exactly-once guarantee.
- Save warning: preserve files and report it. Do not start a replacement run or
  repair/overwrite saves without explicit authorization.

## Report evidence honestly

For gameplay, report actions, resulting mode/state, and unresolved errors. For
tests, state whether you used the real MCP stdio boundary, a live main scene,
windowed rendering, isolated saves, and which screens were exercised. A windowed
test is not a visual inspection unless you actually inspected images. Never
claim full-run MCP coverage from a rules-only seeded expedition.
