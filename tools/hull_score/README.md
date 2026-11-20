# Astral Wake · Living Hull

**Start with `midi/region_2.mid` and `AstralWake.sf2`.** Import the MIDI as separate tracks and point those tracks to the SoundFont. Start playback from the beginning to send the bank and program changes. Solo **rim** for the almost attackless bowed glass; solo **vessel motif** for the shorter glass release. Swap the rim track to bank 0 program **5** to hear it as the cooling tail instead of the rubbed sustain. The short song `midi/guardian_2.mid` can follow the map arrangement on a separate lane. The first contact lands at the reveal; a low psaltery enters 60 ms later, then thin rubbed glass at 1.23 s.

| In the standalone ZIP | Use |
|---|---|
| `AstralWake.sf2` | SF2 2.01, embedded samples, one independently playable melodic program per patch. Normal bank 0 for all scores; banks 1 and 2 for Foley and alternate takes. No GM fallback or percussion-channel dependency. |
| `midi/*.mid` | Editable Type 1 SMFs at 480 PPQ. The conductor owns tempo, meter and section/loop markers. Each named musical track has its own channel, bank select and program change. |
| `instruments/*.sfz`, `samples/*.wav` | A separate SFZ for each patch, with relative sample references. Move the two directories together. Samples are mono, 24 kHz, signed 16-bit PCM and play once; no sustaining synthetic layer. |
| `references/*.wav` | Stereo, full-length mix of each piece with written tension included. `glass-guardian-{off,on}.wav` are the matched desk comparison. `LISTENING.json` gives their trim, peak and spotting times. These are score references rather than recordings of the game mixer. |
| `PATCH-MAP.md`, `bank.json` | Numeric bank/program, display name, root key, channel and track assignments. The JSON includes compiler output, cue variants, bus assignments and factory gain. |
| `presets/{factory,alternate}.json` | Factory mapping with original round robins; or a complete alternate override. Both keep the chosen guardian stinger enabled. |
| `source/`, `SOURCES.json`, `authoring/` | Original licensed recordings, upstream path/revision/digest, license text and offline build tools. `SHA256.json` covers the finished files. |

### Rebuild or edit

Python **3.9+**, standard library only. No network or external sample converter needed. In a repository checkout:

```sh
python3 tools/hull_score/build.py --pack
python3 tests/check_audio.py --pack dist/Astral-Wake-Living-Hull.zip
```

The first command rebuilds `audio/hull/{bank.json,samples/}` from the source recordings and `.mid` masters, then creates the expanded and zipped `dist/Astral-Wake-Living-Hull`. The second compares the bank to its sources and validates the archive. `build.py --midi-only` skips the PCM edits when iterating on a piece. **Do not run `compose.py` after a DAW edit** unless you want to restore the originally engraved masters.

From the root of an **extracted standalone ZIP**:

```sh
python3 authoring/build.py --pack
```

This reads the pack's own `source/` and `midi/`, writes its new runtime bank to `rebuilt/bank/` and its new archive to `rebuilt/`. Both forms accept `--bank` and `--dist` to override their output locations. Paths are resolved relative to the script, not the current directory.

To change a part, edit its notes, velocities, tempo, markers or musical program in a DAW and save to its existing Type 1 master. Keep an initial conductor tempo, meter, named sections, at least two named playable tracks and one melodic channel per part. Each track must explicitly select bank MSB and LSB and a mapped program before its first note. Overlapping notes of the same pitch on the same track, sustain CC, pitch bend, SysEx and unknown events are rejected with the file name rather than silently lost. Loader speed is `2^((note − patch root)/12)`; reference render timing comes from the actual MIDI clocks. All air, pressure and tail sounds are pitched sample articulations; no extra nonpitched bed stem is needed to reproduce these mixes.

To add a recorded patch, add its verified CC0 input and SHA-256 to `materials.SOURCES`, then append a `MUSIC` row or a Foley gesture in `materials.py`. Preserve existing program order: composers may address programs by number. A `Cut` gives the start offset, pitch shift, duration, cutoff, attack and release. A layered gesture uses multiple cuts with relative starts/weights. Run `build.py --pack` for PCM/SF2/SFZ and score output together. Bind a stable cue ID to the new patch in the game or change the MIDI program to score with it.

### Recording credits

The recordings are from Sam Gossner / [Versilian Community Sample Library](https://github.com/sgossner/VCSL/tree/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e), revision `c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e`, under **CC0 1.0 Universal** (full text in `source/LICENSE-VCSL.txt`). The seven original sketch takes are the fast wineglass sustain/release, vibrating bass recorder, long-bowed psaltery, low shaker, low log drum and muted frame drum. An actual second shaker and frame drum take and the next log drum velocity layer supply round robins. The SF2, SFZ and game WAVs contain edited slices and layers of those takes only.
