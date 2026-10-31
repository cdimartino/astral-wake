extends SceneTree
const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/install_engine_fixtures.gd")
const Zones = preload("res://tests/card_zone_fixtures.gd")
const Main = preload("res://scripts/main.gd")
const Session = preload("res://tools/manual_session.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("engines-%d"%Time.get_ticks_usec())

func _initialize() -> void: check.call_deferred()
func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func play(game, index: int, route: Array, choices: Array = []) -> Dictionary:
	var before=Session.snapshot(game.run)
	var preview=game.preview_card(index,route,0,choices)
	require(preview==game.preview_card(index,route,0,choices) and before==Session.snapshot(game.run),"Preview state/RNG purity")
	var result=game.play_card(index,route,0,choices)
	# Selection previews redact hidden draws; these fixtures draw none.
	require(result==preview,"Preview and commit agree")
	return result

func fresh(game) -> void:
	Fixtures.battle(game)

func ready(game) -> void:
	game.run.battle.command_points=3
	game.run.battle.strain=[0,0,0,0,0,0]

func check() -> void:
	var game=Game.new(directory)
	Fixtures.register(game)
	fresh(game)
	require(play(game,0,[3]).ok,"Install Atlas")
	require(game.run.battle.engine_counters[0].stacks==0 and game.run.battle.engine_routes==[[3]],"Installation records route but earns nothing")
	# Neutral organ 3 repairs but never amplifies damage.
	require(play(game,1,[4]).damage==10,"First attack uses no new bonus")
	require(game.run.battle.engine_counters[0].stacks==1,"Novel attack earns one stack")
	require(play(game,2,[5]).damage==11,"Next attack uses prior stack")
	ready(game)
	require(play(game,0,[3]).ok,"Install second engine on used route")
	require(game.run.battle.engine_counters[0].stacks==2,"Installation earns no route stack")
	game._draw(game.run,1)
	var victim=game.run.battle.hand[1].uid
	require(play(game,0,[4],[victim]).ok,"Selected victim then source exhaust")
	require(game.run.battle.ward==3 and game.run.battle.engine_counters[1].stacks==1,"Double exhaust earns ward/stack once")
	require(game.run.battle.engine_counters[1].used,"Exhaust turn latch set")
	require(game._valid_run(game.run),"Current engine state validates")
	game.save()
	var resumed=Game.new(directory)
	Fixtures.register(resumed)
	resumed.load_saved()
	require(Session.snapshot(resumed.run)==Session.snapshot(game.run),"Save reload preserves engines/ledger/latch")
	for field in ["stacks","source_uid","turn","type","used","extra"]:
		for bad in [-1,0.5,999999999999,"unknown",null]:
			var broken=game.run.duplicate(true)
			broken.battle.engine_counters[0][field]=bad
			require(not game._valid_run(broken),"Reject malformed counter "+field+" "+str(bad))
	for bad in [[[1],[1]],[[0.5]],[[6]],[[0,0]],[[0,1,2,3]],"bad"]:
		var broken=game.run.duplicate(true)
		broken.battle.engine_routes=bad
		require(not game._valid_run(broken),"Reject malformed ledger")
	var turn=game.run.battle.turn
	game.end_turn()
	require(game.run.battle.turn==turn+1 and game.run.battle.engine_routes.is_empty(),"Turn resets global ledger")
	require(not game.run.battle.engine_counters[1].used and game.run.battle.engine_counters[1].stacks==1,"Turn reset keeps stacks but clears latch")
	game._start_battle({"type":"battle","enemy_ids":["cinder_mite"]})
	require(game.run.battle.engine_counters.is_empty() and game.run.battle.installed.is_empty() and game.run.battle.engine_routes.is_empty(),"Combat resets everything")
	# Utility and preinstall commands reserve exact ordered routes.
	fresh(game)
	Zones.identify(game,1,"graft_wire")
	play(game,1,[4])
	play(game,0,[3])
	require(play(game,0,[4]).damage==10 and game.run.battle.engine_counters[0].stacks==0,"Preinstall utility route cannot earn stack")
	ready(game)
	Zones.identify(game,3,"fixture_strike")
	play(game,0,[3,4])
	play(game,0,[4,3])
	require(game.run.battle.engine_counters[0].stacks==2,"Reverse ordered route distinct")
	# Cap, armor-zero qualification and repeated routes.
	fresh(game)
	play(game,0,[3])
	for route in [[0],[1],[2],[4],[5],[0,1],[1,0]]:
		ready(game)
		if game.run.battle.hand.is_empty(): game._draw(game.run,5)
		# Avoid installing Furnace / requiring choices during the cap loop.
		for item in game.run.battle.hand: Zones.identify(game,int(item.uid)-1,"fixture_strike")
		game.run.battle.enemies[0].intent.armor=99
		play(game,0,route)
	require(game.run.battle.engine_counters[0].stacks==6,"Atlas cap; armor-zero attacks qualify")
	# Definition validation is strict and bounded.
	for spec in [{"type":"script","cap":2},{"type":"novel_route","cap":6.5},{"type":"other_exhaust","cap":6},{"type":"novel_route","cap":2,"ward":3}]:
		require(not Game.Engines.valid_definition({"install":"x","engine":spec}),"Reject invalid authored engine")
	# Duplicate installation fails before CP, resources, piles or ledger change.
	fresh(game)
	play(game,0,[3])
	Zones.identify(game,1,"fixture_atlas")
	var before=Session.snapshot(game.run)
	require(not game.play_card(0,[4],0).ok and before==Session.snapshot(game.run),"Duplicate identity rejects atomically")
	# Repeated route still receives existing bonus but earns no new stack.
	Zones.identify(game,1,"fixture_strike")
	play(game,0,[4])
	ready(game)
	require(play(game,0,[4]).damage==11 and game.run.battle.engine_counters[0].stacks==1,"Repeated route gets bonus only")
	# Invalid severed path never records a ledger entry; vent/link cannot bypass it.
	game.run.battle.severed=[[0,1]]
	before=Session.snapshot(game.run)
	require(not game.play_card(0,[0,1],0).ok and before==Session.snapshot(game.run),"Severed route rejects without ledger/trigger")
	# Old source sees selected exhaust, newly installed source cannot see its own command.
	fresh(game)
	play(game,1,[3])
	Zones.identify(game,0,"fixture_install_consume")
	victim=game.run.battle.hand[1].uid
	play(game,0,[4],[victim])
	require(game.run.battle.engine_counters[0].stacks==1 and game.run.battle.engine_counters[1].stacks==0,"Entry-active source order; own installation excluded")
	# At cap, another exhaust still adds flat ward once; Echo cannot amplify it.
	game.run.battle.engine_counters[0].stacks=5
	game.run.battle.engine_counters[0].used=false
	game.run.battle.engine_counters[1].used=true
	game.run.battle.ward=4
	Zones.identify(game,3,"fixture_exhaust")
	ready(game)
	play(game,0,[2])
	require(game.run.battle.ward==7 and game.run.battle.engine_counters[0].stacks==5,"At-cap ward is additive flat 3, not Echo or Cadence capped")
	# Selection staging does not pay out; complete preview includes the consequences.
	fresh(game)
	play(game,1,[3])
	var source=game.run.battle.hand[2].uid
	victim=game.run.battle.hand[0].uid
	before=Session.snapshot(game.run)
	require(game.begin_selection(source,[4],0,game.run.battle.enemies[0].duplicate(true)).ok,"Begin engine exhaust selection")
	require(game.run.battle.engine_counters[0].stacks==0 and game.run.battle.engine_routes==[[3]],"Staging records no routes or awards")
	require(game.select_uid(victim).ok,"Choose exhaust victim")
	var staged=Session.snapshot(game.run)
	var preview=game.preview_selection()
	require(preview==game.preview_selection() and staged==Session.snapshot(game.run),"Repeated staged preview pure")
	game.save()
	resumed=Fixtures.FixtureGame.new(directory)
	require(resumed.run.pending_selection==game.run.pending_selection,"Pending reload does not reset ledger/counters")
	require(resumed.confirm_selection()==preview and resumed.run.battle.engine_counters[0].stacks==1 and resumed.run.battle.ward==3,"Deferred preview agrees with commit triggers")
	game.cancel_selection()
	require(Session.snapshot(game.run)==before,"Cancel does not earn effects or ledger entry")
	# Last enemy kill still exhausts and awards; lethal route penalty awards nothing.
	fresh(game)
	play(game,1,[3])
	Zones.identify(game,2,"fixture_exhaust")
	game._cards.fixture_exhaust.damage=10
	game._cards.fixture_exhaust.kind="attack"
	game.run.battle.enemies[0].hp=1
	play(game,1,[4])
	require(game.run.mode=="reward" and game.run.battle.engine_counters[0].stacks==1,"Final kill exhaust awards before combat transition")
	fresh(game)
	play(game,1,[3])
	game.run.hull=1
	game.run.battle.mark=2
	game.run.battle.last_route=[4]
	Zones.identify(game,2,"fixture_exhaust")
	play(game,1,[4])
	require(game.run.mode=="defeat" and game.run.battle.engine_counters[0].stacks==0 and game.run.battle.ward==0,"Lethal mark never triggers installed effects")
	# Runtime damage stays outside the printed/copyable payload, before organ scaling.
	fresh(game)
	play(game,0,[3])
	game.run.battle.engine_counters[0].stacks=2
	game.run.character="palimpsest"
	game.run.battle.trace=0
	require(play(game,1,[3]).damage==12 and game.run.battle.last_payload.damage==10,"Plain payload excludes runtime stacks")
	game._cards.fixture_copy=game._cards.fixture_strike.duplicate(true)
	game._cards.fixture_copy.merge({"id":"fixture_copy","damage":0,"rewrite":true},true)
	Zones.identify(game,3,"fixture_copy")
	game.run.battle.trace=2
	ready(game)
	require(play(game,1,[3]).damage==11 and game.run.battle.last_payload.damage==0,"Conditional damaging attack receives stacks, copied base excludes stacks")
	Zones.identify(game,4,"fixture_copy")
	game.run.battle.trace=2
	require(play(game,1,[3]).damage==6 and game.run.battle.last_payload.damage==0,"Copy chain cannot recursively amplify passive damage")
	# A damaging utility (including damage supplied by organs) is not an attack.
	game.run.character="cartographer"
	game._cards.fixture_strike.kind="utility"
	ready(game)
	game._draw(game.run,2)
	var stacks=game.run.battle.engine_counters[0].stacks
	for item in game.run.battle.hand: Zones.identify(game,int(item.uid)-1,"fixture_strike")
	require(play(game,0,[4]).damage==10 and game.run.battle.engine_counters[0].stacks==stacks,"Utility damage neither receives nor earns stacks")
	game._cards.fixture_strike.damage=0
	game.run.character="palimpsest"
	game.run.battle.trace=2
	game.run.battle.last_payload={"damage":10,"heal":0,"disrupt":0}
	ready(game)
	require(play(game,0,[5]).damage==5 and game.run.battle.engine_counters[0].stacks==stacks,"Organ-created utility damage neither receives nor earns stacks")
	game._cards.fixture_strike.damage=10
	game._cards.fixture_strike.kind="attack"
	# Exhaust stacks reach their authored cap naturally over real turn boundaries.
	fresh(game)
	play(game,1,[3])
	for item in game.run.deck:
		if item.id!="fixture_furnace": Zones.identify(game,int(item.uid)-1,"fixture_exhaust")
	for count in range(6):
		ready(game)
		if game.run.battle.hand.is_empty(): game._draw(game.run,1)
		play(game,0,[4])
		require(game.run.battle.engine_counters[0].stacks==mini(5,count+1) and game.run.battle.ward==3,"Natural Exhaust cap and at-cap ward")
		game.end_turn()
	# Raw malformed primary falls back before fractional fields can be restored.
	fresh(game)
	play(game,0,[3])
	var good=game.run.duplicate(true)
	for mutation in ["fraction","dangling","unknown","duplicate","turn","cap"]:
		var broken=good.duplicate(true)
		match mutation:
			"fraction": broken.battle.engine_counters[0].source_uid=1.5
			"dangling": broken.battle.engine_counters[0].source_uid=999
			"unknown": broken.battle.engine_counters[0].extra=true
			"duplicate": broken.battle.engine_routes.append([3])
			"turn": broken.battle.engine_counters[0].turn=2
			"cap": broken.battle.engine_counters[0].stacks=7
		for entry in [["save.json",broken],["save.backup.json",good]]:
			var file=FileAccess.open(directory.path_join(entry[0]),FileAccess.WRITE)
			file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":entry[1]}))
			file.close()
		resumed=Fixtures.FixtureGame.new(directory)
		require(resumed.run==good and resumed.save_error.contains("backup"),"Raw backup fallback "+mutation)
	# Explicit revision-3 migration initializes empty bookkeeping, preserving RNG.
	Zones.battle(game)
	var old=game.run.duplicate(true)
	old.schema_revision=3
	old.battle.erase("engine_counters")
	old.battle.erase("engine_routes")
	game.store.write(game.profile,old)
	resumed=Fixtures.FixtureGame.new(directory)
	require(resumed.run==game.run,"Revision 3 migration adds only empty fields and revision")
	fresh(game)
	source=game.run.battle.hand[3].uid
	require(game.begin_selection(source,[4],0,game.run.battle.enemies[0].duplicate(true)).ok,"Old pending migration fixture opens")
	old=game.run.duplicate(true)
	old.schema_revision=3
	old.battle.erase("engine_counters")
	old.battle.erase("engine_routes")
	old.pending_selection.guard=Game.Selections.guard(game,old,old.pending_selection)
	game.store.write(game.profile,old)
	resumed=Fixtures.FixtureGame.new(directory)
	require(resumed._valid_pending(resumed.run) and resumed.run.schema_revision==4 and resumed.run.battle.engine_routes.is_empty(),"Verified old pending guard rebinds to revision 4 empty ledger")
	require(resumed.select_uid(resumed.run.battle.hand[2].uid).ok and resumed.confirm_selection().ok,"Migrated pending chooser can commit")
	game.cancel_selection()
	# Inspect actual active counters alongside a legacy dormant install at both sizes.
	fresh(game)
	play(game,0,[3])
	play(game,0,[4])
	Zones.identify(game,2,"fixture_install")
	play(game,0,[5])
	var ui=Main.new()
	root.add_child(ui)
	ui.game=game
	ui.menu=false
	for window in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=window
		ui._render()
		for unused in range(3): await process_frame
		ui.find_child("InstalledPile",true,false).pressed.emit()
		for unused in range(3): await process_frame
		var labels=[]
		collect_text(ui,labels)
		var text="\n".join(labels)
		require(text.contains("next later bonus +0/6") and text.contains("next later bonus +0/5") and text.contains("used this turn: no"),"Active counters visible at "+str(window))
		require(text.contains("Fixture Living Atlas") and text.contains("UID 1") and text.contains("Dormant identity: fixture_engine"),"Source name/UID and dormant distinction visible")
		ui._close_overlay()
	print("Bounded Install engines: %d checks, %d failures"%[checks,failures])
	if failures==0 and "--demo" in OS.get_cmdline_user_args():
		Fixtures.demo(game)
		ui.game=game
		ui._render()
	else:
		ui.ambience.stop()
		ui.audio.stop()
		# Let the audio mixer release WAV playback before disposing the fixture UI.
		await create_timer(0.25).timeout
		ui.queue_free()
		for unused in range(5): await process_frame
		quit(1 if failures else 0)

func collect_text(node: Node, values: Array) -> void:
	if node is Label or node is Button: values.append(node.text)
	for child in node.get_children(): collect_text(child,values)
