# Control the live game with MCP

Astral Wake's source includes a local MCP server. Commands operate the running
game window, not a separate simulation. Control is disabled until you enable it
in Settings. The Python host requires Python 3; no pip packages are needed.

## Enable in Settings

Open the game's Settings and enable **Local AI control (MCP)**. Access is off by
default. Your enabled state, port, and authentication token are saved and reused
on subsequent launches. Settings provides the local connection details; use its authentication token when configuring your
MCP client. Disabling access stops the listener and disconnects connected AI
clients immediately. A failed connection setup is shown in Settings rather
than silently enabling access. If the saved port is unavailable, choose another
port in Settings; the game does not silently change your client's endpoint.

Enabling AI control lets an authenticated client make real moves in your current
expedition. Use a separate save folder when experimenting, and do not share the
token or forward the port to a network.

## Start a controlled game from the command line

From the source checkout, after installing the pinned Godot engine:

```sh
export ASTRAL_MCP_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
export ASTRAL_MCP_PORT=47631
export ASTRAL_SAVE_DIR="$(mktemp -d "${TMPDIR:-/tmp/}astral-mcp.XXXXXX")"
.tools/Godot.app/Contents/MacOS/Godot --path .
```

The isolated save folder is optional but recommended for AI playtesting. Without
it, AI actions affect your normal expedition and profile, just like manual play.
Keep the token private. Use an unused port, and give each controlled game its own
port and token. These environment overrides apply only to that launch and do not
change saved MCP preferences. Stopping the game removes its control endpoint;
Settings-enabled access returns on the next launch until you disable it.

## Connect an MCP client

Client-specific, opt-in integrations are included for
[OpenCode](../integrations/opencode/README.md),
[Codex](../integrations/codex/README.md), and
[Claude Code / Claude Desktop](../integrations/claude/README.md).
These examples do not install themselves or contain credentials. Follow the
client-specific environment and configuration rules rather than copying one
client's JSON shape into another.

Configure a local stdio server using absolute paths to Python and this checkout:

```json
{
  "mcpServers": {
    "astral-wake": {
      "command": "/absolute/path/to/python3",
      "args": ["/absolute/path/to/astral-wake/tools/astral_mcp.py", "--port", "47631"],
      "env": {"ASTRAL_MCP_TOKEN": "the-same-token-used-to-start-the-game"}
    }
  }
}
```

Client configuration formats vary; the executable, arguments, and environment
above are the portable parts. Use the port and token shown in Settings, or the
environment values from the command-line setup. Start the game first. The server only connects to
loopback; do not expose or forward the port to a network.

## Agent interaction loop

Agents should read [the complete playbook](mcp-agent-guide.md), which covers
discovery, combat, every encounter flow, notifications, and safe error recovery.

**Blind-play limitation:** released v0.2.0 exposed draw-pile contents/order and
RNG state. Filtering those from agent displays is not sufficient for a fully
blind test. Use a newer build with server-side projection and leakage tests;
see the playbook's blind-play boundary. Source changes do not update an already
installed app automatically.

1. Call `get_state`. Read `ui`, `run`, `busy`, `revision`, and `legal_actions`.
2. Choose an available semantic action and its arguments from `legal_actions`.
3. Call `act` with `action`, `args`, and that state's `expected_revision`.
4. Use the returned authoritative state immediately. Logical resolution is
   distinct from animation completion: a successful action may return `busy: true`.
5. While busy, inspect state or use `wait_for_state`; do not send another mutation
   until presentation finishes. Refresh and reconsider on `stale_revision`.

`preview` evaluates the current combat selection without committing it. Both
manual interactions and MCP commands change the same live controller. UI-only
changes and presentation completion also advance the state revision. The
`astral://state` resource can be read or subscribed to by supporting MCP clients;
notifications are hints to refresh, not permission to reuse an old revision.

Commands are explicitly allowlisted. The MCP does not provide arbitrary script
execution, object mutation, filesystem access, or a bypass around game rules.
Errors such as invalid arguments, stale state, or presentation locking must not
be interpreted as successful moves. If a connection fails during a mutation,
the outcome can be uncertain: reconnect and read state rather than blindly
retrying the command.

## Source distribution

Keep `tools/astral_mcp.py`, the `scripts/mcp*.gd` implementation, and this guide
with the game source. The Python host is an external MCP process, not a Python
dependency of the game. The macOS export excludes `tools/` and `tests/`; users
need the source-side host to connect an MCP client.

The bridge protocol and verification requirements are documented in
[mcp-contract.md](mcp-contract.md). Normal offline play remains unchanged when
MCP is not enabled.

## Verify from source

```sh
python3 -m unittest discover -s tests -p test_astral_mcp.py -v
python3 tests/mcp_integration.py --godot .tools/Godot.app/Contents/MacOS/Godot
```

The integration harness uses isolated saves and exercises the normal game scene
through an actual MCP stdio subprocess, including selection, preview, combat
resolution, stale-state protection, and presentation completion notifications.
Pass `--visible` to run it with a game window. The focused Godot settings test
also checks persisted enable/disable behavior and token redaction. These checks
do not constitute a complete expedition played through MCP or a human playtest.
