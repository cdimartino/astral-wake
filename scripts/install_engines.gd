extends RefCounted
## Two bounded passives, not an authored script interpreter.

static func integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=low and value<=high

static func valid_definition(definition: Dictionary) -> bool:
	if not definition.has("engine"): return true
	var spec=definition.engine
	if not definition.get("install","") is String or definition.get("install","").is_empty() or definition.get("exhaust",false): return false
	if not spec is Dictionary or spec.size()!=2 or not spec.get("type") is String: return false
	return spec.type in ["novel_route","other_exhaust"] and integer(spec.get("cap"),1,6 if spec.type=="novel_route" else 5)

static func install(battle: Dictionary, instance: Dictionary, definition: Dictionary) -> void:
	if definition.has("engine"):
		battle.engine_counters.append({"source_uid":instance.uid,"type":definition.engine.type,"stacks":0,"used":false,"turn":battle.turn})

static func bonus(battle: Dictionary) -> int:
	var total=0
	for counter in battle.engine_counters: total+=int(counter.stacks)
	return total

static func reset_turn(battle: Dictionary) -> void:
	battle.engine_routes=[]
	for counter in battle.engine_counters:
		counter.used=false
		counter.turn=battle.turn

static func trigger(game, state: Dictionary, kind: String, uid: int, presentation: Array, events: Array) -> void:
	if state.hull<=0: return
	var battle=state.battle
	for counter in battle.engine_counters:
		if counter.type!=kind or counter.source_uid==uid: continue
		if kind=="other_exhaust" and counter.used: continue
		var source=battle.installed.filter(func(item): return item.uid==counter.source_uid)[0]
		var spec=game.effective_card(source).engine
		counter.stacks=mini(int(spec.cap),int(counter.stacks)+1)
		counter.used=true
		if kind=="other_exhaust":
			var gain=3
			battle.ward+=gain
			if gain>0: presentation.append({"kind":"ward","amount":gain})
		events.append("Install UID %d: later attack bonus +%d/%d."%[counter.source_uid,counter.stacks,spec.cap])

static func valid_state(game, battle: Dictionary) -> bool:
	if not battle.get("engine_counters") is Array or not battle.get("engine_routes") is Array or not integer(battle.get("turn"),1,2147483647): return false
	if not battle.get("installed") is Array: return false
	if battle.engine_routes.size()>156: return false
	var routes=[]
	for route in battle.engine_routes:
		if not route is Array or route.is_empty() or route.size()>3 or route in routes: return false
		var seen=[]
		for node in route:
			if not integer(node,0,5) or node in seen: return false
			seen.append(node)
		routes.append(route)
	var expected=[]
	for source in battle.installed:
		if not game._valid_instance(source): return false
		var definition=game.effective_card(source)
		if not valid_definition(definition): return false
		if definition.has("engine"): expected.append(source.uid)
	if expected.size()!=battle.engine_counters.size(): return false
	for counter in battle.engine_counters:
		if not counter is Dictionary or counter.size()!=5 or not integer(counter.get("source_uid"),1,2147483647) or counter.source_uid!=expected[0]: return false
		expected.pop_front()
		var source=battle.installed.filter(func(item): return item.uid==counter.source_uid)[0]
		var spec=game.effective_card(source).engine
		if not counter.get("type") is String or counter.type!=spec.type or not integer(counter.get("stacks"),0,int(spec.cap)) or not counter.get("used") is bool or not integer(counter.get("turn"),1,2147483647) or counter.turn!=battle.turn: return false
		if counter.used and (counter.stacks==0 or battle.engine_routes.is_empty()): return false
	return expected.is_empty()

static func detail(game, instance: Dictionary) -> String:
	var definition=game.effective_card(instance)
	if not definition.has("engine"): return "Dormant identity: %s · source UID %d"%[definition.install,instance.get("uid",0)]
	var text="New ordered damaging attack route: +1 later attack damage" if definition.engine.type=="novel_route" else "Once/turn another card exhausts: ward 3, +1 later attack damage"
	for counter in game.run.get("battle",{}).get("engine_counters",[]):
		if counter.source_uid==instance.get("uid",-1):
			return definition.name+" · "+text+"\nUID %d · next later bonus +%d/%d · used this turn: %s"%[instance.uid,counter.stacks,definition.engine.cap,"yes" if counter.used else "no"]
	return text+" (cap %d)."%definition.engine.cap
