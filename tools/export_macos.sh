#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${1:-dist/Astral Wake.app}"
if [[ -e "$destination" ]]; then
  printf 'Refusing to overwrite existing app: %s\n' "$destination" >&2
  exit 1
fi
mkdir -p "$(dirname "$destination")"
engine='.tools/Godot.app/Contents/MacOS/Godot'
"$engine" --headless --path . --editor --import --quit
# Stage outside synced Documents so Finder metadata cannot race signature verification.
staging="$(mktemp -d "${TMPDIR:-/tmp}/astral-export.XXXXXX")"
"$engine" --headless --path . --export-release macOS "$staging/Astral Wake.app"
codesign --verify --deep --strict "$staging/Astral Wake.app"
ditto "$staging/Astral Wake.app" "$destination"
file "$destination/Contents/MacOS/Astral Wake"
printf 'Verified build staged at %s\n' "$staging/Astral Wake.app"
