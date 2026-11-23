extends SceneTree
const Game=preload("res://scripts/game.gd")
const Targeting=preload("res://scripts/command_targeting.gd")
const Fixtures=preload("res://tests/route_effect_fixtures.gd")
var failures=0
var checks=0
var directory=OS.get_environment("TMPDIR").path_join("command-targeting-%d"%Time.get_ticks_usec())

func _initialize() -> void: check.call_deferred()
func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func classify(game, route: Array, choices: Array = []) -> Dictionary:
	var before=game.run.duplicate(true)
	var result=Targeting.classify(game,game.run.battle.hand[0].uid,route,choices)
	require(game.run==before,"Classification preserves all state, including RNG")
	require(result==Targeting.classify(game,game.run.battle.hand[0].uid,route,choices),"Classification is deterministic")
	return result

func fresh(game, ship: String = "cartographer") -> void:
	Fixtures.battle(game,"fixture_heat_sink")
	game.run.character=ship
	game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
	game.run.battle.command_points=9

func check() -> void:
	var game=Game.new(directory)
	Fixtures.register(game)
	game._cards.fixture_heat_sink.kind="repair"
	game._cards.fixture_heat_sink.heal=3
	for ship in ["cartographer","palimpsest","hollow_choir"]:
		fresh(game,ship)
		var safe=classify(game,[0])
		require(safe.ok and not safe.needs_enemy and safe.target_index==0 and safe.target_guard==game.run.battle.enemies[0],"Default organ utility safely self-only on "+ship)
		safe.target_guard.hp=1
		require(game.run.battle.enemies[0].hp!=1,"Guard is a detached copy")
		for index in range(6):
			fresh(game,ship)
			var result=classify(game,[index])
			var id=game.organ(index).id
			require(result.ok,"Every ship organ previews")
			if id in ["hush","prism","redact","dissonance"]:
				require(result.needs_enemy and result.target_index==-1,"Enemy-directed utility organ requires target: "+id)
	fresh(game)
	game.run.battle.hand[0].id="fixture_survey_spike"
	require(classify(game,[0]).needs_enemy,"Attack requires target")
	game.run.battle.enemies[0].intent.armor=999
	require(classify(game,[0]).needs_enemy,"Armor cannot erase targeting requirement")
	fresh(game)
	game.run.battle.hand[0].id="fixture_parry_filament"
	require(classify(game,[0]).needs_enemy,"Printed disruption requires target")
	fresh(game,"palimpsest")
	game.run.battle.trace=2
	game.run.battle.last_payload={"damage":8,"heal":0,"disrupt":0}
	var rewrite=-1
	for index in range(6):
		if game.organ(index).id=="rewrite": rewrite=index
	require(rewrite>=0 and classify(game,[rewrite]).needs_enemy,"Remembered Rewrite damage requires target despite utility kind")
	fresh(game)
	game._cards.fixture_heat_sink.conditional_ward={"type":"prism_other_foe","amount":4}
	require(classify(game,[5]).needs_enemy,"Prism conditional ward stays enemy-directed")
	game._cards.fixture_heat_sink.erase("conditional_ward")
	fresh(game)
	game._cards.fixture_heat_sink.selections=[{"kind":"exhaust_hand","optional":false}]
	var pending=classify(game,[0])
	require(not pending.ok and pending.needs_enemy and pending.deferred,"Unresolved known-card choices defer classification")
	var chosen_uid=game.run.battle.hand[1].uid
	require(classify(game,[0],[chosen_uid]).ok and not classify(game,[0],[chosen_uid]).needs_enemy,"Completed choices allow safe self-only classification")
	require(not classify(game,[0],[-999]).ok,"Invalid known-card choice cannot self-release")
	var begun=game.begin_selection(game.run.battle.hand[0].uid,[0],0,game.run.battle.enemies[0].duplicate(true))
	require(begun.ok,"Known-card selection can begin")
	require(classify(game,[0]).deferred,"Existing selection defers safe release")
	game.cancel_selection()
	game._cards.fixture_heat_sink.erase("selections")
	fresh(game)
	game.run.battle.command_points=0
	require(not classify(game,[0]).ok,"Unaffordable command cannot self-release")
	fresh(game)
	require(not classify(game,[]).ok and not classify(game,[0,0]).ok,"Incomplete and invalid routes cannot self-release")
	game.run.battle.severed=[[0,1]]
	require(not classify(game,[0,1]).ok,"Severed route cannot self-release")
	fresh(game)
	game.run.battle.strain[0]=game.run.battle.capacity
	require(not classify(game,[0]).ok,"Saturated route cannot self-release")
	fresh(game)
	game._cards.fixture_heat_sink.draw=20
	require(not classify(game,[0]).needs_enemy,"Hidden draws do not affect targeting")
	print("command_targeting_test: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
