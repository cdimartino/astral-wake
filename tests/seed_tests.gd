extends SceneTree
const Game = preload("res://scripts/game.gd")
const Seeds = preload("res://scripts/seed_engine.gd")
var checks := 0
var failures := 0
var directory := OS.get_environment("TMPDIR").path_join("astral-seeds-%d" % Time.get_ticks_usec())

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func snapshot(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(true)
	for key in ["id", "started_at", "elapsed_seconds", "seeded"]: copy.erase(key)
	return copy

func make_game(code = "A1B2C3", ship := "cartographer"):
	var game = Game.new(directory.path_join(str(Time.get_ticks_usec())))
	require(game.new_run(code, ship).ok, "Valid seed starts a game")
	return game

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	for value in [0, 1, 35, 36, 123456, Seeds.SPACE - 1]:
		require(Seeds.decode(Seeds.encode(value)) == value, "Base36 round-trip")
	var state := {}
	Seeds.initialize(state, "A1B2C3")
	var actual := []
	for i in range(8): actual.append(Seeds.pick(state, 1000, "world"))
	require(actual == [828, 634, 769, 977, 800, 846, 757, 167], "RNG v1 golden vector must not drift")
	var paired := {}
	Seeds.initialize(paired, "A1B2C3")
	var original := paired.duplicate(true)
	for i in range(100): Seeds.pick(paired, 300, "cards")
	require(Seeds.pick(paired, 1000, "world") == Seeds.pick(original, 1000, "world"), "Card RNG cannot disturb map RNG")
	for tier in range(4):
		for i in range(20):
			var code := Seeds.generate(tier)
			require(Seeds.valid(code) and Seeds.decode(code) % 4 == tier, "Generated code contains the original discovery tier")
	for ship in ["cartographer", "palimpsest", "hollow_choir"]:
		var a = make_game("A1B2C3", ship)
		var b = make_game("a1b2c3", ship)
		b.profile.unlocks = 0
		a.profile.unlocks = 3
		require(snapshot(a.run) == snapshot(b.run), "Same seed creates identical maps, itinerary, starter deck and RNG across profiles")
		require(a._available_cards() == b._available_cards() and a._available_powerups() == b._available_powerups(), "Discovery pools are encoded in seed, not read from profile")
		for game in [a, b]: game.choose_node(game.run.map[0][0].id)
		require(a.run.battle == b.run.battle, "Same seed creates the same enemies and opening hand/draw order")
		var before: Dictionary = a.run.duplicate(true)
		for i in range(20): a.preview_card(0, [0], 0)
		require(a.run == before, "Previews consume no random values")
		require(not a.play_card(99, [0], 0).ok and a.run == before, "Invalid actions consume no random values")
		for turn in range(2):
			for game in [a, b]:
				if game.run.mode == "combat": game.play_card(0, [0], 0)
				if game.run.mode == "combat": game.end_turn()
			require(snapshot(a.run) == snapshot(b.run), "Same tactics reproduce command results, intentions and reshuffles")
		a.save()
		var resumed = Game.new(a.store.directory)
		require(snapshot(resumed.run) == snapshot(a.run), "Save/resume preserves every stream and card pile")
		for stream in Seeds.STREAMS:
			for i in range(10): require(a._pick(a.run, 97, stream) == resumed._pick(resumed.run, 97, stream), "Resumed RNG matches uninterrupted RNG")
		for tier in range(3):
			for game in [a, b]:
				game.run.region = tier
				# Align independent streams after the explicit resume sequence above.
			b.run.rng_streams = a.run.rng_streams.duplicate(true)
			require(a._generate_map(a.run) == b._generate_map(b.run), "All region maps/enemies/events/edges reproduce")
			for game in [a, b]:
				game.run.battle.kind = "boss"
				game._finish_battle()
			require(a.run.reward == b.run.reward, "Reward order reproduces")
			for game in [a, b]: game._make_shop()
			require(a.run.shop == b.run.shop, "Shop inventory/order reproduces")
		a.profile.unlocks = 0
		var saved_profile: Dictionary = a.profile.duplicate(true)
		a._finish_run(true)
		require(a.profile.unlocks == saved_profile.unlocks and a.profile.history[0].seeded, "Seeded victory grants no durable unlocks and history marks practice")
		b.profile.unlocks = 0
		b.abandon()
		require(b.profile.unlocks == 0, "Seeded abandonment/defeat grants no durable unlocks")
	var normal = make_game("")
	require(Seeds.valid(normal.run.seed) and not normal.run.seeded, "Blank seed generates a six-character normal expedition")
	var code: String = normal.run.seed
	var first := snapshot(normal.run)
	normal._finish_run(false)
	require(normal.profile.unlocks == 1, "Ordinary expedition still grants durable progression")
	normal.new_run(code)
	require(snapshot(normal.run) == first and normal.run.seeded, "Ordinary run can be retried exactly after gaining unlocks")
	for tier in range(4):
		normal.profile.unlocks = tier
		normal.new_run()
		var opening := snapshot(normal.run)
		var saved_code: String = normal.run.seed
		require(normal.run.pool_tier == tier, "Ordinary runs retain the player's earned discovery pool")
		normal.profile.unlocks = (tier + 1) % 4
		normal.new_run(saved_code)
		require(snapshot(normal.run) == opening, "Seed replays original tier despite profile changes")
	var good: Dictionary = normal.run.duplicate(true)
	for invalid in ["A", "ABC1234", "ABC-12", "ÅBC123", "１２３４５６", "AB C12"]:
		require(not normal.new_run(invalid).ok and normal.run == good, "Invalid seed does not replace expedition")
	for field in ["rng_version", "rng_streams", "seeded", "pool_tier"]:
		var broken: Dictionary = good.duplicate(true)
		broken.erase(field)
		require(not normal._valid_run(broken), "Incomplete seed state rejected: " + field)
	for bad in [0, -1, Seeds.MODULUS, 1.5, "123", null]:
		var broken: Dictionary = good.duplicate(true)
		broken.rng_streams.cards = bad
		require(not normal._valid_run(broken), "Corrupt stream rejected")
	normal.save()
	var practice_resume = Game.new(normal.store.directory)
	var unlocks: int = practice_resume.profile.unlocks
	practice_resume.abandon()
	require(practice_resume.profile.unlocks == unlocks, "Resumed practice grants no durable progression")
	var saved_finish = Game.new(practice_resume.store.directory)
	require(saved_finish.run.seeded and saved_finish.profile.history[0].seeded and saved_finish.profile.unlocks == unlocks, "Practice marker/history/progression guard survive a completed save")
	# Incomplete stream state is rejected and recovers the previous verified save.
	normal.new_run("ABC123")
	normal.save()
	var corrupt: Dictionary = normal.run.duplicate(true)
	corrupt.rng_streams.cards = 0
	var path: String = normal.store.directory.path_join("save.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"profile":normal.profile,"run":corrupt}))
	file.close()
	var recovered = Game.new(normal.store.directory)
	require(not recovered.run.is_empty() and recovered._valid_run(recovered.run) and recovered.save_error.contains("backup"), "Corrupt RNG state falls back to a validated backup")
	var legacy = make_game(424242)
	legacy.choose_node(legacy.run.map[0][0].id)
	legacy.save()
	var legacy_resume = Game.new(legacy.store.directory)
	require(legacy_resume.run == legacy.run and not legacy_resume.run.has("rng_version"), "Legacy numeric seeds retain their exact RNG and save semantics")
	print("SEED_TESTS ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
