extends RefCounted
## Isolated fixture definitions: never registered by production or reward generation.
const Zones = preload("res://tests/card_zone_fixtures.gd")

static func register(game) -> void:
	for spec in [
		{"id":"fixture_radiator","name":"Phase Radiator","cost":2,"install":"phase_radiator","engine":{"type":"cooling_ward","threshold":2,"ward":5},"description":"FIXTURE ONLY. Install: once/player turn, first later command removing at least 2 actual strain (vent + post-route cooling) grants 5 flat ward. Not end-turn cooling."},
		{"id":"fixture_loom","name":"Interception Loom","cost":2,"install":"interception_loom","engine":{"type":"redirect_retaliation","damage":6},"description":"FIXTURE ONLY. Install: once/enemy phase, first positive redirect deals 6 extra damage to the SAME recipient after that attack. Separate armor/exposed; dead recipient has no retarget. No payout after player lethal."},
		{"id":"fixture_cool","name":"Fixture Cooling Command","vent":1,"retain":true},
		{"id":"fixture_cool_choice","name":"Fixture Chosen Cooling","vent":1,"retain":true,"selections":[{"kind":"exhaust_hand"}]},
		{"id":"fixture_postcool","name":"Fixture Post-route Cooling","vent":1,"retain":true,"route_cooling":{"type":"three_first","amount":1}},
		{"id":"fixture_neutral","name":"Fixture Neutral"},
	]:
		var definition=game.card("graft_wire").duplicate(true)
		definition.merge({"draw":0,"vent":0,"damage":0,"heal":0,"disrupt":0,"link":false,"cost":1,"kind":"utility","description":"FIXTURE ONLY: defense engine command."},true)
		definition.merge(spec,true)
		game._cards[definition.id]=definition

static func battle(game) -> void:
	Zones.battle(game)
	for i in range(game.run.deck.size()): Zones.identify(game,i,"fixture_neutral")
	for pair in [[0,"fixture_radiator"],[1,"fixture_loom"],[2,"fixture_cool"],[3,"fixture_cool_choice"],[4,"fixture_postcool"]]: Zones.identify(game,pair[0],pair[1])
	# A visible one-boundary mark keeps Loom available for turn 2 without adding
	# intrinsic Retain to either actual engine prototype definition.
	game.retain_card(2)
	game.run.battle.enemies=[game._make_enemy("cinder_mite"),game._make_enemy("cinder_mite")]
	for foe in game.run.battle.enemies:
		foe.hp=100
		foe.max_hp=100
		foe.intent={"kind":"attack","amount":0,"label":"Fixture idle"}

class FixtureGame extends "res://scripts/game.gd":
	func _init(directory: String = "") -> void:
		super(directory)
		load("res://tests/defense_engine_fixtures.gd").register(self)
		load_saved()

class FixtureSession extends "res://tools/manual_session.gd":
	func _create_game(directory: String): return FixtureGame.new(directory)
	func start(directory: String, seed_value, ship: String, unlocks: int) -> Dictionary:
		var result=super(directory,seed_value,ship,unlocks)
		if not result.ok: return result
		load("res://tests/defense_engine_fixtures.gd").battle(game)
		game.save()
		journal.initial=snapshot(game.run)
		return inspect()
