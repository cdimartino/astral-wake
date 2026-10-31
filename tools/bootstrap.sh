#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine_only=0
if [ "${1:-}" = '--engine-only' ]; then
  engine_only=1
fi
mkdir -p .tools
base='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable'
if [ ! -f .tools/godot.zip ]; then
  curl -fL --retry 2 --max-time 600 "$base/Godot_v4.7.2-stable_macos.universal.zip" -o .tools/godot.zip
fi
shasum -a 256 -c <<'CHECKSUMS'
c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e  .tools/godot.zip
CHECKSUMS
if [ ! -x .tools/Godot.app/Contents/MacOS/Godot ]; then
  ditto -x -k .tools/godot.zip .tools
fi
if [ "$engine_only" -eq 0 ]; then
  if [ ! -f .tools/templates.tpz ]; then
    curl -fL --retry 2 --max-time 900 "$base/Godot_v4.7.2-stable_export_templates.tpz" -o .tools/templates.tpz
  fi
  shasum -a 256 -c <<'CHECKSUMS'
f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011  .tools/templates.tpz
CHECKSUMS
  if [ ! -f .tools/macos.zip ]; then
    unzip -p .tools/templates.tpz templates/macos.zip > .tools/macos.zip
  fi
fi
.tools/Godot.app/Contents/MacOS/Godot --version
