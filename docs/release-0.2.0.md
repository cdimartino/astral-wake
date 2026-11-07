# Astral Wake 0.2.0

## Live game control through MCP

- Control the running game through a source-shipped, dependency-free Python MCP
  server. Commands use the same visible controls as manual play.
- Read authoritative state and available actions, preview combat selections,
  and receive state-change notifications. Responses distinguish resolved game
  state from animations still playing.
- Enable local AI control in Settings. Enablement, port, and authentication token
  persist across launches; disabling immediately disconnects clients.
- Authenticated loopback access, revision checks, bounded requests, and explicit
  command validation protect the control boundary. Credentials are omitted from
  exported game-state snapshots.
- Preserve the current game's glossary, terminology, tooltips, and discovery
  documentation alongside the MCP implementation.

## Setup

Download the macOS app archive and the matching source archive. Enable
**Local AI control (MCP)** in Settings, then configure your MCP client to run
`tools/astral_mcp.py` from the source checkout. Python 3 is required; no pip
dependencies are needed. See [the setup guide](mcp.md).

The macOS app is universal (Apple Silicon and Intel) and ad-hoc signed, not
notarized. Local runtime verification is on Apple Silicon.

## Verification scope

The windowed MCP integration exercises settings, expedition startup, card/organ/
target selection, preview, card resolution, end turn, immediate state, animation
completion, authentication, stale-state rejection, notifications, and shutdown.
Focused tests cover persisted configuration and credential redaction. Existing
game checks cover rules, content, UI geometry, audio, and seeded expeditions.
This is not a human playtest or a complete expedition driven through MCP.

The release check suite exited successfully. The enemy-tactics UI test still
prints an audio-resource cleanup warning at process exit despite zero assertion
failures; the MCP tests and windowed integration logs are clean.
