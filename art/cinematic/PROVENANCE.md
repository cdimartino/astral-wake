# Opening cinematic

The nine-second film uses the project's Cartographer portrait, Glass Beyond background, Astral Wake Display font, and animated star/light elements. The opening score plays live from the selected sound bank.

To render the picture:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tools/render_opening.gd --write-movie art/cinematic/opening.ogv --fixed-fps 30 --max-fps 30
```

The packaged picture is 1440×900 at 30 fps. Playback is local, skippable, fades into the title screen, and is bypassed by reduced-motion settings.
