extends SceneTree
const Game=preload("res://scripts/game.gd")
const Session=preload("res://tools/manual_session.gd")
const IDS=["survey_spike","cross_current","living_atlas","heat_sink","thermal_lance","phase_radiator","parry_filament","refracted_fang","interception_loom"]
var checks=0
var failures=0
var directory=OS.get_environment("ASTRAL_SAVE_DIR").path_join("content1-%d"%Time.get_ticks_usec())
func require(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func fresh():
	var game=Game.new(directory.path_join(str(checks)+"-"+str(Time.get_ticks_usec())))
	game.new_run("0093CG")
	return game
func battle(id: String, branch: String=""):
	var game=fresh()
	game.run.deck=[]
	for card_id in [id,"needle","heat_sink","parry_filament","hull_stitch","cross_current","thermal_lance","refracted_fang","cold_breath","survey_spike"]:
		game.run.deck.append(game._instance(game.run,card_id))
	if not branch.is_empty(): game.run.deck[0].merge({"level":1,"evolution":branch},true)
	game._start_battle({"type":"battle","enemy_ids":["cinder_mite","cinder_mite"]})
	game.run.battle.hand=game.run.deck.slice(0,5).duplicate(true)
	game.run.battle.draw=game.run.deck.slice(5).duplicate(true)
	return game
func _initialize() -> void:
	var game=fresh()
	require(game.run.schema_revision==7 and game.run.content_pool_revision==1 and game.run.reward_generation==1,"fresh discovery0 code0093CG has explicit content1/rewards1")
	for ship in ["cartographer","palimpsest","hollow_choir"]:
		for unlocks in [0,3]:
			game.new_run(424242,ship)
			game.profile.unlocks=unlocks
			var pool=game._available_cards()
			for id in IDS: require((id in pool)==(ship=="cartographer"),"core9 eligible at every profile tier; no foreign ships")
			for id in pool: require(game.card(id).get("character","cartographer")==ship,"pool ship isolation")
			game.run.content_pool_revision=0
			for id in IDS: require(not id in game._available_cards(),"pool0 excludes expansion before distribution/event sampling")
	game=fresh()
	for invalid in [null,true,false,0.5,-1,2,"1"]:
		var state=game.run.duplicate(true)
		if invalid==null: state.erase("content_pool_revision")
		else: state.content_pool_revision=invalid
		require(not game._valid_run(state),"current revision field cannot be repaired/defaulted")
		var path=directory.path_join("invalid-"+str(checks))
		Game.SaveStore.new(path).write(game.profile,state)
		require(Game.new(path).run.is_empty(),"raw malformed revision rejected before integer restoration")
	game=battle("survey_spike")
	game.run.content_pool_revision=0
	require(not game._valid_run(game.run),"pool0 cannot own expansion card")
	game=fresh()
	game.run.content_pool_revision=0
	game.run.mode="reward"
	game.run.reward={"choices":[{"kind":"card","id":"survey_spike"}],"boss":false}
	var before=game.run.duplicate(true)
	require(not game._valid_run(game.run) and not game.choose_reward(0).ok and before==game.run,"reward rejects foreign revision atomically")
	game.run.mode="shop"
	game.run.shop={"items":[{"kind":"card","id":"heat_sink","cost":1,"sold":false}]}
	before=game.run.duplicate(true)
	require(not game._valid_run(game.run) and not game.buy(0).ok and before==game.run,"shop rejects foreign revision before payment")
	# Authentic schema6 shape: absent additive field, guard bound to old state.
	for generation in [0,1]:
		game=fresh()
		game.run.reward_generation=generation
		game.run.content_pool_revision=0
		game.choose_node(game.run.map[0][0].id)
		game._finish_battle()
		var old=game.run.duplicate(true)
		old.erase("content_pool_revision")
		old.schema_revision=6
		game.store.write(game.profile,old)
		var loaded=Game.new(game.store.directory)
		require(loaded.run.content_pool_revision==0 and loaded.run.reward_generation==generation,"schema6 migration pins pool0 without changing reward generation")
		var migrated=loaded.run.duplicate(true)
		migrated.erase("content_pool_revision")
		migrated.schema_revision=6
		require(Session.snapshot(migrated)==Session.snapshot(old),"old pending reward/RNG/price payload unchanged")
	for id in IDS:
		for branch in game.card(id).evolutions:
			var payment=fresh()
			payment.run.deck[0].id=id
			payment.run.salvage=100
			payment._make_shop()
			var service=payment.run.shop.items.size()-1
			var cost=payment.run.shop.items[service].cost
			require(payment.buy(service).ok and payment.run.salvage==100,"service reserves but does not prematurely charge "+branch.id)
			var uid=payment.run.deck[0].uid
			require(payment.evolve_card(uid,branch.id).ok and payment.run.deck[0].evolution==branch.id and payment.run.salvage==100-cost and payment.run.shop.items[service].sold,"explicit UID evolution pays exactly once "+branch.id)
			var paid=payment.run.duplicate(true)
			require(not payment.evolve_card(uid,branch.id).ok and payment.run==paid,"duplicate evolution cannot charge again")
			game=battle(id,branch.id)
			game.run.battle.strain=[2,1,0,0,0,0]
			var forecast=game.preview_card(0,[0],0)
			require(forecast.ok and game.play_card(0,[0],0)==forecast,"new branch preview=commit "+branch.id)
			require(game.run.battle.command_points==3-game.card(id).evolutions.filter(func(b): return b.id==branch.id)[0].stats.get("cost",game.card(id).cost),"explicit UID exact branch CP")
			require(game._valid_run(game.run),"wellformed branch state "+branch.id)
			game.save()
			require(Session.snapshot(Game.new(game.store.directory).run)==Session.snapshot(game.run),"branch identity/counters reload "+branch.id)
	mechanics()
	pending_migrations()
	print("CARTOGRAPHER_EXPANSION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func mechanics() -> void:
	var game=battle("survey_spike")
	require(game.preview_card(0,[0],0).conditional_damage==5,"Survey independently rewards unused route")
	game.run.battle.engine_routes=[[0]]
	require(game.preview_card(0,[0],0).conditional_damage==0,"utility/install ledger also denies novelty")
	game=battle("thermal_lance","tempered_lance")
	game.run.battle.strain=[2,0,0,0,0,0]
	require(game.preview_card(0,[0],0).conditional_damage==6,"Tempered Lance checks entry before its own vent")
	game.run.battle.strain[0]=1
	require(game.preview_card(0,[0],0).conditional_damage==0,"not a historical or post-strain check")
	game=battle("refracted_fang","guarded_fang")
	require(game.preview_card(0,[5],0).flat_ward_applied==7,"Guarded Fang group ward7")
	game.run.battle.enemies.pop_back()
	require(game.preview_card(0,[5],0).flat_ward_applied==3,"Guarded Fang lone ward3")
	for id in ["living_atlas","phase_radiator","interception_loom"]:
		var branches=game.card(id).evolutions
		var quick=battle(id,branches[0].id)
		var guarded=battle(id,branches[1].id)
		for candidate in [quick,guarded]:
			preload("res://tests/card_zone_fixtures.gd").identify(candidate,2,"needle")
			for foe in candidate.run.battle.enemies: foe.intent={"kind":"strain","amount":1,"label":"no incoming hull damage"}
		require(quick.play_card(0,[4],0).ok and guarded.play_card(0,[4],0).ok,"install both real branches")
		require(quick.run.battle.command_points==2 and guarded.run.battle.command_points==1 and guarded.run.battle.ward==quick.run.battle.ward+5,"quick extra followup CP versus immediate ward5")
		require(quick.play_card(0,[0],0).ok and quick.play_card(0,[1],0).ok,"quick branch actually fits two later commands")
		require(guarded.play_card(0,[0],0).ok and not guarded.play_card(0,[1],0).ok,"guarded cannot fit second followup")
		require(quick.run.battle.enemies[0].hp<guarded.run.battle.enemies[0].hp,"quick setup produces an actual additional attack, not just unused CP")
		quick.end_turn()
		guarded.end_turn()
		require(quick.run.hull==100 and guarded.run.hull==100 and quick.run.battle.ward==0 and guarded.run.battle.ward==0,"guarded ward actually expires unused on a non-damaging enemy phase")
		# No organ ward: direct hostile attack; ward branch survives a lethal boundary.
		quick=battle(id,branches[0].id)
		guarded=battle(id,branches[1].id)
		for candidate in [quick,guarded]:
			# A genuine scarce-hand boundary, not a policy declining an available
			# Heat Sink/Parry: spare CP cannot manufacture an unheld defense card.
			candidate.run.battle.draw.append_array(candidate.run.battle.hand.slice(1))
			candidate.run.battle.hand=candidate.run.battle.hand.slice(0,1)
			candidate.run.hull=3
			candidate.run.battle.enemies.resize(1)
			candidate.run.battle.enemies[0].intent={"kind":"attack","amount":6,"label":"lethal setup boundary"}
			candidate.play_card(0,[4],0)
			candidate.end_turn()
		require(quick.run.mode=="defeat" and guarded.run.mode=="combat" and guarded.run.hull>0,"ward branch survives setup threshold where quick dies; same future passive "+id)
	# Every non-install branch has a concrete independent advantage.
	for id in ["survey_spike","cross_current","thermal_lance","refracted_fang"]:
		var branches=game.card(id).evolutions
		var a=battle(id,branches[0].id)
		var b=battle(id,branches[1].id)
		a.run.battle.strain=[2,1,0,0,0,0]
		b.run.battle.strain=a.run.battle.strain.duplicate()
		require(a.preview_card(0,[0],0).damage>b.preview_card(0,[0],0).damage,"damage branch earns immediate output "+id)
		if id=="survey_spike":
			var uid=b.run.battle.hand[0].uid
			b.end_turn()
			require(b.run.battle.hand.any(func(c): return c.uid==uid),"Retain branch can wait for a different route/intent")
		elif id=="thermal_lance":
			require(b.preview_card(0,[0],0).command_cooling==2,"vent branch preserves entry bonus while cooling two actual strain")
		else:
			require(b.preview_card(0,[0],0).flat_ward_applied>a.preview_card(0,[0],0).get("flat_ward_applied",0),"ward branch supplies otherwise missing defense "+id)
	var deep=battle("heat_sink","deep_sink")
	var shield=battle("heat_sink","sheltering_sink")
	deep.run.battle.strain=[2,2,0,0,0,0]
	shield.run.battle.strain=deep.run.battle.strain.duplicate()
	require(deep.preview_card(0,[4],0).command_cooling==4 and shield.preview_card(0,[4],0).command_cooling==2,"deep sink doubles actual cooling on loaded organs")
	require(shield.preview_card(0,[4],0).flat_ward_applied==8 and deep.preview_card(0,[4],0).flat_ward_applied==5,"shield sink wins ward when more cooling would be wasted")
	var barbed=battle("parry_filament","barbed_filament")
	var woven=battle("parry_filament","woven_filament")
	for candidate in [barbed,woven]: candidate.run.battle.enemies[0].intent={"kind":"sever","amount":1,"label":"interruptible","interrupt":5}
	barbed.play_card(0,[0],0)
	woven.play_card(0,[0],0)
	require(barbed.run.battle.enemies[0].disrupt==6 and woven.run.battle.enemies[0].disrupt==3,"barbed reaches interruption threshold where woven cannot")
	require(woven.run.battle.ward==8 and barbed.run.battle.ward==3,"woven gives five additional ward versus disruption capped/wasted")

func pending_migrations() -> void:
	var fixtures=preload("res://tests/selection_fixtures.gd")
	for generation in [0,1]:
		var game=fixtures.FixtureGame.new(directory.path_join("pending-source-%d"%generation))
		fixtures.setup(game,"fixture_scrape")
		game.run.reward_generation=generation
		require(game.begin_selection(game.run.battle.hand[0].uid,[0],0,game.run.battle.enemies[0].duplicate(true)).ok,"old chooser opens")
		var old=game.run.duplicate(true)
		old.erase("content_pool_revision")
		old.schema_revision=6
		old.pending_selection.guard=Game.Selections.guard(game,old,old.pending_selection)
		for damaged in [false,true]:
			var state=old.duplicate(true)
			if damaged: state.pending_selection.guard="damaged"
			var path=directory.path_join("pending-%d-%s"%[generation,damaged])
			Game.SaveStore.new(path).write(game.profile,state)
			var loaded=fixtures.FixtureGame.new(path)
			if damaged: require(loaded.run.is_empty(),"old pending guard validated BEFORE adding pool field")
			else:
				require(loaded.run.content_pool_revision==0 and loaded.run.reward_generation==generation and loaded._valid_pending(loaded.run),"verified old chooser rebinds with permanent pool0")
				require(loaded.run.pending_selection.definition==game._restore_integers(old.pending_selection.definition),"migration never invents new effective payload")
