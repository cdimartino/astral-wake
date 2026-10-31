extends SceneTree
const Game = preload("res://scripts/game.gd")
const SHIPS = ["cartographer", "palimpsest", "hollow_choir"]
var checks := 0
var failures := 0
var directory := "/tmp/astral-expansion-%d" % Time.get_ticks_usec()

func require(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new(directory)
	require(game.catalog.cards.size() == 72, "Three distinct card pools total 72 cards")
	require(game.catalog.regions.size() == 6, "Six possible areas")
	require(game.catalog.characters.size() == 3, "Three playable ships")
	var seen_areas := {}
	var widths := {}
	var starters := {}
	for ship in SHIPS:
		for seed_value in range(1, 21):
			require(game.new_run(seed_value, ship).ok, "New expedition for " + ship)
			require(game.character().id == ship, "Selected character is retained")
			var itinerary: Array = game.run.route_regions
			require(itinerary.size() == 3, "Mission contains exactly three areas")
			var unique := {}
			for area in itinerary:
				unique[area] = true
				seen_areas[area] = true
				require(int(area) >= 0 and int(area) < 6, "Area is in registry")
			require(unique.size() == 3, "Areas do not repeat within a mission")
			require(game.run.deck.size() == 10, "Ten-card starting deck")
			for card in game.run.deck:
				require(game.card(card.id).get("character", "cartographer") == ship, "Starting cards belong to selected ship")
			starters[ship] = game.run.deck.map(func(card): return card.id)
			var chart: Array = game.run.map
			require(chart.size() == 12, "Twelve layers including boss")
			var reachable := {}
			for node in chart[0]: reachable[node.id] = true
			for layer in range(chart.size()):
				widths[chart[layer].size()] = true
				for node in chart[layer]:
					require(reachable.has(node.id), "Every displayed map node is reachable")
					for edge in node.edges:
						var next_ids: Array = chart[layer + 1].map(func(next): return next.id) if layer < 11 else []
						require(next_ids.has(edge), "Every route advances exactly one layer")
						reachable[edge] = true
			require(chart[11].size() == 1 and reachable.has(chart[11][0].id), "Boss is reachable")
			var expected := JSON.stringify([game.run.route_regions, game.run.map, game.run.deck, game.run.rng_state])
			game.new_run(seed_value, ship)
			require(JSON.stringify([game.run.route_regions, game.run.map, game.run.deck, game.run.rng_state]) == expected, "Seed reproduces itinerary, map and deck")
		require(game.choose_node(game.run.map[0][0].id).ok, "Opening combat starts")
		var before := JSON.stringify(game.run)
		game.save()
		var restored = Game.new(directory)
		require(restored.load_saved(), "Expanded combat save loads")
		require(JSON.stringify(restored.run) == before, "Resume preserves character, itinerary, deck order and encounter")
	require(seen_areas.size() == 6, "Fixed seeds exercise all six areas")
	require(widths.size() >= 3, "Maps have varied widths rather than identical columns")
	for i in range(SHIPS.size()):
		for j in range(i + 1, SHIPS.size()):
			for id in starters[SHIPS[i]]:
				require(not starters[SHIPS[j]].has(id), "Characters have distinct starting cards")
	mechanics(game)
	legacy_save(game)
	for area in range(6):
		game.new_run(2026)
		var boss: String = game.catalog.regions[area].boss
		game.run.region = 0
		var early = game._make_enemy(boss)
		game.run.region = 2
		var late = game._make_enemy(boss)
		require(late.max_hp > early.max_hp, "Every area's boss scales with mission stage")
	print("EXPANSION_TESTS ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func fixture(game, ship: String, ids: Array) -> void:
	game.new_run(2026,ship)
	game.choose_node(game.run.map[0][0].id)
	game.run.hull = 50
	for i in range(ids.size()): game.run.deck[i].id = ids[i]
	game.run.battle.hand = game.run.deck.slice(0,ids.size()).duplicate(true)
	game.run.battle.draw = game.run.deck.slice(ids.size()).duplicate(true)
	game.run.battle.discard.clear()
	# Character payload checks use an unarmored target, independently of the map.
	game.run.battle.enemies = [game._make_enemy("cinder_mite")]
	for foe in game.run.battle.enemies:
		foe.hp = 5000
		foe.max_hp = 5000

func checked_play(game, route: Array) -> Dictionary:
	var before := JSON.stringify(game.run)
	var preview = game.preview_card(0,route,0)
	require(preview.ok, "Character route has a valid preview")
	require(JSON.stringify(game.run) == before, "Character preview does not mutate meters or piles")
	var result = game.play_card(0,route,0)
	require(result.ok and result.presentation == preview.presentation, "Character preview and actual effects match")
	return result

func mechanics(game) -> void:
	fixture(game,"palimpsest",["first_draft","first_draft","first_draft"])
	checked_play(game,[0])
	require(game.run.battle.trace == 4, "First Draft plus Scribe stores four Trace")
	game.save()
	var restored = Game.new(directory)
	require(restored.run.battle.trace == 4 and restored.run.battle.last_payload.damage == 6, "Trace and prior payload survive resume")
	var recall = checked_play(game,[2])
	require(recall.damage >= 18 and game.run.battle.trace == 0, "Recall spends accumulated Trace on damage")
	var rewrite = checked_play(game,[5])
	require(rewrite.damage >= 9 and game.run.battle.trace == 0, "Rewrite uses the previous base payload, not a recursive amplified result")
	fixture(game,"hollow_choir",["choral_bolt","warm_refrain","choral_bolt"])
	checked_play(game,[0])
	require(game.run.battle.resonance == 1, "Conductor begins a phrase")
	checked_play(game,[0])
	require(game.run.battle.resonance == 3, "Alternating to repair builds capped Resonance")
	var crescendo = checked_play(game,[2])
	require(crescendo.damage >= 14 and game.run.battle.resonance == 0, "Crescendo spends Resonance to amplify an attack")
	require(game.run.battle.last_command_kind == "attack", "Choir remembers its last command kind")

func legacy_save(game) -> void:
	game.new_run(2026)
	game.run.route_regions = [0,1,2]
	game.run.map = game._generate_map(game.run)
	game.choose_node(game.run.map[0][0].id)
	var expected: Dictionary = game.run.duplicate(true)
	game.run.erase("character")
	game.run.erase("route_regions")
	for key in ["trace","resonance","last_payload","last_command_kind"]: game.run.battle.erase(key)
	game.save()
	var restored = Game.new(directory)
	require(restored.run.get("character","") == "cartographer", "Old saves remain Cartographer expeditions")
	require(restored.run.get("route_regions",[]) == [0,1,2], "Old saves keep their original itinerary")
	for key in ["rng_state","deck","map","hull","region","layer"]:
		require(restored.run.get(key) == expected[key], "Migration preserves " + key)
	for key in ["hand","draw","discard","strain","command_points","enemies"]:
		require(restored.run.battle.get(key) == expected.battle[key], "Migration preserves combat " + key)
