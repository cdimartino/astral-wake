"""Rebuild original vector organ specimens. No external assets or dependencies."""
from pathlib import Path
import math

OUT = Path(__file__).resolve().parents[1] / "art" / "organs"

# Each specimen has a distinct anatomical silhouette and functional core.
SPECIMENS = {
    "lens": ("78e5d1", "M120 25 C177 37 215 84 203 129 C193 183 155 211 120 219 C73 204 32 172 35 119 C39 65 76 36 120 25Z", "eye"),
    "fork": ("78e5d1", "M107 218 C90 174 97 143 63 127 C20 107 29 59 48 24 C50 75 92 76 120 105 C151 71 187 77 191 24 C216 68 211 107 177 127 C144 144 149 185 134 218Z", "branch"),
    "echo": ("b2b1f9", "M120 52 C78 5 30 41 34 104 C16 161 59 216 101 207 L120 181 L139 207 C190 221 222 163 207 104 C215 40 160 8 120 52Z", "double"),
    "mend": ("78e5d1", "M120 20 C153 38 168 59 166 88 C205 118 195 174 157 193 L120 221 L83 193 C42 167 43 119 73 89 C73 56 91 33 120 20Z", "stitch"),
    "hush": ("8bd5ec", "M54 25 C120 59 185 31 197 91 C217 149 160 202 91 218 C111 185 60 174 49 134 C34 91 67 70 54 25Z", "gill"),
    "prism": ("c2b3ff", "M120 17 L184 64 L210 133 L164 195 L120 225 L70 193 L30 131 L56 66Z", "crystal"),
    "scribe": ("e8d2a3", "M123 18 C150 53 189 53 181 102 C209 152 173 204 117 218 C65 203 42 174 59 119 C49 69 98 62 123 18Z", "quill"),
    "splice": ("e8d2a3", "M60 24 C112 31 111 69 120 87 C139 43 156 38 193 29 C180 84 210 116 172 148 C151 168 148 197 137 219 L100 213 C103 172 77 156 54 142 C22 106 58 81 60 24Z", "branch"),
    "recall": ("e8d2a3", "M117 23 C184 23 211 85 195 130 C208 175 157 207 107 215 C44 203 28 153 43 103 C42 55 81 27 117 23Z", "spiral"),
    "palimend": ("a6e0c6", "M119 19 C169 47 179 80 169 111 C198 141 176 201 124 220 C74 210 40 176 63 130 C46 81 83 36 119 19Z", "stitch"),
    "redact": ("e8b19c", "M68 24 C111 52 178 28 193 82 C216 133 179 183 121 217 C93 178 52 187 43 136 C34 95 79 67 68 24Z", "gill"),
    "rewrite": ("e8d2a3", "M120 23 C173 23 203 56 201 105 C225 153 182 212 141 204 L120 183 L96 214 C44 211 25 162 41 111 C29 59 68 21 120 23Z", "double"),
    "conductor": ("c0a6ff", "M119 22 C148 39 158 61 151 86 C192 93 204 128 183 163 C161 176 144 199 122 221 C101 194 62 189 53 153 C42 115 64 97 89 88 C78 58 102 36 119 22Z", "pulse"),
    "chorus": ("c0a6ff", "M43 35 C79 38 99 67 120 88 C143 62 167 30 198 35 C178 84 218 107 188 145 C161 169 154 200 120 219 C86 204 80 169 52 148 C22 116 62 86 43 35Z", "pipes"),
    "crescendo": ("d1afff", "M115 217 C81 189 94 158 63 134 C33 107 48 59 32 29 C85 48 99 80 118 90 C137 62 164 44 204 24 C185 74 210 106 172 138 C147 158 154 199 131 218Z", "flare"),
    "rest": ("a6e0da", "M120 23 C172 60 200 104 188 145 C174 189 153 211 119 218 C69 203 36 165 50 118 C63 77 99 63 120 23Z", "seed"),
    "dissonance": ("d8a4e7", "M65 22 C102 57 158 23 187 67 C217 100 187 134 198 164 C166 191 145 211 107 220 C89 187 44 183 47 140 C23 100 68 62 65 22Z", "wave"),
    "cadence": ("c0a6ff", "M120 20 C147 47 181 44 204 69 C193 145 172 197 120 222 C64 195 45 140 36 69 C68 45 89 48 120 20Z", "shield"),
}


def core(kind):
    motifs = {
        "eye": '<ellipse cx="120" cy="118" rx="59" ry="37"/><ellipse cx="120" cy="118" rx="27" ry="37"/><circle cx="120" cy="118" r="15" fill="url(#light)"/>',
        "branch": '<path d="M120 193V126Q76 116 65 69M120 126Q164 112 176 66M120 126V77"/><circle cx="120" cy="126" r="15" fill="url(#light)"/>',
        "double": '<ellipse cx="85" cy="119" rx="24" ry="52"/><ellipse cx="155" cy="119" rx="24" ry="52"/><path d="M66 119Q120 81 174 119Q120 156 66 119"/>',
        "stitch": '<path d="M125 51Q90 89 127 118T118 187"/>' + ''.join(f'<path d="M91 {y}Q121 {y+15} 148 {y-2}"/>' for y in range(77, 173, 19)),
        "gill": ''.join(f'<path d="M79 {y}Q{184-i*9} {y-17} {154-i*6} {y+24}"/>' for i, y in enumerate(range(66, 175, 21))),
        "crystal": '<path d="M120 44L169 117L120 196L72 117Z M120 44V196 M72 117H169 M120 44L143 117L120 196L96 117Z"/>',
        "quill": '<path d="M92 190L143 57Q87 58 88 119L118 132Q166 104 143 57 M99 164L148 136 M107 143L75 109"/>',
        "spiral": '<path d="M152 163C75 198 53 101 108 76C164 52 186 134 139 146C103 155 91 108 121 103C140 100 145 123 129 125"/>',
        "pulse": '<path d="M63 130H92L107 100L121 151L138 79L152 130H180"/><ellipse cx="120" cy="117" rx="38" ry="65"/>',
        "pipes": ''.join(f'<path d="M{x-9} {y}Q{x} {y-14} {x+9} {y}V161Q{x} 179 {x-9} 161Z"/>' for x, y in [(80, 88), (120, 63), (160, 88)]),
        "flare": '<path d="M120 191V97 M120 143L73 81 M120 143L167 77 M85 128L62 72 M155 124L179 67"/><circle cx="120" cy="147" r="20" fill="url(#light)"/>',
        "seed": '<path d="M120 69C58 104 83 169 120 181C160 158 171 108 120 69Z M120 84V169 M91 122L120 145L149 119"/>',
        "wave": '<path d="M64 126L86 90L103 151L122 74L141 158L158 100L179 121 M71 146L88 119 M145 79L166 70"/>',
        "shield": '<path d="M120 67L165 91Q161 153 120 182Q78 154 75 91Z M91 116L113 140L151 102"/>',
    }
    return motifs[kind]


def specimen(tint, shell, kind, variant):
    ribs = []
    for side in [-1, 1]:
        for i in range(7):
            y = 55 + i * 22
            x = 120 + side * (38 + 18 * math.sin(i * .55))
            ribs.append(f'<path d="M{120+side*11} {y+14} Q{x} {y+9} {x+side*13} {y-15}"/>')
    vessels = ''.join(f'<path d="M{87+i*22} 202Q{56+i*40} 227 {68+i*37} 238"/>' for i in range(4))
    dots = ''.join(f'<circle cx="{120+math.cos(i*2.4+variant)*76:.1f}" cy="{120+math.sin(i*2.4+variant)*77:.1f}" r="2"/>' for i in range(12))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240">
<defs>
 <radialGradient id="tissue" cx=".38" cy=".3" r=".75"><stop stop-color="#{tint}" stop-opacity=".75"/><stop offset=".38" stop-color="#344756"/><stop offset=".74" stop-color="#172536"/><stop offset="1" stop-color="#080f1d"/></radialGradient>
 <radialGradient id="light"><stop stop-color="#f4fff5"/><stop offset=".35" stop-color="#{tint}"/><stop offset="1" stop-color="#{tint}" stop-opacity="0"/></radialGradient>
 <linearGradient id="bone" x2="1" y2="1"><stop stop-color="#f3e4be"/><stop offset=".3" stop-color="#9f947e"/><stop offset=".6" stop-color="#374857"/><stop offset="1" stop-color="#cfbf97"/></linearGradient>
</defs>
<g fill="none" stroke="#{tint}" stroke-opacity=".5" stroke-width="2">{vessels}</g>
<path d="{shell}" fill="url(#tissue)" stroke="#070f18" stroke-width="9"/>
<path d="{shell}" fill="none" stroke="url(#bone)" stroke-width="3"/>
<ellipse cx="120" cy="120" rx="66" ry="77" fill="url(#light)" opacity=".2"/>
<g fill="none" stroke="url(#bone)" stroke-width="3" stroke-linecap="round">{''.join(ribs)}</g>
<g fill="#101b2a" fill-opacity=".65" stroke="#{tint}" stroke-width="9" stroke-opacity=".12" stroke-linejoin="round">{core(kind)}</g>
<g fill="none" stroke="#{tint}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">{core(kind)}</g>
<g fill="#f3dfb3">{dots}</g>
<path d="M105 31Q120 42 135 31M107 208Q120 198 133 208" fill="none" stroke="#ece1c9" stroke-width="3"/>
</svg>'''


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (name, (tint, shell, kind)) in enumerate(SPECIMENS.items()):
        (OUT / f"{name}.svg").write_text(specimen(tint, shell, kind, index))
    print(f"Wrote {len(SPECIMENS)} organ specimens to {OUT}")
