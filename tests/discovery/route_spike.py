"""Route-space spike: count legal routes for small organ sets.

Follows the engine rule in scripts/game.gd:_validate_route: organs distinct,
each consecutive pair joined by an open edge (edges are bidirectional).
Strain and enemy effects are ignored. Usage: python3 tests/discovery/route_spike.py
"""
import itertools
import json

catalog = json.load(open("data/catalog.json"))


def routes(n, edges, maxlen):
    adj = set()
    for a, b in edges:
        adj.add((a, b))
        adj.add((b, a))
    out = []

    def rec(r):
        if r:
            out.append(tuple(r))
        if len(r) == maxlen:
            return
        for x in range(n):
            if x in r or (r and (r[-1], x) not in adj):
                continue
            rec(r + [x])

    rec([])
    return out


def report(label, n, edges, maxlen):
    rs = routes(n, edges, maxlen)
    sets = {frozenset(r) for r in rs}
    by_len = [sum(1 for r in rs if len(r) == k) for k in range(1, maxlen + 1)]
    print(f"{label:46s} routes={len(rs):3d} by_len={by_len} distinct_organ_sets={len(sets)}")


tri = [(0, 1), (1, 2), (2, 0)]
report("3-organ ring, current max 3", 3, tri, 3)
report("3-organ ring, cap 2 (proposed)", 3, tri, 2)
report("2-organ start, cap 2", 2, [(0, 1)], 2)
report("2-organ start, current max 3", 2, [(0, 1)], 3)
for c in catalog["characters"]:
    report(f"{c['id']} (6 organs, current max 3)", 6, c["edges"], 3)
    report(f"{c['id']} (6 organs, cap 2)", 6, c["edges"], 2)
for c in catalog["characters"]:
    sub = (0, 1, 2)  # first three organs of each ship: the candidate start set
    E = [(sub.index(a), sub.index(b)) for a, b in c["edges"] if a in sub and b in sub]
    report(f"{c['id']} first 3 organs, cap 2 (edges={len(E)})", 3, E, 2)
    report(f"{c['id']} first 3 organs, max 3 (edges={len(E)})", 3, E, 3)
