# OpenCode integration (opt-in, V2)

This is an example, not an active project configuration. It never connects until
you copy/merge it into your own OpenCode V2 configuration and enable it. Do not
commit an active configuration or credentials, and do not replace unrelated MCP
entries. Nothing here changes your global settings.

## Setup

1. Start a compatible Astral Wake app. In **Settings → Local AI control (MCP)**,
   explicitly enable local control and obtain its loopback port and token. Keep
   the token private. Use the same port/token for this client; no credential file
   is required. The bridge is local only, not a remote service.
2. In the shell that will **launch OpenCode**, set `ASTRAL_MCP_PORT` to that port
   and `ASTRAL_MCP_TOKEN` to that token. For example, these zsh prompts avoid
   writing the token literally into shell history:

   ```zsh
   read 'ASTRAL_MCP_PORT?Game loopback port: '
   read -s 'ASTRAL_MCP_TOKEN?Game token (hidden): '; printf '\n'
   export ASTRAL_MCP_PORT ASTRAL_MCP_TOKEN
   opencode
   ```

   An already-running OpenCode process does **not** acquire environment variables
   exported later in another shell. If its launch environment lacks these values,
   launch a new OpenCode process from the prepared shell. Config reload cannot
   change process environment. Never paste credentials into an AI conversation.
3. Merge [`opencode.jsonc`](opencode.jsonc)'s `mcp.servers.astral-wake` entry into
   your chosen OpenCode V2 config. Replace the absolute Python script path with
   the actual source checkout path (including `tools/astral_mcp.py`); the game
   bundle does not replace the source-shipped Python host. Python 3 is required,
   with no pip dependencies. Set `disabled` to `false` when ready to connect.
   The command/environment placeholders are resolved from OpenCode's process
   environment; this sample contains no actual token.

OpenCode watches configuration live; `/reload` is optional and restarting is not
needed just to apply a config edit. Environment changes are the separate caveat
above. An alternative local CLI setup (replace the absolute path and `PORT` with
your actual path and numeric port) is:

```sh
opencode mcp add astral-wake --env 'ASTRAL_MCP_TOKEN={env:ASTRAL_MCP_TOKEN}' -- python3 /absolute/path/tools/astral_mcp.py --port PORT
```

This adds configuration where your OpenCode CLI is configured to write it; review
that destination before using it. Prefer the disabled sample if you want to
review the entry before allowing a connection. To disconnect, disable the entry;
to revoke game-side access, disable local AI control in the game's Settings.

## Using it

OpenCode uses Code Mode by default: discover the server's tools with `search`
and use the returned exact call signatures under `tools['astral-wake']`; do not
guess a signature. The MCP initialization instructions supply gameplay guidance:

- Read `get_state`, inspect `legal_actions`, then call `act` with the exact
  observed `expected_revision`. The game validates semantic commands/arguments.
- Select card → connected organ route → target, `preview` the live selection,
  then confirm. After busy transitions, wait for completion and refresh state.
- `wait_for_state` accepts `after_revision` and at most 30000 ms. The client
  execution timeout is 45000 ms to leave room for bridge I/O.
- `astral://state` supports resource reads and subscriptions. Notifications are
  advisory; responses and fresh reads are authoritative.
- Never automatically retry an uncertain mutation after disconnect. Re-read
  state first. Session metadata such as `_meta.sessionID` is not authentication;
  only the private bridge token authorizes access.

Blind-play guarantees depend on the connected game's state projection. The old
v0.2.0 app still exposes hidden information; updating this host alone does not
make that old app fully blind. Do not inspect hidden data, saves or secrets to
choose actions, and do not describe an old-app session as fully blind.

Reference: [OpenCode MCP servers](https://opencode.ai/docs/mcp-servers).
