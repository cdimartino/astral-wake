extends SceneTree
const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/defense_engine_fixtures.gd")
const Zones = preload("res://tests/card_zone_fixtures.gd")
const Session = preload("res://tools/manual_session.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("defense-engines-%d"%Time.get_ticks_usec())

func _initialize() -> void: check.call_deferred()
func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func play(game, uid: int, route: Array, choices: Array = []) -> Dictionary:
	var index=Game.Selections.index(game.run.battle.hand,uid)
	var before=Session.snapshot(game.run)
	var preview=game.preview_card(index,route,0,choices)
	require(preview==game.preview_card(index,route,0,choices) and before==Session.snapshot(game.run),"Preview state/RNG purity")
	var result=game.play_card(index,route,0,choices)
	require(result==preview and result.ok,"Preview/commit agree: "+str(result.get("error")))
	return result

func fresh(game, id: String = "fixture_radiator") -> void:
	Fixtures.battle(game)
	Zones.identify(game,0,id)
	play(game,1,[3])

func attack(game, hp: int = 100, armor: int = 0, hull: int = 30, ward: int = 5) -> void:
	game.run.hull=hull
	game.run.battle.ward=ward
	game.run.battle.enemies[0].hp=50
	game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"drain":true,"label":"Fixture drain 12"}
	game.run.battle.enemies[0].disrupt=2
	game.run.battle.enemies[0].redirect=3
	game.run.battle.enemies[1].hp=hp
	game.run.battle.enemies[1].intent={"kind":"attack","amount":9,"armor":armor,"label":"Fixture recipient 9"}

func retaliation(result: Dictionary) -> Array:
	return result.presentation.filter(func(cue): return cue.get("engine","")=="redirect_retaliation")

func check() -> void:
	var game=Game.new(directory)
	Fixtures.register(game)
	# Own install cannot retroactively observe even actual cooling in that command.
	game._cards.fixture_radiator.vent=1
	Fixtures.battle(game)
	game.run.battle.strain=[1,1,0,0,0,0]
	play(game,1,[3])
	require(game.run.battle.ward==0 and not game.run.battle.engine_counters[0].used,"Own cooling install excluded")
	game._cards.fixture_radiator.vent=0
	game.run.battle.strain=[1,1,0,0,0,0]
	play(game,3,[4])
	require(game.run.battle.ward==5 and game.run.battle.engine_counters[0].used and Game.Engines.bonus(game.run.battle)==0,"Actual total cooling 2 pays flat ward; never damage stacks")
	require(game.run.battle.last_command.base=={"damage":0,"heal":0,"disrupt":0},"Plain last-command D/H/I excludes ward")
	game.run.battle.command_points=3
	game.run.battle.strain=[1,1,0,0,0,0]
	play(game,5,[0,1,2])
	require(game.run.battle.ward==5,"Second qualifying command cannot pay")
	game.save()
	var resumed=Fixtures.FixtureGame.new(directory)
	require(resumed.run==game.run and game._valid_run(game.run),"Used zero-stack cooling counter survives raw validation/resume")
	var before=Session.snapshot(game.run)
	for ignored in range(3):
		game._incoming_damage(game.run)
		game._forecast_attack(game.run,0)
	require(before==Session.snapshot(game.run),"Enemy forecast pure, no counters/RNG changes")
	game.end_turn()
	require(not game.run.battle.engine_counters[0].used and game.run.battle.engine_counters[0].turn==game.run.battle.turn,"Exact player boundary resets cooling latch")
	# Attempted zero vent and first-free postcool remove nothing.
	fresh(game)
	game.run.battle.strain=[0,0,0,0,0,0]
	game._cards.fixture_postcool.vent=0
	for zone in [game.run.deck,game.run.battle.hand]:
		for item in zone:
			if item.uid==5: item.level=1
	var zero=play(game,5,[0,1,2])
	require(zero.command_cooling==0 and game.run.battle.ward==0 and not game.run.battle.engine_counters[0].used,"First-free zero vent/postcool is zero actual removal")
	game._cards.fixture_postcool.vent=1
	fresh(game)
	game.run.battle.strain=[1,0,0,0,0,0]
	var twice=play(game,5,[0,1,2])
	require(twice.command_cooling==2 and game.run.battle.strain[0]==0 and game.run.battle.ward==5,"Vent then re-added route strain both count, not net change")
	# Real known choice cancellation, deferred save, preview and confirmation.
	fresh(game)
	game.run.battle.strain=[1,1,0,0,0,0]
	before=Session.snapshot(game.run)
	require(game.begin_selection(4,[4],0,game.run.battle.enemies[0].duplicate(true)).ok,"Stage actual known choice")
	require(game.select_uid(2).ok,"Select known exhaust victim")
	var staged=Session.snapshot(game.run)
	var preview=game.preview_selection()
	require(preview==game.preview_selection() and staged==Session.snapshot(game.run) and game.run.battle.ward==0,"Staged cooling preview pays nothing live")
	game.save()
	resumed=Fixtures.FixtureGame.new(directory)
	require(resumed.run.pending_selection==game.run.pending_selection,"Pending cooling guard resumes")
	game.cancel_selection()
	require(before==Session.snapshot(game.run),"Cancellation restores exact pre-command state")
	require(resumed.confirm_selection()==preview and resumed.run.battle.ward==5 and resumed.run.battle.engine_counters[0].used,"Deferred confirm pays exactly once")
	# Separate redirect/retaliation hits; shared half attack cap and drain use hull only.
	for armor in [0,2,99]:
		fresh(game,"fixture_loom")
		attack(game,100,armor)
		game.run.battle.enemies[1].intent.amount=0
		var result=game.end_turn()
		require(game.run.hull==28 and game.run.battle.enemies[0].hp==52,"12 - disruption 2 - redirect 3 = 7; ward 5 => hull/drain 2")
		require(game.run.battle.enemies[1].hp==100-maxi(0,3-armor)-maxi(0,6-armor),"Independent armor on redirect and retaliation")
		require(retaliation(result).size()==1 and retaliation(result)[0].source_uid==1 and retaliation(result)[0].target_index==1,"Positive resolved redirect triggers even armor absorbs all; exact source/target")
		require(game._valid_run(game.run) and not game.run.battle.engine_counters[0].used,"Completed phase latch reset validates")
	# Death boundaries and stable duplicate-type recipient/actor indices.
	for hp in [3,7]:
		fresh(game,"fixture_loom")
		attack(game,hp)
		var result=game.end_turn()
		require(game.run.hull==28 and game.run.battle.enemies.size()==1 and game.run.battle.enemies[0].hp==52,"Killed recipient skips its action, no compaction shift")
		require(retaliation(result).size()==(0 if hp==3 else 1),"Redirect death has no retarget; retaliation death once")
	fresh(game,"fixture_loom")
	attack(game,100,0,2,0)
	var lethal=game.end_turn()
	require(game.run.mode=="defeat" and game.run.battle.enemies[1].hp==97 and retaliation(lethal).is_empty(),"Redirect before lethal hull; no passive after unrecovered lethal")
	fresh(game,"fixture_loom")
	attack(game,100,0,2,0)
	for definition in game.catalog.powerups:
		if definition.effect=="emergency": game.run.powerups.append(definition.id)
	game.run.battle.enemies[1].intent.amount=0
	var survived=game.end_turn()
	require(game.run.hull>0 and retaliation(survived).size()==1 and game.run.battle.enemies[1].hp==91,"Existing emergency survival occurs before retaliation, no invented resurrection")
	fresh(game,"fixture_loom")
	attack(game,100,0,30,99)
	game.run.battle.enemies[1].intent.amount=0
	game.end_turn()
	require(game.run.battle.enemies[0].hp==50 and game.run.hull==30,"Ward absorbed hull damage never heals drain")
	# Multiple positive redirects consume once, including armor-zero first event.
	fresh(game,"fixture_loom")
	attack(game,100,99)
	game.run.battle.enemies[1].redirect=3
	var multi=game.end_turn()
	require(retaliation(multi).size()==1 and retaliation(multi)[0].target_index==1 and game.run.battle.enemies[0].hp==49,"First armor-zero redirect consumes latch; later redirect no second retaliation")
	# Zero resolved redirect (cap used by disruption) does not consume the first event.
	fresh(game,"fixture_loom")
	attack(game)
	game.run.battle.enemies[0].disrupt=6
	game.run.battle.enemies[1].redirect=3
	var cap=game.end_turn()
	require(retaliation(cap).size()==1 and retaliation(cap)[0].target_index==0,"Shared half cap unchanged; zero redirect cannot consume latch")
	# Duplicate enemy IDs are not identities: recipient 0 dies, actor 1 stays 1,
	# third enemy 2 still acts exactly once despite the hole at the start.
	fresh(game,"fixture_loom")
	attack(game,100)
	var actor=game.run.battle.enemies.pop_front()
	game.run.battle.enemies.push_back(actor)
	game.run.battle.enemies[0].hp=7
	game.run.battle.enemies[0].intent={"kind":"attack","amount":0,"label":"Already acted"}
	var third=game._make_enemy("cinder_mite")
	third.intent={"kind":"attack","amount":1,"label":"Third same type"}
	game.run.battle.enemies.append(third)
	var stable=game.end_turn()
	require(retaliation(stable).size()==1 and retaliation(stable)[0].source_index==1 and retaliation(stable)[0].target_index==0,"Snapshot actor/recipient indices with duplicate types")
	require(game.run.battle.enemies.size()==2 and game.run.battle.enemies[0].hp==52 and game.run.hull==27,"No midphase compaction shifts actor or skips later enemy")
	# Spawned eggs append but do not take their own turn/hatch tick this phase.
	fresh(game,"fixture_loom")
	game.run.battle.enemies[0].intent={"kind":"incubate","label":"Fixture spawn"}
	game.end_turn()
	require(game.run.battle.enemies.size()==3 and game.run.battle.enemies[2].egg_timer==2,"Appended egg not in entry actor count")
	# Exposed applies separately; no organ/powerup/Echo amplification or stacks.
	fresh(game,"fixture_loom")
	attack(game)
	game.run.battle.enemies[1].intent.amount=0
	game.run.battle.enemies[1].intent.exposed=4
	game.run.powerups=["amber_sight"]
	var exposed=game.end_turn()
	require(retaliation(exposed).size()==1 and retaliation(exposed)[0].amount==10 and game.run.battle.enemies[1].hp==83,"Ordinary exposed separately on 3 and 6, no passive attack amps")
	# New real phase can trigger once again; no source definition/counter changes.
	game.run.powerups=[]
	attack(game)
	game.run.battle.enemies[1].intent.amount=0
	var again=game.end_turn()
	require(retaliation(again).size()==1,"Once latch resets at completed enemy phase/player boundary")
	# A lone foe, nonattack or interrupted attack never emits a redirect event.
	fresh(game,"fixture_loom")
	attack(game)
	game.run.battle.enemies[0].intent.interrupt=2
	game.run.battle.enemies[1].intent.amount=0
	require(retaliation(game.end_turn()).is_empty(),"Interrupted attack has no event")
	game.run.battle.enemies.resize(1)
	game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"Lone"}
	game.run.battle.enemies[0].redirect=3
	require(retaliation(game.end_turn()).is_empty(),"Lone foe cannot redirect")
	# Lethal route mark blocks cooling even on final kill; no resurrection.
	fresh(game)
	game.run.hull=1
	game.run.battle.mark=2
	game.run.battle.last_route=[4]
	game.run.battle.strain=[1,1,0,0,0,0]
	game._cards.fixture_cool.damage=200
	game.run.battle.enemies.resize(1)
	play(game,3,[4])
	require(game.run.mode=="defeat" and game.run.battle.ward==0 and not game.run.battle.engine_counters[0].used,"Final kill cannot pay cooling after player lethal")
	game._cards.fixture_cool.damage=0
	fresh(game)
	game.run.battle.strain=[1,1,0,0,0,0]
	game._cards.fixture_cool.damage=200
	game.run.battle.enemies.resize(1)
	play(game,3,[4])
	require(game.run.mode=="reward" and game.run.battle.ward==5 and game._valid_run(game.run),"Living final kill can pay cooling before transition and validates postcombat counters")
	game._cards.fixture_cool.damage=0
	# Raw current omissions, identity/type/latch/stacks/turn and fractions fail closed.
	fresh(game)
	game.run.battle.strain=[1,1,0,0,0,0]
	play(game,3,[4])
	var good=game.run.duplicate(true)
	for field in ["source_uid","type","stacks","used","turn","extra"]:
		for bad in [null,true,0.5,-1,999999999999,"unknown"]:
			var broken=good.duplicate(true)
			broken.battle.engine_counters[0][field]=bad
			if field=="used" and bad is bool: continue
			require(not game._valid_run(broken),"Reject raw counter "+field+"="+str(bad))
	for mutation in ["omission","counter","fraction","turn","stacks","type"]:
		var broken=good.duplicate(true)
		match mutation:
			"omission": broken.battle.erase("engine_counters")
			"counter": broken.battle.engine_counters=[]
			"fraction": broken.battle.engine_counters[0].source_uid=1.5
			"turn": broken.battle.engine_counters[0].turn+=1
			"stacks": broken.battle.engine_counters[0].stacks=1
			"type": broken.battle.engine_counters[0].type="novel_route"
		for entry in [["save.json",broken],["save.backup.json",good]]:
			var file=FileAccess.open(directory.path_join(entry[0]),FileAccess.WRITE)
			file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":entry[1]}))
			file.close()
		resumed=Fixtures.FixtureGame.new(directory)
		require(resumed.run==good and resumed.save_error.contains("backup"),"Raw backup fallback "+mutation)
	for spec in [{"type":"cooling_ward","threshold":true,"ward":5},{"type":"cooling_ward","threshold":2,"ward":5,"cap":1},{"type":"cooling_ward","threshold":2.5,"ward":5},{"type":"redirect_retaliation","damage":true},{"type":"redirect_retaliation","damage":0},{"type":"redirect_retaliation","damage":6,"cap":1}]:
		require(not Game.Engines.valid_definition({"install":"x","engine":spec}),"Strict type-specific authored fields")
	fresh(game,"fixture_loom")
	var broken=game.run.duplicate(true)
	broken.battle.engine_counters[0].used=true
	require(not game._valid_run(broken),"Atomic enemy-phase latch cannot be persisted used between phases")
	# Existing revision 5 typed counters and pending guards validate raw BEFORE rebind.
	fresh(game)
	game.run.battle.strain=[1,1,0,0,0,0]
	play(game,3,[4])
	game.run.battle.command_points=3
	require(game.begin_selection(4,[5],0,game.run.battle.enemies[0].duplicate(true)).ok,"Old typed pending fixture")
	var old=game.run.duplicate(true)
	old.schema_revision=5
	old.pending_selection.guard=Game.Selections.guard(game,old,old.pending_selection)
	game.store.write(game.profile,old)
	resumed=Fixtures.FixtureGame.new(directory)
	require(resumed.run.schema_revision==Game.RUN_SCHEMA and resumed.run.battle.engine_counters==old.battle.engine_counters and resumed._valid_pending(resumed.run),"Revision 5 preserves typed counters and rebinds verified pending guard")
	old.pending_selection.guard="forged"
	for entry in [["save.json",old],["save.backup.json",old]]:
		var file=FileAccess.open(directory.path_join(entry[0]),FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":entry[1]}))
		file.close()
	resumed=Fixtures.FixtureGame.new(directory)
	require(resumed.run.is_empty(),"Forged old guard rejected before migration can rebind")
	print("Defense engines: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
