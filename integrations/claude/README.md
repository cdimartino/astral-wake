# Anthropic clients: Claude Code and Claude Desktop

These are separate opt-in examples, not installed configurations. Start the
game, explicitly enable **Settings → Local AI control (MCP)**, and privately
obtain its port/token. Requires Python 3 and the source checkout's
`tools/astral_mcp.py`; no pip packages. Never paste credentials into chat or
commit a filled-in configuration. Preserve unrelated server entries.

## Claude Code

[claude-code.mcp.json](claude-code.mcp.json) uses Claude Code's documented
`${VAR}` expansion, **not** OpenCode's `{env:VAR}` syntax. Replace the absolute
script path. Export `ASTRAL_MCP_PORT` and `ASTRAL_MCP_TOKEN` in the shell before
launching Claude Code (use a hidden shell prompt for the token, not a literal
history entry). Merge the example into a privately managed `.mcp.json` only
when ready to opt in; project entries require approval. Do not commit an active
project configuration to force connections for every contributor.

Alternatively add a local-scoped server from that prepared shell (the shell
expands the numeric port; the token remains inherited, not on the command line):

```sh
claude mcp add --transport stdio --scope local astral-wake -- python3 /absolute/path/tools/astral_mcp.py --port "$ASTRAL_MCP_PORT"
```

`--` separates Claude options from the host command. Claude Code also documents
`--env KEY=value`; this example avoids putting the literal token in CLI args
or saved settings. The JSON example explicitly maps the environment reference.
Use `/mcp` to inspect/reconnect/disable the server. An already-running process
does not acquire exports made later elsewhere; relaunch from the prepared shell
if its launch environment lacks them.

## Claude Desktop

In **Settings → Developer → Edit Config**, merge
[claude-desktop.json](claude-desktop.json) into your personal configuration
(macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`).
Replace both absolute paths, the numeric port, and the private token placeholder
**locally**. This is an explicit local secret configuration: keep it private,
out of git, and restrict its filesystem access. No `${VAR}` or `{env:VAR}`
interpolation is assumed for Desktop. Do not copy the placeholders unchanged.

GUI launches commonly do not inherit terminal environment or PATH. Absolute
Python/script paths plus explicit `env` avoid that assumption. Alternatively,
only omit the explicit token if you have independently arranged the Desktop
process environment; exporting in a separate terminal is not enough. Completely
quit and restart Desktop after the edit. Review connector/tool approvals before
use. Remove the entry to disconnect, and revoke access in the game's Settings.

## Gameplay and limits

Initialization instructions guide both clients: read `get_state` and
`legal_actions`, call semantic `act` with the exact observed revision; select
card → route → target and `preview` before confirming. Use `wait_for_state`
(max 30000 ms) for completion, then refresh state. Do not automatically retry
uncertain mutations. `astral://state` supports reads/subscriptions where exposed
by the client. Do not inspect secrets, saves or hidden information for gameplay.
The old v0.2.0 app exposes hidden state; this host alone does not make it fully
blind.

Official sources checked:
- [Claude Code MCP](https://code.claude.com/docs/en/mcp): stdio CLI, scopes,
  `mcpServers`, `${VAR}` expansion and environment configuration.
- [MCP local-server guide for Claude Desktop](https://modelcontextprotocol.io/docs/develop/connect-local-servers):
  `mcpServers` JSON, `env`, config location and complete restart.

Examples are syntax-validated, not installed into a personal account. No live
Claude Code/Desktop connection or client-specific resource UI behavior is claimed.
