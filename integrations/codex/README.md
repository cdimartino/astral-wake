# Codex (opt-in local stdio)

Start the game and explicitly enable **Settings → Local AI control (MCP)**.
Obtain the port/token privately. Requires Python 3 and the source-shipped host;
no pip dependencies. This example installs nothing and contains no credential.

Merge [config.toml](config.toml) into your chosen Codex configuration
(`~/.codex/config.toml`, or `.codex/config.toml` in a trusted project). Preserve
existing entries. Replace the absolute script path and `REPLACE_WITH_GAME_PORT`
with the game's numeric port; set `enabled = true` only when ready.

Export `ASTRAL_MCP_TOKEN` in the shell **before launching Codex**. `env_vars`
explicitly forwards that variable to the stdio host. A hidden zsh prompt avoids
putting the literal credential in command history:

```zsh
read -s 'ASTRAL_MCP_TOKEN?Game token (hidden): '; printf '\n'
export ASTRAL_MCP_TOKEN
codex
```

There is no assumed `{env:...}` interpolation in TOML arguments. The port is a
literal numeric string. The documented `env` table can set explicit values,
but prefer `env_vars` over storing the token in configuration. Never commit an
active credential/config or paste secrets into chat. A GUI Codex host may not
inherit terminal exports: ensure its own launch environment supplies the token;
reloading a config does not acquire another shell's new environment.

This guide uses the documented TOML route rather than invoking `codex mcp add`
or writing personal settings. Inspect the connected server with `/mcp`. Disable
the entry with `enabled = false`; revoke access in game Settings too.

The host initialization instructions describe the workflow: `get_state` →
`legal_actions` → `act` with the exact revision; stage combat selections and
`preview` before confirming, then bounded `wait_for_state` (max 30000 ms).
Never retry uncertain mutations automatically; refresh state first. Resource
`astral://state` supports reads/subscriptions where the client exposes them.
Old v0.2.0 game builds leak hidden state: this host alone cannot make them fully
blind. Do not inspect hidden information, saves or credentials for gameplay.

Official source checked:
[Codex MCP documentation](https://developers.openai.com/codex/mcp), currently
redirecting to [MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
Config syntax is validated locally; no actual Codex account/config is modified
or end-to-end Codex UI connection claimed.
