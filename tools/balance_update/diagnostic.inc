# This model never has identities for future draws or a random stream. Only
# seed-independent command effects on visible state are simulated (no end-turn).
class VisibleGame extends Game:
	func _draw(_state: Dictionary, _amount: int, _presentation: Array = []) -> void:
		pass

var visible
var planner := OS.get_environment("BALANCE_DIAGNOSTIC")

func visible_state() -> Dictionary:
	var r=game.run
	var b={}
	for key in r.battle:
		if key!="draw": b[key]=r.battle[key]
	b.draw=[]
	return {"mode":"combat","character":r.character,"region":r.region,"hull":r.hull,"max_hull":r.max_hull,"powerups":r.powerups,"tutorial_step":r.tutorial_step,"log":[],"content_pool_revision":r.content_pool_revision,"battle":b}

func alternatives(s: Dictionary, narrow: bool) -> Array:
	var candidates=[]
	var buckets={}
	visible.run=s
	var battle=s.battle
	var danger=visible._incoming_damage(s)-int(battle.ward)
	var legal=[]
	for route in route_options:
		if visible._validate_route(s,route).is_empty(): legal.append(route)
	var duplicate_cards={}
	for card_index in range(battle.hand.size()):
		var instance=battle.hand[card_index]
		var definition=visible.effective_card(instance)
		if int(definition.cost)>int(battle.command_points): continue
		# Same definition and evolution have identical immediate scores on these
		# ships (no selection commands are committed by the official policy).
		var identity=[instance.id,instance.level,instance.get("evolution","")]
		if duplicate_cards.has(identity): continue
		duplicate_cards[identity]=true
		for route in legal:
			for target in range(battle.enemies.size()):
				var forecast=visible._simulate_card(s.duplicate(true),card_index,route,target,true)
				if not forecast.ok: continue
				var foe=battle.enemies[target]
				var primary=0
				for effect in forecast.presentation:
					if effect.kind=="damage" and effect.target_index==target and not effect.get("split",false): primary+=int(effect.amount)
				var score=point_score(s,forecast,definition,foe,battle,danger,primary)
				var state=forecast.next
				var finish=state.battle.enemies.is_empty() and state.hull>0
				if planner=="visible2" and finish: score+=500.0
				var saved=forecast.trace if s.character=="palimpsest" else forecast.resonance
				var action={"hand":card_index,"target":target,"route":route,"score":score,"bank":saved,"cost":definition.cost,"next":state if narrow else {}}
				if not narrow:
					if candidates.is_empty() or score>candidates[0].score: candidates=[action]
				else:
					# Retain only a small bounded first-action beam by distinct
					# card and resource level. Identical-score ties keep enumeration order.
					var key=str(card_index)+"/"+str(saved)
					if not buckets.has(key) or score>buckets[key].score: buckets[key]=action
	return candidates if not narrow else buckets.values()

func diagnostic_plan() -> Dictionary:
	if visible==null: visible=VisibleGame.new(game.store.directory.path_join("visible-model"))
	var s=visible_state()
	if s.battle.command_points<=0: return {"end_turn":true}
	if planner=="splashfix" or s.battle.command_points==1:
		var choices=alternatives(s,false)
		return choices[0] if not choices.is_empty() and choices[0].score>=0.1 else {"end_turn":true}
	var pool=alternatives(s,true)
	if pool.is_empty(): return {"end_turn":true}
	var now=pool[0]
	var setup=pool[0]
	for a in pool:
		if a.score>now.score: now=a
		if a.bank>setup.bank or (a.bank==setup.bank and a.score>setup.score): setup=a
	var diff={}
	for a in pool:
		if a.hand!=now.hand and (diff.is_empty() or a.score>diff.score): diff=a
	var best={}
	var best_score=0.1
	var seen={}
	for a in [now,setup,diff]:
		if a.is_empty(): continue
		var token=JSON.stringify([a.hand,a.route,a.target])
		if seen.has(token): continue
		seen[token]=true
		var score=a.score
		var next=a.next
		if next.hull>0 and not next.battle.enemies.is_empty() and next.battle.command_points>0:
			var follow=alternatives(next,false)
			if not follow.is_empty(): score+=0.8*maxf(0.0,follow[0].score)
		if score>best_score:
			best_score=score
			best=a
	return best if not best.is_empty() else {"end_turn":true}
