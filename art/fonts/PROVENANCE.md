# Astral Wake Display

Original display typeface drawn for Astral Wake. The alphabet, numerals, and punctuation are authored geometric outlines in `tools/make_font.py`; no existing typeface outlines or font tables were copied. Angular open forms and chamfered terminals echo the game's living spacecraft. Intended for headings and card names; body text retains its existing face.

Coverage: all printable ASCII, lowercase mapped to the corresponding original uppercase glyphs, monospaced digits, curly quotes, en/em dashes, mathematical minus, bullets, ellipsis, multiplication sign, and right arrow. The font contains 74 original glyphs and 108 Unicode mappings. Seven restrained kerning pairs tighten display combinations. Metrics include room for punctuation and descenders.

Build with the existing Python/Pillow environment and fontTools:

```sh
PYTHONPATH=/tmp/astral-font-tools python3 tools/make_font.py
```

fontTools 4.67.0 was installed only as temporary build tooling under `/tmp/astral-font-tools`, not as a game dependency. Its installed distribution metadata states `License: MIT`; the accompanying `fonttools-4.67.0.dist-info/licenses/LICENSE` was inspected. Pillow renders the contact sheet. No font software is required by the shipped game beyond the generated TTF.

Validation: the generator checks complete ASCII coverage, positive advance widths, ascent/descent bounds, and preview text bounds. `AstralWake-Display-preview.png` was visually inspected at 18, 24, 40, and 72 pixels. Font reload and final in-game layout are handled by the UI integration.
