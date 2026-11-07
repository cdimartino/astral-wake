"""Narrow compatibility adapter for frozen pre-release catalog fingerprints."""
import copy


def historical_display_labels(catalog):
    """Copy and normalize only seven asserted, display-only released verb renames.

    Never normalize card/evolution, role/rarity, enemy or numerical gameplay data.
    Callers retain their original canonical serialization and historical digests.
    """
    result = copy.deepcopy(catalog)
    renames = {'fork': ('Split', 'Divide'), 'echo': ('Amplify', 'Resound'),
               'hush': ('Dampen', 'Silence')}
    cartographer = next(c for c in result['characters'] if c['id'] == 'cartographer')
    choir = next(c for c in result['characters'] if c['id'] == 'hollow_choir')
    normalized = 0
    for organs, labels in [(result['organs'], renames), (cartographer['organs'], renames),
                           (choir['organs'], {'rest': ('Settle', 'Breathe')})]:
        for organ_id, (released, historical) in labels.items():
            matches = [o for o in organs if o['id'] == organ_id]
            assert len(matches) == 1, organ_id
            organ = matches[0]
            assert organ['verb'] == released, (organ_id, organ['verb'])
            organ['verb'] = historical
            normalized += 1
    assert normalized == 7
    return result
