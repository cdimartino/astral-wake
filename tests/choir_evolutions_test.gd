extends SceneTree
const Game=preload("res://scripts/game.gd")
const Session=preload("res://tools/manual_session.gd")
const Policy=preload("res://tests/playthrough.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("astral-choir-evolutions-%d"%Time.get_ticks_usec())

func require(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void: run_tests.call_deferred()

func battle(id: String, branch: String):
	var game=Game.new(directory.path_join("case-%d-%d"%[checks,Time.get_ticks_usec()]))
	game.new_run("0093CG","hollow_choir")
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
		if card.get("character","")!="hollow_choir": continue
		count+=1
		require(card.evolutions.size()==2 and Game.Evolutions.valid_definition(card),"Two strict Choir branches: "+card.id)
		for branch in card.evolutions:
			var game=battle(card.id,branch.id)
			var effective=game.effective_card(game.run.deck[0])
			require(Game.Distribution.valid_card(card) and not effective.has("roles") and not effective.has("primary_role"),"Validated draft metadata is not a combat payload")
			for key in branch.stats: require(effective[key]==branch.stats[key],"Exact replacement: "+card.id+"/"+key)
			for key in card:
				if key in ["evolutions","name","description","roles","primary_role"] or key in branch.stats: continue
				require(effective[key]==card[key],"Inherited field: "+card.id+"/"+key)
			game.run.battle.resonance=1
			game.run.battle.strain=[2,2,2,2,2,2]
			var before=Session.snapshot(game.run)
			var p=game.preview_card(0,[1],0)
			require(p.ok and Session.snapshot(game.run)==before,"Pure production preview")
			require(game.play_card(0,[1],0)==p,"Actual equals preview: "+branch.id)
			require(game.run.battle.command_points==3-effective.cost,"Printed cost, no legacy bonus")
			require(game.run.battle.last_payload.is_empty(),"Choir does not populate Palimpsest's copy buffer")
			require(game.run.battle.last_command.base=={"damage":effective.damage,"heal":effective.heal,"disrupt":effective.disrupt},"Recorded plain payload excludes Resonance/Concert/flags")
			require(game.run.battle.hand.size()==effective.draw,"Effective draw count")
			require(game.run.battle.strain[0]==maxi(0,2-int(effective.vent)),"Effective global cooling")
			require(game.run.battle.strain[1]==maxi(0,2-int(effective.vent))+(0 if effective.first_free else 1),"Only explicit first-free spares entry strain")
			var expected=0 if effective.get("concert",false) else mini(3,1+int(effective.get("resonance",0)))
			require(game.run.battle.resonance==expected,"Printed gain before Concert/Chorus; first command has no automatic kind gain")
			require(game._valid_run(game.run),"Production state validates")
			game.save()
			require(Session.snapshot(Game.new(game.store.directory).run)==Session.snapshot(game.run),"Actual reload preserves identity and payload")
			var bad=game.run.duplicate(true)
			bad.battle.last_command.card.evolution="unknown"
			require(not game._valid_run(bad),"Corrupt recorded identity rejected")
	require(count==18,"Exactly 18 Choir pairs")
	choral_pair()
	warm_pair()
	tuning_pair()
	bright_pair()
	counterpoint_pair()
	shell_pair()
	positive_healing()
	atomic_and_legacy()
	policy_checks()
	print("CHOIR_EVOLUTIONS_TEST ",checks," checks, ",failures," failures; artifacts: ",directory)
	quit(1 if failures else 0)

func choral_pair() -> void:
	var a=battle("choral_bolt","piercing_chorus")
	var b=battle("choral_bolt","gathering_chorus")
	for game in [a,b]:
		game.run.battle.last_command_kind="attack"
		game.run.battle.resonance=3
		game.run.battle.enemies[0].hp=11
	var pa=a.preview_card(0,[4],0)
	var pb=b.preview_card(0,[4],0)
	require(pa.damage==11 and pb.damage==7,"Piercing Chorus meets immediate kill; Gathering does not")
	require(pa.resource_preview.card_resonance==0 and pb.resource_preview.card_resonance==1 and pa.disrupt==1 and pb.disrupt==2,"Repeated attack resets before printed gain and Dissonance")
	for game in [a,b]:
		game.run.battle.enemies[0].hp=999
		game.run.battle.enemies.append(game._make_enemy("cinder_mite"))
		game.run.battle.last_command_kind="utility"
		game.run.battle.resonance=0
	pa=a.preview_card(0,[1],0)
	pb=b.preview_card(0,[1],0)
	require(pa.resource_preview.card_resonance==1 and pb.resource_preview.card_resonance==2,"Kind gain then printing reaches Chorus threshold only for Gathering")
	require(pa.damage==12 and pb.damage==10 and pb.route_steps[0].payload_after[0]==7,"Chorus fallback versus seven primary plus three split")
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	require(a.run.battle.enemies[1].hp==a.run.battle.enemies[1].max_hp and b.run.battle.enemies[1].hp==b.run.battle.enemies[1].max_hp-3,"Gathering wins secondary hit: floor(7/2)")
	# Conductor grants on first/different kind, never on a repeat.
	a=battle("choral_bolt","piercing_chorus")
	require(a.preview_card(0,[0],0).resource_preview.card_resonance==0 and a.preview_card(0,[0],0).resonance==1,"First card gets Conductor only, no fake automatic first-kind gain")
	a.run.battle.last_command_kind="attack"
	a.run.battle.resonance=3
	require(a.preview_card(0,[0],0).resonance==0,"Conductor cannot bypass repeated-kind reset")
	a.run.battle.last_command_kind="repair"
	require(a.preview_card(0,[0],0).resonance==3,"Different kind caps both automatic and Conductor gains at three")

func warm_pair() -> void:
	var a=battle("warm_refrain","full_refrain")
	var b=battle("warm_refrain","waiting_refrain")
	require(a.preview_card(0,[1],0).heal==8 and b.preview_card(0,[1],0).heal==6,"Full Refrain wins immediate repair")
	var uid=b.run.deck[0].uid
	for game in [a,b]:
		game.run.battle.resonance=3
		game.run.battle.last_command_kind="repair"
	a.end_turn()
	b.end_turn()
	require(Game.Selections.index(a.run.battle.hand,uid)<0 and Game.Selections.index(b.run.battle.hand,uid)>=0,"Waiting Refrain preserves access to repair-kind bridge, not a free action")
	# Retain does not immunize the held card from same-kind reset.
	b.run.battle.hand=[b.run.deck[0].duplicate(true)]
	b.run.battle.strain=[0,0,0,0,0,0]
	var p=b.preview_card(0,[0],0)
	require(p.resource_preview.card_resonance==1 and p.resonance==1,"Held repair following repair resets three to printed one; Conductor inactive")
	b.run.battle.last_command_kind="attack"
	b.run.battle.resonance=0
	require(b.preview_card(0,[0],0).resonance==3,"Held repair can bridge attack to automatic+printed+Conductor gains")

func tuning_pair() -> void:
	var a=battle("tuning_fork","clear_tuning")
	var b=battle("tuning_fork","gathered_tuning")
	for game in [a,b]:
		game.run.battle.last_command_kind="utility"
		game.run.battle.resonance=3
	var pa=a.preview_card(0,[4],0)
	var pb=b.preview_card(0,[4],0)
	require(pa.resource_preview.card_resonance==1 and pb.resource_preview.card_resonance==2 and pa.disrupt==7 and pb.disrupt==6,"Tuning repetition: printed gain precedes Dissonance, total seven versus six")
	for game in [a,b]: game.run.battle.enemies[0].intent={"kind":"strain","amount":2,"interrupt":5,"label":"Five-point setup"}
	a.play_card(0,[1],0)
	b.play_card(0,[1],0)
	a.end_turn()
	b.end_turn()
	require(a.run.battle.strain.max()<b.run.battle.strain.max(),"Clear Tuning alone stops five-point setup on neutral organ route")
	for game in [a,b]:
		game.run.battle.hand=[game.run.deck[0].duplicate(true)]
		game.run.battle.strain=[0,0,0,0,0,0]
		game.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"Already capped attack"}
		game.run.battle.enemies[0].disrupt=6
		game.run.battle.resonance=3
		game.run.battle.last_command_kind="utility"
	pa=a.preview_card(0,[1],0)
	pb=b.preview_card(0,[1],0)
	require(pa.attack_reduction==0 and pb.attack_reduction==0 and pa.resonance==1 and pb.resonance==2,"At ordinary defense cap extra suppression is wasted; Gathering banks one more resource")

func bright_pair() -> void:
	var a=battle("bright_canon","blazing_canon")
	var b=battle("bright_canon","held_canon")
	for game in [a,b]:
		game.run.battle.last_command_kind="utility"
		game.run.battle.resonance=2
	var pa=a.preview_card(0,[0,1],0)
	var pb=b.preview_card(0,[0,1],0)
	require(pa.resource_preview.card_resonance==0 and pb.resource_preview.card_resonance==0,"Automatic third point spent by Concert before organs")
	require(pa.route_steps[0].payload_before[0]==21 and pb.route_steps[0].payload_before[0]==18 and pa.heal==3 and pb.heal==3,"Concert gives six damage/three repair to both; Blazing wins burst")
	require(pa.route_steps[0].resonance_after==1 and pa.route_steps[1].status=="fallback" and pa.damage==22 and pb.damage==19,"Conductor regains only one; Chorus cannot split spent Resonance")
	var uid=b.run.deck[0].uid
	a.end_turn()
	b.end_turn()
	require(Game.Selections.index(a.run.battle.hand,uid)<0 and Game.Selections.index(b.run.battle.hand,uid)>=0,"Held Canon wins future finisher access")
	b.run.battle.hand=[b.run.deck[0].duplicate(true)]
	b.run.battle.strain=[0,0,0,0,0,0]
	b.run.battle.last_command_kind="attack"
	b.run.battle.resonance=3
	b.run.battle.enemies[0].intent={"kind":"attack","amount":12,"label":"No exposure"}
	var p=b.preview_card(0,[1],0)
	require(p.damage==13 and p.heal==0 and p.resonance==0,"Retained Concert following attack loses banked three; no sequence exception")

func counterpoint_pair() -> void:
	var a=battle("counterpoint","light_counterpoint")
	var b=battle("counterpoint","gathered_counterpoint")
	for game in [a,b]:
		game.run.battle.last_command_kind="utility"
		game.run.battle.resonance=3
		game.run.battle.strain=[2,2,2,2,2,2]
	a.play_card(0,[1,3],0)
	b.play_card(0,[1,3],0)
	require(a.run.battle.resonance==2 and b.run.battle.resonance==3,"Printed one/two after reset, then Rest adds exactly one")
	require(a.run.battle.strain[1]==2 and b.run.battle.strain[1]==3 and a.run.battle.strain[3]==3 and b.run.battle.strain[3]==3,"First-free spares entry only, not every organ")
	require(a.run.battle.command_points==2 and b.run.battle.command_points==2 and a.run.battle.hand.size()==2 and b.run.battle.hand.size()==1,"Light Counterpoint draws more; first-free does not refund CP")
	require(a.preview_card(0,[0],0).ok,"The actual extra hand access is usable with remaining CP and a legal entry")
	a=battle("counterpoint","light_counterpoint")
	b=battle("counterpoint","gathered_counterpoint")
	for game in [a,b]:
		game.run.battle.last_command_kind="utility"
		game.run.battle.resonance=3
		game.play_card(0,[1],0)
	require(a.run.battle.resonance==1 and b.run.battle.resonance==2,"Neutral route preserves resource sibling advantage")
	# A follow-up starter attack converts the extra banked point through Crescendo.
	for game in [a,b]:
		game.run.deck[1].id="choral_bolt"
		game.run.battle.hand=[game.run.deck[1].duplicate(true)]
	require(b.preview_card(0,[2],0).damage==a.preview_card(0,[2],0).damage+2,"Gathering resource converts to two extra Crescendo damage")
	a=battle("counterpoint","light_counterpoint")
	a.run.battle.command_points=1
	a.play_card(0,[1],0)
	require(a.run.battle.command_points==0 and not a.preview_card(0,[1],0).ok,"Extra draw at zero CP is not another play")

func shell_pair() -> void:
	var a=battle("resonant_shell","full_shell")
	var b=battle("resonant_shell","light_shell")
	for game in [a,b]:
		game.run.battle.last_command_kind="repair"
		game.run.battle.resonance=3
		game.run.battle.command_points=3
	var pa=a.preview_card(0,[3],0)
	var pb=b.preview_card(0,[3],0)
	require(pa.resource_preview.card_resonance==2 and pb.resource_preview.card_resonance==1 and pa.heal==11 and pb.heal==6 and pa.resonance==3 and pb.resonance==2,"Shell repeat resets first; Rest yields eleven/three versus six/two")
	a.play_card(0,[3],0)
	b.play_card(0,[3],0)
	require(a.run.battle.command_points==1 and b.run.battle.command_points==2,"Discount explicitly buys one next-action point")
	for game in [a,b]:
		game.run.deck[1].id="bright_canon"
		game.run.battle.hand.append(game.run.deck[1].duplicate(true))
	require(not a.preview_card(0,[1],0).ok and b.play_card(0,[1],0).ok,"Only Light Shell affords an actual two-CP Concert follow-up")
	require(b.run.battle.last_command.base=={"damage":12,"heal":0,"disrupt":0},"Concert resource payoff never enters recorded printed payload")
	a=battle("resonant_shell","full_shell")
	b=battle("resonant_shell","light_shell")
	for game in [a,b]:
		game.run.battle.last_command_kind="utility"
		game.run.battle.resonance=2
	pa=a.preview_card(0,[1],0)
	pb=b.preview_card(0,[1],0)
	require(pa.resonance==3 and pb.resonance==3,"Automatic transition fills cap before printing; both printed gains overflow")
	for preview in [pa,pb]:
		var gains=preview.presentation.filter(func(event): return event.kind=="resonance")
		require(gains.size()==1 and gains[0].amount==1,"Cap presentation reports actual net one, not printing plus transition")

func positive_healing() -> void:
	for pair in [["crescendo","rising_crescendo","restorative_crescendo"],["unison","striking_unison","sustaining_unison"]]:
		var a=battle(pair[0],pair[1])
		var b=battle(pair[0],pair[2])
		for game in [a,b]:
			game.run.battle.resonance=0
			game.run.battle.last_command_kind=""
		var pa=a.preview_card(0,[0,1,2],0)
		var pb=b.preview_card(0,[0,1,2],0)
		require(pa.damage>pb.damage and pa.heal==0 and pb.heal==5,"Zero Concert spend then Conductor/Crescendo adds healing only to positive printed sibling: "+pair[0])
		require(pa.resource_preview.card_resonance==0 and pb.resource_preview.card_resonance==0 and pb.resonance==0,"No invented Concert resource or cap")
		var rest=b.preview_card(0,[3],0)
		require(rest.heal==3 and rest.resonance==0 and b.effective_card(b.run.deck[0]).kind=="attack","Printed healing never changes attack kind or grants Rest benefits")
		b.play_card(0,[0,1,2],0)
		require(b.run.battle.last_command.base.heal==3 and b.run.battle.last_command.resolved.heal==5,"Organ healing amplification is resolved-only, not printing")

func atomic_and_legacy() -> void:
	var game=Game.new(directory.path_join("atomic"))
	game.new_run("0093CG","hollow_choir")
	game.run.mode="recovery"
	game.recover("upgrade")
	var uid=game.run.deck[0].uid
	var before=Session.snapshot(game.run)
	require(not game.modify_card(0).ok and Session.snapshot(game.run)==before,"No implicit Choir branch")
	require(game.cancel_modify().ok and game.run.deck[0].level==0,"Recovery cancellation costs no evolution")
	game.run.mode="modify"
	game.run.modify_kind="upgrade"
	game.run.modify_return="shop"
	game.run.modify_shop_index=0
	game.run.shop={"items":[{"kind":"upgrade","id":"","cost":35,"sold":false}]}
	game.run.salvage=50
	before=Session.snapshot(game.run)
	for branch in ["", "legacy", "unknown"]:
		require(not game.evolve_card(uid,branch).ok and Session.snapshot(game.run)==before,"Invalid Choir identity is atomic")
	require(game.cancel_modify().ok and game.run.salvage==50 and not game.run.shop.items[0].sold,"Paid cancellation charges nothing")
	game.run.mode="modify"
	game.run.modify_kind="upgrade"
	game.run.modify_return="shop"
	require(game.evolve_card(uid,"gathering_chorus").ok and game.run.salvage==15,"Paid explicit branch charges once")
	require(not game.evolve_card(uid,"piercing_chorus").ok and game.run.salvage==15,"Second evolution/payment rejected")
	game.run.schema_revision=4
	game.run.erase("reward_generation")
	game.run.erase("content_pool_revision")
	game.run.erase("rare_offer_misses")
	game.run.deck[0].erase("evolution")
	require(game._migrate_evolutions(game.run) and game.run.deck[0].evolution=="legacy","Old level-one Choir stays legacy")
	var legacy=game.effective_card(game.run.deck[0])
	require(legacy.damage==11 and legacy.get("resonance",0)==0,"Legacy arithmetic does not adopt authored resource gain")

func policy_checks() -> void:
	var p=Policy.new()
	p.game=battle("choral_bolt","piercing_chorus")
	require(p.evolution_policy_version()=="choir-branches-v1","Choir policy named explicitly")
	var a=p.game.effective_card({"id":"choral_bolt","level":1,"evolution":"piercing_chorus"})
	var b=p.game.effective_card({"id":"choral_bolt","level":1,"evolution":"gathering_chorus"})
	for goal in ["balanced","aggressive","tactical"]:
		p.policy=goal
		p.game.run.battle.last_command_kind="attack"
		p.game.run.battle.resonance=3
		require(p.branch_score(a)>p.branch_score(b),"Modest gain cannot overwhelm four damage: "+goal)
		var without=b.duplicate(true)
		without.resonance=0
		require(is_equal_approx(p.branch_score(b)-p.branch_score(without),0.8),"Same-kind reset creates headroom before printed scoring")
		p.game.run.battle.last_command_kind="utility"
		p.game.run.battle.resonance=2
		require(p.branch_score(b)==p.branch_score(without),"Transition fills cap; no score for overflowing printing")
	for goal in ["aggressive","tactical"]:
		p.game=Game.new(directory.path_join("policy-confirm-"+goal))
		p.game.new_run("0093CG","hollow_choir")
		p.game.run.deck[0].id="dissonant_edge"
		p.game.run.mode="recovery"
		p.game.recover("upgrade")
		p.policy=goal
		var uid=p.game.run.deck[0].uid
		var expected="cutting_dissonance" if goal=="aggressive" else "silencing_dissonance"
		require(p.plan_modify_branches()[uid]==expected,"Opposing policy goal chooses named ID")
		p.game._cards.dissonant_edge.evolutions.reverse()
		require(p.plan_modify_branches()[uid]==expected and p.game.evolve_card(uid,expected).ok and p.game.run.deck[0].evolution==expected,"Array order irrelevant; scored UID choice matches actual committed branch")
	p.game.run.character="palimpsest"
	require(p.evolution_policy_version()=="palimpsest-branches-v1","Palimpsest version unchanged")
	p.game.run.character="cartographer"
	p.game.run.content_pool_revision=0 # Historical Cartographer policy stays versioned.
	require(p.evolution_policy_version()=="cartographer-branches-v1","Cartographer version unchanged")
	p.free()
