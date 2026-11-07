# Runtime scripts

## Overview

Godot GDScript runtime for Astral Wake. The dictionary-based rules engine owns
expedition state and persistence; the programmatic UI presents its forecasts and
results. Drawing controls and the opening film remain presentation-only. This
directory has no child components.

## Interface

- [game.gd](game.gd): `AstralGame` (`RefCounted`), constructed with an optional save
  directory. Exposes `catalog`, `run`, `profile`, and `save_error`; content/readout
  queries include `card`, `enemy`, `powerup`, `character`, `organ`, `region`,
  `owned_card_count`, `card_text`, and `enemy_tactics_text`. Expedition actions are
  `new_run`, `reachable`, `choose_node`, `preview_card`, `play_card`,
  `enemy_attack_preview`, `end_turn`, `choose_reward` (`-1` skips),
  `continue_region`, `buy`, `modify_card`, `cancel_modify`, `recover`,
  `event_choice`, `leave_location`, and `abandon`. Actions return dictionaries
  with `ok`/`error`; combat results also carry presentation records and forecasts.
  `save`, `load_saved`, `run_exists`, and `set_settings` handle lifecycle/settings.
- [save_store.gd](save_store.gd): `AstralSaveStore` (`RefCounted`), optional custom
  directory; `candidates()` supplies primary/backup envelopes and `write(profile,
  run)` returns success. Exposes `error`, `primary_verified`, `recovered`,
  `directory`, `VERSION`, and `MAX_BYTES`; semantic validation belongs to the game.
- [main.gd](main.gd): root `Control`; `_ready` builds assets, audio, UI, and optional
  intro; `_input` routes keyboard commands. Owns `game`, selection/route/target,
  menu/overlay state, and presentation scheduling. `presentation_busy()` reports
  the action lock. Integration seams include `_perform`, `_render`,
  `_feedback_plan`, and `_apply_settings`; UI route availability calls the engine's
  `_validate_route` rather than duplicating its rules.
- [organ_circuit.gd](organ_circuit.gd): noninteractive conduit `Control`, configured
  through `edges`, `severed`, `route`, `available`, `hovered`, `organic`,
  `reduced_motion`, and `tint`. `ORIGIN`, `NODE_SIZE`, `GRAPH_SIZE`, `POSITIONS`, and
  static `center(index)` define console geometry.
- [ship_anatomy.gd](ship_anatomy.gd): noninteractive hull `Control`; `tint` and the
  same geometry constants/static `center(index)` define embedded-organ geometry.
- [organ_socket.gd](organ_socket.gd): noninteractive socket `Control`; `tint`,
  `selected`, `available`, `strain`, `projected`, and `capacity` drive its artwork.
  The parent button owns interaction.
- [organ_visuals.gd](organ_visuals.gd): `RefCounted` holding `READOUTS`, keyed by
  organ ID with `[short effect, condition, hex color]` values; full descriptions
  and engine behavior remain authoritative.
- [space_canvas.gd](space_canvas.gd): noninteractive multi-purpose drawing
  `Control`. `points`/`connections`, `connection_colors`, `map_paths`,
  `active_route`, and `severed` configure paths; `stars`/`animate_stars` configure
  the backdrop; `pulse_start`, `pulse_end`, and `pulse_progress` configure pulses.
  `icon_kind` selects icons; `effect_kind`, `effect_style`, `effect_echo`,
  `effect_from`, `effect_to`, `effect_color`, `effect_route`, and `effect_progress`
  configure combat effects. `draw_ellipse_shape` is a draw-context utility.
- [intent_badge.gd](intent_badge.gd): `Button` with BBCode `explanation`; custom
  hover tooltip and focus tooltip expose the same explanation. Inherited button
  signals allow target selection; `focus_tip` tracks the temporary focus panel.
- [intro_cinematic.gd](intro_cinematic.gd): full-screen `Control` with
  `start(volume)`, idempotent `skip()`, and `finished` signal. Plays the local
  opening video, accepts any key/click to skip, and has a 12-second fallback.

## Invariants

- `game.gd:_validate_route` accepts one to three distinct organs indexed 0–5,
  below strain capacity, connected by real, unsevered battle edges. Organ order
  affects resolution; conduit drawings must reflect that same graph.
- `game.gd:preview_card` and `play_card` share simulation on deep copies; previews
  do not mutate live state or advance its RNG. Successful plays install the
  simulated state before battle-end transitions. RNG state persists as a decimal
  string; content/state integer restoration preserves pile/route equality.
- `game.gd:_valid_run` checks vessel-specific decks, three distinct route regions,
  twelve map layers, unique card UIDs, and combat pile conservation. Combat has
  six strain entries, three maximum command points, trace 0–6, resonance 0–3,
  and hand size at most ten. Deck removal retains at least five cards.
- `game.gd:_attack_payload` caps combined disruption/redirection at half the raw
  attack; redirection needs another living foe. Forecasts account for earlier
  strain actions. Presentation must consume resolved records, not apply damage.
- `save_store.gd:_read` accepts version-1 dictionary envelopes no larger than
  4 MiB. `game.gd:load_saved` migrates supported legacy fields, validates candidates
  in primary-then-backup order, and only marks a semantically accepted primary
  verified. Backup rotation must never promote an unverified primary.
- `main.gd:_layout_stage` preserves a centered 1440×900 logical stage.
  `presentation_busy` gates actions; `feedback_serial` invalidates stale callbacks
  after rerendering. Reduced motion retains result readouts without moving effects.
  Geometry indices and organ IDs must match the engine and `READOUTS`.
- `space_canvas.gd:_draw` prioritizes effects over icons over backdrop/paths;
  callers supply valid nonnegative point/organ indices and request redraws after
  changing ordinary drawing fields. Progress setters request redraw automatically.
- `intro_cinematic.gd:skip` emits completion only once after fading and never
  changes expedition/profile state.

## Side Effects

- `game.gd:_init` reads `res://data/catalog.json` and existing saves. Successful
  state-changing actions normally autosave; `save` updates elapsed time, while
  concluded runs update discovery tiers and bounded history. Save failure is
  reported separately through `save_error`, not an action rollback.
- `save_store.gd:write` creates its directory and writes/flushes/verifies
  `save.pending.json`, optionally rotates through `save.backup.pending.json` to
  `save.backup.json`, then renames the pending file to `save.json`. Directory precedence
  is explicit argument, `ASTRAL_SAVE_DIR`, then Godot's user-data directory.
- `main.gd` loads local art/manifests/fonts/audio, creates/frees scene nodes,
  schedules timers/tweens, changes focus, consumes input, changes window mode,
  and creates/configures global Master/Music/Combat/Interface audio buses.
  Settings save immediately. Audio micro-variation does not consume gameplay RNG.
  Headless mode, `ASTRAL_SKIP_INTRO=1`, or reduced motion suppress the intro.
- Drawing controls only update local animation/drawing state; `intent_badge.gd`
  creates/frees tooltip children. `intro_cinematic.gd` loads local video, plays
  audio on Music (or Master), consumes skip input, fades, emits, and frees itself.
  No runtime network calls are made by these scripts.

## Verification

- From the repository root, run: `bash tools/check.sh`.
- The checked-in runner validates content/audio/art, imports with the bundled
  `.tools/Godot.app/Contents/MacOS/Godot`, runs engine, balance, tactics, expansion,
  routing, UI, presentation, audio and smoke checks, then a seeded tactical
  playthrough. It isolates saves with `ASTRAL_SAVE_DIR`; its audio smoke check
  explicitly uses CoreAudio.
