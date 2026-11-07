extends RefCounted
const Zones = preload("res://tests/card_zone_fixtures.gd")

static func register(game) -> void:
	Zones.register(game)
	for spec in [
		{"id":"fixture_scrape","name":"Fixture Scrape Clean","selections":[{"kind":"exhaust_hand"}],"draw":1},
		{"id":"fixture_binding","name":"Fixture Binding Thread","selections":[{"kind":"retain_hand"}],"draw":1},
		{"id":"fixture_reprise","name":"Fixture Reprise","selections":[{"kind":"return_discard"}],"draw":2},
		{"id":"fixture_attack","name":"Fixture Attack Recall","selections":[{"kind":"return_discard","kind_filter":"attack"}]},
		{"id":"fixture_repair","name":"Fixture Repair Recall","selections":[{"kind":"return_discard","kind_filter":"repair","optional":true}]},
		{"id":"fixture_pair","name":"Fixture Ordered Choices","selections":[{"kind":"exhaust_hand"},{"kind":"retain_hand"},{"kind":"return_discard"}],"draw":2},
	]:
		var definition=game.card("graft_wire").duplicate(true)
		definition.merge(spec,true)
		definition.cost=1
		definition.description="Fixture only. "
		for op in definition.selections: definition.description+=op.kind.replace("_"," ")+"; "
		definition.description+="then draw %d. No triggers."%definition.draw
		game._cards[definition.id]=definition

static func setup(game, id: String = "fixture_pair", modern: bool = true) -> void:
	register(game)
	Zones.battle(game,modern)
	Zones.identify(game,0,id)
	game.run.battle.discard.append(game.run.battle.draw.pop_back())

class FixtureGame extends "res://scripts/game.gd":
	func _init(directory: String = "") -> void:
		super(directory)
		load("res://tests/selection_fixtures.gd").register(self)
		load_saved()

class FixtureSession extends "res://tools/manual_session.gd":
	func _create_game(directory: String): return FixtureGame.new(directory)
	func start(directory: String, seed_value, ship: String, unlocks: int) -> Dictionary:
		var result=super(directory,seed_value,ship,unlocks)
		if not result.ok: return result
		load("res://tests/selection_fixtures.gd").setup(game)
		game.save()
		journal.initial=snapshot(game.run)
		return inspect()
