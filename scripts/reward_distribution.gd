class_name AstralRewardDistribution
extends RefCounted
## Generation 1. No deck, hull, ownership or tactical scoring inputs.
const NORMAL = [65, 28, 7]
const ELITE = [35, 45, 20]
const PRICES = [30, 40, 55]
const PITY_LIMIT = 6
const ROLES = ["attack", "group", "prevention", "repair", "enabler", "selection", "scaling"]
const IMMEDIATE = ["attack", "group", "prevention", "repair"]

static func price(card: Dictionary) -> int:
	# Explicit audit exception: do not sell base-dominating Bright Canon for
	# less than Crescendo while the separate Choir base-design follow-up is open.
	return 40 if card.id == "bright_canon" else int(PRICES[int(card.rarity)])

static func valid_weights(weights: Variant) -> bool:
	if not weights is Array or weights.size() != 3: return false
	var total: int = 0
	for weight in weights:
		if not (weight is int or weight is float) or not is_finite(float(weight)) or weight != floor(weight) or weight < 0 or weight > 100: return false
		total += int(weight)
	return total == 100

static func mechanical_roles(card: Dictionary) -> Array:
	var roles: Array = []
	if card.get("damage", 0) > 0: roles.append("attack")
	# Split routing is not printed group damage. Do not label it as such.
	if card.get("disrupt", 0) > 0 or card.get("ward", 0) > 0 or card.has("conditional_ward"): roles.append("prevention")
	if card.get("heal", 0) > 0: roles.append("repair")
	if card.get("vent", 0) > 0 or card.get("link", false) or card.get("trace", 0) > 0 or card.get("resonance", 0) > 0 or card.has("route_cooling"): roles.append("enabler")
	# Selection includes card access (draw), not a promise of targeted search.
	if card.get("draw", 0) > 0 or card.has("selections"): roles.append("selection")
	if card.get("rewrite", false) or card.get("concert", false) or card.has("engine"): roles.append("scaling")
	return roles

static func valid_card(card: Dictionary) -> bool:
	var rarity: Variant = card.get("rarity")
	if not (rarity is int or rarity is float) or not is_finite(float(rarity)) or rarity != floor(rarity) or rarity < 0 or rarity > 2: return false
	var roles: Variant = card.get("roles")
	if not roles is Array or roles.is_empty() or not card.get("primary_role") in roles: return false
	var expected: Array = mechanical_roles(card)
	if roles.size() != expected.size(): return false
	for role in expected:
		if roles.count(role) != 1: return false
	return true

static func matching(game: RefCounted, pool: Array, roles: Array) -> Array:
	var result: Array = []
	for id in pool:
		for role in roles:
			if role in game.card(id).roles:
				result.append(id)
				break
	return result

static func draw(game: RefCounted, pool: Array, weights: Array, stream: String) -> String:
	assert(valid_weights(weights))
	if pool.is_empty(): return ""
	var buckets: Array = [[], [], []]
	for id in pool: buckets[int(game.card(id).rarity)].append(id)
	var total: int = 0
	for rarity in range(3):
		if not buckets[rarity].is_empty(): total += int(weights[rarity])
	# Exhausted/zero-weight rarity pools: uniform among remaining IDs, finite.
	if total == 0: return str(pool[game._pick(game.run, pool.size(), stream)])
	var roll: int = game._pick(game.run, total, stream)
	for rarity in range(3):
		if buckets[rarity].is_empty(): continue
		roll -= int(weights[rarity])
		if roll < 0: return str(buckets[rarity][game._pick(game.run, buckets[rarity].size(), stream)])
	return ""

static func reward(game: RefCounted, pool: Array, count: int, kind: String) -> Array:
	var remaining: Array = pool.duplicate()
	var chosen: Array = []
	var weights: Array = NORMAL if kind == "battle" else ELITE
	var ordinary: bool = kind == "battle"
	if ordinary and game.run.rare_offer_misses == PITY_LIMIT:
		var rares: Array = []
		for id in remaining:
			if game.card(id).rarity == 2: rares.append(id)
		if not rares.is_empty() and count > 0:
			var id: String = draw(game, rares, weights, "rewards")
			chosen.append(id)
			remaining.erase(id)
	while chosen.size() < count and not remaining.is_empty():
		var candidates: Array = remaining
		# On the final slot, restrict only if all earlier primary roles match.
		if ordinary and count >= 3 and chosen.size() == count - 1:
			var roles: Array = []
			for id in chosen:
				if not game.card(id).primary_role in roles: roles.append(game.card(id).primary_role)
			if roles.size() == 1:
				var diverse: Array = []
				for id in remaining:
					if game.card(id).primary_role != roles[0]: diverse.append(id)
				if not diverse.is_empty(): candidates = diverse
		var id: String = draw(game, candidates, weights, "rewards")
		chosen.append(id)
		remaining.erase(id)
	if ordinary:
		var rare: bool = false
		for id in chosen:
			if game.card(id).rarity == 2: rare = true
		game.run.rare_offer_misses = 0 if rare else mini(PITY_LIMIT, int(game.run.rare_offer_misses) + 1)
	return chosen

static func shop(game: RefCounted, pool: Array) -> Array:
	# Enumerate valid distinct pairs before drawing, so overlapping roles cannot
	# consume the only eligible engine candidate in the first slot.
	var pairs: Array = []
	var immediate: Array = matching(game, pool, IMMEDIATE)
	var engines: Array = matching(game, pool, ["enabler", "scaling"])
	for first in immediate:
		for second in engines:
			if first != second: pairs.append([first, second])
	if not pairs.is_empty(): return pairs[game._pick(game.run, pairs.size(), "shop")]
	var remaining: Array = pool.duplicate()
	var chosen: Array = []
	# If both promises cannot coexist, prefer immediate use, then fill uniformly.
	var preferred: Array = immediate if not immediate.is_empty() else engines
	if not preferred.is_empty():
		chosen.append(preferred[game._pick(game.run, preferred.size(), "shop")])
		remaining.erase(chosen[0])
	while chosen.size() < 2 and not remaining.is_empty():
		var id: String = remaining[game._pick(game.run, remaining.size(), "shop")]
		chosen.append(id)
		remaining.erase(id)
	return chosen

static func policy(state: Dictionary) -> String:
	if state.get("reward_generation", 0) == 0: return "Rewards v0 · legacy uniform offers and shop prices · no pity."
	var misses: int = int(state.rare_offer_misses)
	return "Rewards v1 · rare pity %d/6 · %s Ordinary offers only; resets on offer, not take. Elite/boss offers do not count." % [misses, "Rare guaranteed on next eligible ordinary offer." if misses == 6 else "After 6 misses, next eligible ordinary offer guarantees a rare."]
