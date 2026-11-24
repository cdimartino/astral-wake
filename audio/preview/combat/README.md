# Per-event Audio Preview assets

These are isolated events, **not playback of a mixed review sampler**.
`build.py` extracts the retained reviewed articulations without resynthesis,
normalization or a new dependency. `provenance.json` records exact source
hashes/frame cuts and output hashes.

| Event | Asset duration | Bus | Default runtime gain |
| --- | ---: | --- | ---: |
| Enemy kinetic launch | 0.30s | Combat | +6.0206dB |
| Enemy kinetic strike | 0.76s | Combat | +6.0206dB |
| Enemy sonic launch | 0.30s | Combat | +6.0206dB |
| Enemy sonic strike | 0.91s | Combat | +6.0206dB |
| Ward | 0.73s | Combat | +6.0206dB |
| Retained kill signature | 0.38s | Combat | 0dB |
| R2 short minor clear | 1.70s | Music | 0dB |

The attack/ward mock authored its replacement PCM in **final output** at a
reference Master 0.5. +6.0206dB restores that level before the real Master
fader, not a global loudness increase. Kinetic/sonic use their original
16/9-damage reference levels; actual damage strength adjusts around these.
Do not apply the old enemy .88 pitch again: movement/pitch is already baked.

Kill/clear diagnostics were captured **pre-category/pre-Master** with their
authored envelopes/gains already applied, so their correct runtime gain is
0dB. R2's listening profile was Master 0.7, Music 0.22, Combat 1. Runtime
honors the real category sliders; it does not secretly bake the review's
Music attenuation into the resource or change saved preferences.

`CombatAudioPreview` uses existing Sound Desk controls:
- Enemy attacks → their corresponding `combat_*` cues.
- Ward → `combat_shield`.
- Kill → `combat_vent` control/group.
- Clear → `score_seam_air` control/group and `vessel motif` track.

Explicit user patch bindings or a user-selected external bank take precedence
through HullAudio's validated player. Gain/pitch/pan and cue/group/track
mute/solo are retained; new voices appear in HullAudio's trace with
`preview_event` and `preview/NAME` labels. The default Sound Desk audition of
a legacy cue still means that original cue; these preview events are a
presentation-only replacement, not new editable bank entries.

The production `Main._combat_sound` interceptor consumes only enemy
kinetic/sonic launch/strike and shield callbacks. Existing throttles remain;
original player attacks are not replaced. `EnemyDefeatAudio.resolved_batch`
remains the actual-commit entry point, deduplicates grouped deaths, plays one
kill and (only on encounter clear) schedules the short response after 0.45s.
Stinger-off suppresses the musical clear, not the Combat kill; guardian and
voyage-ending slots are never replaced.

No factory bank/source sample, master volume, game rules or personal saves
are changed by this component.
