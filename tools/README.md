# Tools

## Overview

Repository tooling separates verification (`check.sh`) from downloading Godot (`bootstrap.sh`), generating authored assets (`hull_score/build.py`, `make_font.py`, `make_organ_art.py`), capturing presentation material (`capture_screenshots.gd:capture`, `render_opening.gd:_setup`), and building/distributing macOS bundles (`export_macos.sh:--export-release`, `package_release.sh:archive`). These are developer entry points, not game runtime modules; the screenshot tool deliberately instantiates the runtime UI (`capture_screenshots.gd:Main`).

## Interface

Run the following commands from the repository root. Shell entry points also change to that root themselves (`bootstrap.sh`, `check.sh`, `export_macos.sh`, `package_release.sh`: `cd`).

| Tool / source | Entry point and contract |
| --- | --- |
| [bootstrap.sh](./bootstrap.sh) | `bash tools/bootstrap.sh`: download/cache Godot **4.7.2-stable** macOS universal and export-template archives, validate pinned SHA-256 digests, extract the editor and `templates/macos.zip`, then print `--version` (`base`, `CHECKSUMS`, `--version`). |
| [check.sh](./check.sh) | `bash tools/check.sh`: run Python content/audio/art checks, Godot editor import, headless game/UI tests, a CoreAudio smoke test, and a seeded tactical playthrough (`--self-test`, `--editor --import --quit`, `--audio-driver CoreAudio`, `--seed=424242 --policy=tactical`). |
| [export_macos.sh](./export_macos.sh) | `bash tools/export_macos.sh`: import with the cached engine, export preset `macOS` into temporary staging, verify the signature, and copy to `dist/Astral Wake.app` (`--export-release`, `codesign --verify --deep --strict`, `ditto`). |
| [package_release.sh](./package_release.sh) | `bash tools/package_release.sh`: package an existing exported app as `dist/Astral-Wake-0.3.0-macos.zip`; verify bundle version, clean/re-sign a staged copy, verify both architectures before and after archive round-trip, then print SHA-256. Pass a source app and output path to keep previous builds intact; export likewise accepts a new destination. |
| [hull_score/build.py](./hull_score/build.py) | `python3 tools/hull_score/build.py --pack`: rebuild the editable SF2/SFZ and multitrack MIDI archive, reference mixes and runtime bank from acoustic source recordings. |
| [make_font.py](./make_font.py) | `python3 tools/make_font.py` with `fontTools` and Pillow available: build `art/fonts/AstralWake-Display.ttf` and `AstralWake-Display-preview.png` (`GLYPHS`, `glyph(paths)`, `build()`, `DEST`). The module docstring offers a `PYTHONPATH` example, not dependency installation. |
| [make_organ_art.py](./make_organ_art.py) | `python3 tools/make_organ_art.py`: generate 18 authored 240×240 SVG specimens in `art/organs/`, using only the standard library (`SPECIMENS`, `core(kind)`, `specimen(tint, shell, kind, variant)`, `OUT`, `__main__`). |
| [capture_screenshots.gd](./capture_screenshots.gd) | Run the cached Godot engine with `--path . --script tools/capture_screenshots.gd`, optionally appending `-- --anatomy-sample`. Captures ship selection, overmap, and three ships' combat views by default; the option captures only three `*-anatomy.png` views (`capture()`, `shot(filename)`, `OS.get_cmdline_user_args()`). |
| [render_opening.gd](./render_opening.gd) | Run Godot with `--path . --script tools/render_opening.gd`; use Godot Movie Maker when recording (the script header specifies 30 fps). Builds a 1440×900 animated title scene for the live opening score and exits at nine seconds (`_setup()`, `_process(delta)`). It does not itself select a movie output path. |

## Invariants

- Shell workflows are fail-fast (`set -euo pipefail` in all four `.sh` files). Verification and export use `.tools/Godot.app/Contents/MacOS/Godot`; bootstrap supplies that exact location (`check.sh:engine`, `export_macos.sh:engine`, `bootstrap.sh:ditto`). These shell workflows depend on macOS utilities; checks explicitly request CoreAudio (`bootstrap.sh:ditto`, `export_macos.sh:codesign`, `package_release.sh:PlistBuddy`, `check.sh:--audio-driver CoreAudio`).
- Cached downloads must match both pinned checksums even when no download occurs. Existing cache files are reused rather than automatically repaired, and executable/template extraction is conditional (`bootstrap.sh:CHECKSUMS`, `-f`, `-x`).
- Packaging requires an existing app whose `CFBundleShortVersionString` equals the hard-coded `version`; both `arm64` and `x86_64` must verify. The staged app is ad-hoc signed with preserved entitlements and must lack FinderInfo/ResourceFork metadata; signature and architecture checks repeat after unzip (`package_release.sh:version`, `codesign --sign -`, `xattr -r`, `lipo -verify_arch`).
- The sound bank maps gameplay cues and score parts to named sample patches. The authoring package documents MIDI tracks, source material, and program mappings; see [the workshop](../docs/sound-workshop.md).
- Font outlines are authored geometry; lowercase maps to uppercase glyphs, digits have fixed advances, timestamps are fixed, and generation asserts printable ASCII coverage, vertical bounds, positive advances, and preview text bounds (`make_font.py:GLYPHS`, `glyph`, `build`). Organ cores must be keys of the motif table used by `core(kind)` (`make_organ_art.py:SPECIMENS`, `core`).
- Screenshots use an isolated `ASTRAL_SAVE_DIR`, skip the intro, disable GUI input, and wait for rendered frames before PNG output. The seed search tries `2026..2125` for a requested starting region but does not assert a match; failed node selection or PNG saving exits with error (`capture_screenshots.gd:_initialize`, `expedition`, `settle`, `shot`, `capture`).
- Opening rendering constructs its own scene rather than loading game state; it loads specific background, ship and font assets and uses star seed `87412` (`render_opening.gd:_setup`).

## Side Effects

- Bootstrap performs GitHub downloads and creates/reuses files under `.tools/`; asset generators create output directories and overwrite their named WAV/TTF/PNG/SVG assets (`bootstrap.sh:curl`, `mkdir`, `ditto`, `unzip`; `hull_score/build.py`; `make_font.py:build`; `make_organ_art.py:__main__`).
- Checks create and export a temporary save directory, import project assets, and execute tests. `check.sh` has no cleanup trap for its `/tmp/astral-check.*` directory (`ASTRAL_SAVE_DIR`, `--editor --import --quit`).
- Export imports assets, stages under `/tmp/astral-export.*`, and copies into `dist/`; its staging directory is retained and printed (`export_macos.sh:staging`, `ditto`, `printf`). Packaging modifies only its staged app while cleaning metadata and signing, moves the resulting archive into `dist/`, and removes its temporary staging directory on exit (`package_release.sh:staging`, `trap`, `find -delete`, `codesign`, `mv`).
- Screenshot capture mutates in-memory run/UI state, changes process environment, writes `docs/screenshots/*.png`, and stops ambience before exit. The output directory is not created by the tool (`capture_screenshots.gd:_initialize`, `expedition`, `shot`, `capture`). Opening rendering loads project assets, animates nodes, and quits; movie output is controlled externally by Godot, not a script file writer (`render_opening.gd:_setup`, `_process`).

## Verification

Run **`bash tools/check.sh`** with the cached macOS Godot executable available. This is the actual repository verification entry point, not an asset-generation or release-build command (`check.sh:engine`, `--editor --import --quit`). It runs:

1. `tests/validate_content.py data/catalog.json --self-test`, `tests/check_audio.py`, and `tests/check_art.py` (`check.sh`: Python invocations).
2. Godot scripts `run_tests.gd`, `balance_tests.gd`, `enemy_tactics_tests.gd`, `enemy_tactics_ui_test.gd`, `expansion_tests.gd`, `expansion_ui_test.gd`, `organ_routing_test.gd`, `ui_legibility_test.gd`, `combat_presentation_test.gd`, `audio_settings_test.gd`, and `ui_smoke.gd` under `tests/` (`check.sh:--script`).
3. `tests/audio_smoke.gd` with CoreAudio and `tests/playthrough.gd` with seed `424242` and tactical policy (`check.sh:--audio-driver CoreAudio`, `--seed=424242 --policy=tactical`).

`bootstrap.sh` downloads prerequisites; the `make_*.py` scripts regenerate assets; the two presentation scripts capture/render; `export_macos.sh` builds; `package_release.sh` packages. Their checksum, font assertions, signature, and architecture checks validate their own operations, but do not replace `check.sh` (`bootstrap.sh:CHECKSUMS`, `make_font.py:build`, `export_macos.sh:codesign`, `package_release.sh:lipo`).
