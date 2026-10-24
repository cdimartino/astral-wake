# Astral Wake — high-resolution command illustrations

All 36 illustrations are original project-bound images generated with the built-in OpenAI imagegen tool on 2026-10-24. The existing project image `art/cards.png` was used only as a visual identity and palette reference. No paid third-party assets or external API calls were used. Images are bundled for offline gameplay; generation does not occur at runtime.

Each `sheet_N.png` is the unchanged built-in tool output, **1774 × 887 pixels**, containing two equal square paintings. The UI uses Godot `AtlasTexture` rectangles; no bitmap was cropped, resized, sharpened, composited or upscaled. The original tool output remains at the source path recorded in `provenance.json`. SHA-256 hashes verify byte-for-byte preservation.

- `manifest.json`: exact UI contract, `cards` dictionary with catalog-index string keys `0` through `35`, each containing `path` and `rect`.
- `prompts.json`: complete final prompt set, reference path, requested layout and catalog indices.
- `prompt_0.txt` through `prompt_17.txt`: final prompts used for each sheet.
- `provenance.json`: original generated file locations, native dimensions, output hashes and tool method.

Every panel has a 1-pixel inset to prevent neighboring texture bleed. Left rectangles are `[1, 1, 885, 885]`; right rectangles are `[888, 1, 885, 885]`. The visual split is exactly x=887. The 885-pixel usable edge is over four times the old 209-pixel cell edge and exceeds the requested 740-pixel Retina inspection threshold.

## Catalog mapping

| Sheet | Left square | Right square |
|---|---|---|
| 0 | 0: `needle` — Needle of Dawn | 1: `hull_stitch` — Hull Stitch |
| 1 | 2: `cold_breath` — Cold Breath | 3: `quiet_pulse` — Quiet Pulse |
| 2 | 4: `graft_wire` — Graft Wire | 5: `sun_splinter` — Sun Splinter |
| 3 | 6: `mercy_circuit` — Mercy Circuit | 7: `black_suture` — Black Suture |
| 4 | 8: `spare_heartbeat` — Spare Heartbeat | 9: `frost_seam` — Frost Seam |
| 5 | 10: `red_interval` — Red Interval | 11: `wake_lance` — Wake Lance |
| 6 | 12: `glass_murmur` — Glass Murmur | 13: `thread_cannon` — Thread Cannon |
| 7 | 14: `mute_bell` — Mute Bell | 15: `cold_psalm` — Cold Psalm |
| 8 | 16: `salvage_hymn` — Salvage Hymn | 17: `votive_shard` — Votive Shard |
| 9 | 18: `mirror_cut` — Mirror Cut | 19: `open_channel` — Open Channel |
| 10 | 20: `scar_bridge` — Scar Bridge | 21: `winter_needle` — Winter Needle |
| 11 | 22: `hollow_chorus` — Hollow Chorus | 23: `seam_of_light` — Seam of Light |
| 12 | 24: `pilgrim_signal` — Pilgrim Signal | 25: `long_hem` — Long Hem |
| 13 | 26: `blue_refrain` — Blue Refrain | 27: `last_match` — Last Match |
| 14 | 28: `white_noise` — White Noise | 29: `star_chart` — Star Chart |
| 15 | 30: `ember_abacus` — Ember Abacus | 31: `kindly_static` — Kindly Static |
| 16 | 32: `afterimage` — Afterimage | 33: `deep_winter` — Deep Winter |
| 17 | 34: `whole_horizon` — Whole Horizon | 35: `unbroken_song` — Unbroken Song |

## Verification

Every generated sheet was visually inspected for the correct two subjects, crisp focal detail, coherent cyan/gold/violet cosmic style, clean central boundary, and absence of titles or frames. PNG dimensions, all 36 region bounds and source hashes were checked without modifying pixels.

`python3 tests/check_art.py` passed after completion: 36 HD cards and 19 HD ships have bounded crops at least 740 pixels per side; the standalone player and three environment redraws are present. Combined check log: `.oldhand/astral-wake/qa/hd-art-check.log`.

Native rendering, import settings and export verification are owned by integration; this asset slice does not claim those checks.
