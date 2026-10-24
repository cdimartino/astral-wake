#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine='.tools/Godot.app/Contents/MacOS/Godot'
export ASTRAL_SAVE_DIR="$(mktemp -d /tmp/astral-check.XXXXXX)"
python3 tests/validate_content.py data/catalog.json --self-test
python3 tests/check_audio.py
python3 tests/check_art.py
"$engine" --headless --path . --editor --import --quit
"$engine" --headless --path . --script tests/run_tests.gd
"$engine" --headless --path . --script tests/expansion_tests.gd
"$engine" --headless --path . --script tests/expansion_ui_test.gd
"$engine" --headless --path . --script tests/combat_presentation_test.gd
"$engine" --headless --path . --script tests/ui_smoke.gd
"$engine" --headless --audio-driver CoreAudio --path . --script tests/audio_smoke.gd
"$engine" --headless --path . --script tests/playthrough.gd -- --seed=424242
