"""Verify full-resolution art coverage without decoding or editing pixels."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def dimensions(path):
    with path.open('rb') as file:
        data = file.read(24)
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II', data[16:24])


for kind, expected in [('ships', set(range(1, 20))), ('cards', set(range(36)))]:
    manifest = json.loads((ROOT / f'art/{kind}_hd/manifest.json').read_text())[kind]
    assert {int(key) for key in manifest} == expected, f'Incomplete {kind} HD coverage'
    for key, asset in manifest.items():
        path = ROOT / asset['path'].removeprefix('res://')
        width, height = dimensions(path)
        x, y, w, h = asset['rect']
        assert x >= 0 and y >= 0 and x + w <= width and y + h <= height, (kind, key, asset)
        assert min(w, h) >= 740, (kind, key, 'undersized Retina art', w, h)
    print(f'HD {kind}: {len(manifest)} complete, bounded crops; each at least 740 pixels per side')

assert min(dimensions(ROOT / 'art/ships_hd/player.png')) >= 1024
for region in range(3):
    width, height = dimensions(ROOT / f'art/backgrounds_hd/region_{region}.png')
    assert width >= 1600 and height >= 900
print('Standalone player and all three environment redraws present')

catalog = json.loads((ROOT / 'data/catalog.json').read_text())
expansion = json.loads((ROOT / 'art/expansion/manifest.json').read_text())
characters = {item['id'] for item in catalog['characters'] if item['id'] != 'cartographer'}
regions = {item['id'] for item in catalog['regions'][3:]}
expected = {
    'characters': characters,
    'regions': regions,
    'cards': {item['id'] for item in catalog['cards'] if item.get('character') in characters},
    'enemies': {item['id'] for item in catalog['enemies'] if catalog['regions'][item['region']]['id'] in regions},
}
assert {key: len(value) for key, value in expected.items()} == {'characters': 2, 'regions': 3, 'cards': 36, 'enemies': 18}
for kind, identifiers in expected.items():
    assert set(expansion[kind]) == identifiers, (kind, 'Incomplete expansion art IDs')
    for identifier, asset in expansion[kind].items():
        assert asset['path'].startswith('res://art/expansion/'), (kind, identifier, 'Nonlocal image path')
        path = ROOT / asset['path'].removeprefix('res://')
        width, height = dimensions(path)
        if kind == 'characters':
            assert min(width, height) >= 1024, (identifier, width, height)
        elif kind == 'regions':
            assert width >= 1672 and height >= 941, (identifier, width, height)
        else:
            x, y, w, h = asset.get('rect', [0, 0, width, height])
            assert min(x, y) >= 0 and x + w <= width and y + h <= height, (identifier, asset)
            assert min(w, h) >= 740, (identifier, 'Undersized expansion art', w, h)
        settings = set(Path(str(path) + '.import').read_text().splitlines())
        assert {'compress/mode=0', 'mipmaps/generate=true', 'process/size_limit=0'} <= settings, (identifier, 'Lossless full-size mipmapped import required')
    print(f'Expansion {kind}: {len(identifiers)} IDs complete, HD crops bounded, full-size lossless mipmapped imports verified')
