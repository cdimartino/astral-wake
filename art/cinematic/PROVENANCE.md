# Opening cinematic

The nine-second film is rendered entirely from this project's original Cartographer portrait, Glass Beyond background, original Astral Wake Display font, animated star/light elements, and an original synthesized score. No external video footage is used.

Rebuild the score with `tools/make_audio.py`, import it in Godot, then render:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tools/render_opening.gd --write-movie art/cinematic/opening.ogv --fixed-fps 30 --max-fps 30
```

The packaged film is 1440×900 at 30 fps with stereo audio. Playback is local, skippable, fades into the title screen, and is bypassed by reduced-motion settings. Movie rendering is build tooling, not a gameplay dependency.
