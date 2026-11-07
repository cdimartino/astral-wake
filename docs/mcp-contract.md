# Live MCP bridge contract

Implementation contract: the source-shipped Python stdio MCP host connects to an
opt-in Godot main-thread TCP bridge. No HTTP, arbitrary evaluation, or save-file
mutation. Fresh profiles have no listener. Players may enable/disable MCP in
Settings; the enabled preference, concrete loopback port, and cryptographically
generated token persist across launches. Disabling closes clients and the
listener immediately and persists the disabled preference. A busy saved port
must report an error rather than silently change endpoints. Never include the
saved token in MCP state snapshots.

## Wire protocol

UTF-8 newline-delimited JSON on `127.0.0.1`. As an alternative to Settings,
automated launches enable the bridge with `ASTRAL_MCP_PORT` (1–65535) and
`ASTRAL_MCP_TOKEN` (at least 32 characters).
One request per line:

```json
{"id":"unique-id","token":"secret","method":"get_state","params":{}}
```

Methods: `get_state`, `act`, `preview`. `act` params are
`{"action":"command","args":{},"expected_revision":12}`. Every act requires
the expected revision; unknown or malformed input must not mutate state.

Response: `{"id":"unique-id","ok":true,"state":{...},"result":{...}}` or
`{"id":"unique-id","ok":false,"error":{"code":"stale_revision","message":"..."},"state":{...}}`.
Unauthenticated errors must not disclose state. State contains `revision` (int),
`busy` (bool), `ui` (screen, overlay, selection, notice), `run`, `profile`, and
`legal_actions` (explicit commands and argument descriptions/options).
`preview` params use the live selection and do not mutate.

Command names and parameters are discoverable from `legal_actions`; include all
normal gameplay, title/character flows, overlays and settings. Game-side schema
is authoritative. MCP host passes whitelisted semantic commands, not method names
to invoke dynamically. Mutations use shared controller handlers/presentation.

Recent request IDs are cached per connection: identical retries return their
original response; ID reuse with different content returns `duplicate_id`.
Stable errors include `unauthorized`, `invalid_request`, `unknown_action`,
`invalid_args`, `stale_revision`, `busy`, `unavailable`, and `internal_error`.
Bound input to 1 MiB, clients to 4, work per frame, and retry cache to 128 IDs.

After authenticated activity, bridge sends advisory messages
`{"event":"state_changed","state":{...}}` on externally visible changes,
including manual interaction and presentation completion. Responses are the
authoritative result. Revision must cover UI-only and busy transitions too.

## MCP host

`tools/astral_mcp.py`: Python 3 standard library, MCP JSON-RPC stdio (stdout
protocol only), `--port` and token from `ASTRAL_MCP_TOKEN`, loopback only.
Tools: `get_state`, `act` (action, args, expected_revision), `preview`, and
`wait_for_state` (after_revision, timeout_ms capped at 30000). State resource
`astral://state` with subscriptions/resource-updated notifications. Never retry
a mutation automatically after a connection loss. Bound I/O and timeouts;
explain uncertain outcomes and require a fresh state read.

## Evidence required

Exercise real stdio MCP → authenticated loopback → instantiated live main scene;
assert UI selections/overlays and game mutations, immediate post-action state,
busy/stale/auth/invalid-input protections, manual updates, and completion updates.
Use isolated saves. Run existing `tools/check.sh` once after reconciliation.
Visible smoke evidence supplements headless main-scene integration; neither is
a claim of testing an entire expedition through the new MCP.
