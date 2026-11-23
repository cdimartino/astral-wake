extends RefCounted
## Read-only UI adapter. This does not grant permission to play: refresh and
## reclassify at release, then let the existing guarded controller validate.
## Never expose simulation cues (which can contain hidden drawn cards).

static func _blocked(message: String, pending: bool = false) -> Dictionary:
	return {"ok":false,"needs_enemy":true,"deferred":pending,"error":message,"reason":message,"target_index":-1,"target_guard":{}}

static func classify(game, source_uid, ordered_route: Array, choices: Array = []) -> Dictionary:
	if not game._number(source_uid):
		return _blocked("Choose a command UID.")
	if game.run.get("mode","")!="combat":
		return _blocked("There is no active battle.")
	if game.selection_pending():
		return _blocked("Confirm or cancel the pending card selection first.",true)
	var battle=game.run.battle
	var hand_index=-1
	for i in range(battle.hand.size()):
		if battle.hand[i].uid==source_uid: hand_index=i
	if hand_index<0: return _blocked("Choose a card from your hand.")
	# preview_card accepts typed integer targets but route validation must run
	# before any simulation indexes a route node.
	var route_error=game._validate_route(game.run,ordered_route)
	if not route_error.is_empty(): return _blocked(route_error)
	var canonical=-1
	var needs_enemy=false
	var signature=[]
	for i in range(battle.enemies.size()):
		if int(battle.enemies[i].hp)<=0: continue
		var preview=game.preview_card(hand_index,ordered_route,i,choices)
		if not preview.get("ok",false):
			return _blocked(str(preview.get("error","Command preview unavailable.")),preview.get("selection_required",false))
		# Read resolved payload, not printed kind, damage dealt, or intent.
		# Zero damage through armor is still an enemy-directed command.
		for step in preview.get("route_steps",[]):
			var payload=step.payload_after
			if int(payload[0])>0 or int(payload[2])>0 or int(payload[3])>0:
				needs_enemy=true
		for cue in preview.get("presentation",[]):
			if cue.get("kind","") in ["damage","disrupt","redirect"]:
				needs_enemy=true
		# Catch target-dependent self effects as well, without retaining any
		# hidden card identity, event text, or resulting simulated state.
		var current=[]
		for key in ["heal","ward_gained","flat_ward_requested","flat_ward_applied","conditional_damage","command_cooling","attack_reduction","trace","resonance","strain","command_points","resource_preview"]:
			current.append(preview.get(key))
		if canonical<0:
			canonical=i
			signature=current
		elif current!=signature:
			needs_enemy=true
	if canonical<0: return _blocked("Choose a living target.")
	return {
		"ok":true,"needs_enemy":needs_enemy,"deferred":false,"error":"",
		"reason":"Command affects an enemy or depends on its target." if needs_enemy else "Self-only command; guarded internal target is safe.",
		"target_index":-1 if needs_enemy else canonical,
		"target_guard":{} if needs_enemy else battle.enemies[canonical].duplicate(true),
	}
