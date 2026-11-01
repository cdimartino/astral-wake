#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine="${GODOT_BIN:-.tools/Godot.app/Contents/MacOS/Godot}"
export ASTRAL_SAVE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/astral-check.XXXXXX")"
python3 tests/validate_content.py data/catalog.json --self-test
python3 tests/reward_catalog_test.py
python3 tests/production_evolutions_test.py
python3 tests/route_effects_validator_test.py
python3 tests/check_audio.py
python3 tests/check_art.py
"$engine" --headless --path . --editor --import --quit
"$engine" --headless --path . --script tests/run_tests.gd
"$engine" --headless --path . --script tests/effective_card_test.gd
"$engine" --headless --path . --script tests/evolutions_test.gd
"$engine" --headless --path . --script tests/production_evolutions_test.gd
"$engine" --headless --path . --script tests/palimpsest_evolutions_test.gd
"$engine" --headless --path . --script tests/choir_evolutions_test.gd
"$engine" --headless --path . --script tests/evolutions_ui_test.gd
"$engine" --headless --path . --script tests/palimpsest_evolutions_ui_test.gd
"$engine" --headless --path . --script tests/choir_evolutions_ui_test.gd
"$engine" --headless --path . --script tests/card_zones_test.gd
"$engine" --headless --path . --script tests/known_selections_test.gd
"$engine" --headless --path . --script tests/install_engines_test.gd
"$engine" --headless --path . --script tests/route_effects_test.gd
"$engine" --headless --path . --script tests/route_effects_ui_test.gd
"$engine" --headless --path . --script tests/seed_tests.gd
"$engine" --headless --path . --script tests/reward_distribution_test.gd
"$engine" --headless --path . --script tests/reward_distribution_ui_test.gd
"$engine" --headless --path . --script tests/manual_replay_tests.gd
python3 tests/manual_replay_cli_test.py "$engine"
python3 tests/reward_fingerprint_test.py "$engine"
python3 tests/evolution_replay_test.py "$engine"
python3 tests/evolution_replay_test.py "$engine" --production
python3 tests/evolution_replay_test.py "$engine" --palimpsest
python3 tests/evolution_replay_test.py "$engine" --choir
python3 tests/install_engine_replay_test.py "$engine"
"$engine" --headless --path . --script tests/seed_ui_test.gd
"$engine" --headless --path . --script tests/balance_tests.gd
"$engine" --headless --path . --script tests/enemy_tactics_tests.gd
"$engine" --headless --path . --script tests/enemy_tactics_ui_test.gd
"$engine" --headless --path . --script tests/expansion_tests.gd
"$engine" --headless --path . --script tests/expansion_ui_test.gd
"$engine" --headless --path . --script tests/organ_routing_test.gd
"$engine" --headless --path . --script tests/conduit_visibility_test.gd
"$engine" --headless --path . --script tests/last_command_test.gd
"$engine" --headless --path . --script tests/deck_overlay_test.gd
"$engine" --headless --path . --script tests/card_effects_test.gd
"$engine" --headless --path . --script tests/route_resource_preview_test.gd
"$engine" --headless --path . --script tests/card_piles_test.gd
"$engine" --headless --path . --script tests/split_preview_test.gd
"$engine" --headless --path . --script tests/keyword_tooltip_test.gd
"$engine" --headless --path . --script tests/ui_legibility_test.gd
"$engine" --headless --path . --script tests/combat_presentation_test.gd
"$engine" --headless --path . --script tests/actor_motion_test.gd
"$engine" --headless --path . --script tests/audio_settings_test.gd
"$engine" --headless --path . --script tests/ui_smoke.gd
"$engine" --headless --path . --script tests/intro_test.gd
"$engine" --headless --path . --script tests/intro_test.gd -- --skip
"$engine" --headless --audio-driver "${ASTRAL_AUDIO_DRIVER:-CoreAudio}" --path . --script tests/audio_smoke.gd
"$engine" --headless --path . --script tests/playthrough.gd -- --seed=424242 --policy=tactical
