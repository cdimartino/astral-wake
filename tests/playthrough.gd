extends SceneTree
const Game=preload("res://scripts/game.gd")
var game
var cards_played=0
var cards_this_turn=0
var max_cards_per_turn=0
var actions=0
var started=0
var route_options=[]
var checkpoints=[]
var policy="balanced"
var no_bonuses=false
var allow_defeat=false

func _initialize() -> void:
	started=Time.get_ticks_msec()
	var seed_value=424242
	var hp_scale=1.0
	var character_id="cartographer"
	var unlocks=0
	var save_directory=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value=int(arg.trim_prefix("--seed="))
		if arg.begins_with("--code="): seed_value=arg.trim_prefix("--code=")
		if arg.begins_with("--character="): character_id=arg.trim_prefix("--character=")
		if arg.begins_with("--hp-scale="): hp_scale=float(arg.trim_prefix("--hp-scale="))
		if arg.begins_with("--policy="): policy=arg.trim_prefix("--policy=")
		if arg=="--no-bonuses": no_bonuses=true
		if arg=="--allow-defeat": allow_defeat=true
		if arg.begins_with("--unlocks="): unlocks=int(arg.trim_prefix("--unlocks="))
		if arg.begins_with("--save-dir="): save_directory=arg.trim_prefix("--save-dir=")
	if unlocks<0 or unlocks>3 or not policy in ["balanced","aggressive","tactical"]:
		printerr("Invalid unlock tier or policy")
		quit(1)
		return
	if save_directory.is_empty(): save_directory=OS.get_environment("TMPDIR").path_join("astral-playthrough-%s-%d"%[seed_value,Time.get_ticks_usec()])
	game=Game.new(save_directory)
	game.profile.unlocks=unlocks
	for definition in game.catalog.enemies: definition.hp=int(round(definition.hp*hp_scale))
	var beginning=game.new_run(seed_value,character_id)
	if not beginning.ok:
		printerr(beginning.error)
		quit(1)
		return
	prepare_routes()
	while not game.run.mode in ["victory","defeat"] and actions<4000:
		var outcome={"ok":true}
		match game.run.mode:
			"map": outcome=choose_path()
			"combat": outcome=combat_action()
			"reward": outcome=choose_reward()
			"transition":
				checkpoints.append({"region":game.run.region,"turns":game.run.turns,"hull":game.run.hull,"cards":game.run.deck.size()})
				outcome=game.continue_region()
			"recovery": outcome=game.recover("repair" if no_bonuses or game.run.hull<72 else "upgrade")
			"modify": outcome=modify()
			"shop": outcome=shop()
			"event": outcome=event()
		if not outcome.ok:
			printerr("ACTION FAILED ",game.run.mode," ",outcome)
			quit(1)
			return
		if not game._valid_run(game.run):
			printerr("INVALID STATE AFTER ACTION ",actions," mode=",game.run.mode)
			quit(1)
			return
		actions+=1
		if actions%100==0: print("PROGRESS actions=%d region=%d layer=%d hull=%d mode=%s"%[actions,game.run.region+1,game.run.layer+1,game.run.hull,game.run.mode])
	var result={"seed":seed_value,"character":game.run.character,"route_regions":game.run.route_regions,"mode":game.run.mode,"region":game.run.region+1,"layer":game.run.layer+1,"turns":game.run.turns,"battles":game.run.battles,"cards_played":cards_played,"max_cards_per_turn":max_cards_per_turn,"actions":actions,"hull":game.run.hull,"deck":game.run.deck,"powerups":game.run.powerups,"checkpoints":checkpoints,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"save_directory":game.store.directory}
	result.policy=policy
	result.no_bonuses=no_bonuses
	result.profile_unlocks=unlocks
	result.pool_tier=game.run.get("pool_tier",unlocks)
	result.rng_version=game.run.get("rng_version",0)
	result.seeded=game.run.get("seeded",false)
	print("PLAYTHROUGH "+JSON.stringify(result))
	quit(0 if game.run.mode=="victory" or (allow_defeat and game.run.mode=="defeat") else 2)

func prepare_routes() -> void:
	route_options.clear()
	var edges=game.character().edges
	for i in range(6): route_options.append([i])
	for a in range(6):
		for b in range(6):
			if a==b or not game._edge_exists(edges,a,b): continue
			route_options.append([a,b])
			for c in range(6):
				if c!=a and c!=b and game._edge_exists(edges,b,c): route_options.append([a,b,c])

func choose_path() -> Dictionary:
	return game.choose_node(plan_path().id)

func plan_path() -> Dictionary:
	var best={}
	var best_score=-100000.0
	for layer in game.run.map:
		for node in layer:
			if not game.reachable(node): continue
			var score=0.0
			match node.type:
				"recovery": score=30.0 if game.run.hull<70 else 8.0
				"event": score=15.0
				"shop": score=20.0 if game.run.salvage>=75 else 2.0
				"elite": score=3.0 if game.run.hull>85 else -20.0
				"battle":
					for id in node.enemy_ids: score-=float(game.enemy(id).hp)/100.0
			if score>best_score:
				best=node
				best_score=score
	return best

func plan_combat_action() -> Dictionary:
	var best={}
	var best_score=-100000.0
	var battle=game.run.battle
	if int(battle.command_points)<=0: return {"end_turn":true}
	for card_index in range(battle.hand.size()):
		var definition=game.effective_card(battle.hand[card_index])
		if int(definition.cost)>int(battle.command_points): continue
		for route in route_options:
			if not game._validate_route(game.run,route).is_empty(): continue
			for target in range(battle.enemies.size()):
				var forecast=game.preview_card(card_index,route,target)
				if not forecast.ok: continue
				var foe=battle.enemies[target]
				var score=float(forecast.damage)
				score+=maxi(0,int(forecast.heal))*(2.1 if game.run.hull<60 else 1.1)
				if forecast.damage>=foe.hp: score+=12
				if foe.id=="_egg": score+=forecast.damage*0.3
				score+=maxi(0,int(forecast.get("attack_reduction",0)))*1.6
				for effect in forecast.get("presentation",[]):
					if effect.kind=="trace": score+=int(effect.amount)*0.6
					if effect.kind=="resonance": score+=int(effect.amount)*0.8
					if effect.kind=="ward": score+=int(effect.amount)*1.1
				score+=int(definition.get("draw",0))*2
				var net=0
				for i in range(6):
					net+=int(forecast.strain[i])-int(battle.strain[i])
					if int(forecast.strain[i])>=int(battle.capacity): score-=1.2
				score-=net*1.2
				if policy=="tactical":
					var incoming=maxi(0,game._incoming_damage(game.run)-int(battle.ward))
					var urgency=clampf(float(incoming+30)/maxf(1,float(game.run.hull)),0.5,4.0)
					score+=(maxi(0,int(forecast.heal))+maxi(0,int(forecast.get("attack_reduction",0))))*urgency
					score/=float(definition.cost)
				if policy=="aggressive": score=float(forecast.damage)-net*1.2
				if score>best_score:
					best_score=score
					best={"hand":card_index,"route":route,"target":target}
	if best.is_empty() or best_score<0.1: return {"end_turn":true}
	return best

func combat_action() -> Dictionary:
	if game.run.battle.first_play: cards_this_turn=0
	var best=plan_combat_action()
	if best.get("end_turn",false): return game.end_turn()
	var result=game.play_card(best.hand,best.route,best.target)
	if result.ok:
		cards_played+=1
		cards_this_turn+=1
		max_cards_per_turn=maxi(max_cards_per_turn,cards_this_turn)
		assert(cards_this_turn<=3,"Command budget cannot permit more than three cards per turn")
	return result

func choose_reward() -> Dictionary:
	if no_bonuses: return game.choose_reward(-1)
	var best=-1
	var best_score=8.0
	for i in range(game.run.reward.choices.size()):
		var choice=game.run.reward.choices[i]
		var score=0.0
		if choice.kind=="powerup": score=25.0
		else:
			var definition=game.effective_card({"id":choice.id})
			score=float(definition.get("damage",0))+float(definition.get("heal",0))*0.8+float(definition.get("vent",0))*5+float(definition.get("draw",0))*3+float(definition.get("disrupt",0))
			score-=game.owned_card_count(choice.id)*5
			if game.run.deck.size()>18: score-=10
		if score>best_score:
			best_score=score
			best=i
	return game.choose_reward(best)

func modify() -> Dictionary:
	if no_bonuses: return game.cancel_modify()
	var best=-1
	var score=-10000.0
	for i in range(game.run.deck.size()):
		var instance=game.run.deck[i]
		# Freeze the existing policy's intrinsic (unevolved) removal/upgrade ranking.
		# Actual plays and affordability use the owned instance above.
		var definition=game.effective_card({"id":instance.id})
		if game.run.modify_kind=="upgrade" and int(instance.level)>0: continue
		var current=float(definition.get("damage",0))+float(definition.get("vent",0))*5+float(definition.get("heal",0))
		if game.run.modify_kind=="remove": current=-current
		if current>score:
			score=current
			best=i
	if best<0: return game.cancel_modify()
	return game.modify_card(best)

func shop() -> Dictionary:
	if no_bonuses: return game.leave_location()
	for i in range(game.run.shop.items.size()):
		var item=game.run.shop.items[i]
		if not item.sold and item.cost<=game.run.salvage and item.kind=="powerup": return game.buy(i)
	for i in range(game.run.shop.items.size()):
		var item=game.run.shop.items[i]
		if not item.sold and item.cost<=game.run.salvage and item.kind=="upgrade" and game._can_upgrade(): return game.buy(i)
	return game.leave_location()

func event() -> Dictionary:
	if no_bonuses: return game.leave_location()
	var definition={}
	for item in game.catalog.events:
		if item.id==game.run.event_id: definition=item
	var best=-1
	var score=-10000.0
	for i in range(definition.choices.size()):
		var choice=definition.choices[i]
		var current=0.0
		match choice.effect:
			"powerup": current=40
			"heal": current=mini(int(choice.value),int(game.run.max_hull)-int(game.run.hull))*1.5
			"repair_trade": current=mini(35,int(game.run.max_hull)-int(game.run.hull))-8 if game.run.salvage>=25 else -100
			"capacity_trade": current=20 if game.run.max_hull>60 else -100
			"salvage": current=float(choice.value)/2
			"hurt_salvage": current=float(choice.value)/2-15 if game.run.hull>20 else -100
			"upgrade": current=12 if game._can_upgrade() else -100
			"remove": current=5 if game.run.deck.size()>5 else -100
			"card": current=5
		if current>score:
			score=current
			best=i
	if best<0: return game.leave_location()
	return game.event_choice(best)
