# Reproduce a listening comparison

In **Settings → Local Sound Workshop**, choose **Enter admin mode · Sound Desk**.
The scene now plays a private copy of the expedition. Close the desk to play it
normally; the workshop badge stays visible. The configured desk key reopens the
console. Choose **Leave admin mode · restore expedition** to return to the
original ship and staged selection. Neither recording nor exporting affects the
expedition save. A named sound preset, however, is intentionally available
outside this session.

## Listen to the same scene twice

```text
scenario load glass-listening
audio preset load factory
scenario replay
```

The included recording lingers in The Glass Beyond, starts a two-foe encounter,
plays Glass Murmur through three organs, catches an incoming attack, repairs,
collects the encounter reward, and reveals the Witness Array. `inspect scenario`
shows the recorded steps and whether the replay finished or stopped on an error.
After it finishes:

```text
audio preset load alternate
scenario replay
```

`scenario stop` cancels future steps. The current animation finishes normally.
For a single sound, use `audio cues`, `audio variants <cue>`, then `audio audition
<cue>` or `audio bind <cue> <variant>` with the IDs Tab offers. `audio voices`
shows bus levels. `effect shield` previews the shield animation and cue without
changing the player’s ward.
Quote multi-word track names: `audio solo "hull contact"`. Tab produces the
complete quoted command for tracks available in the current bank.

Use `audio packs` to list installed banks, `audio bank <name>` to switch, and
`audio bank factory` to return to the shipped one. `audio stinger guardian_2 off`
silences only the Glass Beyond reveal; replay, then turn it `on` and compare.
`audio stinger off` silences all musical stingers without muting the impact
sounds themselves.

## Record your own

1. Use `run start cartographer GLASS1` and `region jump pale_aperture 0`. Complete
   `encounter boss wit` with Tab to start the Witness Array encounter.
2. `scenario checkpoint` captures the full sandbox expedition, including combat
   piles, RNG and staged selection. `card add glass_murmur hand` adds a matching
   UID to both deck and hand. `organ strain 0 1` warms the lens. `inspect piles`
   and `inspect organs` show the new values.
3. Close the desk, play a command, and end a turn. Actual committed combat
   cards (including ordered known-card choices) and enemy phases are recorded
   automatically. For locations or navigation you want to replay, use console
   commands or `act <action> [index]`; `act` completes currently available
   ordinary player controls. Card UIDs survive a reshuffle; hand and foe indices
   refer to the current scene. For timing between steps, use `scenario wait 3`.
4. `scenario save lens-test` stores the starting checkpoint and the command
   sequence. Use `scenario restore` to return to the start, or `scenario replay`
   to run the sequence. After restore, a new mutation starts a new recording
   from the same checkpoint. Replay waits for combat presentation between steps.
5. Tune the mix. `scenario export lens-comparison` writes one
   `lens-comparison.comparison.json` containing the checkpoint, sequence and
   preset’s stable IDs. The console prints its full path. Copy it into the other
   installation’s `hull-workshop/` folder under its save directory, then use
   `scenario import lens-comparison` followed by `scenario replay`. The receiving
   bank must contain the referenced cues/patches; share any external bank
   separately. The bundle contains the **sandbox expedition at the checkpoint**
   (including its seed and piles), not your profile history, settings, or MCP
   credentials.

Use `help <word>` to search by capability. The [generated command table](hull-admin-commands.md)
contains every game command, argument hint, valid state, and recording policy.
Admin commands never appear as MCP methods or player actions.

## Add a game command

Add an entry to `scripts/hull_admin_registry.gd`: argument types, required
state, whether to record it, and the result description. Reuse an argument type
or define its validation and catalog completion in `scripts/hull_admin.gd`.
Implement game edits in `scripts/hull_admin_game.gd` against the supplied
sandbox `Game`. Prefer the real game operation for formation, cost, RNG and
outcome logic. Validate before mutating; a failed command must leave state
unchanged. Use a fixed handler, never a text-selected method or property.

Regenerate the reference with the project’s pinned Godot:

```sh
godot --headless --path . --script tools/hull_admin_reference.gd
godot --headless --path . --script tools/hull_admin_reference.gd -- --check
godot --headless --path . --script tests/hull_admin_test.gd
```
