"""Production authoring gates; frozen base is infrastructure commit 63fbd24."""
import copy
import hashlib
import json
from pathlib import Path
from validate_content import validate_evolutions

data = json.loads(Path('data/catalog.json').read_text())
# Canonical catalog at 63fbd24, pinned once; works in shallow CI/source exports too.
BASE_CATALOG_SHA256 = '452f8b67171790200bec1a05ebf5ffc83e3aac53b3e3cce9668aa8c082a47988'
stripped = copy.deepcopy(data)
for card in stripped['cards']:
    card.pop('evolutions', None)
digest = hashlib.sha256(json.dumps(stripped, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
assert digest == BASE_CATALOG_SHA256, 'Every base field and all other catalog content must remain unchanged'
cart = [c for c in data['cards'] if c.get('character', 'cartographer') == 'cartographer']
assert len(cart) == 36
assert all('evolutions' not in c for c in data['cards'] if c not in cart)
for card in cart:
    validate_evolutions(card)
    a, b = [dict(card, **branch['stats']) for branch in card['evolutions']]
    # Necessary authoring gate, NOT proof of encounter/deck-level balance.
    def dimensions(c):
        return [c.get(k, 0) for k in ('damage', 'heal', 'vent', 'disrupt', 'draw')] + [
            int(c.get('retain', False)), int(c.get('first_free', False)),
            -int(c.get('exhaust', False)), -c['cost']]
    pairs = list(zip(dimensions(a), dimensions(b)))
    assert any(x > y for x, y in pairs) and any(y > x for x, y in pairs), card['id']
for flag in ('retain', 'exhaust', 'first_free'):
    for value in (0, 1, 'true', None, [], {}):
        bad = copy.deepcopy(cart[0])
        bad['evolutions'][0]['stats'][flag] = value
        try:
            validate_evolutions(bad)
        except ValueError:
            continue
        raise AssertionError((flag, value))
    for value in (True, False):
        good = copy.deepcopy(cart[0])
        good['evolutions'][0]['stats'][flag] = value
        validate_evolutions(good)
bad = copy.deepcopy(cart[0])
bad['install'] = 'fixture'
bad['evolutions'][0]['stats']['exhaust'] = True
try:
    validate_evolutions(bad)
except ValueError:
    pass
else:
    raise AssertionError('Install/Exhaust incompatibility')
print('PRODUCTION_EVOLUTIONS 36 pairs: unchanged catalog bases, typed flags, no scalar dominance')
