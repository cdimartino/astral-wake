extends RefCounted
const Zones = preload("res://tests/card_zone_fixtures.gd")

static func register(game) -> void:
	Zones.register(game)
	for spec in [
		{"id":"fixture_atlas","name":"Fixture Living Atlas","install":"living_atlas","engine":{"type":"novel_route","cap":6}},
		{"id":"fixture_furnace","name":"Fixture Archive Furnace","install":"archive_furnace","engine":{"type":"other_exhaust","cap":5}},
		{"id":"fixture_strike","name":"Fixture Ten","kind":"attack","damage":10},
		{"id":"fixture_consume","name":"Fixture Double Exhaust","exhaust":true,"selections":[{"kind":"exhaust_hand"}]},
		{"id":"fixture_install_consume","name":"Fixture Installing Furnace","install":"second_furnace","engine":{"type":"other_exhaust","cap":5},"selections":[{"kind":"exhaust_hand"}]},
	]:
		var definition=game.card("graft_wire").duplicate(true)
		definition.merge({"draw":0,"vent":0,"damage":0,"heal":0,"disrupt":0,"link":false,"cost":1},true)
		definition.merge(spec,true)
		definition.description="Test-only bounded engine fixture."
		game._cards[definition.id]=definition

static func battle(game) -> void:
	Zones.battle(game)
	for i in range(game.run.deck.size()): Zones.identify(game,i,"fixture_strike")
	Zones.identify(game,0,"fixture_atlas")
	Zones.identify(game,1,"fixture_furnace")
	Zones.identify(game,3,"fixture_consume")
	game.run.battle.capacity=20

static func demo(game) -> void:
	register(game)
	battle(game)
	game.run.battle.capacity=3
	# Deterministic second-turn manual choices, with visible intrinsic Retain.
	game._cards.fixture_consume.retain=true
	game._cards.fixture_strike.retain=true

class FixtureGame extends "res://scripts/game.gd":
	func _init(directory: String = "") -> void:
		super(directory)
		load("res://tests/install_engine_fixtures.gd").register(self)
		load_saved()

class FixtureSession extends "res://tools/manual_session.gd":
	func _create_game(directory: String): return FixtureGame.new(directory)
	func start(directory: String, seed_value, ship: String, unlocks: int) -> Dictionary:
		var result=super(directory,seed_value,ship,unlocks)
		if not result.ok: return result
		load("res://tests/install_engine_fixtures.gd").battle(game)
		# Keep exact second-turn exhaust choices known across separate processes.
		game.retain_card(4)
		game.retain_card(5)
		game.save()
		journal.initial=snapshot(game.run)
		return inspect()
