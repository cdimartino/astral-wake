extends SceneTree
const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/route_effect_fixtures.gd")
const Zones = preload("res://tests/card_zone_fixtures.gd")
const Session = preload("res://tools/manual_session.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("route-effects-%d"%Time.get_ticks_usec())

func _initialize() -> void: check.call_deferred()
func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func fresh(game, id: String) -> void: Fixtures.battle(game,id)
func play(game, route: Array) -> Dictionary:
	var before=Session.snapshot(game.run)
	var preview=game.preview_card(0,route,0)
	require(preview==game.preview_card(0,route,0) and before==Session.snapshot(game.run),"Pure repeated preview")
	var result=game.play_card(0,route,0)
	require(result==preview,"Preview and selected commit agree")
	return result

func check() -> void:
	var game=Game.new(directory)
	Fixtures.register(game)
	for id in ["fixture_survey_spike","fixture_cross_current","fixture_heat_sink","fixture_thermal_lance","fixture_parry_filament","fixture_refracted_fang"]:
		require(not game.card(id).has("evolutions") and game.Distribution.valid_card(game.card(id)),"Prototype has correct roles and no unrelated inherited branches")
	for id in ["fixture_heat_sink","fixture_parry_filament"]:
		for ward in [0,3,8,999]:
			fresh(game,id)
			game.run.battle.ward=ward
			var result=play(game,[2])
			require(result.ok and result.flat_ward_requested==5 and result.flat_ward_applied==5 and game.run.battle.ward==ward+5,"Printed ward additive, never Echo multiplied or capped")
			require(game.run.battle.last_command.base.damage==0 and not game.run.battle.last_command.base.has("ward"),"Ward excluded from copy payload")
	fresh(game,"fixture_parry_filament")
	game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"Fixture attack"}
	play(game,[3])
	game.end_turn()
	require(game.run.hull==96 and game.run.battle.ward==0,"Printed ward absorbs after capped disruption, then expires normally")
	fresh(game,"fixture_heat_sink")
	game._cards.fixture_heat_sink.conditional_damage={"type":"novel_route","amount":5}
	require(not game.preview_card(0,[4],0).ok and not game._valid_run(game.run),"Conditional damage cannot turn zero-damage utility into an attack")
	game._cards.fixture_heat_sink.erase("conditional_damage")
	for strain in [0,1,2,3]:
		fresh(game,"fixture_thermal_lance")
		game.run.battle.capacity=4
		game.run.battle.strain[4]=strain
		game._cards.fixture_thermal_lance.vent=1
		var result=play(game,[4])
		require(result.damage==(15 if strain==2 else 9),"Exact pre-command strain two, independent of vent")
		require(game.run.battle.last_command.base.damage==9,"Conditional damage not copyable")
	game._cards.fixture_thermal_lance.erase("vent")
	for ward in [0,2,3,8]:
		fresh(game,"fixture_heat_sink")
		game.run.character="hollow_choir"
		game.run.battle.resonance=2
		game.run.battle.ward=ward
		require(play(game,[5]).flat_ward_applied==5 and game.run.battle.ward==maxi(ward,3)+5,"Cadence only fills local room to three; printed ward remains additive")
	fresh(game,"fixture_heat_sink")
	game.run.character="hollow_choir"
	game.run.battle.resonance=3
	require(play(game,[2]).flat_ward_applied==5 and game.run.battle.ward==5,"Crescendo never multiplies printed ward")
	fresh(game,"fixture_thermal_lance")
	game.run.battle.strain=[2,2,0,0,0,0]
	var thermal=play(game,[0,1,2])
	require(thermal.conditional_damage==6 and thermal.damage==27,"Multiple qualifying organs pay once, before Lens/Echo")
	for mitigation in ["neutral","armor","exposed"]:
		fresh(game,"fixture_survey_spike")
		if mitigation=="armor": game.run.battle.enemies[0].intent.armor=2
		if mitigation=="exposed": game.run.battle.enemies[0].intent.exposed=2
		var result=play(game,[4])
		require(result.conditional_damage==5 and result.damage==(11 if mitigation=="armor" else 15 if mitigation=="exposed" else 13),"Conditional attack uses normal mitigation")
	fresh(game,"fixture_survey_spike")
	game.run.battle.engine_routes=[[4]]
	require(play(game,[4]).damage==8,"Earlier utility or attack route consumes global novelty")
	fresh(game,"fixture_survey_spike")
	game.run.battle.engine_routes=[[0,1]]
	require(play(game,[1,0]).conditional_damage==5,"Ordered novelty")
	for route in [[0],[0,1],[0,1,2]]:
		fresh(game,"fixture_cross_current")
		game.run.battle.strain[0]=1
		var result=play(game,route)
		require(game.run.battle.strain[0]==(1 if route.size()==3 else 2) and result.command_cooling==(1 if route.size()==3 else 0),"Cross Current only cools three-organ first, after strain")
	fresh(game,"fixture_cross_current")
	game._cards.fixture_cross_current.first_free=true
	# Base definitions do not consume first_free; authored evolution explicitly can.
	game._cards.fixture_cross_current.evolutions=[{"id":"free_route","name":"Free Current","description":"Fixture","stats":{"first_free":true}},{"id":"ward_route","name":"Ward Current","description":"Fixture","stats":{"ward":1}}]
	game.run.battle.hand[0].level=1
	game.run.battle.hand[0].evolution="free_route"
	require(play(game,[0,1,2]).command_cooling==0,"First-free route with zero strain removes nothing")
	game._cards.fixture_cross_current.erase("first_free")
	for id in ["fixture_heat_sink","fixture_cross_current"]:
		fresh(game,id)
		game.run.battle.strain[0]=3
		var before=Session.snapshot(game.run)
		require(not game.play_card(0,[0,1,2],0).ok and before==Session.snapshot(game.run),"Vent/route cooling cannot legalize saturated route")
	for other in [false,true]:
		for prism in [false,true]:
			fresh(game,"fixture_refracted_fang")
			if other: game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
			var result=play(game,[5] if prism else [4])
			require(result.flat_ward_applied==(4 if other and prism else 0),"Prism identity plus another entry-living foe required")
	fresh(game,"fixture_refracted_fang")
	game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
	game.run.battle.enemies[1].hp=1
	game.run.battle.edges.append([1,5])
	require(play(game,[1,5]).flat_ward_applied==4,"Entry other-foe eligibility persists through split kill")
	fresh(game,"fixture_refracted_fang")
	game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
	var organs=game.character().organs
	var saved=organs[4]
	organs[4]=organs[5]
	organs[5]=saved
	require(play(game,[4]).flat_ward_applied==4,"Prism predicate uses identity, not socket five")
	saved=organs[4]
	organs[4]=organs[5]
	organs[5]=saved
	fresh(game,"fixture_refracted_fang")
	game.run.hull=1
	game.run.battle.mark=2
	game.run.battle.last_route=[1,5]
	game.run.battle.edges.append([1,5])
	game.run.battle.enemies[0].hp=9
	game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
	game.run.battle.enemies[1].hp=1
	var simultaneous=play(game,[1,5])
	require(game.run.mode=="defeat" and simultaneous.flat_ward_requested==4 and simultaneous.flat_ward_applied==0,"Simultaneous final kills cannot reverse lethal route mark or award eligible ward")
	fresh(game,"fixture_heat_sink")
	game.run.hull=1
	game.run.battle.mark=2
	game.run.battle.last_route=[4]
	var lethal=play(game,[4])
	require(game.run.hull==0 and lethal.flat_ward_requested==5 and lethal.flat_ward_applied==0,"Lethal mark prevents flat ward, never resurrects")
	fresh(game,"fixture_heat_sink")
	game.run.battle.strain=[2,2,0,0,0,0]
	require(play(game,[4]).command_cooling==2,"Actual vent removals only")
	fresh(game,"fixture_cross_current")
	game._cards.fixture_cross_current.vent=1
	game.run.battle.strain[0]=1
	require(play(game,[0,1,2]).command_cooling==2,"Cooling sums legitimate vent and post-strain removals, not net strain change")
	game._cards.fixture_cross_current.erase("vent")
	game.save()
	var resumed=Game.new(directory)
	Fixtures.register(resumed)
	resumed.load_saved()
	require(Session.snapshot(resumed.run)==Session.snapshot(game.run),"Fixture state save/load unchanged schema")
	for field in ["ward","conditional_damage","conditional_ward","route_cooling"]:
		for bad in [null,true,-1,0.5,100,"script",{"type":"script","amount":5}]:
			fresh(game,"fixture_heat_sink")
			var original=game._cards.fixture_heat_sink.duplicate(true)
			game._cards.fixture_heat_sink[field]=bad
			require(not game.preview_card(0,[4],0).ok and not game._valid_run(game.run),"Resolver and raw-save validator reject invalid printed effect")
			game._cards.fixture_heat_sink=original
	fresh(game,"fixture_heat_sink")
	game._cards.fixture_heat_sink.vent=0
	game.run.battle.hand[0].level=1
	game.run.battle.hand[0].evolution="legacy"
	var effective=game.effective_card(game.run.battle.hand[0])
	require(effective.ward==5 and not effective.first_free,"Ward-only legacy upgrade invents neither ward nor free strain")
	var evolved=game.card("fixture_heat_sink").duplicate(true)
	evolved.evolutions=[{"id":"strong_ward","name":"Strong Sink","description":"Gain 7 flat ward.","stats":{"ward":7}},{"id":"plain_ward","name":"Plain Sink","description":"Gain 5 flat ward.","stats":{"ward":5}}]
	require(game.Evolutions.valid_definition(evolved),"Explicit printed ward evolution supported")
	game._cards.fixture_heat_sink=evolved
	game.run.battle.hand[0].evolution="strong_ward"
	require(game.effective_card(game.run.battle.hand[0]).ward==7 and play(game,[4]).flat_ward_applied==7,"Authored ward replacement receives no legacy increment")
	# Exercise the existing chooser contract with new printed fields, without
	# adding selection effects to any production or permanent prototype definition.
	Fixtures.register(game)
	fresh(game,"fixture_heat_sink")
	game._cards.fixture_heat_sink.selections=[{"kind":"retain_hand"}]
	var initial=Session.snapshot(game.run)
	require(game.begin_selection(game.run.battle.hand[0].uid,[4],0,game.run.battle.enemies[0].duplicate(true)).ok,"Begin pending new-effect command")
	require(game.select_uid(game.run.battle.hand[1].uid).ok,"Select known retained UID")
	var pending=Session.snapshot(game.run)
	var broken=game.run.duplicate(true)
	broken.pending_selection.definition.ward=99
	require(not game._valid_run(broken),"Reject tampered pending printed ward")
	broken=game.run.duplicate(true)
	broken.battle.engine_routes=[[4]]
	require(not game._valid_run(broken),"Pending guard covers route-ledger mutation")
	game.save()
	resumed=Game.new(directory)
	Fixtures.register(resumed)
	resumed._cards.fixture_heat_sink.selections=[{"kind":"retain_hand"}]
	resumed.load_saved()
	require(Session.snapshot(resumed.run)==pending,"Pending ward command resumes exactly")
	var selected=resumed.preview_selection()
	require(selected==resumed.preview_selection() and Session.snapshot(resumed.run)==pending,"Selected preview remains pure")
	require(resumed.confirm_selection()==selected and resumed.run.battle.ward==5,"Selected confirmation agrees and grants flat ward once")
	require(game.cancel_selection().ok and Session.snapshot(game.run)==initial,"Cancel restores untouched new-effect command state")
	resumed=null
	game=null
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Route effects: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
