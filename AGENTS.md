# Astral Wake agent instructions

Astral Wake is a native Godot game. Use its **live MCP** for gameplay and game
state inspection whenever available—not screenshots, simulated input, direct
save edits, or a separate rules-engine instance as a substitute for live control.

Read [the MCP agent playbook](docs/mcp-agent-guide.md) before controlling the game.
Connection/setup details are in [docs/mcp.md](docs/mcp.md). Tool names may have a
client-specific prefix; discover them rather than assuming one.
Opt-in client configurations and setup guides live in `integrations/opencode/`,
`integrations/codex/`, and `integrations/claude/`. The MCP server also supplies
workflow instructions during initialization; follow the blind-view safeguards
even if your client does not display those instructions automatically.

## Live control essentials

- `get_state` is authoritative. Inspect `revision`, `busy`, `ui`, `run`,
  `profile`, and `legal_actions` before deciding.
- Use `act` with an advertised action, its advertised arguments, and the exact
  `expected_revision`. Option indices refer to the current visible controls;
  never assume they are permanent card, organ, or map identifiers.
- Stage combat selection, call `preview`, then confirm. Inspect the returned
  logical state immediately; wait for presentation completion before mutating
  again. Use bounded `wait_for_state` instead of polling in a tight loop.
- Subscribe to `astral://state` when supported. Manual play changes the same
  state, so refresh after notifications and stale-revision errors.
- A lost connection during a move is an uncertain outcome. Read state after
  reconnecting; do not blindly retry a non-idempotent move.
- Treat the MCP as a blind, player-visible interface. Do not inspect save files,
  RNG internals, seeds, or draw-pile identities/order to choose moves. If hidden
  information leaks, report it and do not label that run fully blind, even if
  you subsequently filter the display or promise not to use it.
- MCP access is off by default. Settings enablement, port, and token persist.
  Never print or commit credentials. Do not silently enable access or change a
  person's saved expedition without their authorization.
- Use UI automation only for unsupported UI operations (including enabling MCP
  before connecting) or explicit visual verification. The MCP returns semantic
  state, not proof of rendered appearance.

## Development and verification

Use the pinned Godot version and commands in README.md. Run `bash tools/check.sh`
for game regressions and focused MCP checks. For the actual protocol-to-scene
boundary run:

```sh
python3 tests/mcp_integration.py --godot .tools/Godot.app/Contents/MacOS/Godot
```

Add `--visible` for the windowed path. Tests must create fresh isolated save
directories: never unset an override and accidentally fall back to `user://`.
Do not equate a headless rules playthrough with a complete MCP/UI playthrough.

The Python host lives in `tools/astral_mcp.py`; controller, local transport, and
settings UI live in `scripts/mcp_controller.gd`, `scripts/mcp_bridge.gd`, and
`scripts/mcp_settings.gd`. Keep game mutations in the existing validated shared
controller/game paths. No arbitrary evaluation or network-selected method calls.
