extends SceneTree
const Game = preload("res://scripts/game.gd")
const D = preload("res://scripts/reward_distribution.gd")
const Manual = preload("res://tools/manual_session.gd")
var checks: int = 0
var failures: int = 0
var directory: String = OS.get_environment("TMPDIR").path_join("astral-rewards-%d" % Time.get_ticks_usec())
var report: Dictionary = {"families":[], "raw":[], "offers":[], "exposure":[]}

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func make_game(seed_value = "A1B2C3", ship: String = "cartographer"):
	var game = Game.new(directory.path_join(str(Time.get_ticks_usec())))
	game.new_run(seed_value, ship)
	game.run.content_pool_revision=0 # Historical distribution calibration, not expansion data.
	return game

func _initialize() -> void:
	call_deferred("check")

func ids(choices: Array) -> Array:
	var result: Array = []
	for choice in choices:
		if choice.kind == "card": result.append(choice.id)
	return result

func has_rare(game, offer: Array) -> bool:
	for id in offer:
		if game.card(id).rarity == 2: return true
	return false

func validate_offer(game, offer: Array, pool: Array, count: int, diverse: bool) -> void:
	require(offer.size() == mini(count, pool.size()), "finite offer fills available slots")
	var seen: Array = []
	var primaries: Array = []
	var available_roles: Array = []
	for id in pool:
		if not game.card(id).primary_role in available_roles: available_roles.append(game.card(id).primary_role)
	for id in offer:
		require(id in pool and not id in seen, "eligible distinct IDs; deck ownership does not filter")
		seen.append(id)
		if not game.card(id).primary_role in primaries: primaries.append(game.card(id).primary_role)
	if diverse and count >= 3 and available_roles.size() >= 2: require(primaries.size() >= 2, "true primary-role diversity")

func check() -> void:
	for weights in [D.NORMAL, D.ELITE, [100,0,0]]: require(D.valid_weights(weights), "bounded valid weights")
	for weights in [[65.1,27.9,7], [true,92,7], [101,-8,7], [65,28], [0,0,0], [NAN,0,100]]: require(not D.valid_weights(weights), "reject malformed weights before conversion")
	var game = make_game()
	require(game.run.schema_revision == 7 and game.run.reward_generation == 1, "schema7 generation1, explicit historical pool0")
	for card in game.catalog.cards:
		require(D.valid_card(card), "72 meaningful role definitions")
		var malformed: Dictionary = card.duplicate(true)
		malformed.roles.append("group")
		require(not D.valid_card(malformed), "no fake group damage")
		malformed = card.duplicate(true)
		malformed.rarity = true
		require(not D.valid_card(malformed), "no boolean rarity")
	for field in ["reward_generation", "rare_offer_misses"]:
		for invalid in [null, true, 0.5, -1, 7]:
			var state: Dictionary = game.run.duplicate(true)
			if invalid == null: state.erase(field)
			else: state[field] = invalid
			require(not game._valid_run(state), "strict current-schema distribution field validation")
			var corrupt_directory: String = directory.path_join("raw-%d" % checks)
			DirAccess.make_dir_recursive_absolute(corrupt_directory)
			var file = FileAccess.open(corrupt_directory.path_join("save.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":state}))
			file.close()
			require(Game.new(corrupt_directory).run.is_empty(), "raw JSON malformed field rejected before integer restore")
	var pool: Array = game._available_cards()
	var common: Array = []
	var rare: Array = []
	for id in pool:
		if game.card(id).rarity == 0: common.append(id)
		if game.card(id).rarity == 2: rare.append(id)
	game.run.rare_offer_misses = 0
	for i in range(6):
		D.reward(game, common, 3, "battle")
		require(game.run.rare_offer_misses == i + 1, "ordinary missing-rare offer increments once")
	for kind in ["elite", "boss"]:
		D.reward(game, rare, 2, kind)
		require(game.run.rare_offer_misses == 6, "elite/boss rare neither increments nor resets pity")
	D.shop(game, pool)
	require(game.run.rare_offer_misses == 6, "shop does not alter pity")
	for small in [[], [common[0]], common, [common[0], rare[0]]]:
		game.run.rare_offer_misses = 6
		var offer: Array = D.reward(game, small, 4, "battle")
		validate_offer(game, offer, small, 4, true)
		require(game.run.rare_offer_misses == (0 if has_rare(game, offer) else 6), "pity caps without eligible rares and terminates")
	game.run.rare_offer_misses = 6
	require("6/6" in D.policy(game.run) and "next eligible" in D.policy(game.run), "inspectable guarantee")
	require(has_rare(game, D.reward(game, pool, 3, "battle")) and game.run.rare_offer_misses == 0, "next eligible normal forces rare and resets on offer")
	# Real integration: save/reload, rejection and skip never regenerate offers.
	game = make_game()
	game.choose_node(game.run.map[0][0].id)
	game.run.rare_offer_misses = 6
	game._finish_battle()
	require(has_rare(game, ids(game.run.reward.choices)), "real normal generation uses pity")
	game.save()
	var resumed = Game.new(game.store.directory)
	require(Manual.snapshot(game.run) == Manual.snapshot(resumed.run), "pending v1 reward save exact")
	var before: Dictionary = game.run.duplicate(true)
	D.policy(game.run)
	game.choose_reward(999)
	require(game.run == before, "inspect and rejected take consume nothing")
	game.choose_reward(-1)
	require(game.run.rare_offer_misses == 0, "skip cannot undo/reset offer pity")
	for kind in ["battle", "elite", "boss"]:
		for pockets in [false,true]:
			game = make_game()
			game.choose_node(game.run.map[0][0].id)
			game.run.battle.kind = kind
			if pockets: game.run.powerups.append("many_pockets")
			game._finish_battle()
			var count: int = (3 if kind == "battle" else 2) + (1 if pockets else 0)
			require(ids(game.run.reward.choices).size() == count, "real Many Pockets card count remains additive")
			require(game.run.reward.choices.size() == count + (0 if kind == "battle" else 2), "elite/boss retain separate powerup structure")
			validate_offer(game, ids(game.run.reward.choices), game._available_cards(), count, kind == "battle")
	# Independent modern streams and same-RNG reproducibility.
	game = make_game()
	var paired = make_game()
	paired.run.hull = 1
	paired.run.deck.append_array(paired.run.deck.duplicate(true))
	before = game.run.duplicate(true)
	for i in range(30):
		require(D.reward(game, pool, 4, "battle") == D.reward(paired, pool, 4, "battle"), "same RNG exact constrained offer")
		require(D.shop(game, pool) == D.shop(paired, pool), "same RNG exact shop")
	for stream in ["world", "cards", "enemies"]:
		require(game.run.rng_streams[stream] == before.rng_streams[stream], "reward/shop never consume map/combat streams")
	var same_role: Array = ["needle", "sun_splinter", "wake_lance", "last_match"]
	validate_offer(game, D.reward(game, same_role, 3, "battle"), same_role, 3, true)
	for small in [[], ["needle"], ["needle", "winter_needle"]]:
		var drawn: String = D.draw(game, small, [0,100,0], "rewards")
		require((drawn == "" if small.is_empty() else drawn in small), "zero-positive-weight available bucket falls back finitely")
	shop_checks()
	legacy_checks()
	pending_migration()
	sampling()
	report.metadata = {"content_pool_revision":0,"generation":1,"schema":7,"normal_draw_weights":D.NORMAL,"elite_draw_weights":D.ELITE,"pity_limit":6,"comparison_base":"7382d3d","godot":Engine.get_version_info().string,"scope":"historical pool0 fast offer generation, NOT actual area-1 boss reach; original 72-card pool, NOT an expansion comparison","sources":{}}
	for path in ["scripts/game.gd", "scripts/reward_distribution.gd", "scripts/seed_engine.gd", "data/catalog.json", "tests/reward_distribution_test.gd"]:
		report.metadata.sources[path] = FileAccess.get_sha256("res://" + path)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file = FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "  ", true) + "\n")
	print("REWARD_DISTRIBUTION %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func shop_checks() -> void:
	var game = make_game()
	require(D.price(game.card("bright_canon")) == 40 and D.price(game.card("crescendo")) == 40, "explicit dominance audit floor, not a cheaper strict upgrade")
	for card in game.catalog.cards:
		if card.id != "bright_canon": require(D.price(card) == D.PRICES[int(card.rarity)], "all other prices follow nominal rarity")
	for pool in [[], ["needle"], ["cold_breath"], ["needle", "cold_breath"], ["thread_cannon", "needle"], ["thread_cannon", "graft_wire"]]:
		var offer: Array = D.shop(game, pool)
		validate_offer(game, offer, pool, 2, false)
		if pool.size() >= 2:
			require(not D.matching(game, offer, D.IMMEDIATE).is_empty() and not D.matching(game, offer, ["enabler","scaling"]).is_empty(), "shop overlapping roles still distinct feasible pair")
	game.run.powerups.append("old_favour")
	game._make_shop()
	for item in game.run.shop.items:
		var base: int = D.price(game.card(item.id)) if item.kind == "card" else 75 if item.kind == "powerup" else 30 if item.kind == "remove" else 35
		require(item.cost == int(round(base * 0.8)), "rarity price/service price discounted exactly once")
	game.save()
	var resumed = Game.new(game.store.directory)
	require(resumed.run.shop == game.run.shop, "pending shop prices preserve on reload")
	game.run.salvage = 1000
	var cost: int = game.run.shop.items[0].cost
	var count: int = game.run.deck.size()
	require(game.buy(0).ok and game.run.salvage == 1000 - cost and game.run.deck.size() == count + 1, "card payment and acquisition")
	var before: Dictionary = game.run.duplicate(true)
	require(not game.buy(0).ok and game.run == before, "sold cannot charge twice")
	for i in range(game.run.shop.items.size()):
		if game.run.shop.items[i].kind != "upgrade": continue
		before = game.run.duplicate(true)
		require(game.buy(i).ok, "service opens chooser")
		require(game.cancel_modify().ok and game.run.salvage == before.salvage and not game.run.shop.items[i].sold, "cancel preserves service and salvage")
	for family in range(30):
		for tier in [0,3]:
			for ship in ["cartographer", "palimpsest", "hollow_choir"]:
				game = make_game(Game.SeedEngine.encode(120000 + family * 400 + tier), ship)
				var offer: Array = D.shop(game, game._available_cards())
				require(offer.size() == 2 and offer[0] != offer[1], "all shop seed families have distinct choices")
				require(not D.matching(game, offer, D.IMMEDIATE).is_empty() and not D.matching(game, offer, ["enabler", "scaling"]).is_empty(), "fresh and full production shops cover both role promises")

func legacy_checks() -> void:
	var oracles: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reward_legacy_oracle.json"))
	for oracle in oracles:
		if oracle.seed is String:
			var fresh = make_game(oracle.seed, oracle.ship)
			fresh.choose_node(fresh.run.map[0][0].id)
			fresh._finish_battle()
			require(fresh.run.map == fresh._restore_integers(oracle.reward.map) and fresh.run.route_regions == fresh._restore_integers(oracle.reward.route_regions), "v1 seed encoding and initial world equal base revision")
			for stream in ["world", "cards", "enemies", "shop", "events"]:
				require(fresh.run.rng_streams[stream] == int(oracle.reward.rng_streams[stream]), "v1 changed rewards do not perturb unrelated baseline streams")
		for mode in ["reward", "shop"]:
			var game = make_game()
			var old: Dictionary = oracle[mode].duplicate(true)
			game.store.write(oracle.profile, old)
			var resumed = Game.new(game.store.directory)
			require(resumed.run_exists() and resumed.run.reward_generation == 0, "schema5 migrates permanently to uniform v0")
			var migrated: Dictionary = resumed.run.duplicate(true)
			migrated.schema_revision = 5
			migrated.erase("reward_generation")
			migrated.erase("rare_offer_misses")
			migrated.erase("content_pool_revision")
			require(migrated == game._restore_integers(old), "all pending reward/shop state and legacy streams unchanged")
			require(JSON.stringify(resumed.run[mode], "", true) == JSON.stringify(game._restore_integers(old[mode]), "", true), "pending reward/shop canonical JSON bytes unchanged after existing integral-number restoration")
			if mode == "reward":
				resumed.run.powerups.append("old_favour")
				resumed._make_shop()
				require(resumed.run.shop == game._restore_integers(oracle.shop.shop), "v0 shop exact baseline stock/prices/discount")
			resumed.run.battle.kind = "elite"
			resumed._finish_battle()
			require(resumed.run.reward == game._restore_integers(oracle.next_reward), "v0 subsequent reward exact baseline")
			require(resumed.run.get("rng_streams", {}) == game._restore_integers(oracle.next_streams) and resumed.run.get("rng_state", "") == oracle.next_legacy, "v0 subsequent RNG exact baseline")

func pending_migration() -> void:
	var fixtures = preload("res://tests/selection_fixtures.gd")
	var game = fixtures.FixtureGame.new(directory.path_join("pending-source"))
	fixtures.setup(game, "fixture_scrape")
	require(game.begin_selection(game.run.battle.hand[0].uid, [0], 0, game.run.battle.enemies[0].duplicate(true)).ok, "schema5 pending selection fixture opens")
	var old: Dictionary = game.run.duplicate(true)
	old.schema_revision = 5
	old.erase("reward_generation")
	old.erase("rare_offer_misses")
	old.erase("content_pool_revision")
	old.pending_selection.guard = Game.Selections.guard(game, old, old.pending_selection)
	for damaged in [false,true]:
		var target: String = directory.path_join("old-pending-%s" % damaged)
		DirAccess.make_dir_recursive_absolute(target)
		var state: Dictionary = old.duplicate(true)
		if damaged: state.pending_selection.guard = "wrong"
		var file = FileAccess.open(target.path_join("save.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":state}))
		file.close()
		var loaded = fixtures.FixtureGame.new(target)
		if damaged: require(loaded.run.is_empty(), "old pending guard rejected before migration, not repaired")
		else:
			require(not loaded.run.is_empty() and loaded.run.reward_generation == 0 and loaded._valid_pending(loaded.run), "old verified pending chooser migrates to v0 and rebinds guard")
			require(loaded.run.pending_selection.definition == game._restore_integers(old.pending_selection.definition), "migration never rewrites old effective payload")

func sampling() -> void:
	# Exactly 30 published seed families, four adjacent codes encode tiers 0..3.
	# Fresh/full use offsets 0/3; no dependence on durable profile unlocks.
	for family in range(30): report.families.append(Game.SeedEngine.encode(120000 + family * 400))
	for ship in ["cartographer", "palimpsest", "hollow_choir"]:
		for tier in [0,3]:
			var game = make_game(Game.SeedEngine.encode(120000 + tier), ship)
			var pool: Array = game._available_cards()
			for kind in ["battle", "elite"]:
				var weights: Array = D.NORMAL if kind == "battle" else D.ELITE
				var counts: Array = [0,0,0]
				for i in range(12000): counts[int(game.card(D.draw(game, pool, weights, "rewards")).rarity)] += 1
				for rarity in range(3): require(absf(float(counts[rarity])/12000 - weights[rarity]/100.0) < 0.025, "raw draw rarity weights within fixed finite-sample tolerance")
				report.raw.append({"ship":ship,"tier":tier,"kind":kind,"draws":12000,"rarity":counts})
			for scenario in ["normal", "normal_pockets", "elite", "elite_pockets", "sparse_no_rare"]:
				for version in [0,1]:
					var counts: Array = [0,0,0]
					var exposure: Dictionary = {"defense":0,"enabler":0,"scaling":0,"rare":0}
					var pity_due: int = 0
					var elite: bool = scenario.begins_with("elite")
					var kind: String = "elite" if elite else "battle"
					var slots: int = (2 if elite else 3) + (1 if "pockets" in scenario else 0)
					for family in range(30):
						game = make_game(Game.SeedEngine.encode(120000 + family * 400 + tier), ship)
						var candidates: Array = game._available_cards()
						if scenario == "sparse_no_rare":
							candidates = candidates.filter(func(id): return game.card(id).rarity == 0).slice(0,2)
						var seen: Dictionary = {"defense":false,"enabler":false,"scaling":false,"rare":false}
						for offer_index in range(100):
							var offer: Array
							if version == 0:
								offer = candidates.duplicate()
								game._shuffle(game.run, offer, "rewards")
								offer = offer.slice(0, slots)
							else:
								var previous: int = game.run.rare_offer_misses
								if previous == 6 and not elite: pity_due += 1
								offer = D.reward(game, candidates, slots, kind)
								validate_offer(game, offer, candidates, slots, not elite)
								var expected: int = previous if elite else 0 if has_rare(game, offer) else mini(6, previous + 1)
								require(game.run.rare_offer_misses == expected, "every sampled offer applies pity once on offer")
								if not elite and previous == 6 and scenario != "sparse_no_rare": require(has_rare(game, offer), "every eligible sampled pity offer has a rare")
							for id in offer:
								var card: Dictionary = game.card(id)
								counts[int(card.rarity)] += 1
								if offer_index < 7:
									if "repair" in card.roles or "prevention" in card.roles: seen.defense = true
									if "enabler" in card.roles: seen.enabler = true
									if "scaling" in card.roles: seen.scaling = true
									if card.rarity == 2: seen.rare = true
						for key in exposure:
							if seen[key]: exposure[key] += 1
					var row: Dictionary = {"ship":ship,"tier":tier,"scenario":scenario,"generation":version,"offers":3000,"rarity":counts,"pity_due":pity_due}
					report.offers.append(row)
					report.exposure.append({"ship":ship,"tier":tier,"scenario":scenario,"generation":version,"families":30,"first_offers":7,"seen":exposure})
