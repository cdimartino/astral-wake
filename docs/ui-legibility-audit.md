# UI legibility audit

Completed October 31, 2026. Examined the native Godot UI at 1440×900 and 1100×720, including 40 rendered captures across 20 screen states. The fixed 1440×900 stage scales to fit the window; at 1100 pixels wide, logical font sizes render at approximately 76% of their authored size.

## Findings and changes

| Finding | Change |
| --- | --- |
| The living-circuit layout reduced the ship portrait to 145 pixels high. | Restored a 280×270 portrait beside a two-column organ network. The vessel is approximately 1.86× taller, with its hull and resource readouts directly below. |
| Thin display lettering was automatically applied to every uppercase string and to body copy at 24 pixels or larger. Numbers, abbreviations, card titles and enemy names were unnecessarily hard to scan. | Reserve the original display face for large headings of at least 32 pixels. Use Avenir Next for gameplay text and semibold Avenir Next for card/enemy names, buttons and floating feedback. |
| Organ conditions were 11 pixels, strain readouts 12, and route instructions 13. | Conditions and strain now use 14 pixels; instructions use 16. Taller specimen tiles support two-line conditions without shrinking the type. |
| Small card names used the thin display font at 14 pixels. | Semibold card names use 15 pixels at rest and 17 when enlarged. All 72 card titles, including upgraded versions, were checked for wrapping at both window sizes. |
| Enemy captions, map labels, instructions and narrative copy competed with bright nebulae and lightning. | Added near-opaque dark reading surfaces beneath exposed text. Large artwork remains visible around those surfaces. Map depth labels and ship-selection names also have dedicated backing. |
| Secondary and disabled text was unnecessarily faint. | Secondary text is now `#b5c6d2`; disabled button text is `#9aabba`. Disabled controls retain their darker frame/fill rather than relying on barely visible letters. Tooltips increased to 18 pixels; deck descriptions increased to 17. |
| Long enemy names overlapped hull text after switching to a sturdier font. | Gave two-line names explicit vertical room, including the compact multi-enemy layout. |
| Reward descriptions silently stopped after three lines. | Reward descriptions now accommodate eight lines at 18 pixels. Compact shop/workshop descriptions show an explicit ellipsis and retain their full tooltip. |
| Elevated hand cards rendered over help, settings and deck windows. | Modal overlays now sit above cards and combat feedback. Their dimming layer correctly covers the entire underlying game. |

The opening film's native skip hint already uses an 18-pixel label with a black outline. It retains that treatment.

## Contrast checks

The reading-plate palette was evaluated over a deliberately worst-case **pure white background**, after compositing its 94%-opaque dark fill. Ratios use sRGB relative luminance; the automated floor is 4.5:1.

| Text | Contrast |
| --- | ---: |
| Primary cream | 14.23:1 |
| Secondary blue-gray | 9.85:1 |
| Teal | 10.99:1 |
| Gold | 10.30:1 |
| Coral | 7.90:1 |
| Disabled control text against its actual fill | 6.99:1 |

These measurements cover the shared reading-surface palette, not every pixel of every illustration. Font-size checks are in logical stage pixels; the smaller window still scales them down.

## Screen coverage

Title, ship selection, ship details, map, combat, crowded combat, help, settings, deck, history, discoveries, pause menu, rewards, event, shop, recovery, workshop, region transition, victory and defeat. Visual inspection used contact sheets and full-size captures, including the smaller-window modal and combat layouts.

## Verification

- `tests/ui_legibility_test.gd`: shared contrast, minimum label size, small-text font choice, hidden lines, ship size and modal/card stacking; **3,183 checks passed** during the captured audit.
- `tests/ui_smoke.gd`: **10,137 geometry checks passed**, including all card titles, long enemy names, both window sizes, hover states and modal focus.
- `tests/organ_routing_test.gd`: all three ships, two sizes, specimen/readout bounds, route availability, severed/grafted links and reduced motion.
- `tests/expansion_ui_test.gd`: **525 checks passed**.
- `tests/combat_presentation_test.gd`: **35 checks passed**, including projectile/hull feedback at the restored ship position.

Run the legibility audit headlessly:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_legibility_test.gd
```

To save the 40 native captures, set `ASTRAL_UI_AUDIT_DIR` to an output directory and omit `--headless`. The audit uses an isolated temporary save directory. The regular `tools/check.sh` workflow includes the new legibility and organ-routing checks.

Current combat example: [Hollow Choir](screenshots/hollow_choir-combat.png).
