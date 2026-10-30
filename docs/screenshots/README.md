# Gameplay screenshots

These PNGs are unedited 1440 × 900 viewport captures rendered by the current native Godot game. They show real seeded opening maps and encounters; no cards, enemy stats, hull values, or rewards are injected. The combat images show a command preview before confirmation, rather than a completed battle.

| Image | Scene |
| --- | --- |
| `ship-selection.png` | All three playable vessels |
| `overmap.png` | Crown of Storms, seeded branching destinations |
| `cartographer-combat.png` | Cartographer in Cradle of Embers; Lens → Fork → Echo preview |
| `palimpsest-combat.png` | Palimpsest in the Tidal Archive; Scribe preview |
| `hollow_choir-combat.png` | Hollow Choir in Crown of Storms; Conductor preview |

Regenerate from the repository root with the pinned engine:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_screenshots.gd --windowed --resolution 1440x900
```

The capture script uses a unique temporary save folder and skips the opening film. It never reads or replaces player progress. Documentation assets and capture tools are excluded from the game export.
