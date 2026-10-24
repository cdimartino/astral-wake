#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
engine='.tools/Godot.app/Contents/MacOS/Godot'
"$engine" --headless --path . --editor --import --quit
# Stage outside synced Documents so Finder metadata cannot race signature verification.
staging="$(mktemp -d /tmp/astral-export.XXXXXX)"
"$engine" --headless --path . --export-release macOS "$staging/Astral Wake.app"
codesign --verify --deep --strict "$staging/Astral Wake.app"
ditto "$staging/Astral Wake.app" 'dist/Astral Wake.app'
file 'dist/Astral Wake.app/Contents/MacOS/Astral Wake'
printf 'Verified build staged at %s\n' "$staging/Astral Wake.app"
