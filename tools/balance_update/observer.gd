extends "res://tests/playthrough.gd"
# The inherited frozen driver owns all combat, reward, map and upgrade decisions.
# This observer measures only resolved commands and visible pre-action inputs.
var fight := {}
var path_taken := []
var picked := {}
var hit := {}
var running_digest := ""
var which := OS.get_environment("BALANCE_ARM")
var switch_at := OS.get_environment("BALANCE_SWITCH_AT")
var prototype
var scorer := "official-v1"

func choose_path() -> Dictionary:
	var out = super.choose_path()
	if out.ok:
		path_taken.append([game.run.region,game.run.current_node])
		if game.run.mode == "combat": open_fight()
	return out

func prepare_routes() -> void:
	if switch_at != "":
		# Local effect test: replay original rules until the control loss, then
		# change only the rules at entry (no save file edits). Quit after fight.
		prototype = game
		var base = GDScript.new()
		base.source_code = FileAccess.get_file_as_string(OS.get_environment("BALANCE_CONTROL_RULES"))
		assert(base.reload()==OK)
		game = base.new(prototype.store.directory.path_join("base"))
		game.run = prototype.run
		game.profile = prototype.profile
	super.prepare_routes()

func open_fight() -> void:
	var r = game.run
	var b = r.battle
	var enemies := []
	for foe in b.enemies: enemies.append([foe.id,foe.hp])
	fight = {"region":int(r.region)+1,"area":game.region().id,"node":r.current_node,"kind":b.kind,"roster":enemies,"entry_hull":r.hull,"min_hull":r.hull,"turns":1,"end_turns":0,"counts":{},"procs":[],"path":path_taken.duplicate(true)}
	fight.entry_signature = JSON.stringify([path_taken,r.hull,r.max_hull,r.salvage,r.deck,r.powerups,b.hand,enemies,b.strain,b.capacity,b.ward]).sha256_text()
	fight.prior_actions = running_digest
	if switch_at == "%d/%s"%[fight.region,fight.node]:
		prototype.run = r
		prototype.profile = game.profile
		game = prototype
		fight.switched = true
	for card in b.hand:
		if card.id=="crescendo": count("crescendo_draws")

func count(key: String, n: int = 1) -> void:
	fight.counts[key] = int(fight.counts.get(key,0))+n

func plan_combat_action() -> Dictionary:
	var best = super.plan_combat_action()
	observe_decision(best)
	return best

func observe_decision(best: Dictionary) -> void:
	picked = {}
	hit = {}
	var r = game.run
	var b = r.battle
	fight.turns = b.turn
	if best.get("end_turn",false):
		count("end_choices")
		fight.end_turns += 1
		running_digest = (running_digest+"end").sha256_text()
		return
	var instance = b.hand[best.hand]
	var d = game.effective_card(instance)
	var foe = b.enemies[best.target]
	running_digest = (running_digest+JSON.stringify([instance.uid,instance.id,best.route,best.target])).sha256_text()
	picked = {"id":instance.id,"target":best.target,"target_hp":foe.hp,"previous":b.last_command_kind,"kind":d.kind,"trace":b.trace,"res":b.resonance,"card_trace_gain":d.get("trace",0),"card_res_gain":d.get("resonance",0),"concert":d.get("concert",false),"rewrite":d.get("rewrite",false),"route_len":best.route.size()}
	if r.character not in ["palimpsest","hollow_choir"]: return
	if r.character=="hollow_choir" and instance.id!="crescendo": return
	if r.character=="palimpsest" and not best.route.any(func(o):return game.organ(o).id=="recall"): return
	# Post-choice marginal damage audit; compare the same hit twice on visible
	# foes only. _damage_enemy performs armor, weakness and HP clipping. Apply
	# hits in resolution order so Parliament protection also tracks living foes.
	hit = {"enemies":b.enemies.duplicate(true),"fork":game._effect(r,"fork")}

func actual_hits(main: int, splash: int, split: bool) -> Array:
	var t = picked.target
	var s = {"battle":{"enemies":hit.enemies.duplicate(true)}}
	var primary = game._damage_enemy(s,t,main,picked.route_len)
	var total = primary
	if split:
		for i in range(s.battle.enemies.size()):
			if i!=t and s.battle.enemies[i].hp>0:
				total += game._damage_enemy(s,i,splash,picked.route_len,true)
	return [primary,total]

func combat_action() -> Dictionary:
	var h = int(game.run.hull)
	var out = super.combat_action()
	if not out.ok: return out
	# Replay actual hull cues in order, including pre-repair/emergency lows.
	var low = h
	for cue in out.get("presentation",[]):
		match cue.kind:
			"draw_card":
				if cue.card.id=="crescendo": count("crescendo_draws")
			"heal":
				low+=int(cue.amount)
				count("healing_"+str(cue.get("source","other")),int(cue.amount))
			"ward": count("ward_granted",cue.amount)
			"interrupted": count("interrupts")
			"enemy_attack","hull_damage":
				low-=int(cue.amount)
				fight.min_hull=mini(fight.min_hull,low)
				count("actual_hull_damage",cue.amount)
				count("ward_absorbed",cue.get("absorbed",0))
				count("attack_disrupted",cue.get("disrupted",0))
				count("attack_redirected",cue.get("redirected",0))
	fight.min_hull=mini(fight.min_hull,game.run.hull)
	if not picked.is_empty(): after_play(out)
	if game.run.mode!="combat":
		fight.won=game.run.mode!="defeat"
		fight.exit_hull=game.run.hull
		fight.actions_digest=running_digest
		print("FIGHT "+JSON.stringify(fight))
		if fight.get("switched",false):
			print("RESCUE "+JSON.stringify({"won":fight.won,"region":fight.region,"node":fight.node}))
			# Stop outer policy loop immediately, without another world action.
			actions = 4000
	return out

func after_play(out: Dictionary) -> void:
	count("plays")
	var record=false
	var is_a=false
	var spent=0
	var pre = picked.res
	if picked.previous!="":
		pre=mini(3,pre+1) if picked.previous!=picked.kind else 0
	pre=mini(3,pre+int(picked.card_res_gain))
	if picked.concert:
		count("concert_plays")
		count("concert_spent",pre)
		if pre==3: count("concert_full")
	if picked.rewrite:
		count("rewrite_card_spent",mini(6,picked.trace+int(picked.card_trace_gain)))
	if picked.id=="crescendo":
		count("crescendo_plays")
		count("crescendo_spent",pre)
		record=pre==3
		spent=pre
	for step in out.route_steps:
		var organ_id = game.organ(step.organ).id
		for key in ["trace","resonance"]:
			var paid = maxi(0,int(step[key+"_before"])-int(step[key+"_after"]))
			if paid: count(organ_id+"_"+key+"_spent",paid)
		if organ_id=="recall" and step.trace_before==6 and step.trace_after==0:
			record=true
			is_a=true
			spent=6
	if not record: return
	count("threshold")
	var after = out.route_steps.back().payload_after
	var patched = (which=="trial-a" if is_a else which=="trial-b") and (switch_at=="" or fight.get("switched",false))
	var control_raw = int(after[0])-(4 if not is_a and patched else 0)
	var base = actual_hits(control_raw,int(floor(control_raw/2.0))+hit.fork,after[4])
	var raised = actual_hits(control_raw+(3 if is_a else 4),int(floor((control_raw+(0 if is_a else 4))/2.0))+hit.fork,after[4])
	var expected = raised if patched else base
	var observed_primary=0
	for cue in out.presentation:
		if cue.kind=="damage" and not cue.get("split",false) and not cue.has("source_index"): observed_primary+=cue.amount
	assert(observed_primary==expected[0] and out.damage==expected[1],"Marginal projection != resolved command")
	var extra = int(raised[1])-int(base[1])
	var crossed=base[0]<picked.target_hp and raised[0]>=picked.target_hp
	if extra>0: count("eligible_effective")
	if patched:
		count("effective_bonus_damage",extra)
		if crossed: count("bonus_target_kills")
	fight.procs.append({"turn":fight.turns,"card":picked.id,"target_hp":picked.target_hp,"spend":spent,"base":base,"raised":raised,"patched":patched,"crossed":crossed})

func choose_reward() -> Dictionary:
	var offered=game.run.reward.choices.any(func(c): return c.kind=="card" and c.id=="crescendo")
	var before=game.owned_card_count("crescendo")
	var out=super.choose_reward()
	if offered:
		print("OFFER "+JSON.stringify({"region":int(game.run.region)+1,"node":game.run.current_node,"picked":game.owned_card_count("crescendo")>before}))
	return out
