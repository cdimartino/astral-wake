"""Build original Astral Wake display outlines; tooling only: fontTools and Pillow.

Run: PYTHONPATH=/tmp/astral-font-tools python3 tools/make_font.py
All strokes below are authored geometry, with no source-font outlines.
"""
import math
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'art' / 'fonts'
STROKE = 66
# Centerline designs in a 680-unit cap height; chamfered strokes keep the family coherent.
O = [(160, 0), (440, 0), (540, 100), (540, 580), (440, 680), (160, 680), (60, 580), (60, 100), (160, 0)]
P = [(60, 0), (60, 680), (420, 680), (540, 560), (540, 440), (420, 340), (60, 340)]
GLYPHS = {
    'A': [[(60, 0), (60, 500), (220, 680), (380, 680), (540, 500), (540, 0)], [(60, 260), (540, 260)]],
    'B': [[(60, 0), (60, 680), (420, 680), (540, 560), (540, 440), (420, 340), (540, 240), (540, 120), (420, 0), (60, 0)], [(60, 340), (420, 340)]],
    'C': [[(540, 570), (430, 680), (170, 680), (60, 570), (60, 110), (170, 0), (430, 0), (540, 110)]],
    'D': [[(60, 0), (60, 680), (400, 680), (540, 540), (540, 140), (400, 0), (60, 0)]],
    'E': [[(540, 680), (60, 680), (60, 0), (540, 0)], [(60, 340), (430, 340)]],
    'F': [[(60, 0), (60, 680), (540, 680)], [(60, 340), (430, 340)]],
    'G': [[(540, 570), (430, 680), (170, 680), (60, 570), (60, 110), (170, 0), (430, 0), (540, 110), (540, 310), (330, 310)]],
    'H': [[(60, 0), (60, 680)], [(540, 0), (540, 680)], [(60, 340), (540, 340)]],
    'I': [[(60, 680), (260, 680)], [(160, 680), (160, 0)], [(60, 0), (260, 0)]],
    'J': [[(260, 680), (540, 680), (540, 120), (420, 0), (180, 0), (60, 120), (60, 220)]],
    'K': [[(60, 0), (60, 680)], [(540, 680), (60, 290), (540, 0)]],
    'L': [[(60, 680), (60, 0), (540, 0)]],
    'M': [[(60, 0), (60, 680), (360, 330), (660, 680), (660, 0)]],
    'N': [[(60, 0), (60, 680), (540, 0), (540, 680)]],
    'O': [O], 'P': [P],
    'Q': [O, [(340, 150), (570, -70)]],
    'R': [P, [(310, 340), (550, 0)]],
    'S': [[(540, 570), (430, 680), (170, 680), (60, 570), (60, 440), (170, 340), (430, 340), (540, 240), (540, 110), (430, 0), (170, 0), (60, 110)]],
    'T': [[(60, 680), (540, 680)], [(300, 680), (300, 0)]],
    'U': [[(60, 680), (60, 120), (180, 0), (420, 0), (540, 120), (540, 680)]],
    'V': [[(60, 680), (300, 0), (540, 680)]],
    'W': [[(60, 680), (210, 0), (360, 350), (510, 0), (660, 680)]],
    'X': [[(60, 680), (540, 0)], [(540, 680), (60, 0)]],
    'Y': [[(60, 680), (300, 350), (540, 680)], [(300, 350), (300, 0)]],
    'Z': [[(60, 680), (540, 680), (60, 0), (540, 0)]],
    '0': [O, [(170, 130), (430, 550)]],
    '1': [[(100, 540), (300, 680), (300, 0)], [(120, 0), (480, 0)]],
    '2': [[(60, 570), (170, 680), (430, 680), (540, 570), (540, 440), (60, 0), (540, 0)]],
    '3': [[(60, 680), (430, 680), (540, 570), (540, 440), (430, 340), (230, 340)], [(430, 340), (540, 230), (540, 110), (430, 0), (60, 0)]],
    '4': [[(400, 0), (400, 680), (60, 220), (540, 220)]],
    '5': [[(540, 680), (60, 680), (60, 350), (430, 350), (540, 240), (540, 110), (430, 0), (60, 0)]],
    '6': [[(540, 570), (430, 680), (170, 680), (60, 570), (60, 110), (170, 0), (430, 0), (540, 110), (540, 240), (430, 350), (60, 350)]],
    '7': [[(60, 680), (540, 680), (170, 0)]],
    '8': [O, [(60, 340), (540, 340)]],
    '9': [[(540, 330), (170, 330), (60, 440), (60, 570), (170, 680), (430, 680), (540, 570), (540, 110), (430, 0), (60, 0)]],
    '.': [[(100, 0), (100, 64)]], ',': [[(130, 64), (130, 0), (80, -80)]],
    ':': [[(100, 420), (100, 484)], [(100, 0), (100, 64)]],
    ';': [[(130, 420), (130, 484)], [(130, 64), (130, 0), (80, -80)]],
    '!': [[(100, 680), (100, 200)], [(100, 0), (100, 64)]],
    '?': [[(60, 570), (170, 680), (430, 680), (540, 570), (540, 460), (300, 280), (300, 200)], [(300, 0), (300, 64)]],
    '-': [[(60, 300), (420, 300)]], '_': [[(60, -80), (540, -80)]],
    '+': [[(60, 320), (500, 320)], [(280, 100), (280, 540)]],
    '=': [[(60, 440), (500, 440)], [(60, 200), (500, 200)]],
    '/': [[(60, -40), (500, 720)]], '\\': [[(60, 720), (500, -40)]],
    '(': [[(250, 720), (100, 560), (100, 120), (250, -40)]],
    ')': [[(100, 720), (250, 560), (250, 120), (100, -40)]],
    '[': [[(280, 720), (80, 720), (80, -40), (280, -40)]],
    ']': [[(80, 720), (280, 720), (280, -40), (80, -40)]],
    '{': [[(280, 720), (160, 650), (160, 420), (80, 340), (160, 260), (160, 30), (280, -40)]],
    '}': [[(80, 720), (200, 650), (200, 420), (280, 340), (200, 260), (200, 30), (80, -40)]],
    "'": [[(100, 680), (100, 510)]], '"': [[(100, 680), (100, 510)], [(250, 680), (250, 510)]],
    '<': [[(430, 600), (100, 340), (430, 80)]], '>': [[(100, 600), (430, 340), (100, 80)]],
    '|': [[(100, -80), (100, 760)]], '^': [[(60, 420), (280, 680), (500, 420)]],
    '`': [[(100, 720), (200, 600)]], '~': [[(60, 280), (170, 400), (390, 280), (500, 400)]],
    '*': [[(100, 250), (460, 550)], [(100, 550), (460, 250)], [(280, 140), (280, 660)]],
    '#': [[(200, 0), (260, 680)], [(400, 0), (460, 680)], [(80, 220), (560, 220)], [(100, 460), (580, 460)]],
    '%': [[(60, 0), (540, 680)], [(120, 440), (60, 500), (60, 620), (120, 680), (240, 680), (300, 620), (300, 500), (240, 440), (120, 440)], [(360, 0), (300, 60), (300, 180), (360, 240), (480, 240), (540, 180), (540, 60), (480, 0), (360, 0)]],
    '&': [[(540, 0), (120, 420), (60, 530), (60, 590), (150, 680), (300, 680), (390, 590), (390, 500), (60, 180), (60, 90), (150, 0), (360, 0), (540, 250)]],
    '@': [O, [(440, 100), (440, 470), (350, 540), (240, 540), (170, 470), (170, 230), (240, 160), (350, 160), (440, 250), (540, 250)]],
    '$': [[(540, 570), (430, 680), (170, 680), (60, 570), (60, 440), (170, 340), (430, 340), (540, 240), (540, 110), (430, 0), (60, 0)], [(300, -100), (300, 780)]],
    '→': [[(60, 340), (620, 340)], [(410, 550), (620, 340), (410, 130)]],
    '×': [[(100, 100), (500, 560)], [(100, 560), (500, 100)]],
    '·': [[(100, 300), (100, 364)]], '…': [[(100, 0), (100, 64)], [(280, 0), (280, 64)], [(460, 0), (460, 64)]],
}


def glyph(paths):
    pen = TTGlyphPen(None)
    for path in paths:
        for a, b in zip(path, path[1:]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dy)
            ux, uy = dx / length, dy / length
            nx, ny = -uy, ux
            half, bevel = STROKE / 2, 8
            points = [(a[0] + nx * (half - bevel), a[1] + ny * (half - bevel)),
                      (a[0] + ux * bevel + nx * half, a[1] + uy * bevel + ny * half),
                      (b[0] - ux * bevel + nx * half, b[1] - uy * bevel + ny * half),
                      (b[0] + nx * (half - bevel), b[1] + ny * (half - bevel)),
                      (b[0] - nx * (half - bevel), b[1] - ny * (half - bevel)),
                      (b[0] - ux * bevel - nx * half, b[1] - uy * bevel - ny * half),
                      (a[0] + ux * bevel - nx * half, a[1] + uy * bevel - ny * half),
                      (a[0] - nx * (half - bevel), a[1] - ny * (half - bevel))]
            pen.moveTo(tuple(round(v) for v in points[0]))
            for point in points[1:]: pen.lineTo(tuple(round(v) for v in point))
            pen.closePath()
    return pen.glyph()


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    outlines = {'.notdef': glyph([[(60, 0), (60, 680), (540, 680), (540, 0), (60, 0)], [(60, 0), (540, 680)]]), 'space': glyph([])}
    cmap, metrics = {32: 'space'}, {'.notdef': (640, 27), 'space': (320, 0)}
    for character, paths in GLYPHS.items():
        name = character if character.isascii() and character.isupper() else 'uni%04X' % ord(character)
        item = glyph(paths)
        outlines[name] = item
        maximum = max(x for x, y in item.coordinates)
        advance = maximum + 70
        if character in '0123456789': advance = 640
        metrics[name] = (advance, min(x for x, y in item.coordinates))
        cmap[ord(character)] = name
    for character in 'abcdefghijklmnopqrstuvwxyz': cmap[ord(character)] = cmap[ord(character.upper())]
    for character, source in {'–': '-', '—': '-', '−': '-', '‘': "'", '’': "'", '“': '"', '”': '"', '•': '·', '\u00a0': ' '}.items(): cmap[ord(character)] = cmap[ord(source)]
    builder = FontBuilder(1000, isTTF=True)
    builder.setupGlyphOrder(list(outlines))
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(outlines)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=850, descent=-200, lineGap=80)
    builder.setupNameTable({'familyName': 'Astral Wake Display', 'styleName': 'Regular', 'uniqueFontIdentifier': 'AstralWakeDisplay-Regular-1.0', 'fullName': 'Astral Wake Display', 'psName': 'AstralWakeDisplay-Regular', 'version': 'Version 1.0', 'copyright': 'Original Astral Wake project artwork. No third-party font outlines.'})
    builder.setupOS2(sTypoAscender=850, sTypoDescender=-200, sTypoLineGap=80, usWinAscent=850, usWinDescent=200, sxHeight=713, sCapHeight=713, usWeightClass=450, fsType=0)
    builder.setupPost()
    kern = newTable('kern')
    kern.version = 0
    subtable = KernTable_format_0()
    subtable.version, subtable.coverage = 0, 1
    subtable.kernTable = {(a, b): -25 for a, b in [('A', 'V'), ('V', 'A'), ('A', 'W'), ('W', 'A'), ('T', 'A'), ('T', 'O'), ('Y', 'A')]}
    kern.kernTables = [subtable]
    builder.font['kern'] = kern
    # Fixed timestamps keep rebuilding the same authored outlines reproducible.
    builder.font['head'].created = builder.font['head'].modified = 3875644800
    builder.font.recalcTimestamp = False
    path = DEST / 'AstralWake-Display.ttf'
    builder.save(path)
    font = TTFont(path)
    assert set(range(32, 127)) <= set(font.getBestCmap()), 'ASCII glyph coverage incomplete'
    assert font['hhea'].ascent >= font['head'].yMax and -font['hhea'].descent >= -font['head'].yMin
    assert all(width > 0 for width, bearing in font['hmtx'].metrics.values())
    preview = Image.new('RGB', (1440, 800), '#07121d')
    draw = ImageDraw.Draw(preview)
    samples = [(72, 'Astral Wake'), (40, 'The Cartographer / Unbroken Song'), (40, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'), (40, '0123456789  +14 / -3  →  2 × 3'), (24, 'Needle of Dawn · Hull Stitch · Cold Breath'), (18, 'Readable at 18: Command points 3 / 3'), (24, '!? ., :; / \\ () [] {} + - = # % & @ $'), (24, 'The quick brown fox jumps over the lazy dog.')]
    y = 28
    for size, text in samples:
        face = ImageFont.truetype(str(path), size)
        draw.text((40, y), text, font=face, fill='#e5d9b6' if size >= 40 else '#7be0ca')
        assert draw.textbbox((40, y), text, font=face)[2] < 1400, 'Preview text overflow'
        y += size + 34
    preview.save(DEST / 'AstralWake-Display-preview.png')
    print(f'Built {path}: {len(outlines)} original glyphs, {len(cmap)} Unicode mappings; metrics/ASCII/render checks passed.')


if __name__ == '__main__': build()
