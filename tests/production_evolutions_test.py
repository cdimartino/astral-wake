"""Production gates: frozen bases, Cartographer/Palimpsest pinned before Choir."""
import copy
import hashlib
import json
from pathlib import Path
from validate_content import validate, validate_evolutions

data = json.loads(Path('data/catalog.json').read_text())
# Additive draft metadata is validated separately, never part of combat hashes.
validate(data)
for card in data['cards']:
    card.pop('roles')
    card.pop('primary_role')
# Canonical catalog at 63fbd24, pinned once; works in shallow CI/source exports too.
BASE_CATALOG_SHA256 = '452f8b67171790200bec1a05ebf5ffc83e3aac53b3e3cce9668aa8c082a47988'
stripped = copy.deepcopy(data)
for card in stripped['cards']:
    card.pop('evolutions', None)
digest = hashlib.sha256(json.dumps(stripped, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
assert digest == BASE_CATALOG_SHA256, 'Every base field and all other catalog content must remain unchanged'
previous = copy.deepcopy(data)
for card in previous['cards']:
    if card.get('character') in {'palimpsest', 'hollow_choir'}:
        card.pop('evolutions', None)
assert hashlib.sha256(json.dumps(previous, sort_keys=True, separators=(',', ':')).encode()).hexdigest() == 'ea3c5904215ab7f853c618d7337be2c29fb71cbc65283eed541d9ded5b070a9c', 'Cartographer branches and all bases must match cf175c7'
previous = copy.deepcopy(data)
for card in previous['cards']:
    if card.get('character') == 'hollow_choir':
        card.pop('evolutions', None)
assert hashlib.sha256(json.dumps(previous, sort_keys=True, separators=(',', ':')).encode()).hexdigest() == '6ec26df183c35d256931376efc0aa76ce4b1ba680be4e910ad1507b715528554', 'Only Choir evolution additions may differ from f66fe8e'
cart = [c for c in data['cards'] if c.get('character', 'cartographer') == 'cartographer']
pal = [c for c in data['cards'] if c.get('character') == 'palimpsest']
choir = [c for c in data['cards'] if c.get('character') == 'hollow_choir']
assert len(cart) == 36
assert len(pal) == len(choir) == 18
CHOIR_OVERRIDES = {
    'choral_bolt': [{'damage': 11}, {'damage': 7, 'resonance': 1}],
    'warm_refrain': [{'heal': 8}, {'heal': 6, 'retain': True}],
    'silent_measure': [{'vent': 2}, {'draw': 0, 'resonance': 2}],
    'call_and_response': [{'damage': 9, 'draw': 0}, {'damage': 6, 'retain': True}],
    'tuning_fork': [{'disrupt': 5}, {'disrupt': 3, 'resonance': 2}],
    'bright_canon': [{'damage': 15}, {'damage': 12, 'retain': True}],
    'breath_between': [{'heal': 6}, {'heal': 3, 'vent': 2}],
    'dissonant_edge': [{'damage': 10}, {'damage': 6, 'disrupt': 4}],
    'shared_pulse': [{'damage': 9}, {'damage': 5, 'heal': 5}],
    'counterpoint': [{'draw': 2, 'first_free': True}, {'draw': 1, 'resonance': 2}],
    'crescendo': [{'damage': 13}, {'damage': 10, 'heal': 3}],
    'hushed_chord': [{'disrupt': 8, 'vent': 0}, {'disrupt': 5, 'vent': 2}],
    'orbital_round': [{'damage': 12, 'draw': 0}, {'damage': 9, 'retain': True}],
    'harmonic_bridge': [{'heal': 7}, {'heal': 4, 'resonance': 2}],
    'grand_concert': [{'damage': 15}, {'heal': 7}],
    'resonant_shell': [{'heal': 10}, {'cost': 1, 'heal': 5, 'resonance': 1}],
    'rest_note': [{'vent': 3, 'draw': 0}, {'vent': 2, 'retain': True}],
    'unison': [{'damage': 13}, {'damage': 9, 'heal': 3}],
}
assert {c['id'] for c in choir} == set(CHOIR_OVERRIDES)
for card in choir:
    assert [b['stats'] for b in card['evolutions']] == CHOIR_OVERRIDES[card['id']], card['id']
for value in (True, False, 1.5, -1, 4, '2', None, [], {}):
    bad = copy.deepcopy(choir[0])
    bad['evolutions'][1]['stats']['resonance'] = value
    try:
        validate_evolutions(bad)
    except ValueError:
        continue
    raise AssertionError(('invalid Choir Resonance', value))
bad = copy.deepcopy(choir[0])
bad['evolutions'][1]['stats']['trace'] = 1
try:
    validate_evolutions(bad)
except ValueError:
    pass
else:
    raise AssertionError('Choir cannot gain foreign Trace')
PALIMPSEST_OVERRIDES = {
    'margin_knife': [{'damage': 11}, {'damage': 7, 'trace': 2}],
    'pale_patch': [{'heal': 8}, {'heal': 5, 'trace': 2}],
    'carbon_breath': [{'vent': 2}, {'draw': 0, 'trace': 3}],
    'first_draft': [{'damage': 9}, {'damage': 6, 'trace': 3}],
    'ghost_line': [{'trace': 2, 'draw': 1}, {'retain': True}],
    'revision_spike': [{'damage': 15}, {'damage': 12, 'retain': True}],
    'vellum_shield': [{'heal': 6}, {'heal': 3, 'disrupt': 3}],
    'cut_sentence': [{'damage': 10}, {'damage': 6, 'disrupt': 4}],
    'borrowed_dawn': [{'damage': 11}, {'heal': 6}],
    'ink_well': [{'vent': 3}, {'vent': 1, 'trace': 3}],
    'overwrite': [{'damage': 9}, {'damage': 6, 'retain': True}],
    'scar_note': [{'heal': 10}, {'heal': 7, 'vent': 2}],
    'lost_paragraph': [{'disrupt': 8, 'draw': 0}, {'disrupt': 5, 'retain': True}],
    'double_exposure': [{'damage': 12, 'draw': 0}, {'damage': 9, 'retain': True}],
    'final_revision': [{'damage': 15}, {'damage': 12, 'retain': True}],
    'memory_lattice': [{'heal': 8}, {'heal': 5, 'trace': 3}],
    'blank_page': [{'vent': 3}, {'cost': 1, 'vent': 1, 'trace': 1}],
    'second_history': [{'heal': 12}, {'heal': 9, 'retain': True}],
}
assert {c['id'] for c in pal} == set(PALIMPSEST_OVERRIDES)
for card in pal:
    assert [b['stats'] for b in card['evolutions']] == PALIMPSEST_OVERRIDES[card['id']], card['id']
for card in cart + pal + choir:
    validate_evolutions(card)
    a, b = [dict(card, **branch['stats']) for branch in card['evolutions']]
    # Necessary authoring gate, NOT proof of encounter/deck-level balance.
    def dimensions(c):
        return [c.get(k, 0) for k in ('damage', 'heal', 'vent', 'disrupt', 'draw', 'trace', 'resonance')] + [
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
print('PRODUCTION_EVOLUTIONS 72 pairs: unchanged bases/prior branches, typed flags, no scalar dominance')
