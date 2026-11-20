extends SceneTree
const Game=preload("res://scripts/game.gd")
const Session=preload("res://tools/manual_session.gd")
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("astral-rules-%d"%Time.get_ticks_usec())

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void: run_tests.call_deferred()

func run_tests() -> void:
	var game=Game.new(directory)
	game.new_run("0093CG","hollow_choir")
	check(game.run.rules_revision==1,"New run independently pins rules")
	check(Game.new(directory).run==game.run,"Explicit revision survives actual JSON reload")
	game.choose_node(game.run.map[0][0].id)
	game.run.battle.enemies=[game._make_enemy("cinder_mite")]
	game.run.battle.enemies[0].hp=999
	game.run.battle.enemies[0].max_hp=999
	game.run.hull=40
	var frozen=game.run.duplicate(true)
	# Freeze a schema-7 pre-revision combat continuation, including exact RNG/piles.
	frozen.erase("rules_revision")
	game.run=frozen.duplicate(true)
	game.save()
	var continued=Game.new(directory)
	check(continued.run==frozen,"Old schema-7 continuation is not repaired/rerolled")
	check(continued._valid_run(continued.run),"Missing rules field remains valid legacy")
	for id in ["crescendo","bright_canon"]:
		var copies=[{"uid":1000,"id":id,"level":0},{"uid":1000,"id":id,"level":1,"evolution":"legacy"}]
		for branch in game.card(id).evolutions:
			copies.append({"uid":1000,"id":id,"level":1,"evolution":branch.id})
		for copy in copies:
			for resonance in [0,1,2,3]:
				for route in [[1],[4]]:
					game.run=frozen.duplicate(true)
					game.run.battle.hand=[copy]
					game.run.battle.draw=[]
					game.run.battle.discard=[]
					game.run.battle.resonance=resonance
					game.run.battle.last_command_kind=""
					var old=game.preview_card(0,route,0)
					var old_state=game._simulate_card(game.run.duplicate(true),0,route,0)
					game.run.rules_revision=1
					var before=game.run.duplicate(true)
					var modern=game.preview_card(0,route,0)
					var definition=game.effective_card(copy)
					var spent=mini(3,resonance+int(definition.get("resonance",0)))
					var bonus=4 if id=="crescendo" and definition.get("concert",false) and spent==3 else 0
					check(old.ok and modern.ok,"Both rules forecast")
					check(modern.damage==old.damage+bonus,"Only full printed Crescendo spend boosts damage")
					check(modern.heal==old.heal,"Bonus never boosts healing")
					var new_state=game._simulate_card(game.run.duplicate(true),0,route,0)
					check(new_state.next.battle.resonance==old_state.next.battle.resonance,"No double spend at named organ")
					check(new_state.next.battle.last_command.base==old_state.next.battle.last_command.base,"Remembered printed payload unchanged")
					check(game.run==before,"Forecast pure")
					check(game.play_card(0,route,0)==modern,"Forecast equals commit for every evolution")
					check(game.card_text(copy).contains("adds 4 damage")== (id=="crescendo" and definition.get("concert",false)),"New-rule public card explanation")
					game.run.erase("rules_revision")
					check(not game.card_text(copy).contains("adds 4 damage"),"Historical legacy card explanation")
	for invalid in [-1,2,1.5,"1",true]:
		var bad=frozen.duplicate(true)
		bad.rules_revision=invalid
		check(not game._valid_run(bad),"Unsupported explicit revision rejected")
	game.run=frozen.duplicate(true)
	game._finish_run(false)
	check(game.profile.history[0].rules_revision==0,"Historical record pins legacy rules")
	game.new_run("0093CG","hollow_choir")
	game._finish_run(false)
	check(game.profile.history[0].rules_revision==1,"New history pins new rules")
	print("Balance revision failures: ",failures)
	quit(1 if failures else 0)
