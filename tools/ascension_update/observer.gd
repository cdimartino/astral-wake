extends "res://tools/ascension_update/policy.gd"
# Observation only. No hidden draw identities, RNG inspection, or policy changes.
var fight := {}
var selected := {}
var forecast := {}
var digest := ""

func prepare_routes() -> void:
	min_positive_hull = int(game.run.hull)
	print("IDENTITY "+JSON.stringify({"ascension_rank":game.run.ascension_rank,"modifier_revision":game.run.modifier_revision,"rules_revision":Game.RULES_REVISION,"pool_tier":game.run.pool_tier,"policy":policy,"no_bonuses":no_bonuses}))
	super.prepare_routes()

func choose_path() -> Dictionary:
	var out = super.choose_path()
	if out.ok:
		path_taken.append([int(game.run.region)+1,game.run.current_node])
		if game.run.mode == "combat": open_fight()
	return out

func open_fight() -> void:
	var r = game.run
	var b = r.battle
	var roster := []
	for foe in b.enemies: roster.append([foe.id,foe.hp])
	fight = {"region":int(r.region)+1,"area":game.region().id,"node":r.current_node,"kind":b.kind,"roster":roster,"entry_hull":r.hull,"min_positive_hull":r.hull,"turns":1,"end_turns":0,"plays":0,"hull_damage":0,"incoming_by_phase":[],"path":path_taken.duplicate(true),"prior_actions":digest}
	# Entry signature deliberately excludes rank and hidden future draws/RNG.
	fight.entry_signature = JSON.stringify([path_taken,r.hull,r.max_hull,r.salvage,r.deck,r.powerups,b.hand,roster,b.strain,b.capacity,b.ward]).sha256_text()

func plan_combat_action() -> Dictionary:
	selected = super.plan_combat_action()
	forecast = {}
	if not selected.get("end_turn",false):
		forecast = game.preview_card(selected.hand,selected.route,selected.target)
	return selected

func sample_hull(hull: int) -> void:
	if hull>0:
		min_positive_hull = mini(min_positive_hull,hull)
		fight.min_positive_hull = mini(int(fight.min_positive_hull),hull)

func combat_action() -> Dictionary:
	var before = int(game.run.hull)
	var turn = int(game.run.battle.turn)
	var incoming = int(game._incoming_damage(game.run))
	var ward = int(game.run.battle.ward)
	var out = super.combat_action()
	if not out.ok: return out
	fight.turns = turn
	var end_turn = selected.get("end_turn",false)
	if end_turn:
		fight.end_turns += 1
		fight.incoming_by_phase.append({"turn":turn,"incoming":incoming,"ward":ward,"hull":before})
	else:
		fight.plays += 1
		quality.forecast_checks += 1
		if int(forecast.get("damage",-1)) != int(out.get("damage",-2)):
			quality.forecast_mismatches += 1
	var low = before
	for cue in out.get("presentation",[]):
		if cue.kind == "heal": low += int(cue.amount)
		if cue.kind in ["enemy_attack","hull_damage"]:
			low -= int(cue.amount)
			fight.hull_damage += int(cue.amount)
		sample_hull(low)
	sample_hull(int(game.run.hull))
	digest = (digest+JSON.stringify([selected,turn,before,game.run.hull])).sha256_text()
	print("ACTION "+JSON.stringify({"region":fight.region,"node":fight.node,"turn":turn,"selection":selected,"hull_before":before,"hull_after":game.run.hull,"digest":digest}))
	if game.run.mode != "combat":
		fight.won = game.run.mode != "defeat"
		fight.exit_hull = game.run.hull
		fight.actions_digest = digest
		print("FIGHT "+JSON.stringify(fight))
	return out
