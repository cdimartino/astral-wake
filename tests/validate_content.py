#!/usr/bin/env python3
"""Validate the complete Astral Wake catalog using only the Python standard library."""
import argparse
import copy
import json
from collections import Counter
from pathlib import Path

COUNTS = {'organs': 6, 'cards': 72, 'powerups': 18, 'enemies': 36,
          'events': 18, 'regions': 6, 'starting_deck': 10, 'characters': 3}
FIELDS = {
    'organs': {'id', 'name', 'verb', 'description', 'color'},
    'characters': {'id', 'name', 'description', 'max_hull', 'capacity', 'cooling', 'starting_deck', 'organs', 'edges'},
    'cards': {'id', 'name', 'kind', 'description', 'damage', 'heal', 'vent', 'draw',
              'disrupt', 'link', 'rarity', 'unlock', 'art', 'cost'},
    'powerups': {'id', 'name', 'description', 'effect', 'value', 'unlock'},
    'enemies': {'id', 'name', 'region', 'role', 'hp', 'art', 'description', 'pattern'},
    'events': {'id', 'name', 'region', 'text', 'choices'},
    'regions': {'id', 'name', 'subtitle', 'color', 'boss', 'description'},
}
POWER_EFFECTS = {'damage', 'heal', 'capacity', 'cooling', 'draw', 'starting_ward',
                 'kill_heal', 'salvage', 'first_damage', 'short_route', 'long_route',
                 'disrupt', 'echo', 'fork', 'repair_after', 'reward_choices',
                 'shop_discount', 'emergency'}
EVENT_EFFECTS = {'heal', 'hurt_salvage', 'salvage', 'powerup', 'card', 'upgrade',
                 'remove', 'capacity_trade', 'repair_trade'}
PATTERN_KINDS = {'attack', 'strain', 'sever', 'incubate', 'rebuild', 'mark'}
BOSSES = ['unhatched_sun', 'salvage_parliament', 'witness_array', 'root_of_all_suns', 'drowned_catalogue', 'crown_unbound']


def require(ok, message):
    if not ok:
        raise ValueError(message)


def integer(value, low, high, label):
    require(type(value) is int and low <= value <= high,
            f'{label}: expected integer in [{low}, {high}]')


def text(value, label):
    require(isinstance(value, str) and value.strip(), f'{label}: missing text')


def validate(data):
    require(isinstance(data, dict) and set(data) == set(COUNTS), 'catalog keys differ from schema')
    for group, count in COUNTS.items():
        require(isinstance(data[group], list) and len(data[group]) == count,
                f'{group}: expected {count} entries')
        if group == 'starting_deck':
            continue
        ids, names = set(), set()
        for item in data[group]:
            optional = {'character', 'trace', 'rewrite', 'resonance', 'concert'} if group == 'cards' else set()
            require(isinstance(item, dict) and FIELDS[group] <= set(item) <= FIELDS[group] | optional, f'{group}: unsupported or missing fields')
            ident = item['id']
            text(ident, f'{group}.id')
            require(ident.replace('_', '').isalnum() and ident.islower(), f'{ident}: invalid id')
            require(ident not in ids, f'{group}: duplicate id {ident}')
            require(item['name'] not in names, f'{group}: duplicate name {item["name"]}')
            ids.add(ident)
            names.add(item['name'])
            text(item['name'], f'{ident}.name')
            for field in ('description', 'text', 'subtitle', 'verb'):
                if field in item:
                    text(item[field], f'{ident}.{field}')
            if 'color' in item:
                color = item['color']
                require(isinstance(color, str) and len(color) == 7 and color[0] == '#', f'{ident}: invalid color')
                try:
                    int(color[1:], 16)
                except ValueError:
                    raise ValueError(f'{ident}: invalid color') from None

    require([o['id'] for o in data['organs']] == ['lens', 'fork', 'echo', 'mend', 'hush', 'prism'],
            'organ order differs from routing indexes')
    cards = {c['id']: c for c in data['cards']}
    for c in cards.values():
        ident = c['id']
        require(c['kind'] in {'attack', 'repair', 'utility'}, f'{ident}: invalid card kind')
        for field in ('damage', 'heal', 'vent', 'draw', 'disrupt'):
            integer(c[field], 0, 99, f'{ident}.{field}')
            if c[field]:
                require(str(c[field]) in c['description'], f'{ident}: missing payload number in description')
        require(c.get('character', 'cartographer') in {'cartographer', 'palimpsest', 'hollow_choir'}, f'{ident}: unknown card pool')
        for resource, maximum in [('trace', 6), ('resonance', 3)]:
            if resource in c: integer(c[resource], 0, maximum, f'{ident}.{resource}')
        for flag in ('rewrite', 'concert'):
            if flag in c: require(type(c[flag]) is bool, f'{ident}: invalid resource command flag')
        require(not any(k in c for k in ('trace', 'rewrite')) or c.get('character') == 'palimpsest', f'{ident}: Trace belongs to Palimpsest')
        require(not any(k in c for k in ('resonance', 'concert')) or c.get('character') == 'hollow_choir', f'{ident}: Resonance belongs to Choir')
        integer(c['cost'], 1, 2, f'{ident}.cost')
        integer(c['rarity'], 0, 2, f'{ident}.rarity')
        integer(c['unlock'], 0, 3, f'{ident}.unlock')
        integer(c['art'], 0, 19, f'{ident}.art')
        require(type(c['link']) is bool, f'{ident}: link must be boolean')
        require(any(c[f] for f in ('damage', 'heal', 'vent', 'draw', 'disrupt', 'link')), f'{ident}: empty card')
        require(c['kind'] != 'attack' or c['damage'] > 0, f'{ident}: attack must deal damage')
        require(c['kind'] != 'repair' or c['heal'] > 0, f'{ident}: repair must heal')
    require(Counter(c['unlock'] for c in cards.values()) == {0: 66, 1: 2, 2: 2, 3: 2},
            'cards: expected six unlocks, two at each level')
    for ident in data['starting_deck']:
        require(ident in cards, f'starting_deck: unknown card {ident}')
        require(cards[ident]['unlock'] == 0, f'starting_deck: locked card {ident}')
    require(any(cards[x]['damage'] for x in data['starting_deck']), 'starter deck lacks damage')
    require(any(cards[x]['heal'] for x in data['starting_deck']), 'starter deck lacks healing')
    require(any(cards[x]['vent'] for x in data['starting_deck']), 'starter deck lacks venting')

    require([v['id'] for v in data['characters']] == ['cartographer', 'palimpsest', 'hollow_choir'], 'character registry order differs')
    require(Counter(c.get('character', 'cartographer') for c in cards.values()) == {'cartographer': 36, 'palimpsest': 18, 'hollow_choir': 18}, 'incorrect isolated card pools')
    networks = []
    for vessel in data['characters']:
        ident = vessel['id']
        integer(vessel['max_hull'], 80, 120, f'{ident}.max_hull')
        integer(vessel['capacity'], 3, 3, f'{ident}.capacity')
        integer(vessel['cooling'], 1, 1, f'{ident}.cooling')
        require(len(vessel['starting_deck']) == 10, f'{ident}: starter deck must contain ten cards')
        for card_id in vessel['starting_deck']:
            require(card_id in cards and cards[card_id].get('character', 'cartographer') == ident and cards[card_id]['unlock'] == 0, f'{ident}: foreign or locked starter card')
        require(len(vessel['organs']) == 6 and len({o['id'] for o in vessel['organs']}) == 6, f'{ident}: needs six distinct organs')
        for organ in vessel['organs']:
            require(set(organ) == FIELDS['organs'], f'{ident}: malformed organ')
            for field in ('id', 'name', 'verb', 'description', 'color'): text(organ[field], f'{ident}.organ.{field}')
        edges = set()
        for edge in vessel['edges']:
            require(isinstance(edge, list) and len(edge) == 2 and edge[0] != edge[1], f'{ident}: malformed graph edge')
            for node in edge: integer(node, 0, 5, f'{ident}.edge')
            key = tuple(sorted(edge))
            require(key not in edges, f'{ident}: duplicate graph edge')
            edges.add(key)
        visited = {0}
        while True:
            expanded = visited | {b for a, b in edges if a in visited} | {a for a, b in edges if b in visited}
            if expanded == visited: break
            visited = expanded
        require(len(visited) == 6, f'{ident}: disconnected organ network')
        networks.append(frozenset(edges))
    require(len(set(networks)) == 3, 'characters must have distinct routing networks')

    require({p['effect'] for p in data['powerups']} == POWER_EFFECTS, 'powerups: missing, duplicate, or unsupported effect')
    for p in data['powerups']:
        integer(p['value'], 1, 99, f'{p["id"]}.value')
        integer(p['unlock'], 0, 3, f'{p["id"]}.unlock')
        require(str(p['value']) in p['description'], f'{p["id"]}: missing numeric description')
    require(Counter(p['unlock'] for p in data['powerups']) == {0: 15, 1: 1, 2: 1, 3: 1},
            'powerups: expected one unlock at each level')

    enemies = {e['id']: e for e in data['enemies']}
    for e in enemies.values():
        ident = e['id']
        integer(e['region'], 0, 5, f'{ident}.region')
        integer(e['art'], 0, 19, f'{ident}.art')
        require(e['role'] in {'regular', 'elite', 'boss'}, f'{ident}: invalid role')
        integer(e['hp'], 1, 999, f'{ident}.hp')
        if e['role'] == 'regular':
            integer(e['hp'], 70, 140, f'{ident}.hp')
        require(isinstance(e['pattern'], list) and e['pattern'], f'{ident}: empty pattern')
        for p in e['pattern']:
            require(isinstance(p, dict) and set(p) == {'kind', 'amount', 'label'}, f'{ident}: unsupported pattern fields')
            require(p['kind'] in PATTERN_KINDS, f'{ident}: unsupported pattern kind')
            integer(p['amount'], 1, 99, f'{ident}.pattern.amount')
            text(p['label'], f'{ident}.pattern.label')
            if p['kind'] == 'attack':
                integer(p['amount'], [5, 8, 11, 5, 5, 5][e['region']], [10, 13, 16, 12, 12, 12][e['region']], f'{ident}.attack')
    for region in range(6):
        pool = [e for e in enemies.values() if e['region'] == region]
        require(Counter(e['role'] for e in pool) == {'regular': 4, 'elite': 1, 'boss': 1}, f'region {region}: incorrect enemy roles')
        elite = next(e for e in pool if e['role'] == 'elite')
        require(elite['hp'] > max(e['hp'] for e in pool if e['role'] == 'regular'), f'{elite["id"]}: elite hull must exceed regular enemies')
        boss = enemies.get(BOSSES[region])
        require(boss is not None and boss['region'] == region and boss['role'] == 'boss', f'region {region}: wrong boss')
        require(boss['hp'] > elite['hp'], f'{boss["id"]}: boss hull must exceed its elite')
        require(data['regions'][region]['boss'] == boss['id'], f'region {region}: broken boss reference')
    require('incubate' in {p['kind'] for p in enemies[BOSSES[0]]['pattern']}, 'sun must incubate')
    require('rebuild' in {p['kind'] for p in enemies[BOSSES[1]]['pattern']}, 'parliament must rebuild')
    require({'mark', 'sever'} <= {p['kind'] for p in enemies[BOSSES[2]]['pattern']}, 'witness must mark and sever')

    require(Counter(e['region'] for e in data['events']) == {-1: 6, 0: 2, 1: 2, 2: 2, 3: 2, 4: 2, 5: 2}, 'events: incorrect regional distribution')
    for e in data['events']:
        integer(e['region'], -1, 5, f'{e["id"]}.region')
        require(isinstance(e['choices'], list) and len(e['choices']) >= 2, f'{e["id"]}: needs choices')
        for c in e['choices']:
            require(isinstance(c, dict) and set(c) == {'label', 'detail', 'effect', 'value'}, f'{e["id"]}: unsupported choice fields')
            require(c['effect'] in EVENT_EFFECTS, f'{e["id"]}: unsupported event effect')
            text(c['label'], f'{e["id"]}.choice.label')
            text(c['detail'], f'{e["id"]}.choice.detail')
            integer(c['value'], 1, 99, f'{e["id"]}.choice.value')
            require(str(c['value']) in c['detail'], f'{e["id"]}: missing consequence number')
    require({c['effect'] for e in data['events'] for c in e['choices']} == EVENT_EFFECTS, 'event catalog must exercise every supported effect')
    return dict(COUNTS)


def self_test(data):
    mutations = [
        lambda d: d['cards'].pop(),
        lambda d: d['characters'][1]['starting_deck'].__setitem__(0, 'needle'),
        lambda d: d['characters'][1].__setitem__('edges', [[0, 1]]),
        lambda d: d['cards'][36].__setitem__('character', 'hollow_choir'),
        lambda d: d['cards'][0].__setitem__('cost', 0),
        lambda d: d['cards'][0].__setitem__('cost', 3),
        lambda d: d['starting_deck'].__setitem__(0, 'missing_card'),
        lambda d: d['cards'][0].__setitem__('damage', True),
        lambda d: d['cards'][0].__setitem__('unsupported', 1),
        lambda d: d['powerups'][0].__setitem__('effect', 'teleport'),
        lambda d: d['enemies'][0]['pattern'][0].__setitem__('kind', 'poison'),
        lambda d: d['regions'][0].__setitem__('boss', 'missing_boss'),
        lambda d: d['events'][0]['choices'][0].__setitem__('effect', 'future_feature'),
        lambda d: d['cards'][1].__setitem__('id', d['cards'][0]['id']),
    ]
    for index, mutate in enumerate(mutations, 1):
        broken = copy.deepcopy(data)
        mutate(broken)
        try:
            validate(broken)
        except ValueError:
            continue
        raise ValueError(f'self-test {index}: accepted invalid catalog')
    return len(mutations)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', nargs='?', type=Path, default=Path(__file__).resolve().parents[1] / 'data' / 'catalog.json')
    parser.add_argument('--self-test', action='store_true', help='also prove rejection of fourteen invalid catalogs')
    args = parser.parse_args()
    try:
        data = json.loads(args.catalog.read_text())
        counts = validate(data)
        print('PASS: ' + ', '.join(f'{n} {k}' for k, n in counts.items()))
        if args.self_test:
            print(f'PASS: rejected {self_test(data)} malformed catalog mutations')
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'FAIL: {error}\n')


if __name__ == '__main__':
    main()
