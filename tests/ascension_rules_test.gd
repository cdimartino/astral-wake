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
	check(game.new_run("ABC123").ok,"A0 default")
	var baseline=game.run.duplicate(true)
	for rank in range(12):
		game.profile.ascension_unlocks.cartographer=11
		check(game.new_run("ABC123","cartographer",rank).ok,"Eligible rank")
		check(game.run.rng_streams==baseline.rng_streams and game.run.map==baseline.map and game.run.deck==baseline.deck,"Rank independent RNG")
		var distinct=rank==0
		for area in range(3):
			for turn in [2,3,4,5,8,9]:
				for kind in ["battle","elite","boss"]:
					var bonus=A.attack_bonus(rank,area,turn,kind)
					check(area!=0 or bonus==0,"Area 1 excluded")
					if rank>0:
						var prior=A.attack_bonus(rank-1,area,turn,kind)
						check(bonus>=prior,"Monotonic pressure")
						distinct=distinct or bonus>prior
					game.run.region=area
					game.run.battle={"kind":kind}
					game.run.ascension_rank=0
					var base=game._intent_for("_hatchling",turn)
					game.run.ascension_rank=rank
					var intent=game._intent_for("_hatchling",turn)
					check(intent.amount==base.amount+bonus,"Visible spawn intent bonus parity")
		check(distinct,"Each rank changes a condition")
	check(A.attack_bonus(11,2,9,"boss")==5,"A11 final guardian cap")
	check(A.attack_bonus(11,1,9,"boss")==4,"A11 Area 2 guardian cap")
	# Exercise the actual shared forecast/resolution path, including normal defenses.
	game.new_run("ABC123","cartographer",11)
	game.run.region=2
	game._start_battle({"type":"boss","enemy_ids":["_hatchling"]})
	game.run.battle.turn=9
	game.run.battle.enemies[0].intent=game._intent_for("_hatchling",9)
	game.run.battle.enemies[0].disrupt=2
	game.run.battle.ward=3
	var forecast=game.enemy_attack_preview(0)
	var hull=int(game.run.hull)
	var result=game.end_turn()
	var attacks=result.presentation.filter(func(event): return event.kind=="enemy_attack")
	check(attacks.size()==1,"One visible attack resolves once")
	check(int(attacks[0].amount)==maxi(0,int(forecast.damage)-3),"Forecast mitigation equals committed damage")
	check(int(attacks[0].absorbed)==mini(3,int(forecast.damage)) and int(attacks[0].disrupted)==2,"Ward and disruption parity")
	check(hull-int(game.run.hull)==int(attacks[0].amount),"Actual hull agrees with presentation")
	# Force only the authored spawn intent; all timer and attack progression is real.
	game.new_run("ABC123","cartographer",11)
	game.run.region=2
	game._start_battle({"type":"boss","enemy_ids":["_hatchling"]})
	game.run.battle.enemies[0].intent={"kind":"incubate","amount":0,"label":"Spawn cocoon"}
	hull=int(game.run.hull)
	game.end_turn()
	check(game.run.battle.enemies.size()==2 and game.run.battle.enemies[1].egg_timer==2,"Creation phase excluded")
	game.run.battle.enemies.remove_at(0)
	check(game.run.battle.enemies[0].intent.label.contains("2"),"Fresh visible countdown")
	game.run.battle.enemies[0].disrupt=999
	game.end_turn()
	check(game.run.battle.enemies[0].id=="_egg" and game.run.battle.enemies[0].egg_timer==1,"First subsequent phase counts down despite disruption")
	check(game.run.battle.enemies[0].intent.label.contains("1"),"Live countdown shows one")
	game.end_turn()
	check(game.run.battle.enemies[0].id=="_hatchling" and int(game.run.hull)==hull,"Second subsequent phase hatches without attacking")
	forecast=game.enemy_attack_preview(0)
	check(forecast.raw==game._intent_for("_hatchling",int(game.run.battle.turn)).amount,"Hatched attack inherits encounter pressure")
	game.end_turn()
	check(hull-int(game.run.hull)==int(forecast.damage),"First hatchling attack occurs following phase")
	print("ascension_rules_test failures=",failures)
	quit(1 if failures else 0)
