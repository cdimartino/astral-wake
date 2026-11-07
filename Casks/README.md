# Homebrew Cask

## Overview

This directory declares the macOS release package for the repository's Homebrew tap.

## Interface

- [`astral-wake.rb`](./astral-wake.rb), `cask "astral-wake"`: exposes the `astral-wake` cask, release metadata, and GitHub release archive URL.
- `astral-wake.rb:app`: names `Astral Wake.app` as the application artifact.

## Invariants

- `astral-wake.rb:version`, `url`, and `sha256`: the version selects the release tag and archive filename; the checksum pins that archive. Update these together for a release.
- `astral-wake.rb:depends_on`: declares macOS, without a specific minimum version in the cask.

## Side Effects

- `astral-wake.rb:url` and `app`: Homebrew uses these declarations to download the archive and install the application when the user installs the cask. Reading the file does not install anything.
- `astral-wake.rb:caveats`: displays the ad-hoc signing and Gatekeeper guidance; it does not change security settings or sign the application.

## Verification

From the repository root:

```sh
ruby -c Casks/astral-wake.rb
```

This checks Ruby syntax only. The project check runner, `bash tools/check.sh`, tests game content and behavior, not Homebrew installation or the published archive checksum.
