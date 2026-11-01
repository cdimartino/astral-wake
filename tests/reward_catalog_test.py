"""Distribution-only slice: strip exactly two additive fields, then pin all content."""
import hashlib
import json
from pathlib import Path

catalog = json.loads(Path('data/catalog.json').read_text())
assert len(catalog['cards']) == 72
for card in catalog['cards']:
    assert card.pop('roles') and card.pop('primary_role')
digest = hashlib.sha256(json.dumps(catalog, sort_keys=True, separators=(',', ':'),
                                   ensure_ascii=False).encode()).hexdigest()
assert digest == 'af3babb5ce90b1497a2df649255ef07f7e85b1ca19935c78b886928777304078', digest
print('REWARD_CATALOG all 72 base cards, evolutions and all other content equal 7382d3d')
