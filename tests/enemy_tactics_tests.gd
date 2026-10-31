extends SceneTree
const Game=preload("res://scripts/game.gd")
var checks=0
var failures=0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+message)

func fixture(id: String, turn: int = 1):
	var root=OS.get_environment("ASTRAL_SAVE_DIR")
	var game=Game.new((root if not root.is_empty() else "user://")+"/tactics-"+str(Time.get_ticks_usec()))
	game.new_run(424242)
	game.choose_node(game.run.map[0][0].id)
	game.run.battle.enemies=[game._make_enemy(id)]
	game.run.battle.turn=turn
	game.run.battle.enemies[0].intent=game._intent_for(id,turn)
	return game

func _initialize() -> void:
	var game=fixture("lantern_eel")
	check(game._damage_enemy(game.run,0,10)==7,"eel armor resists small hits during Arc")
	game.run.battle.enemies[0].intent=game._intent_for("lantern_eel",2)
	check(game._damage_enemy(game.run,0,10)==15,"eel Afterglow rewards attacking the recovery window")
	check(game._damage_enemy(game.run,0,0)==0,"exposure cannot turn a zero payload into damage")
	for example in [["ribbon_leech",1,false,15],["toll_scrap",3,false,11],["rivet_widow",1,true,12]]:
		game=fixture(example[0])
		check(game._damage_enemy(game.run,0,10,example[1],example[2])==example[3],"route or split weakness changes actual damage: "+example[0])
	# Every interruptible utility family must be stopped at the threshold,
	# still happen below it, and advance its cycle rather than stun-lock.
	for example in [["ash_cantor",1,"strain"],["gravity_moth",1,"sever"],["sap_collector",2,"rebuild"],["index_ray",1,"mark"],["unhatched_sun",1,"incubate"]]:
		for stopped in [false,true]:
			game=fixture(example[0],example[1])
			var foe=game.run.battle.enemies[0]
			foe.hp-=20
			var hp=int(foe.hp)
			foe.disrupt=int(foe.intent.interrupt)-(0 if stopped else 1)
			var result=game.end_turn()
			var interrupted=false
			for effect in result.presentation:
				if effect.kind=="interrupted": interrupted=true
			check(interrupted==stopped,"interrupt threshold: "+example[0])
			var happened=false
			match example[2]:
				"strain": happened=game.run.battle.strain.max()>0
				"sever": happened=not game.run.battle.severed.is_empty()
				"rebuild": happened=int(foe.hp)>hp
				"mark": happened=int(game.run.battle.mark)>0
				"incubate": happened=game.run.battle.enemies.size()>1
			check(happened!=stopped,"interruption cancels the actual effect: "+example[0])
			check(foe.disrupt==0 and game.run.battle.turn==int(example[1])+1,"interrupt expires and the cycle advances")
	game=fixture("ribbon_leech",2)
	game.run.battle.enemies[0].hp-=30
	var hp=int(game.run.battle.enemies[0].hp)
	game.run.battle.ward=100
	game.end_turn()
	check(game.run.battle.enemies[0].hp==hp,"ward denies parasite healing completely")
	game=fixture("ribbon_leech",2)
	game.run.battle.enemies[0].hp-=30
	hp=int(game.run.battle.enemies[0].hp)
	var hull=int(game.run.hull)
	game.run.battle.enemies[0].disrupt=4
	game.end_turn()
	check(int(game.run.battle.enemies[0].hp)-hp==hull-int(game.run.hull),"drain heals only actual hull damage after prevention")
	game=fixture("ash_cantor",2)
	var raw=int(game.enemy_attack_preview(0).raw)
	game.run.battle.strain=[3,3,0,0,0,0]
	check(game.enemy_attack_preview(0).raw==raw+4,"overload forecast includes saturated organs")
	var expected=int(game.enemy_attack_preview(0).damage)
	hull=int(game.run.hull)
	game.end_turn()
	check(hull-int(game.run.hull)==expected,"overload resolves before cooling exactly as forecast")
	game=fixture("cinder_mite",2)
	game.run.battle.enemies.append(game._make_enemy("ash_cantor"))
	game.run.battle.enemies[1].intent=game._intent_for("ash_cantor",2)
	game.run.battle.strain=[1,1,0,0,0,0]
	expected=int(game.enemy_attack_preview(1).damage)
	check(expected==int(game.run.battle.enemies[1].intent.amount)+4,"forecast includes earlier enemies saturating organs")
	hull=int(game.run.hull)
	game.end_turn()
	check(hull-int(game.run.hull)==expected,"combined strain/overload forecast matches enemy action order")
	for defend in [false,true]:
		game=fixture("ash_cantor",2)
		game.run.hull=20
		game.run.battle.strain=[3,3,3,3,0,0]
		for pile in [game.run.deck,game.run.battle.hand,game.run.battle.draw,game.run.battle.discard]:
			for instance in pile: instance.id="cold_breath" if defend else "needle"
		game.play_card(0,[4],0)
		game.end_turn()
		check((game.run.mode=="defeat")!=defend,"venting counters a lethal overload; an attack instead loses")
	game=fixture("cinder_mite",2)
	game.run.battle.strain=[0,0,1,0,1,0]
	var rng_state=game.run.rng_state
	game.run.battle.draw.append_array(game.run.battle.discard)
	game.run.battle.discard.clear()
	game.end_turn()
	check(game.run.battle.strain==[0,0,2,0,2,0],"strain targets busiest organs with stable tie order")
	check(game.run.rng_state==rng_state,"enemy targeting does not consume RNG")
	game=fixture("gravity_moth")
	game.run.battle.last_route=[2,1,0]
	game.end_turn()
	check(game.run.battle.severed==[[2,1],[1,0]],"cuts can be baited into the last route in route order")
	# New intent modifiers survive saves; older intents without modifiers remain valid.
	game=fixture("ash_cantor",2)
	game.save()
	var resumed=Game.new(game.store.directory)
	check(resumed.run.battle.enemies[0].intent==game.run.battle.enemies[0].intent,"save/resume preserves the telegraphed stance")
	var old=game.run.duplicate(true)
	old.battle.enemies[0].intent.erase("overload")
	check(game._valid_run(old),"legacy intents remain loadable")
	old.battle.enemies[0].intent.overload="bad"
	check(not game._valid_run(old),"malformed saved modifiers are rejected")
	for definition in game.catalog.enemies:
		game=fixture(definition.id)
		check(game.enemy_tactics_text(0).contains(definition.tactics.counter),"counter is exposed in combat: "+definition.id)
		for turn in range(1,definition.pattern.size()+1):
			var first=game._intent_for(definition.id,turn)
			var repeated=game._intent_for(definition.id,turn+definition.pattern.size())
			check(first.kind==repeated.kind,"enemy action cycle repeats: "+definition.id)
			for field in ["armor","exposed","interrupt","drain","overload"]:
				check(first.get(field)==repeated.get(field),"stance cycle repeats: "+definition.id)
		var before=JSON.stringify(game.run)
		var forecast=game.preview_card(0,[0],0)
		check(forecast.ok and JSON.stringify(game.run)==before,"tactical preview stays pure: "+definition.id)
		var played=game.play_card(0,[0],0)
		check(played.damage==forecast.damage and played.heal==forecast.heal and played.attack_reduction==forecast.attack_reduction,"tactical preview matches commit: "+definition.id)
	print("ENEMY TACTICS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
