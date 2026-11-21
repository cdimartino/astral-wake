extends SceneTree
const Game=preload("res://scripts/game.gd")
const A=preload("res://scripts/ascension.gd")
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("astral-ascension-%d"%Time.get_ticks_usec())
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void: run_tests.call_deferred()

func run_tests() -> void:
	var game=Game.new(directory)
	check(game.new_run("ABC123").ok,"Start")
	var old=game.run.duplicate(true)
	old.erase("ascension_rank")
	old.erase("modifier_revision")
	game.run=old.duplicate(true)
	game.save()
	var resumed=Game.new(directory)
	check(resumed.run==old,"Legacy run unchanged on resume")
	var fixtures=load("res://tests/selection_fixtures.gd")
	var pending_game=fixtures.FixtureGame.new(directory.path_join("pending"))
	fixtures.setup(pending_game)
	pending_game.run.erase("ascension_rank")
	pending_game.run.erase("modifier_revision")
	check(pending_game.begin_selection(pending_game.run.battle.hand[0].uid,[0],0,pending_game.run.battle.enemies[0].duplicate(true)).ok,"Old pending selection created")
	var pending_before=pending_game.run.duplicate(true)
	pending_game.save()
	var pending_loaded=fixtures.FixtureGame.new(directory.path_join("pending"))
	check(pending_loaded.run==pending_before,"Old pending guard and checkpoint unchanged on load")
	check(pending_loaded.run.pending_selection.guard==pending_before.pending_selection.guard,"Old pending guard exact equality")
	for rank in [-1,12,1.5,"1",null]:
		var invalid=old.duplicate(true)
		invalid.ascension_rank=rank
		invalid.modifier_revision=1
		check(not game._valid_run(invalid),"Invalid rank rejected")
	var invalid=old.duplicate(true)
	invalid.ascension_rank=0
	check(not game._valid_run(invalid),"Partial identity rejected")
	check(not game.new_run("ABC123","cartographer",1).ok,"Locked rank rejected")
	game.profile.ascension_unlocks.cartographer=10
	check(game.new_run("","cartographer",10).ok,"Ordinary A10")
	game._finish_run(true)
	check(game.ascension_unlocked("cartographer")==11,"A10 unlocks A11")
	game._finish_run(true)
	check(game.profile.history.size()==1,"Duplicate finish")
	check(game.new_run("","cartographer",11).ok,"Ordinary A11")
	game._finish_run(true)
	check(game.ascension_unlocked("cartographer")==11,"No A12")
	game.profile.ascension_unlocks.cartographer=0
	game.new_run("ABC123")
	game._finish_run(true)
	check(game.ascension_unlocked("cartographer")==0,"Practice grants no unlock")
	game.profile.ascension_migrated=false
	game.profile.history=[{"won":true,"seeded":false,"seed":"ABC123","character":"cartographer"},{"won":true,"seeded":false,"seed":123,"character":"hollow_choir"}]
	game._migrate_ascension()
	check(game.ascension_unlocked("cartographer")==1,"Explicit ordinary backfill")
	check(game.ascension_unlocked("hollow_choir")==0,"Ambiguous numeric origin not backfilled")
	game.new_run(123,"hollow_choir")
	game.run.seeded=false
	game._finish_run(true)
	check(game.ascension_unlocked("hollow_choir")==0,"Active numeric seeded=false victory has no ordinary provenance; no rank unlock")
	game.profile.history=[]
	game._migrate_ascension()
	check(game.ascension_unlocked("cartographer")==1,"Backfill independent of history retention")
	print("ascension_compatibility_test failures=",failures)
	quit(1 if failures else 0)
