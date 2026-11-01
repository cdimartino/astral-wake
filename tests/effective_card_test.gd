extends SceneTree
const Game = preload("res://scripts/game.gd")
const Session = preload("res://tools/manual_session.gd")
const Baseline = preload("res://tests/effective_card_baseline.gd")
const Policy = preload("res://tests/playthrough.gd")
var checks := 0
var failures := 0
var directory := OS.get_environment("TMPDIR").path_join("astral-effective-%d" % Time.get_ticks_usec())

# A seam test, not new content: existing fields must all come from normalization.
class EffectiveGame extends Game:
	var overrides := {}
	func effective_card(instance: Dictionary) -> Dictionary:
		var result = super.effective_card(instance)
		result.merge(overrides, true)
		return result

func require(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func fixture(game, ship: String, id: String, level: int = 1) -> void:
	game.new_run("A1B2C3", ship)
	game.choose_node(game.run.map[0][0].id)
	game.run.hull = 30
	game.run.deck[0].id = id
	game.run.deck[0].level = level
	game.run.battle.hand = [game.run.deck[0].duplicate(true)]
	game.run.battle.draw = game.run.deck.slice(1).duplicate(true)
	game.run.battle.discard.clear()
	game.run.battle.enemies = [game._make_enemy("cinder_mite")]
	game.run.battle.enemies[0].hp = 5000
	game.run.battle.enemies[0].max_hp = 5000

func checked_play(game, route: Array) -> Dictionary:
	var before = Session.snapshot(game.run)
	var preview = game.preview_card(0, route, 0)
	require(preview.ok and Session.snapshot(game.run) == before, "Preview is a pure query, including RNG")
	require(game.preview_card(0, route, 0) == preview and Session.snapshot(game.run) == before, "Repeated preview preserves results, resources, piles and RNG")
	var result = game.play_card(0, route, 0)
	require(result == preview, "Preview and actual result agree exactly")
	return result

func payload(game, damage: int, heal: int, disrupt: int) -> void:
	var expected = {"damage":damage, "heal":heal, "disrupt":disrupt}
	require(game.run.battle.last_command.base == expected, "Last-command base is only unconditional effective printed payload")
	if game.run.character == "palimpsest":
		require(game.run.battle.last_payload == expected, "Rewrite remembers the same non-recursive payload")

func _run() -> void:
	var game = Game.new(directory)
	var needle_original = game._cards.needle
	game._cards.needle = needle_original.duplicate(true)
	game._cards.needle.test_nested = {"values":[1, 2]}
	var source_instance = {"id":"needle", "uid":42, "level":1}
	var detached = game.effective_card(source_instance)
	detached.test_nested.values[0] = 99
	require(game._cards.needle.test_nested.values == [1, 2] and source_instance == {"id":"needle", "uid":42, "level":1}, "Normalizer deep-copies nested fields and preserves source instance identity")
	game._cards.needle = needle_original
	for original in game.catalog.cards:
		var unchanged = original.duplicate(true)
		for level in [0, 1]:
			var instance = {"id":original.id, "uid":42, "level":level}
			var effective = game.effective_card(instance)
			var first_free = level == 1 and int(original.get("ward",0))==0 and not original.has("engine")
			for field in ["damage", "heal", "vent", "disrupt"]:
				var base = int(original.get(field, 0))
				var bonus = 3 if field == "damage" else 2 if field == "heal" else 1
				require(int(effective.get(field, 0)) == base + (bonus if level == 1 and base > 0 else 0), original.id + " exact legacy " + field)
				if base > 0: first_free = false
			require(effective.first_free == first_free, original.id + " exact pure-utility strain exception")
			for field in ["cost", "draw", "trace", "resonance", "link", "rewrite", "concert", "kind"]:
				require(effective.get(field) == original.get(field), original.id + " unchanged " + field)
			effective.description = "mutated copy"
			require(original == unchanged and game.effective_card(instance).description == original.description, "Definitions are detached from catalog and future calls")
	fixture(game, "cartographer", "graft_wire")
	var uid = game.run.battle.hand[0].uid
	game.run.battle.draw.clear()
	checked_play(game, [0, 1, 2])
	require(game.run.battle.strain == [0, 1, 1, 0, 0, 0], "Graft Wire+ spares only first organ")
	require(game.run.battle.hand.size() == 1 and game.run.battle.hand[0].uid == uid and game.run.battle.discard.is_empty(), "Discard-before-draw permits same-UID self-redraw")
	fixture(game, "palimpsest", "carbon_breath")
	game.run.battle.strain = [2, 2, 2, 2, 2, 2]
	checked_play(game, [0])
	require(game.run.battle.trace == 3 and game.run.battle.strain == [1, 0, 0, 0, 0, 0], "Carbon Breath+ vents two, gains Trace then Scribe, adds normal strain")
	fixture(game, "palimpsest", "carbon_breath")
	game.run.battle.strain[0] = game.run.battle.capacity
	var before = Session.snapshot(game.run)
	require(not game.preview_card(0, [0], 0).ok and not game.play_card(0, [0], 0).ok, "Vent cannot authorize routing through a saturated organ")
	require(Session.snapshot(game.run) == before, "Rejected route spends nothing and preserves all RNG/piles")
	fixture(game, "palimpsest", "first_draft")
	require(checked_play(game, [0]).damage == 9 and game.run.battle.trace == 4, "First Draft+ keeps exact damage and Trace")
	payload(game, 9, 0, 0)
	fixture(game, "palimpsest", "borrowed_dawn")
	game.run.battle.trace = 2
	game.run.battle.last_payload = {"damage":9, "heal":5, "disrupt":3}
	var result = checked_play(game, [0])
	require(result.cost == 2 and result.damage == 19 and result.heal == 7 and result.disrupt == 1 and game.run.battle.trace == 2, "Borrowed Dawn+ copies prior plain stats after spending Trace, before Scribe")
	payload(game, 11, 5, 0)
	for id in ["bright_canon", "grand_concert"]:
		for previous in ["repair", "attack"]:
			fixture(game, "hollow_choir", id)
			game.run.battle.resonance = 2
			game.run.battle.last_command_kind = previous
			result = checked_play(game, [2])
			var repair = 6 if id == "grand_concert" else 0
			require(result.damage == (21 if previous == "repair" else 15) and result.heal == repair + (3 if previous == "repair" else 0) and game.run.battle.resonance == 0, "Concert sequencing/spend before Crescendo remains exact")
			payload(game, 15, repair, 0)
	fixture(game, "palimpsest", "first_draft")
	game.run.powerups = ["amber_sight", "soft_copper", "first_light", "pilgrim_spine"]
	result = checked_play(game, [0, 1, 2])
	require(result.damage > 9, "Runtime powerups and ordered organs amplify damage")
	payload(game, 9, 0, 0)
	fixture(game, "palimpsest", "borrowed_dawn")
	game.run.powerups = ["amber_sight", "soft_copper", "first_light", "hermit_knot", "velvet_tongue"]
	game.run.battle.trace = 2
	game.run.battle.last_payload = {"damage":9, "heal":5, "disrupt":3}
	result = checked_play(game, [0])
	require(result.damage == 30 and result.heal == 9 and result.disrupt == 2, "Copied/resource, conditional and passive contributions affect only resolved payload")
	payload(game, 11, 5, 0)
	consumer_seam()
	var expected = {
		"cartographer":{"cases":216, "sha256":"b22363c001307d4986e61cb493dd8a155b7828fc0607462e96869ede615f4a68"},
		"palimpsest":{"cases":108, "sha256":"85f1b3a19adcc8df1bf7e2e66d7357d59ffbd10d4ce33212bf6db003a2e66135"},
		"hollow_choir":{"cases":108, "sha256":"5fbae2950785cb0ea685dd06c6e6c30940d9d825304759bc4495aada986ef1c3"}}
	var captured = Baseline.capture(game)
	for ship in expected:
		require(captured[ship] == expected[ship], "Full-state a382575 baseline unchanged for " + ship)
	print("EFFECTIVE_CARD_TEST ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func consumer_seam() -> void:
	var game = EffectiveGame.new(directory.path_join("seam"))
	fixture(game, "palimpsest", "first_draft", 0)
	game.overrides = {"cost":2, "damage":10, "heal":4, "disrupt":2, "trace":1, "draw":1, "link":true, "rewrite":true, "first_free":true}
	game.overrides.description = "Effective text: Deal 6 damage."
	require(game.card_text(game.run.battle.hand[0]).begins_with("Effective text: Deal 10 damage."), "Full text reads effective description and stats")
	game.run.battle.trace = 2
	game.run.battle.last_payload = {"damage":9, "heal":5, "disrupt":3}
	game.run.battle.command_points = 1
	require(not game.preview_card(0, [0], 0).ok, "Affordability reads effective cost, not raw catalog")
	game.run.battle.command_points = 3
	game.run.battle.severed = [[4, 5]]
	var session = Session.new()
	session.game = game
	session.journal = {"entries":[], "errors":[]}
	var view = session.inspect()
	require(view.hand[0].effective_card == game.effective_card(game.run.battle.hand[0]), "Manual inspection shares normalization")
	var effective = view.hand[0].effective_card
	var applied = session.apply({"op":"play", "uid":view.hand[0].uid, "route":[0], "target":{"id":"cinder_mite", "slot":0}, "expect":session.guard()})
	var result = applied.result
	require(applied.ok and session.journal.entries[0].effective_card == effective, "Manual play journals the same effective definition used for resolution")
	require(result.cost == 2 and result.damage == 20 and result.heal == 6 and result.disrupt == 3 and game.run.battle.trace == 2 and game.run.battle.hand.size() == 1 and game.run.battle.severed.is_empty() and game.run.battle.strain[0] == 0, "Resolution reads effective cost, payload, resource gain, Rewrite, draw, Link and first-free")
	payload(game, 10, 4, 2)
	game.overrides.clear()
	fixture(game, "hollow_choir", "bright_canon", 0)
	game.overrides = {"concert":false, "kind":"utility", "resonance":1}
	game.run.battle.resonance = 1
	game.run.battle.last_command_kind = "attack"
	result = checked_play(game, [3])
	require(result.damage == 12 and result.heal == 1 and game.run.battle.resonance == 3 and game.run.battle.last_command_kind == "utility", "Choir sequencing, resource gain, Concert and organ kind checks read effective fields")
	game.overrides.clear()
	fixture(game, "palimpsest", "borrowed_dawn", 0)
	game.overrides = {"cost":1}
	game.run.battle.command_points = 1
	var driver = Policy.new()
	driver.game = game
	driver.prepare_routes()
	var planned = driver.plan_combat_action()
	require(not planned.get("end_turn", false) and planned.hand == 0, "Policy does not skip a card affordable only through effective cost")
	driver.free()
