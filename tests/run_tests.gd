extends SceneTree
const Game = preload("res://scripts/game.gd")
var failures=0
var checks=0
var directory="/tmp/astral-tests-"+str(Time.get_ticks_usec())

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+message)

func make_game(seed_value: int=101, character_id: String="cartographer"):
	var game=Game.new(directory+"/case-"+str(checks)+"-"+str(Time.get_ticks_usec()))
	game.new_run(seed_value,character_id)
	return game

func battle_game(character_id: String="cartographer"):
	var game=make_game(101,character_id)
	game.choose_node(game.run.map[0][0].id)
	return game

func command_points_checks() -> void:
	var limited=battle_game()
	check(limited.run.battle.command_points==3 and limited.run.battle.max_command_points==3,"combat opens with three command points")
	for pile in [limited.run.deck,limited.run.battle.hand,limited.run.battle.draw,limited.run.battle.discard]:
		for instance in pile: instance.id="needle"
	limited.run.battle.enemies[0].hp=999
	limited.run.battle.enemies[0].max_hp=999
	var before=JSON.stringify(limited.run)
	var forecast=limited.preview_card(0,[0],0)
	check(forecast.ok and forecast.cost==1 and forecast.command_points==2,"preview forecasts one-point card cost")
	check(JSON.stringify(limited.run)==before,"cost preview cannot spend real command points")
	for remaining in [2,1,0]:
		check(limited.play_card(0,[0],0).ok,"normal card plays within three-point budget")
		check(limited.run.battle.command_points==remaining,"each normal card spends exactly one point")
	before=JSON.stringify(limited.run)
	var rejected=limited.preview_card(0,[1],0)
	check(not rejected.ok and rejected.error.contains("command points"),"fourth normal card preview is unaffordable")
	check(not limited.play_card(0,[1],0).ok,"fourth normal card commit is rejected")
	check(JSON.stringify(limited.run)==before,"unaffordable actions spend no cards, strain, points or RNG")
	limited.end_turn()
	check(limited.run.battle.command_points==3,"end turn refreshes exactly three command points")
	check(limited.run.battle.strain[0]==2,"point refresh retains separate strain and cooling rules")
	var strong=battle_game()
	for pile in [strong.run.deck,strong.run.battle.hand,strong.run.battle.draw,strong.run.battle.discard]:
		for instance in pile: instance.id="seam_of_light"
	var strong_preview=strong.preview_card(0,[3],0)
	check(strong_preview.ok and strong_preview.cost==2 and strong_preview.command_points==1,"strong card preview spends two points")
	check(strong.play_card(0,[3],0).ok and strong.run.battle.command_points==1,"strong card commit spends exactly two points")
	before=JSON.stringify(strong.run)
	check(not strong.preview_card(0,[4],0).ok and not strong.play_card(0,[4],0).ok,"two-point card is rejected with one point left")
	check(JSON.stringify(strong.run)==before,"failed strong card leaves state unchanged")
	strong.save()
	var resumed=Game.new(strong.store.directory)
	check(resumed.run.battle.command_points==1 and resumed.run.battle.max_command_points==3,"resume preserves partially spent command budget")
	check(not resumed.preview_card(0,[4],0).ok,"resume grants no free actions")
	resumed.end_turn()
	resumed.save()
	var next_turn=Game.new(resumed.store.directory)
	check(next_turn.run.battle.command_points==3,"reset command budget persists across resume")
	for invalid_points in [-1,4,"3"]:
		var invalid=strong.run.duplicate(true)
		invalid.battle.command_points=invalid_points
		check(not strong._valid_run(invalid),"invalid saved command points rejected")
	var incomplete=strong.run.duplicate(true)
	incomplete.battle.erase("command_points")
	check(not strong._valid_run(incomplete),"partially missing command budget is corrupt")
	# Legacy saves know whether a card was played, but cannot prove remaining actions.
	var legacy=battle_game()
	var old=legacy.run.duplicate(true)
	old.erase("schema_revision")
	for key in ["exhausted","installed","installed_sources","temporary_retain"]: old.battle.erase(key)
	old.battle.erase("command_points")
	old.battle.erase("max_command_points")
	legacy.store.write(legacy.profile,old)
	var fresh_legacy=Game.new(legacy.store.directory)
	check(fresh_legacy.run.battle.command_points==3,"untouched legacy turn safely resumes with full budget")
	old.battle.first_play=false
	legacy.store.write(legacy.profile,old)
	var spent_legacy=Game.new(legacy.store.directory)
	check(spent_legacy.run.battle.command_points==0,"played legacy turn requires end turn before more cards")
	check(not spent_legacy.preview_card(0,[0],0).ok,"legacy migration grants no unproven free actions")
	spent_legacy.end_turn()
	check(spent_legacy.run.battle.command_points==3,"legacy run can continue after refresh")

func balance_presentation_checks() -> void:
	var solo=battle_game()
	solo.run.battle.enemies=[solo._make_enemy("cinder_mite")]
	solo.run.battle.enemies[0].hp=999
	solo.run.battle.enemies[0].max_hp=999
	solo.run.battle.enemies[0].intent={"kind":"attack","amount":8,"label":"Test strike"}
	solo.run.battle.enemies[0].redirect=99
	check(solo.enemy_attack_preview(0).redirected==0 and solo.enemy_attack_preview(0).damage==8,"Prism cannot cancel or self-reflect a lone enemy attack")
	solo.run.battle.enemies[0].disrupt=99
	for raw in range(1,21):
		solo.run.battle.enemies[0].intent.amount=raw
		check(solo.enemy_attack_preview(0).damage==int(ceil(raw/2.0)),"combined defense never prevents more than half an attack")
	var pair=battle_game()
	pair.run.battle.enemies=[pair._make_enemy("cinder_mite"),pair._make_enemy("cinder_mite")]
	for foe in pair.run.battle.enemies:
		foe.hp=999
		foe.max_hp=999
		foe.intent={"kind":"attack","amount":8,"label":"Test strike"}
	pair.run.battle.enemies[0].disrupt=100
	pair.run.battle.enemies[0].redirect=100
	pair.run.battle.enemies[1].redirect=3
	var phase=pair.end_turn()
	check(pair.run.hull==91,"two capped enemy attacks still inflict real hull pressure")
	var redirected=false
	var attacks=[]
	for effect in phase.presentation:
		if effect.kind=="enemy_attack": attacks.append(effect)
		if effect.kind=="damage" and effect.get("source_index",-1)==1:
			redirected=effect.target_index==0 and effect.amount==3
	check(attacks.size()==2 and attacks[0].source_index==0 and attacks[0].amount==4 and attacks[1].source_index==1 and attacks[1].amount==5,"enemy feedback uses exact hull loss and original attacker indices")
	check(redirected,"redirect feedback identifies exact source and target")
	check(pair.run.battle.enemies[0].disrupt==0 and pair.run.battle.enemies[0].redirect==0,"defenses expire after the enemy phase")
	var bank=battle_game()
	bank.run.battle.enemies=[bank._make_enemy("ash_cantor")]
	bank.run.battle.enemies[0].disrupt=12
	bank.run.battle.enemies[0].redirect=3
	bank.end_turn()
	check(bank.run.battle.enemies[0].disrupt==0 and bank.run.battle.enemies[0].redirect==0,"nonattack phases cannot bank defenses for later turns")
	var prism=battle_game()
	prism.run.battle.enemies=[prism._make_enemy("cinder_mite"),prism._make_enemy("lantern_eel")]
	for foe in prism.run.battle.enemies:
		foe.hp=999
		foe.max_hp=999
	for instance in prism.run.battle.hand: instance.id="needle"
	for ignored in range(3): prism.play_card(0,[5],0)
	check(prism.run.battle.enemies[0].redirect==3,"three Prism commands cannot stack beyond three redirection")
	var heal=battle_game()
	heal.run.hull=50
	heal.run.battle.hand[0].id="needle"
	check(heal.preview_card(0,[3],0).heal==1,"Mend supplies one healing instead of free healing that exceeds enemy damage")
	heal.run.hull=99
	heal.run.battle.hand[0].id="hull_stitch"
	var repair=heal.preview_card(0,[3],0)
	var repaired=0
	for effect in repair.presentation:
		if effect.kind=="heal": repaired+=int(effect.amount)
	check(repair.heal==1 and repaired==1,"repair feedback reports capped actual healing")
	var split=battle_game()
	split.run.battle.enemies=[split._make_enemy("cinder_mite"),split._make_enemy("cinder_mite")]
	split.run.battle.enemies[0].hp=1
	split.run.battle.enemies[1].hp=10
	split.run.battle.hand[0].id="needle"
	var forecast=split.preview_card(0,[1],0)
	var applied=split.play_card(0,[1],0)
	var hits=[]
	for effect in applied.presentation:
		if effect.kind=="damage": hits.append(effect)
	check(hits.size()==2 and hits[0].target_index==0 and hits[0].amount==1 and hits[1].target_index==1 and hits[1].amount==4,"duplicate enemies retain original pre-clean target indices and capped damage")
	check(forecast.presentation==applied.presentation,"preview and commit provide identical structured command effects")
	check(split.run.battle.enemies.size()==1 and split.run.battle.enemies[0].hp==6,"split effect indices remain valid even after primary target dies")
	var vent=battle_game()
	vent.run.battle.strain=[2,0,1,3,2,1]
	vent.run.battle.hand[0].id="cold_breath"
	var cooling=vent.preview_card(0,[1],0)
	var removed=[]
	for effect in cooling.presentation:
		if effect.kind=="cooling": removed=effect.amounts
	check(removed==[1,0,1,1,1,1] and cooling.strain==[1,1,0,2,1,0],"cooling reports exact removed strain separately from new route strain")
	var ending=battle_game()
	ending.run.hull=50
	ending.run.powerups=["patient_heart","carrion_grace"]
	ending.run.battle.enemies[0].hp=1
	ending.run.battle.hand[0].id="needle"
	var finish=ending.preview_card(0,[0],0)
	ending.play_card(0,[0],0)
	check(finish.heal==4 and ending.run.hull==54,"final-kill preview includes actual kill and after-battle healing")
	var fatal=battle_game()
	fatal.run.hull=1
	fatal.run.powerups=["carrion_grace"]
	fatal.run.battle.enemies=[fatal._make_enemy("lantern_eel"),fatal._make_enemy("ash_cantor")]
	fatal.run.battle.enemies[0].intent={"kind":"attack","amount":6,"label":"Lethal strike"}
	fatal.run.battle.enemies[0].redirect=3
	fatal.run.battle.enemies[1].hp=1
	fatal.end_turn()
	check(fatal.run.mode=="defeat" and fatal.run.hull==0,"passive kill healing cannot resurrect a lethal hit without Emergency")

func expansion_save_boundary_checks() -> void:
	var test=battle_game()
	var unchanged=JSON.stringify(test.run)
	check(not test.new_run(2026,"missing_ship").ok and JSON.stringify(test.run)==unchanged,"invalid character selection cannot replace an active expedition")
	for area in range(3):
		test.run.region=area
		var definition=test.enemy(test.catalog.regions[area].boss)
		var native=test._make_enemy(definition.id)
		var scale=[1.0,1.4/1.3,1.8/1.6][area]
		check(native.max_hp==int(round(int(definition.hp)*scale)),"legacy geography normalizes authored hull to the new area curve")
		var expected=int(definition.pattern[0].amount)
		if definition.pattern[0].kind in ["rebuild","mark"]: expected=int(round(expected*scale))
		check(int(native.intent.amount)==expected,"legacy boss utility intent uses the new area curve")
	test.run.region=0
	var altered=test.run.duplicate(true)
	altered.battle.hand[0].id="margin_knife"
	check(not test._valid_run(altered),"saved battle piles cannot substitute a cross-character card for a deck UID")
	altered=test.run.duplicate(true)
	altered.battle.hand[0].id="needle" if altered.battle.hand[0].id!="needle" else "hull_stitch"
	check(not test._valid_run(altered),"saved battle piles must match the exact deck card ID")
	altered=test.run.duplicate(true)
	altered.battle.hand[0].level=1
	check(not test._valid_run(altered),"saved battle piles must match deck upgrade level")
	altered=test.run.duplicate(true)
	altered.mode="reward"
	altered.reward={"choices":[{"kind":"card","id":"margin_knife"}],"boss":false}
	check(not test._valid_run(altered),"saved rewards cannot cross character card pools")
	altered=test.run.duplicate(true)
	altered.mode="shop"
	altered.shop={"items":[{"kind":"card","id":"choral_bolt","cost":35,"sold":false}]}
	check(not test._valid_run(altered),"saved shop cards cannot cross character card pools")
	test.abandon()
	var profile=test.profile.duplicate(true)
	profile.history[0].character="missing_ship"
	check(not test._valid_profile(profile),"corrupt history cannot name an unknown character")
	profile=test.profile.duplicate(true)
	profile.history[0].route_regions=[0,0,1]
	check(not test._valid_profile(profile),"corrupt history cannot contain a repeated itinerary area")
	profile=test.profile.duplicate(true)
	profile.history[0].erase("character")
	profile.history[0].erase("route_regions")
	check(test._valid_profile(profile),"legacy history without new optional fields remains valid")

func resource_fixture(ship: String, card_id: String):
	var test=battle_game(ship)
	for instance in test.run.deck: instance.id=card_id
	test._start_battle({"type":"battle","enemy_ids":["cinder_mite"]})
	test.run.battle.enemies[0].hp=999
	test.run.battle.enemies[0].max_hp=999
	test.run.hull=50
	return test

func character_resource_checks() -> void:
	var rewrite=resource_fixture("palimpsest","overwrite")
	rewrite.run.battle.trace=4
	rewrite.run.battle.last_payload={"damage":12,"heal":6,"disrupt":2}
	var copied=rewrite.preview_card(0,[1],0)
	check(copied.ok and copied.damage==22 and copied.heal==3 and copied.disrupt==1,"Rewrite card spends Trace and copies half the previous base payload")
	rewrite.play_card(0,[1],0)
	check(rewrite.run.battle.trace==0 and rewrite.run.battle.last_payload.damage==6,"Rewrite stores its own base payload without recursive amplification")
	rewrite.run.battle.trace=4
	check(rewrite.preview_card(0,[1],0).damage==19,"a subsequent Rewrite copies base damage, not its predecessor's amplified damage")
	var memory=resource_fixture("palimpsest","revision_spike")
	memory.run.battle.trace=1
	check(memory.preview_card(0,[3],0).heal==2,"Palimend converts one Trace into two healing")
	memory.play_card(0,[3],0)
	check(memory.run.battle.trace==0,"Palimend spends the Trace it uses")
	check(memory.preview_card(0,[4],0).disrupt==1,"uncharged Redact supplies one disruption")
	memory.run.battle.trace=1
	memory.play_card(0,[4],0)
	check(memory.run.battle.enemies[0].disrupt==3 and memory.run.battle.trace==0,"charged Redact spends Trace for stronger disruption")
	var splice=resource_fixture("palimpsest","revision_spike")
	splice.run.battle.enemies.append(splice._make_enemy("cinder_mite"))
	splice.run.battle.enemies[1].hp=999
	splice.run.battle.enemies[1].max_hp=999
	check(splice.preview_card(0,[1],0).damage==14,"uncharged Splice strengthens one target")
	splice.run.battle.trace=2
	check(splice.preview_card(0,[1],0).damage==18,"charged Splice distributes damage among targets")
	var concert=resource_fixture("hollow_choir","bright_canon")
	concert.run.battle.resonance=2
	concert.run.battle.last_command_kind="repair"
	var singing=concert.preview_card(0,[1],0)
	check(singing.damage==19 and singing.heal==3,"Concert card spends the coordinated phrase for damage and healing")
	concert.play_card(0,[1],0)
	check(concert.run.battle.resonance==0 and concert.run.battle.last_command_kind=="attack","Concert consumes Resonance and records the new command kind")
	var repeat=resource_fixture("hollow_choir","choral_bolt")
	repeat.run.battle.resonance=3
	repeat.run.battle.last_command_kind="attack"
	repeat.play_card(0,[1],0)
	check(repeat.run.battle.resonance==0,"repeating a Choir command kind breaks coordination")
	var cadence=resource_fixture("hollow_choir","warm_refrain")
	cadence.run.battle.resonance=1
	cadence.run.battle.last_command_kind="attack"
	cadence.play_card(0,[5],0)
	check(cadence.run.battle.ward==3 and cadence.run.battle.resonance==1,"Cadence trades two Resonance for three ward")
	var rest=resource_fixture("hollow_choir","silent_measure")
	rest.run.battle.last_command_kind="attack"
	rest.play_card(0,[3],0)
	check(rest.run.hull==51 and rest.run.battle.resonance==3,"Rest coordinates a nonattack and adds one healing")
	var corrupted=rest.run.duplicate(true)
	corrupted.battle.resonance=4
	check(not rest._valid_run(corrupted),"saved Resonance cannot exceed its cap")
	corrupted=memory.run.duplicate(true)
	corrupted.battle.trace=7
	check(not memory._valid_run(corrupted),"saved Trace cannot exceed its cap")

func partial_expansion_save_checks() -> void:
	var test=battle_game("palimpsest")
	test.run.battle.trace=4
	test.save()
	test.save()
	var expected=test.run.duplicate(true)
	for missing in ["character","route_regions","trace"]:
		var broken=expected.duplicate(true)
		if missing=="trace": broken.battle.erase(missing)
		else: broken.erase(missing)
		check(not test._valid_run(broken),"partial new expansion metadata is rejected: "+missing)
		var primary=FileAccess.open(test.store.directory.path_join("save.json"),FileAccess.WRITE)
		primary.store_string(JSON.stringify({"version":1,"profile":test.profile,"run":broken}))
		primary.close()
		var restored=Game.new(test.store.directory)
		check(restored.run==expected and restored.save_error.contains("backup"),"partial new save recovers exact character, itinerary and Trace from backup: "+missing)

func _initialize() -> void:
	partial_expansion_save_checks()
	character_resource_checks()
	expansion_save_boundary_checks()
	balance_presentation_checks()
	command_points_checks()
	var game=battle_game()
	check(game.run.mode=="combat","enter first encounter")
	check(game.run.battle.hand.size()==5,"draw five opening cards")
	check(game.run.deck.size()==10,"ten-card starting deck")
	check(game.catalog.cards.size()==72 and game.catalog.powerups.size()==18 and game.catalog.characters.size()==3 and game.catalog.regions.size()==6,"expanded content counts")
	var original=JSON.stringify(game.run)
	var preview=game.preview_card(0,[0,1,2],0)
	check(preview.ok,"valid route preview")
	check(JSON.stringify(game.run)==original,"preview is pure including RNG and deck")
	var first_draw=int(game.card(game.run.battle.hand[0].id).get("draw",0))
	game.play_card(0,[0,1,2],0)
	check(game.run.battle.strain==preview.strain,"preview strain equals committed strain")
	check(game.run.battle.hand.size()==4+first_draw,"play consumes one card before any card-draw effect")
	var before=JSON.stringify(game.run)
	check(not game.play_card(0,[0,0],0).ok,"repeated organ rejected")
	check(not game.play_card(0,[],0).ok,"empty route rejected")
	check(not game.play_card(0,[0,2],0).ok,"disconnected route rejected")
	check(not game.play_card(0,[0,1,2,3],0).ok,"overlong route rejected")
	check(not game.play_card(99,[0],0).ok,"invalid hand rejected")
	check(not game.play_card(0,[0],99).ok,"invalid target rejected")
	check(JSON.stringify(game.run)==before,"invalid actions cannot mutate state")
	game.run.battle.strain[0]=game.run.battle.capacity
	check(not game.preview_card(0,[0],0).ok,"saturated organ rejected")
	game.run.battle.strain=[3,3,3,3,3,3]
	check(game.end_turn().ok,"end turn remains available with every organ blocked")
	check(game.run.battle.hand.size()==5,"next turn draws five")
	check(game.run.battle.strain[0]<3,"end turn cools strain")
	# Every card uses the same pure resolver, including draw, link and vent.
	for definition in game.catalog.cards:
		var test=battle_game(definition.get("character","cartographer"))
		test.run.deck[0].id=definition.id
		test.run.battle.hand=[test.run.deck[0].duplicate(true)]
		test.run.battle.draw=test.run.deck.slice(1).duplicate(true)
		test.run.battle.discard=[]
		test.run.battle.enemies[0].hp=999
		test.run.battle.enemies[0].max_hp=999
		test.run.hull=50
		var forecast=test.preview_card(0,[0,1,2],0)
		check(forecast.ok,"card preview "+definition.id)
		var hp=test.run.battle.enemies[0].hp
		var hull=test.run.hull
		test.play_card(0,[0,1,2],0)
		check(hp-test.run.battle.enemies[0].hp==forecast.damage,"damage preview "+definition.id)
		check(test.run.hull-hull==forecast.heal,"repair preview "+definition.id)
		check(test.run.battle.strain==forecast.strain,"strain preview "+definition.id)
	# Order matters: amplify then echo differs from echo then amplify.
	var ordered=battle_game()
	for definition in ordered.catalog.cards:
		if int(definition.get("damage",0))>0:
			ordered.run.battle.hand[0].id=definition.id
			break
	ordered.run.battle.enemies[0].hp=999
	ordered.run.battle.enemies[0].max_hp=999
	ordered.run.battle.edges.append([0,2])
	check(ordered.preview_card(0,[0,2],0).damage>ordered.preview_card(0,[2,0],0).damage,"organ order changes payload")
	ordered.run.battle.severed=[[0,1]]
	check(not ordered.preview_card(0,[0,1],0).ok,"severed edge rejected")
	# Deck starvation is legal and cannot soft-lock End Turn.
	var empty=battle_game()
	empty.run.battle.hand=[]
	empty.run.battle.draw=[]
	empty.run.battle.discard=[]
	check(empty.end_turn().ok,"empty battle piles can advance")
	check(empty.run.battle.hand.is_empty(),"empty draw remains empty")
	var capped=battle_game()
	capped._draw(capped.run,30)
	check(capped.run.battle.hand.size()==10,"hand cap ten")
	# Deterministic maps have legal forward edges and reachable bosses.
	for seed_value in range(1,31):
		var a=make_game(seed_value)
		var b=make_game(seed_value)
		check(a.run.map==b.run.map,"deterministic map seed%d"%seed_value)
		for tier in range(3):
			a.run.region=tier
			var map=a._generate_map(a.run)
			check(map.size()==12 and map[11].size()==1 and map[11][0].type=="boss","twelve layers and boss")
			for depth in range(11):
				var next_ids=[]
				for node in map[depth+1]: next_ids.append(node.id)
				for node in map[depth]:
					check(not node.edges.is_empty(),"every node has onward route")
					for edge in node.edges: check(edge in next_ids,"edges advance exactly one layer")
					for id in node.enemy_ids: check(int(a.enemy(id).region)==int(a.run.route_regions[tier]),"enemy belongs to itinerary area")
	# Save/load exact combat, deck order and RNG; no reward duplication.
	var saved=battle_game()
	saved.play_card(0,[3],0)
	check(saved.save(),"save succeeds")
	var state=saved.run.duplicate(true)
	var restored=Game.new(saved.store.directory)
	check(restored.run==saved._restore_integers(state),"combat roundtrip preserves complete state")
	check(restored._valid_run(restored.run),"saved combat validates")
	saved.run.battle.enemies=[]
	saved._check_battle_end()
	saved.save()
	var reward_state=saved.run.duplicate(true)
	var reward_game=Game.new(saved.store.directory)
	check(reward_game.run==saved._restore_integers(reward_state),"reward roundtrip exact")
	var size_before=reward_game.run.deck.size()
	check(reward_game.choose_reward(0).ok,"reward chosen")
	check(reward_game.run.deck.size()==size_before+1,"card granted once")
	check(not reward_game.choose_reward(0).ok,"repeated reward request rejected")
	var resumed=Game.new(saved.store.directory)
	check(resumed.run.deck.size()==size_before+1 and resumed.run.mode=="map","resume after reward keeps grant")
	var unlocks_before=resumed.profile.unlocks
	resumed.abandon()
	check(resumed.profile.unlocks==unlocks_before+1,"concluded run unlocks variety")
	var history_count=resumed.profile.history.size()
	resumed.abandon()
	check(resumed.profile.history.size()==history_count,"conclusion idempotent")
	resumed.new_run(999)
	check(resumed.run.hull==100 and resumed.run.max_hull==100 and resumed.run.deck.size()==10,"unlocks never inflate starting stats")
	check(resumed.run.powerups.is_empty(),"unlocks give no free powerups")
	# Corrupt primary falls back to valid previous generation.
	resumed.save()
	var file=FileAccess.open(resumed.store.directory.path_join("save.json"),FileAccess.WRITE)
	file.store_string("{corrupted")
	file.close()
	var recovered=Game.new(resumed.store.directory)
	check(not recovered.run.is_empty() and recovered.save_error.contains("backup"),"backup recovery")
	# Invalid structured save rejected instead of throwing on nested fields.
	var broken=state.duplicate(true)
	broken.battle.hand=[{"id":"bogus"}]
	check(not saved._valid_run(broken),"invalid card instance rejected")
	broken=state.duplicate(true)
	broken.battle.strain=["bad",0,0,0,0,0]
	check(not saved._valid_run(broken),"invalid strain rejected")
	# Review regressions: accepted save schema and backup promotion.
	var incomplete=state.duplicate(true)
	incomplete.battle.erase("kind")
	check(not saved._valid_run(incomplete),"missing battle kind is rejected before resume")
	incomplete=state.duplicate(true)
	incomplete.battle.erase("first_play")
	check(not saved._valid_run(incomplete),"missing first-play flag rejected")
	var recovery=battle_game()
	recovery.save()
	var damaged=recovery.run.duplicate(true)
	damaged.erase("hull")
	var primary=FileAccess.open(recovery.store.directory.path_join("save.json"),FileAccess.WRITE)
	primary.store_string(JSON.stringify({"version":1,"profile":recovery.profile,"run":damaged}))
	primary.close()
	var fallback=Game.new(recovery.store.directory)
	check(fallback.run_exists() and fallback.save_error.contains("backup"),"semantic corruption recovers backup")
	fallback.set_settings({"volume":0.2})
	var backup=fallback.store._read(fallback.store.directory.path_join("save.backup.json"))
	check(backup.run.has("hull"),"settings save never promotes rejected primary over backup")
	primary=FileAccess.open(recovery.store.directory.path_join("save.json"),FileAccess.WRITE)
	primary.store_string("broken")
	primary.close()
	var fallback_again=Game.new(recovery.store.directory)
	check(fallback_again.run_exists(),"second corruption still has valid recovery generation")
	# Text displayed to the player agrees with protected damage and emergency recovery.
	var parliament=battle_game()
	parliament.run.battle.enemies=[parliament._make_enemy("salvage_parliament"),parliament._make_enemy("_hatchling"),parliament._make_enemy("_hatchling")]
	parliament.run.battle.hand[0].id="needle"
	var protected=parliament.preview_card(0,[0],0)
	check(protected.summary.contains("%d damage"%int(protected.damage)),"visible preview includes Parliament protection")
	var mark=battle_game()
	for definition in mark.catalog.powerups:
		if definition.effect=="emergency": mark.run.powerups.append(definition.id)
	mark.run.hull=2
	mark.run.battle.mark=8
	mark.run.battle.last_route=[0]
	mark.run.battle.hand[0].id="needle"
	var emergency=mark.preview_card(0,[0],0)
	check(emergency.summary.contains("hull restored"),"visible preview explains emergency revival")
	# Ending turns without playing loses a real battle; restart resets only the run.
	var defeated=battle_game()
	var turns=0
	while defeated.run.mode=="combat" and turns<100:
		defeated.end_turn()
		turns+=1
	check(defeated.run.mode=="defeat","real enemy phases cause defeat")
	check(defeated.new_run(27).ok and defeated.run.mode=="map","restart after defeat")
	print("TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
