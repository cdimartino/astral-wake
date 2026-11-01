extends SceneTree
const Game=preload("res://scripts/game.gd")
const Session=preload("res://tools/manual_session.gd")
const Policy=preload("res://tests/playthrough.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("astral-palimpsest-evolutions-%d"%Time.get_ticks_usec())

func require(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void: run_tests.call_deferred()

func battle(id: String, branch: String):
	var game=Game.new(directory.path_join("case-%d-%d"%[checks,Time.get_ticks_usec()]))
	game.new_run("0093CG","palimpsest")
	game.run.deck[0].id=id
	game.run.mode="recovery"
	game.recover("upgrade")
	require(game.evolve_card(game.run.deck[0].uid,branch).ok,"Explicit production UID/branch: "+id+"/"+branch)
	game.choose_node(game.run.map[0][0].id)
	game.run.battle.hand=[game.run.deck[0].duplicate(true)]
	game.run.battle.draw=game.run.deck.slice(1).duplicate(true)
	game.run.battle.discard=[]
	game.run.battle.enemies=[game._make_enemy("cinder_mite")]
	game.run.battle.enemies[0].hp=999
	game.run.battle.enemies[0].max_hp=999
	game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"Paired attack"}
	game.run.hull=40
	return game

func run_tests() -> void:
	var catalog=Game.new(directory.path_join("catalog"))
	var count=0
	for card in catalog.catalog.cards:
		if card.get("character","")!="palimpsest": continue
		count+=1
		require(card.evolutions.size()==2 and Game.Evolutions.valid_definition(card),"Two valid Palimpsest branches: "+card.id)
		for branch in card.evolutions:
			var game=battle(card.id,branch.id)
			var effective=game.effective_card(game.run.deck[0])
			require(Game.Distribution.valid_card(card) and not effective.has("roles") and not effective.has("primary_role"),"Validated draft metadata is not a combat payload")
			for key in branch.stats: require(effective[key]==branch.stats[key],"Exact replacement: "+card.id+"/"+key)
			for key in card:
				if key in ["evolutions","name","description","roles","primary_role"] or key in branch.stats: continue
				require(effective[key]==card[key],"Inherited base field: "+card.id+"/"+key)
			game.run.battle.trace=1
			game.run.battle.strain=[2,2,2,2,2,2]
			var before=Session.snapshot(game.run)
			var preview=game.preview_card(0,[1],0)
			require(preview.ok and before==Session.snapshot(game.run),"Pure production preview")
			require(game.play_card(0,[1],0)==preview,"Actual equals preview: "+branch.id)
			require(game.run.battle.command_points==3-effective.cost,"Printed CP, no legacy arithmetic")
			require(game.run.battle.last_payload=={"damage":effective.damage,"heal":effective.heal,"disrupt":effective.disrupt},"Copy payload is printed stats only")
			require(game.run.battle.last_command.base==game.run.battle.last_payload,"Last record uses printed payload")
			require(game.run.battle.hand.size()==effective.draw,"Effective draw count")
			require(game.run.battle.strain[0]==maxi(0,2-int(effective.vent)),"Global vent")
			require(game.run.battle.strain[1]==maxi(0,2-int(effective.vent))+1,"No implicit free strain")
			var expected_trace=0 if effective.get("rewrite",false) else mini(6,1+int(effective.get("trace",0)))
			require(game.run.battle.trace==expected_trace,"Gain before Rewrite/Splice; no invented spend control")
			require(game._valid_run(game.run),"Production state validates")
			game.save()
			require(Session.snapshot(Game.new(game.store.directory).run)==Session.snapshot(game.run),"Actual reload preserves chosen branch and last-command record")
			var bad=game.run.duplicate(true)
			bad.battle.last_command.card.evolution="unknown"
			require(not game._valid_run(bad),"Corrupt last-command identity rejected")
	require(count==18,"Exactly 18 Palimpsest pairs")
	trace_pairs()
	carbon_pair()
	retained_rewrite_pair()
	copy_pairs()
	defense_pairs()
	economy_pair()
	ghost_pair()
	atomic_and_legacy()
	policy_checks()
	print("PALIMPSEST_EVOLUTIONS_TEST ",checks," checks, ",failures," failures; artifacts: ",directory)
	quit(1 if failures else 0)

func trace_pairs() -> void:
	var a=battle("first_draft","decisive_draft")
	var b=battle("first_draft","working_draft")
	for game in [a,b]: game.run.battle.trace=1
	var pa=a.preview_card(0,[0],0)
	var pb=b.preview_card(0,[0],0)
	require(pa.resource_preview.card_trace==3 and pb.resource_preview.card_trace==4,"Drafts: printed gains precede organs")
	require(pa.trace==5 and pb.trace==6,"Drafts: Scribe then reaches 5 versus 6")
	require(pa.damage==9 and pb.damage==6,"Immediate Draft advantage with no spend")
	for game in [a,b]: game.run.battle.trace=0
	# Bank after Scribe, then spend on a separate command; never call retained Trace free damage.
	a.play_card(0,[0],0)
	b.play_card(0,[0],0)
	for game in [a,b]:
		game.run.battle.hand=[game.run.deck[1].duplicate(true)]
		game.run.battle.hand[0].id="revision_spike"
	require(b.preview_card(0,[2],0).damage==a.preview_card(0,[2],0).damage+2,"Banked Draft Trace scales a later Recall by two")
	for game in [a,b]:
		game.run.battle.hand=[game.run.deck[0].duplicate(true)]
		game.run.battle.trace=5
	pa=a.preview_card(0,[0],0)
	pb=b.preview_card(0,[0],0)
	require(pa.resource_preview.card_trace==6 and pb.resource_preview.card_trace==6 and pa.trace==6 and pb.trace==6,"Overflow gives only one actual Trace, not printed two/three")
	for preview in [pa,pb]:
		var gains=preview.presentation.filter(func(event): return event.kind=="trace")
		require(gains.size()==1 and gains[0].amount==1,"Overflow presentation reports actual net gain, not printing")
	# Margin's extra Trace crosses Splice's split threshold before any organ runs.
	a=battle("margin_knife","keen_margin")
	b=battle("margin_knife","inscribed_margin")
	for game in [a,b]: game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
	pa=a.preview_card(0,[1],0)
	pb=b.preview_card(0,[1],0)
	require(pa.damage>pb.damage,"Keen Margin wins single-target pressure")
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(a.run.battle.enemies[1].hp==a.run.battle.enemies[1].max_hp and b.run.battle.enemies[1].hp<b.run.battle.enemies[1].max_hp,"Inscribed Margin alone reaches immediate split threshold")

func carbon_pair() -> void:
	var a=battle("carbon_breath","cool_carbon")
	var b=battle("carbon_breath","carbon_imprint")
	for game in [a,b]: game.run.battle.strain=[2,2,2,2,2,2]
	require(a.preview_card(0,[1],0).strain[0]<b.preview_card(0,[1],0).strain[0],"Cool Carbon leaves more routing headroom")
	for game in [a,b]: game.run.battle.strain=[0,0,0,0,0,0]
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(a.run.battle.hand.size()==1 and b.run.battle.hand.is_empty() and a.run.battle.command_points==2,"Cool Carbon finds a playable command with CP remaining")
	require(b.run.battle.trace==3 and a.run.battle.trace==1,"Carbon Imprint sacrifices draw/cooling for actual Trace")
	for game in [a,b]:
		game.run.battle.hand=[game.run.deck[1].duplicate(true)]
		game.run.battle.hand[0].id="revision_spike"
	require(b.preview_card(0,[2],0).damage==a.preview_card(0,[2],0).damage+4,"Carbon generation has a concrete later Recall payoff")
	for game in [a,b]: game.run.battle.command_points=0
	require(not a.preview_card(0,[2],0).ok and not b.preview_card(0,[2],0).ok,"Draw and Trace never refund CP")

func retained_rewrite_pair() -> void:
	var a=battle("overwrite","forceful_overwrite")
	var b=battle("overwrite","deferred_overwrite")
	for game in [a,b]:
		game.run.battle.trace=1
		game.run.battle.last_payload={"damage":9,"heal":7,"disrupt":3}
	require(a.preview_card(0,[1],0).damage==b.preview_card(0,[1],0).damage+3,"Forceful Overwrite wins immediate burst")
	var uid=b.run.deck[0].uid
	a.end_turn()
	b.end_turn()
	require(Game.Selections.index(a.run.battle.hand,uid)<0 and Game.Selections.index(b.run.battle.hand,uid)>=0,"Deferred Overwrite survives an unplayed turn")
	# Intervening utility changes last_payload: Retain is not a payload reservation.
	b.run.battle.hand=[b.run.deck[0].duplicate(true),b.run.deck[1].duplicate(true)]
	b.run.battle.hand[1].id="carbon_breath"
	b.run.battle.strain=[0,0,0,0,0,0]
	b.play_card(1,[0],0)
	require(b.run.battle.last_payload=={"damage":0,"heal":0,"disrupt":0},"Utility replaces the previous printed payload")
	b.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"No exposure bonus"}
	var trace=b.run.battle.trace
	var p=b.preview_card(0,[1],0)
	require(p.damage==6+trace*2+2 and p.heal==0 and p.disrupt==0,"Retained Rewrite copies intervening utility, not old attack/repair")

func copy_pairs() -> void:
	for pair in [["borrowed_dawn","searing_dawn","kindled_dawn"],["final_revision","definitive_revision","reserved_revision"]]:
		var a=battle(pair[0],pair[1])
		var b=battle(pair[0],pair[2])
		for game in [a,b]:
			game.run.battle.last_payload={"damage":9,"heal":7,"disrupt":3}
			game.run.battle.trace=0
		var zero=a.preview_card(0,[1],0)
		require(zero.damage==a.effective_card(a.run.deck[0]).damage+2 and zero.disrupt==0,"Zero Trace never copies or spends: "+pair[0])
		for game in [a,b]: game.run.battle.trace=1
		var pa=a.preview_card(0,[1],0)
		var pb=b.preview_card(0,[1],0)
		require(pa.damage==a.effective_card(a.run.deck[0]).damage+2+4+2 and pa.disrupt==1,"Positive Trace adds floor-half printed copy: "+pair[0])
		require(pa.damage>pb.damage,"Offensive sibling wins burst: "+pair[0])
		if pair[0]=="borrowed_dawn": require(pb.heal==pa.heal+3,"Kindled Dawn wins missing-hull recovery")
		else:
			var uid=b.run.deck[0].uid
			a.end_turn()
			b.end_turn()
			require(Game.Selections.index(a.run.battle.hand,uid)<0 and Game.Selections.index(b.run.battle.hand,uid)>=0,"Reserved Revision wins future access")
	var game=battle("borrowed_dawn","searing_dawn")
	game.run.battle.trace=3
	game.run.battle.last_payload={"damage":9,"heal":7,"disrupt":3}
	game.play_card(0,[2],0)
	require(game.run.battle.last_command.resolved.damage>11 and game.run.battle.last_payload=={"damage":11,"heal":3,"disrupt":0},"Rewrite/Recall runtime additions never enter copyable base")
	game.run.battle.hand=[game.run.deck[1].duplicate(true)]
	game.run.battle.hand[0].id="overwrite"
	game.run.battle.command_points=1
	game.run.battle.trace=1
	var p=game.preview_card(0,[1],0)
	require(p.damage==6+2+5+2 and p.heal==1 and p.disrupt==0,"Next Rewrite copies floor-half branch printing, not previous resolved chain or Trace gain")

func defense_pairs() -> void:
	for pair in [["vellum_shield","layered_vellum","sealed_vellum",3],["cut_sentence","sharp_sentence","silencing_sentence",4]]:
		var a=battle(pair[0],pair[1])
		var b=battle(pair[0],pair[2])
		if pair[0]=="vellum_shield": require(a.preview_card(0,[1],0).heal>b.preview_card(0,[1],0).heal,"Layered Vellum wins repair")
		else: require(a.preview_card(0,[1],0).damage>b.preview_card(0,[1],0).damage,"Sharp Sentence wins damage")
		for game in [a,b]:
			game.run.battle.enemies[0].intent={"kind":"strain","amount":2,"interrupt":pair[3],"label":"Interruptible setup"}
			game.play_card(0,[1],0)
			game.end_turn()
		require(a.run.battle.strain.max()>b.run.battle.strain.max(),"Defensive sibling actually interrupts setup: "+pair[0])
		for game in [a,b]:
			game.run.battle.hand=[game.run.deck[0].duplicate(true)]
			game.run.battle.strain=[0,0,0,0,0,0]
			game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"Already capped attack"}
			game.run.battle.enemies[0].disrupt=6
			game.run.hull=game.run.max_hull
		var pa=a.preview_card(0,[1],0)
		var pb=b.preview_card(0,[1],0)
		require(pa.attack_reduction==0 and pb.attack_reduction==0,"Extra disruption cannot exceed ordinary half-defense cap")
		if pair[0]=="vellum_shield": require(pa.heal==0 and pb.heal==0,"Full hull makes both repair payloads wasted, not extra ward")

func economy_pair() -> void:
	var a=battle("blank_page","clean_slate")
	var b=battle("blank_page","loose_leaf")
	for game in [a,b]:
		# One legal entry; vent does not legalize a saturated entry organ.
		game.run.battle.strain=[3,2,3,3,3,3]
		game.run.battle.command_points=2
		require(not game.preview_card(0,[0],0).ok and game.preview_card(0,[1],0).ok,"Cooling cannot bypass route validation")
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(a.run.battle.strain[0]==0 and b.run.battle.strain[0]==2 and a.run.battle.trace==2 and b.run.battle.trace==1,"Clean Slate wins thermal reset and generation")
	require(a.run.battle.command_points==0 and b.run.battle.command_points==1,"Loose Leaf explicitly buys one next action")
	for game in [a,b]:
		game.run.battle.hand[0].id="revision_spike"
		game.run.battle.hand[0].level=0
		game.run.battle.hand[0].erase("evolution")
	require(not a.preview_card(0,[2],0).ok and b.play_card(0,[2],0).ok,"Only cheap branch affords the actual next Recall play")
	require(b.run.battle.last_payload=={"damage":12,"heal":0,"disrupt":0},"Recall spend is not copyable")
	# A cheap utility's Trace/cost/vent/draw cannot be copied into a Rewrite.
	b=battle("blank_page","loose_leaf")
	b.play_card(0,[1],0)
	b.run.battle.hand=[b.run.deck[1].duplicate(true)]
	b.run.battle.hand[0].id="overwrite"
	var p=b.preview_card(0,[1],0)
	require(p.damage==10 and p.heal==0 and p.disrupt==0 and p.trace==0,"Loose Leaf's printed Trace is spent once, never copied as resource")

func ghost_pair() -> void:
	var a=battle("ghost_line","etched_line")
	var b=battle("ghost_line","waiting_line")
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(a.run.battle.trace==2 and b.run.battle.trace==1 and a.run.battle.hand.size()==1 and b.run.battle.hand.size()==2,"Ghost Line trades generation against cycling; neither has equal payload")
	a=battle("ghost_line","etched_line")
	b=battle("ghost_line","waiting_line")
	var uid=b.run.deck[0].uid
	a.end_turn()
	b.end_turn()
	require(Game.Selections.index(a.run.battle.hand,uid)<0 and Game.Selections.index(b.run.battle.hand,uid)>=0,"Waiting Line holds link restoration for a later turn")

func atomic_and_legacy() -> void:
	var game=Game.new(directory.path_join("atomic"))
	game.new_run("0093CG","palimpsest")
	game.run.mode="recovery"
	game.recover("upgrade")
	var uid=game.run.deck[0].uid
	var before=Session.snapshot(game.run)
	require(not game.modify_card(0).ok and Session.snapshot(game.run)==before,"Palimpsest never defaults an authored branch")
	require(game.cancel_modify().ok and game.run.deck[0].level==0,"Recovery cancel does not evolve")
	game.run.mode="modify"
	game.run.modify_kind="upgrade"
	game.run.modify_return="shop"
	game.run.modify_shop_index=0
	game.run.shop={"items":[{"kind":"upgrade","id":"","cost":35,"sold":false}]}
	game.run.salvage=50
	before=Session.snapshot(game.run)
	for branch in ["", "legacy", "unknown"]:
		require(not game.evolve_card(uid,branch).ok and Session.snapshot(game.run)==before,"Invalid choice is atomic")
	require(game.cancel_modify().ok and game.run.salvage==50 and not game.run.shop.items[0].sold,"Paid service cancellation charges nothing")
	game.run.mode="modify"
	game.run.modify_kind="upgrade"
	game.run.modify_return="shop"
	require(game.evolve_card(uid,"inscribed_margin").ok and game.run.salvage==15,"Paid UID confirmation selects exact branch once")
	require(not game.evolve_card(uid,"keen_margin").ok and game.run.salvage==15,"No second payment/evolution")
	game.run.schema_revision=4
	game.run.erase("reward_generation")
	game.run.erase("rare_offer_misses")
	game.run.deck[0].erase("evolution")
	require(game._migrate_evolutions(game.run) and game.run.deck[0].evolution=="legacy","Old level-one Palimpsest stays legacy, never reassigned")
	require(game.effective_card(game.run.deck[0]).damage==11 and game.effective_card(game.run.deck[0]).trace==1,"Legacy arithmetic excludes authored Trace")

func policy_checks() -> void:
	var p=Policy.new()
	p.game=battle("first_draft","decisive_draft")
	require(p.evolution_policy_version()=="palimpsest-branches-v1","Per-ship named policy version")
	var a=p.game.effective_card({"id":"first_draft","level":1,"evolution":"decisive_draft"})
	var b=p.game.effective_card({"id":"first_draft","level":1,"evolution":"working_draft"})
	for goal in ["balanced","aggressive","tactical"]:
		p.policy=goal
		p.game.run.battle.trace=0
		require(p.branch_score(a)>p.branch_score(b),"Modest Trace never overvalues Draft over fast damage: "+goal)
		var without=a.duplicate(true)
		without.trace=0
		require(is_equal_approx(p.branch_score(a)-p.branch_score(without),1.2),"Printed two Trace valued modestly across goals")
		p.game.run.battle.trace=5
		require(is_equal_approx(p.branch_score(a)-p.branch_score(without),0.6),"Only actual headroom counts at five Trace")
		p.game.run.battle.trace=6
		require(p.branch_score(a)==p.branch_score(without),"No score for overflow")
	p.game.run.mode="modify"
	p.game.run.deck[0]={"id":"cut_sentence","uid":999,"level":0}
	p.policy="aggressive"
	require(p.plan_modify_branches()[999]=="sharp_sentence","Aggressive explicit UID branch choice")
	p.policy="tactical"
	require(p.plan_modify_branches()[999]=="silencing_sentence","Tactical chooses opposing branch")
	p.game._cards.cut_sentence.evolutions.reverse()
	require(p.plan_modify_branches()[999]=="silencing_sentence","Policy never defaults to first array branch")
	for goal in ["aggressive","tactical"]:
		p.game=Game.new(directory.path_join("policy-confirm-"+goal))
		p.game.new_run("0093CG","palimpsest")
		p.game.run.deck[0].id="cut_sentence"
		p.game.run.mode="recovery"
		p.game.recover("upgrade")
		p.policy=goal
		var uid=p.game.run.deck[0].uid
		var selected=p.plan_modify_branches()[uid]
		var expected="sharp_sentence" if goal=="aggressive" else "silencing_sentence"
		require(selected==expected and p.game.evolve_card(uid,selected).ok and p.game.run.deck[0].evolution==expected,"Scored stable-UID selection is the actual committed identity: "+goal)
	p.game.run.character="cartographer"
	require(p.evolution_policy_version()=="cartographer-branches-v1","Cartographer version unchanged")
	p.free()
