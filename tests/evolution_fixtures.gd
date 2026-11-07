extends RefCounted
## Prototype stats, not final production content or balance evidence.
static func register(game) -> void:
	var needle=game.card("needle").duplicate(true)
	needle.damage=10
	needle.description="Deal 10 damage."
	needle.evolutions=[
		{"id":"impact","name":"Fixture Needle · Impact","description":"Deal 13 damage.","stats":{"damage":13}},
		{"id":"flow","name":"Fixture Needle · Flow","description":"Deal 10 damage. Draw 1 command.","stats":{"damage":10,"draw":1}},
	]
	game._cards.needle=needle
	var installed=needle.duplicate(true)
	installed.id="fixture_evolving_install"
	installed.install="fixture_evolving_install"
	game._cards[installed.id]=installed
	var repair=game.card("hull_stitch").duplicate(true)
	repair.evolutions=[
		{"id":"restore","name":"Fixture Stitch · Restore","description":"Restore 9 hull.","stats":{"heal":9}},
		{"id":"cool","name":"Fixture Stitch · Cool","description":"Restore 5 hull. Cool every organ by 1.","stats":{"heal":5,"vent":1}},
	]
	game._cards.hull_stitch=repair

static func setup(game) -> void:
	register(game)
	game.new_run("A1B2C3")
	game.run.mode="recovery"
	game.recover("upgrade")

class FixtureGame extends "res://scripts/game.gd":
	func _init(directory: String = "") -> void:
		super(directory)
		load("res://tests/evolution_fixtures.gd").register(self)
		load_saved()

class FixtureSession extends "res://tools/manual_session.gd":
	func _create_game(directory: String): return FixtureGame.new(directory)
	func start(directory: String, seed_value, ship: String, unlocks: int) -> Dictionary:
		var result=super(directory,seed_value,ship,unlocks)
		if not result.ok: return result
		game.run.mode="recovery"
		game.recover("upgrade")
		journal.initial=snapshot(game.run)
		return inspect()
