#!/usr/bin/env python3
"""Closed typed definitions and explicit ward evolution override validation."""
import copy
from validate_content import validate_route_effects, validate_evolutions

checks = 0


def check(card, valid):
    global checks
    checks += 1
    try:
        validate_route_effects(card)
        validate_evolutions(card)
    except ValueError:
        assert not valid, card
    else:
        assert valid, card


base = dict(kind='attack', damage=9, heal=0)
for field, types in [('conditional_damage', ['novel_route', 'route_strain_two']),
                     ('conditional_ward', ['prism_other_foe']),
                     ('route_cooling', ['three_first'])]:
    for typ in types:
        good = base | {field: dict(type=typ, amount=1)}
        check(good, True)
        for bad in [None, True, -1, 0, .5, 100, '6']:
            card = copy.deepcopy(good)
            card[field]['amount'] = bad
            check(card, False)
        for bad in [None, True, 'script', {}, dict(type='script', amount=1), dict(type=typ, amount=1, cap=6)]:
            check(base | {field: bad}, False)
        if field == 'conditional_damage':
            for overrides in [dict(kind='utility'), dict(damage=0), dict(damage=True)]:
                check(good | overrides, False)
for ward in [0, 5, 99]:
    check(base | dict(ward=ward), True)
for ward in [None, True, -1, 100, .5, '5']:
    check(base | dict(ward=ward), False)
branches = [dict(id='warded', name='Warded', description='Gain 7 flat ward.', stats=dict(ward=7)),
            dict(id='plain', name='Plain', description='Deal 10 damage.', stats=dict(damage=10))]
check(base | dict(evolutions=branches), True)
for key, value in [('ward', True), ('ward', -1), ('ward', .5), ('ward', 100),
                   ('conditional_damage', dict(type='novel_route', amount=5)),
                   ('conditional_ward', dict(type='prism_other_foe', amount=4)),
                   ('route_cooling', dict(type='three_first', amount=1))]:
    bad = copy.deepcopy(branches)
    bad[0]['stats'] = {key: value}
    check(base | dict(evolutions=bad), False)
print(f'Route effects validator: {checks} checks passed')
