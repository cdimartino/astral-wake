# Living Hull verification

| Question | Evidence |
| --- | --- |
| Does a change survive export? | `python3 tools/check_exported_hull.py` boots the packaged app in a fresh profile. A second check loads its actual exported pack, switches between the bundled samples and a separately copied WAV bank during playback, rejects a missing bank, and saves a named preset. |
| Can another musician play the files? | Apple’s DLS sampler and AVAudioSequencer rendered the Glass Beyond region and guardian MIDIs with the shipped SF2. The independent `sfizz_render` renderer played the `bow_thread.sfz` patch. `python3 tests/check_audio.py --pack dist/Astral-Wake-Living-Hull.zip` checks all MIDI event mappings, SF2 zones, SFZ paths, original recordings and archive digests. |
| Is the softer beam in the game? | The listening takes used the same Glass Beyond fixture and player-visible MCP actions on the baseline and the new build. The narrow ring in the annotated passage was present after the third organ contact. The new brush and damped impact last under 200 ms, and the repeated beam is quieter. The standalone sample check guards against the strong 1.18 kHz ring returning. |
| Does the opening hand off cleanly? | `tests/intro_test.gd` starts the real film, samples the master mix, and checks that the opening cue fires once, the menu does not start another track, and the mix settles to silence. Run it again with `-- --skip` to exercise the early handoff. Set `ASTRAL_INTRO_TAKE` to a WAV output path to listen to either case. |
| Can the cue and its alternative both be heard? | `tests/audio_smoke.gd` captures real samples from the mixer, including the selectable variants and six regional loops. The guardian comparison retains the same physical contact when the musical stinger is switched off. |
| Does local tuning change an ordinary expedition? | `tests/hull_admin_test.gd` checks the original save and backup bytes across edits, replay and leaving the sandbox. `tests/hull_workshop_test.gd` covers authenticated bridge isolation while the local workshop is open. |

The audio captures establish what reaches the mixer. They do not stand in for a listener’s judgment on headphones or laptop speakers. The guardian and beam choices were informed by feedback on the attached listening comparisons.
