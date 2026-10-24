#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

version='0.1.0'
source_app='dist/Astral Wake.app'
archive="dist/Astral-Wake-${version}-macos.zip"
if [[ ! -d "$source_app" ]]; then
  printf 'Export the app first: bash tools/export_macos.sh\n' >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")" != "$version" ]]; then
  printf 'App version does not match release version %s.\n' "$version" >&2
  exit 1
fi

# Keep the signed bundle outside synced Documents while cleaning and verifying it.
staging="$(mktemp -d /tmp/astral-release.XXXXXX)"
trap 'rm -rf "$staging"' EXIT
staged_app="$staging/Astral Wake.app"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$source_app" "$staged_app"
find "$staged_app" -name .DS_Store -delete
codesign --force --deep --sign - --timestamp=none --preserve-metadata=entitlements "$staged_app"
codesign --verify --deep --strict "$staged_app"
/usr/bin/lipo "$staged_app/Contents/MacOS/Astral Wake" -verify_arch arm64
/usr/bin/lipo "$staged_app/Contents/MacOS/Astral Wake" -verify_arch x86_64
if xattr -r "$staged_app" | grep -E 'com\.apple\.(FinderInfo|ResourceFork)' >/dev/null; then
  printf 'Finder metadata remains in the staged app.\n' >&2
  exit 1
fi

COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$staged_app" "$staging/release.zip"
mkdir "$staging/unpacked"
ditto -x -k "$staging/release.zip" "$staging/unpacked"
codesign --verify --deep --strict "$staging/unpacked/Astral Wake.app"
/usr/bin/lipo "$staging/unpacked/Astral Wake.app/Contents/MacOS/Astral Wake" -verify_arch arm64
/usr/bin/lipo "$staging/unpacked/Astral Wake.app/Contents/MacOS/Astral Wake" -verify_arch x86_64
mv "$staging/release.zip" "$archive"
shasum -a 256 "$archive"
