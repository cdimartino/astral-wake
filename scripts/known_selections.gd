extends RefCounted
## Bounded known-card operations only. No hidden draws, interpreter or triggers.
const KINDS = ["exhaust_hand", "retain_hand", "return_discard"]

static func valid_definition(value) -> bool:
	if not value is Array or value.is_empty() or value.size()>3: return false
	for op in value:
		if not op is Dictionary or not op.get("kind","") in KINDS: return false
		for key in op:
			if not key in ["kind","optional","kind_filter"]: return false
		if op.has("optional") and not op.optional is bool: return false
		if op.has("kind_filter") and (op.kind!="return_discard" or not op.kind_filter in ["attack","repair"]): return false
	return true

static func index(items: Array, uid) -> int:
	for i in range(items.size()):
		if items[i].uid==uid: return i
	return -1

static func candidates(game, battle: Dictionary, source_uid: int, op: Dictionary, used: Array) -> Array:
	var result=[]
	var zone="discard" if op.kind=="return_discard" else "hand"
	# Source use frees one slot. Retrieval precedes source draw and reserves it.
	if zone=="discard" and battle.hand.size()-1>=10: return [null] if op.get("optional",false) else []
	for instance in battle[zone]:
		if instance.uid==source_uid or instance.uid in used: continue
		if op.has("kind_filter") and game.effective_card(instance).kind!=op.kind_filter: continue
		result.append(instance.uid)
	if op.get("optional",false): result.append(null)
	return result

static func move(battle: Dictionary, op: Dictionary, uid) -> void:
	if uid==null: return
	match op.kind:
		"exhaust_hand":
			battle.exhausted.append(battle.hand.pop_at(index(battle.hand,uid)))
			battle.temporary_retain.erase(uid)
		"retain_hand":
			if not uid in battle.temporary_retain: battle.temporary_retain.append(uid)
		"return_discard": battle.hand.append(battle.discard.pop_at(index(battle.discard,uid)))

static func possible(game, battle: Dictionary, source_uid: int, ops: Array, step: int, used: Array) -> bool:
	if step==ops.size(): return true
	for uid in candidates(game,battle,source_uid,ops[step],used):
		var next=battle.duplicate(true)
		move(next,ops[step],uid)
		if possible(game,next,source_uid,ops,step+1,used+[uid]): return true
	return false

static func plan(game, battle: Dictionary, source_uid: int, ops: Array, choices: Array) -> Dictionary:
	if choices.size()>ops.size(): return game._fail("Too many card choices.")
	var next=battle.duplicate(true)
	var used=[]
	for step in range(ops.size()):
		var eligible=[]
		for uid in candidates(game,next,source_uid,ops[step],used):
			var trial=next.duplicate(true)
			move(trial,ops[step],uid)
			if possible(game,trial,source_uid,ops,step+1,used+[uid]): eligible.append(uid)
		if eligible.is_empty(): return game._fail("No eligible known cards can complete this command.")
		if step==choices.size(): return {"ok":true,"complete":false,"step":step,"operation":ops[step].duplicate(true),"eligible":eligible}
		var uid=choices[step]
		if uid!=null and not game._number(uid): return game._fail("Choose an integral card UID.")
		if not uid in eligible: return game._fail("That card choice is no longer eligible.")
		move(next,ops[step],uid)
		used.append(uid)
	return {"ok":true,"complete":true}

static func guard(game, state: Dictionary, context: Dictionary) -> String:
	var value=game._restore_integers(state)
	for key in ["pending_selection","elapsed_seconds","started_at","id"]: value.erase(key)
	# Bind command context/prefix as well as gameplay. Legal but different saved
	# routes, sources, targets or choices must not reuse another context's guard.
	var command={}
	for key in ["source_uid","route","target_index","target_guard","definition","choices"]: command[key]=context.get(key)
	return JSON.stringify([value,game._restore_integers(command)]).sha256_text()
