extends SceneTree
const Game=preload("res://scripts/game.gd")
const Policy=preload("res://tests/playthrough.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("astral-production-evolutions-%d"%Time.get_ticks_usec())

func require(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void: run_tests.call_deferred()

func battle(id: String, branch: String):
	var game=Game.new(directory.path_join("case-%d-%d"%[checks,Time.get_ticks_usec()]))
	game.new_run("0093CG","cartographer")
	game.run.deck[0].id=id
	game.run.mode="recovery"
	game.recover("upgrade")
	require(game.evolve_card(game.run.deck[0].uid,branch).ok,"Production stable UID evolution: "+id+"/"+branch)
	game.choose_node(game.run.map[0][0].id)
	game.run.battle.hand=[game.run.deck[0].duplicate(true)]
	game.run.battle.draw=game.run.deck.slice(1).duplicate(true)
	game.run.battle.discard=[]
	game.run.battle.enemies=[game._make_enemy("cinder_mite")]
	game.run.battle.enemies[0].hp=999
	game.run.battle.enemies[0].max_hp=999
	game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"Test attack"}
	game.run.hull=50
	return game

func run_tests() -> void:
	var catalog=Game.new(directory.path_join("catalog"))
	var count=0
	for card in catalog.catalog.cards:
		if card.get("character","cartographer")!="cartographer":
			require(card.evolutions.size()==2 and Game.Evolutions.valid_definition(card),"Other ships have two strict branches")
			continue
		count+=1
		require(card.evolutions.size()==2 and Game.Evolutions.valid_definition(card),"Two strict branches: "+card.id)
		for branch in card.evolutions:
			var game=battle(card.id,branch.id)
			var instance=game.run.deck[0]
			var effective=game.effective_card(instance)
			for key in branch.stats: require(effective[key]==branch.stats[key],"Exact replacement "+card.id+"/"+branch.id+"/"+key)
			game.run.battle.strain=[2,2,2,2,2,2]
			var preview=game.preview_card(0,[1],0)
			require(preview.ok and game.play_card(0,[1],0)==preview,"Actual production payload and CP match preview: "+branch.id)
			require(game.run.battle.command_points==3-effective.cost,"Exact production cost")
			require(game.run.battle.last_command.base.damage==effective.damage and game.run.battle.last_command.base.heal==effective.heal and game.run.battle.last_command.base.disrupt==effective.disrupt,"Actual primary stats, never generic bonus")
			require(game.run.battle.hand.size()==effective.draw,"Actual production draw count")
			require(game.run.battle.strain[0]==maxi(0,2-int(effective.vent)),"Actual production global vent")
			require(game.run.battle.strain[1]==maxi(0,2-int(effective.vent))+(0 if effective.first_free else 1),"Actual first-free strain replacement")
			if effective.get("exhaust",false): require(game.run.battle.exhausted[0].uid==instance.uid,"Actual exhaustion")
			if effective.get("retain",false): require(game.retained(instance),"Actual retention")
	require(count==36,"Exactly 36 Cartographer pairs")
	flags(catalog)
	paired_scenarios()
	policy_checks()
	print("PRODUCTION_EVOLUTIONS_TEST ",checks," checks, ",failures," failures; artifacts: ",directory)
	quit(1 if failures else 0)

func flags(game) -> void:
	var definition=game.card("needle").duplicate(true)
	for flag in ["retain","exhaust","first_free"]:
		for value in [0,1,"true",null,[],{}]:
			definition.evolutions[0].stats[flag]=value
			require(not Game.Evolutions.valid_definition(definition),"Strict flag type: "+flag)
		for value in [true,false]:
			definition.evolutions[0].stats[flag]=value
			require(Game.Evolutions.valid_definition(definition),"Boolean flag accepted")
		definition.evolutions[0].stats.erase(flag)
	definition.install="fixture"
	definition.evolutions[0].stats.exhaust=true
	require(not Game.Evolutions.valid_definition(definition),"Effective Install/Exhaust rejected")
	# False must replace inherited true, not OR/stack.
	game._cards.needle.retain=true
	game._cards.needle.exhaust=true
	game._cards.needle.evolutions[0].stats.merge({"retain":false,"exhaust":false,"first_free":true})
	var effective=game.effective_card({"id":"needle","level":1,"evolution":"sunpoint"})
	require(not effective.retain and not effective.exhaust and effective.first_free,"Flags replace inherited values")

func paired_scenarios() -> void:
	var a=battle("needle","sunpoint")
	var b=battle("needle","held_dawn")
	a.run.battle.enemies[0].hp=12
	b.run.battle.enemies[0].hp=12
	require(a.preview_card(0,[1],0).damage>=12 and b.preview_card(0,[1],0).damage<12,"Needle immediate kill threshold")
	# Keep draw full so ordinary redraw cannot disguise the retention window.
	var uid=b.run.battle.hand[0].uid
	a.end_turn()
	b.end_turn()
	require(Game.Selections.index(b.run.battle.hand,uid)>=0 and Game.Selections.index(a.run.battle.hand,uid)<0,"Needle retained next-turn window")
	a=battle("hull_stitch","deep_stitch")
	b=battle("hull_stitch","coolant_stitch")
	require(a.preview_card(0,[1],0).heal>b.preview_card(0,[1],0).heal,"Stitch missing-hull advantage")
	a.run.hull=a.run.max_hull
	b.run.hull=b.run.max_hull
	a.run.battle.strain=[2,2,2,2,2,2]
	b.run.battle.strain=[2,2,2,2,2,2]
	require(b.preview_card(0,[1],0).strain[0]<a.preview_card(0,[1],0).strain[0],"Stitch strain advantage when repair caps")
	a=battle("cold_breath","deep_breath")
	b=battle("cold_breath","last_breath")
	a.run.battle.strain=[2,2,2,2,2,2]
	b.run.battle.strain=[2,2,2,2,2,2]
	require(a.preview_card(0,[1],0).strain[0]<b.preview_card(0,[1],0).strain[0],"Breath strained-ship advantage")
	a.run.battle.strain=[0,0,0,0,0,0]
	b.run.battle.strain=[0,0,0,0,0,0]
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(b.run.battle.hand.size()==a.run.battle.hand.size()+1 and b.run.battle.command_points==2,"Breath cool-ship draw advantage with remaining CP")
	a=battle("cold_breath","deep_breath")
	b=battle("cold_breath","last_breath")
	a.run.battle.command_points=1
	b.run.battle.command_points=1
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(not b.preview_card(0,[1],0).ok and a.run.battle.exhausted.is_empty() and b.run.battle.exhausted.size()==1,"Zero CP draw is not an extra action; finite burst loses future circulation")
	a=battle("graft_wire","live_wire")
	b=battle("graft_wire","reserve_wire")
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(a.run.battle.hand.size()==2 and b.run.battle.hand.size()==1,"Wire draw advantage")
	require(b.run.battle.strain[1]==0 and a.run.battle.strain[1]==1,"Wire first-strain advantage")
	for branch in ["live_wire","reserve_wire"]:
		var game=battle("graft_wire",branch)
		game.run.battle.draw=[]
		game.play_card(0,[1],0)
		require(game.run.battle.hand.size()==1,"Wire can self-redraw; draw two does not duplicate one UID")
	a=battle("quiet_pulse","hard_pulse")
	b=battle("quiet_pulse","still_pulse")
	require(a.preview_card(0,[1],0).damage>=10 and b.preview_card(0,[1],0).damage<10,"Pulse kill threshold")
	require(b.preview_card(0,[1],0).attack_reduction>a.preview_card(0,[1],0).attack_reduction,"Pulse interrupt advantage")
	var c=battle("quiet_pulse","hard_pulse")
	var d=battle("quiet_pulse","still_pulse")
	c.run.battle.enemies[0].intent={"kind":"strain","amount":2,"interrupt":3,"label":"Interruptible strain"}
	d.run.battle.enemies[0].intent=c.run.battle.enemies[0].intent.duplicate(true)
	c.play_card(0,[1],0)
	d.play_card(0,[1],0)
	c.end_turn()
	d.end_turn()
	require(c.run.battle.strain.max()>d.run.battle.strain.max(),"Pulse interrupts an existing special-action threshold; attacks still obey half-damage cap")
	a.run.battle.enemies[0].disrupt=6
	b.run.battle.enemies[0].disrupt=6
	require(a.preview_card(0,[1],0).attack_reduction==b.preview_card(0,[1],0).attack_reduction,"Pulse extra interruption has no value at defense cap")
	a=battle("whole_horizon","wide_horizon")
	b=battle("whole_horizon","near_horizon")
	require(a.preview_card(0,[1],0).damage>b.preview_card(0,[1],0).damage,"Horizon short-fight burst advantage")
	a.run.battle.command_points=1
	b.run.battle.command_points=1
	require(not a.preview_card(0,[1],0).ok and b.preview_card(0,[1],0).ok,"Horizon 1 CP action advantage")
	a.run.battle.command_points=3
	b.run.battle.command_points=3
	a.run.battle.draw=[]
	b.run.battle.draw=[]
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	a._draw(a.run,1)
	b._draw(b.run,1)
	require(a.run.battle.hand.is_empty() and b.run.battle.hand.size()==1 and b.play_card(0,[1],0).ok,"Horizon repeatable long-fight action versus exhausted future loss")

func policy_checks() -> void:
	var p=Policy.new()
	p.game=battle("quiet_pulse","hard_pulse")
	var hard=p.game.effective_card({"id":"quiet_pulse","level":1,"evolution":"hard_pulse"})
	var still=p.game.effective_card({"id":"quiet_pulse","level":1,"evolution":"still_pulse"})
	p.policy="aggressive"
	require(p.branch_score(hard)>p.branch_score(still),"Aggressive scores Pulse kill branch higher")
	p.policy="tactical"
	require(p.branch_score(still)>p.branch_score(hard),"Tactical scores Pulse interrupt branch higher")
	var deep=p.game.effective_card({"id":"hull_stitch","level":1,"evolution":"deep_stitch"})
	var cool=p.game.effective_card({"id":"hull_stitch","level":1,"evolution":"coolant_stitch"})
	p.policy="balanced"
	p.game.run.hull=90
	require(p.branch_score(cool)>p.branch_score(deep),"Healthy policy cooling preference")
	p.game.run.hull=30
	require(p.branch_score(deep)>p.branch_score(cool),"Wounded policy repair preference")
	p.game.run.deck[0]={"id":"quiet_pulse","uid":999,"level":0}
	p.policy="aggressive"
	require(p.plan_modify_branches()[999]=="hard_pulse","Aggressive plan chooses opposing explicit branch")
	p.policy="tactical"
	require(p.plan_modify_branches()[999]=="still_pulse","Plan uses stable UID and explicit score winner")
	p.game._cards.quiet_pulse.evolutions.reverse()
	require(p.plan_modify_branches()[999]=="still_pulse","Branch array reordering does not change policy")
	p.game.run.deck[0].id="hull_stitch"
	p.policy="balanced"
	p.game.run.hull=90
	require(p.plan_modify_branches()[999]=="coolant_stitch","Healthy plan chooses cooling by explicit UID")
	p.game.run.hull=30
	require(p.plan_modify_branches()[999]=="deep_stitch","Wounded plan chooses opposing repair branch")
	p.free()
