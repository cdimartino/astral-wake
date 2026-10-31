class_name AstralGame
extends RefCounted

const SaveStore = preload("res://scripts/save_store.gd")
const SeedEngine = preload("res://scripts/seed_engine.gd")
const BASE_EDGES = [[0,1],[1,2],[2,3],[3,4],[4,5],[5,0],[0,3],[1,4],[2,5]]
const MODES = ["map","combat","reward","event","shop","recovery","modify","transition","victory","defeat"]
# Normalize legacy area stats first, then apply expedition pressure consistently.
const AREA_STRENGTH = [1.0,1.4,1.8]
const ATTACK_PRESSURE = 1.6
var catalog: Dictionary = {}
var run: Dictionary = {}
var profile: Dictionary = {"version":1,"unlocks":0,"history":[],"settings":{"reduced_motion":false,"volume":0.5,"music_volume":1.0,"combat_volume":1.0,"interface_volume":1.0,"fullscreen":false}}
var save_error = ""
var store
var _cards = {}
var _enemies = {}
var _powerups = {}
var _last_clock = 0

func _init(save_directory: String = "") -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	assert(parsed is Dictionary, "Game content missing or invalid")
	catalog = _restore_integers(parsed)
	for item in catalog.cards: _cards[item.id] = item
	for item in catalog.enemies: _enemies[item.id] = item
	for item in catalog.powerups: _powerups[item.id] = item
	store = SaveStore.new(save_directory)
	load_saved()

func card(id: String) -> Dictionary: return _cards.get(id, {})
func enemy(id: String) -> Dictionary:
	if id == "_egg": return {"id":id,"name":"Ember Cocoon","description":"Cannot attack. Destroy it within two enemy phases to prevent a Newborn Flare; disruption does not delay hatching.","art":1,"hp":14,"pattern":[{"kind":"incubate","amount":0,"label":"Hatching"}]}
	if id == "_hatchling": return {"id":id,"name":"Newborn Flare","description":"Attacks every turn with no recovery phase. Its low hull makes it a priority for a quick kill or split damage.","art":2,"hp":22,"pattern":[{"kind":"attack","amount":7,"label":"Solar bite"}]}
	return _enemies.get(id, {})
func powerup(id: String) -> Dictionary: return _powerups.get(id, {})
func character(id: String = "") -> Dictionary:
	if id.is_empty(): id=str(run.get("character","cartographer"))
	for definition in catalog.characters:
		if definition.id==id: return definition
	return {}
func organ(index: int) -> Dictionary: return character().organs[index]
func region() -> Dictionary:
	return catalog.regions[int(run.get("route_regions",[0,1,2])[int(run.get("region",0))])]
func _ok() -> Dictionary: return {"ok":true,"error":""}
func _fail(message: String) -> Dictionary: return {"ok":false,"error":message}
func _mode(expected: String) -> bool: return run.get("mode","") == expected

func _pick(state: Dictionary, count: int, stream: String = "world") -> int:
	if state.has("rng_version"): return SeedEngine.pick(state,count,stream)
	return SeedEngine.pick_legacy(state,count)

func _shuffle(state: Dictionary, items: Array, stream: String = "world") -> void:
	for i in range(items.size()-1,0,-1):
		var j = _pick(state,i+1,stream)
		var old = items[i]
		items[i] = items[j]
		items[j] = old

func _effect(state: Dictionary, effect: String) -> int:
	var total = 0
	for id in state.get("powerups",[]):
		var item = powerup(id)
		if item.get("effect","") == effect: total += int(item.get("value",0))
	return total

func _log(state: Dictionary, message: String) -> void:
	state.log.append(message)
	if state.log.size() > 60: state.log.pop_front()

func _instance(state: Dictionary, id: String) -> Dictionary:
	var instance = {"uid":int(state.next_uid),"id":id,"level":0}
	state.next_uid += 1
	return instance

func owned_card_count(id: String) -> int:
	var count = 0
	for instance in run.get("deck",[]):
		if instance.id == id: count += 1
	return count

func effective_card(instance: Dictionary) -> Dictionary:
	var definition = card(instance.get("id","")).duplicate(true)
	definition.first_free=false
	if int(instance.get("level",0)) > 0:
		definition.first_free=true
		for field in ["damage","heal","vent","disrupt"]:
			if int(definition.get(field,0))>0:
				definition[field]+=3 if field=="damage" else 2 if field=="heal" else 1
				definition.first_free=false
	return definition

func card_text(instance: Dictionary) -> String:
	var original = card(instance.get("id",""))
	var effective = effective_card(instance)
	var text = str(original.get("description",""))
	var phrases = {"damage":"Deal %d damage", "heal":"Restore %d hull", "vent":"Cool every organ by %d", "disrupt":"Apply %d disruption"}
	for field in phrases:
		if int(original.get(field,0))>0:
			text=text.replace(phrases[field]%int(original[field]),phrases[field]%int(effective[field]))
	if effective.first_free: text+="\nFirst routed organ gains no strain."
	return text

func new_run(seed_value = "", character_id: String = "cartographer") -> Dictionary:
	var vessel=character(character_id)
	if vessel.is_empty(): return _fail("Choose an available vessel.")
	var modern=seed_value is String or (seed_value is int and seed_value==0)
	var seeded=false
	if modern:
		var code=SeedEngine.canonical(str(seed_value)) if seed_value is String else ""
		seeded=not code.is_empty()
		if seeded and not SeedEngine.valid(code): return _fail("Use exactly 6 letters or digits (A–Z, 0–9).")
		seed_value=code if seeded else SeedEngine.generate(int(profile.unlocks))
	elif seed_value is int:
		# Retain the old numeric API/RNG for legacy saves and deterministic fixtures.
		seed_value=absi(seed_value)%2147483647
	else: return _fail("Use exactly 6 letters or digits (A–Z, 0–9).")
	run = {"id":"%s-%s" % [seed_value,Time.get_ticks_usec()],"seed":seed_value,"region":0,"layer":-1,"mode":"map","hull":100,"max_hull":100,"salvage":35,"deck":[],"powerups":[],"map":[],"current_node":"","visited":[],"battle":{},"reward":{},"event_id":"","shop":{},"log":[],"turns":0,"started_at":int(Time.get_unix_time_from_system()),"elapsed_seconds":0,"tutorial_step":0,"next_uid":1,"modify_return":"","modify_kind":"","finished":false,"battles":0}
	if modern:
		SeedEngine.initialize(run,seed_value)
		run.seeded=seeded
	run.character=character_id
	run.max_hull=int(vessel.max_hull)
	run.hull=run.max_hull
	var areas=[]
	for i in range(catalog.regions.size()): areas.append(i)
	_shuffle(run,areas)
	run.route_regions=areas.slice(0,3)
	for id in vessel.starting_deck: run.deck.append(_instance(run,id))
	run.map = _generate_map(run)
	_last_clock = Time.get_ticks_msec()
	_log(run,str(vessel.name)+" wakes. A signal waits beyond three horizons.")
	save()
	return _ok()

func _generate_map(state: Dictionary) -> Array:
	var result=[]
	var tier=int(state.region)
	var area=int(state.get("route_regions",[0,1,2])[tier])
	var regulars=[]
	var elites=[]
	var events=[]
	for definition in catalog.enemies:
		if int(definition.region)==area:
			if definition.role=="regular": regulars.append(definition.id)
			if definition.role=="elite": elites.append(definition.id)
	for definition in catalog.events:
		if int(definition.region)==-1 or int(definition.region)==area: events.append(definition.id)
	for depth in range(12):
		var layer=[]
		var width=1 if depth==11 else 2+_pick(state,3)
		for column in range(width):
			var type="battle"
			if depth==11: type="boss"
			elif depth==10: type=["recovery","shop","recovery"][column%3]
			elif depth in [3,7]: type=["elite","event","battle"][(_pick(state,3)+column)%3]
			elif depth in [2,5,8]: type=["event","shop","recovery"][(_pick(state,3)+column)%3]
			var enemies=[]
			if type=="boss": enemies.append(catalog.regions[area].boss)
			elif type=="elite": enemies.append(elites[_pick(state,elites.size())])
			elif type=="battle":
				enemies.append(regulars[_pick(state,regulars.size())])
				if depth>=4 or tier>0: enemies.append(regulars[_pick(state,regulars.size())])
			layer.append({"id":"r%d-l%d-c%d"%[tier,depth,column],"layer":depth,"column":column,"type":type,"enemy_ids":enemies,"event_id":events[_pick(state,events.size())] if type=="event" else "","edges":[]})
		result.append(layer)
	for depth in range(11):
		var current=result[depth]
		var following=result[depth+1]
		for node in current:
			var center=clampi(int(round((float(node.column)+0.5)*following.size()/current.size()-0.5)),0,following.size()-1)
			node.edges.append(following[center].id)
			if following.size()>1 and _pick(state,4)>0:
				var side=clampi(center+(-1 if _pick(state,2)==0 else 1),0,following.size()-1)
				if side==center: side=1 if center==0 else center-1
				node.edges.append(following[side].id)
		# Every displayed destination has incoming coverage, including wider forks.
		for node in following:
			var incoming=false
			for previous in current:
				if node.id in previous.edges: incoming=true
			if not incoming:
				var source=clampi(int(floor((float(node.column)+0.5)*current.size()/following.size())),0,current.size()-1)
				current[source].edges.append(node.id)
	return result

func reachable(node: Dictionary) -> bool:
	if not _mode("map"): return false
	if int(run.layer) == -1: return int(node.layer)==0
	for layer in run.map:
		for current in layer:
			if current.id == run.current_node: return node.id in current.edges
	return false

func choose_node(node_id: String) -> Dictionary:
	if not _mode("map"): return _fail("Finish this encounter first.")
	var selected = {}
	for layer in run.map:
		for node in layer:
			if node.id == node_id: selected = node
	if selected.is_empty() or not reachable(selected): return _fail("Choose a connected destination ahead of your ship.")
	run.current_node = selected.id
	run.layer = selected.layer
	run.visited.append(selected.id)
	match selected.type:
		"battle","elite","boss": _start_battle(selected)
		"event":
			run.mode = "event"
			run.event_id = selected.event_id
		"shop": _make_shop()
		"recovery": run.mode = "recovery"
	save()
	return _ok()

func _enemy_scale(id: String) -> float:
	var native=int(enemy(id).get("region",0))
	var authored=[1.0,1.3,1.6][native] if native>=0 and native<3 else 1.0
	return AREA_STRENGTH[int(run.get("region",0))]/authored

func _intent_for(id: String, turn: int) -> Dictionary:
	var pattern=enemy(id).pattern
	var intent=pattern[(turn-1)%pattern.size()].duplicate(true)
	var tactics=enemy(id).get("tactics",{})
	var phases=tactics.get("phases",[])
	if not phases.is_empty(): intent.merge(phases[(turn-1)%phases.size()],true)
	if intent.kind in ["attack","rebuild","mark"]: intent.amount=maxi(1,int(round(int(intent.amount)*_enemy_scale(id))))
	# Long fights become dangerous even with a repair-heavy deck. The full damage
	# is stored in the visible intent, so previews and resolution always agree.
	if intent.kind=="attack": intent.amount=int(ceil(int(intent.amount)*ATTACK_PRESSURE))+int((turn-1)/4)
	var name=str(intent.get("label","")).get_slice(" · ",0)
	match intent.kind:
		"attack": intent.label=name+" · %d damage"%int(intent.amount)
		"rebuild": intent.label=name+" · heal living enemies by %d"%int(intent.amount)
		"mark": intent.label=name+" · repeated route costs %d hull"%int(intent.amount)
		"incubate": intent.label=name+" · egg %d hull; hatches in 2 phases"%int(round(14*_enemy_scale("_egg")))
	return intent

func enemy_tactics_text(index: int) -> String:
	var foe=run.battle.enemies[index]
	var definition=enemy(foe.id)
	var tactics=definition.get("tactics",{})
	var lines=[str(definition.get("description",""))]
	if not tactics.is_empty():
		lines.append(str(tactics.name)+": "+str(tactics.counter))
		var cycle=[]
		for step in range(definition.pattern.size()):
			var phase=_intent_for(foe.id,step+1)
			cycle.append(str(phase.label).get_slice(" · ",0)+_stance_text(phase))
		lines.append("Repeats: "+" → ".join(cycle)+".")
	lines.append("Now: "+str(foe.intent.label)+_stance_text(foe.intent))
	if int(foe.intent.get("interrupt",0))>0:
		lines.append("Disruption: %d / %d to interrupt."%[int(foe.disrupt),int(foe.intent.interrupt)])
	return "\n".join(lines)

func _stance_text(intent: Dictionary) -> String:
	var traits=[]
	if int(intent.get("armor",0))>0: traits.append("armor %d per hit"%int(intent.armor))
	if int(intent.get("exposed",0))>0: traits.append("takes +%d per hit"%int(intent.exposed))
	if int(intent.get("interrupt",0))>0: traits.append("interrupt with %d disruption"%int(intent.interrupt))
	if intent.get("drain",false): traits.append("repairs actual hull damage dealt")
	if int(intent.get("overload",0))>0: traits.append("+%d damage per saturated organ"%int(intent.overload))
	return " ["+", ".join(traits)+"]" if not traits.is_empty() else ""

func _make_enemy(id: String) -> Dictionary:
	var definition=enemy(id)
	var hp=maxi(1,int(round(int(definition.hp)*_enemy_scale(id))))
	return {"id":id,"name":definition.name,"hp":hp,"max_hp":hp,"intent":_intent_for(id,1),"disrupt":0,"redirect":0,"egg_timer":2 if id=="_egg" else -1}

func _start_battle(node: Dictionary) -> void:
	run.mode = "combat"
	run.battle = {"enemies":[],"hand":[],"draw":run.deck.duplicate(true),"discard":[],"strain":[0,0,0,0,0,0],"capacity":int(character().capacity)+_effect(run,"capacity"),"edges":character().edges.duplicate(true),"severed":[],"ward":_effect(run,"starting_ward"),"turn":1,"last_route":[],"mark":0,"first_play":true,"emergency_used":false,"kind":node.type,"command_points":3,"max_command_points":3,"trace":0,"last_payload":{},"resonance":0,"last_command_kind":""}
	for id in node.enemy_ids: run.battle.enemies.append(_make_enemy(id))
	if node.type=="boss" and "salvage_parliament" in node.enemy_ids:
		var ids=[]
		for definition in catalog.enemies:
			if int(definition.region)==1 and definition.role=="regular": ids.append(definition.id)
		for i in range(2):
			var attendant=_make_enemy(ids[i])
			attendant.hp = int(ceil(attendant.hp*0.6))
			attendant.max_hp=attendant.hp
			run.battle.enemies.append(attendant)
	_shuffle(run,run.battle.draw,"cards")
	_draw(run,5+_effect(run,"draw"))
	_log(run,"Encounter: " + run.battle.enemies[0].name)

func _draw(state: Dictionary, count: int, presentation: Array = []) -> void:
	var battle = state.battle
	for unused in range(count):
		if battle.hand.size()>=10: break
		if battle.draw.is_empty():
			if battle.discard.is_empty(): break
			battle.draw=battle.discard.duplicate(true)
			battle.discard.clear()
			_shuffle(state,battle.draw,"cards")
			presentation.append({"kind":"shuffle","draw_count":battle.draw.size(),"discard_count":0})
		var instance=battle.draw.pop_back()
		battle.hand.append(instance)
		presentation.append({"kind":"draw_card","card":instance.duplicate(true),"hand_index":battle.hand.size()-1,"draw_count":battle.draw.size(),"discard_count":battle.discard.size()})

func _edge_exists(edges: Array, a: int, b: int) -> bool:
	for edge in edges:
		if (int(edge[0])==a and int(edge[1])==b) or (int(edge[0])==b and int(edge[1])==a): return true
	return false

func _validate_route(state: Dictionary, route: Array) -> String:
	if route.is_empty() or route.size()>3: return "Route through one to three organs."
	var visited=[]
	for i in range(route.size()):
		var node=int(route[i])
		if node<0 or node>=6 or node in visited: return "Each organ can appear only once in a route."
		if int(state.battle.strain[node])>=int(state.battle.capacity): return organ(node).name+" is at strain capacity."
		if i>0:
			var previous=int(route[i-1])
			if not _edge_exists(state.battle.edges,previous,node) or _edge_exists(state.battle.severed,previous,node): return "Those organs do not have an open connection."
		visited.append(node)
	return ""

func _simulate_card(state: Dictionary, hand_index: int, route: Array, target_index: int, preview_only: bool = false) -> Dictionary:
	if state.get("mode","")!="combat": return _fail("There is no active battle.")
	var battle=state.battle
	if hand_index<0 or hand_index>=battle.hand.size(): return _fail("Choose a card from your hand.")
	var route_error=_validate_route(state,route)
	if not route_error.is_empty() and not (preview_only and route.is_empty()): return _fail(route_error)
	if target_index<0 or target_index>=battle.enemies.size() or int(battle.enemies[target_index].hp)<=0: return _fail("Choose a living target.")
	var incoming_before=_incoming_damage(state)
	var instance=battle.hand[hand_index]
	var definition=card(instance.id)
	var cost=int(definition.cost)
	if cost>int(battle.command_points): return _fail("Not enough command points: this command costs %d, with %d remaining."%[cost,int(battle.command_points)])
	var trace_before=int(battle.get("trace",0))
	var resonance_before=int(battle.get("resonance",0))
	var previous_kind=str(battle.get("last_command_kind",""))
	var vessel_id=str(state.get("character","cartographer"))
	var ward_gain=0
	var effective=effective_card(instance)
	var damage=int(effective.get("damage",0))
	var heal=int(effective.get("heal",0))
	var vent=int(effective.get("vent",0))
	var disrupt=int(effective.get("disrupt",0))
	var plain_payload={"damage":damage,"heal":heal,"disrupt":disrupt}
	if vessel_id=="palimpsest":
		battle.trace=mini(6,int(battle.trace)+int(definition.get("trace",0)))
		if definition.get("rewrite",false):
			var spent=int(battle.trace)
			battle.trace=0
			if spent>0:
				damage+=spent*2+int(floor(int(battle.last_payload.get("damage",0))/2.0))
				heal+=int(floor(int(battle.last_payload.get("heal",0))/2.0))
				disrupt+=int(floor(int(battle.last_payload.get("disrupt",0))/2.0))
	elif vessel_id=="hollow_choir":
		if not previous_kind.is_empty():
			battle.resonance=mini(3,int(battle.resonance)+1) if previous_kind!=definition.kind else 0
		battle.resonance=mini(3,int(battle.resonance)+int(definition.get("resonance",0)))
		if definition.get("concert",false):
			var spent=int(battle.resonance)
			battle.resonance=0
			damage+=spent*2
			heal+=spent
	var resource_preview={"trace_before":trace_before,"resonance_before":resonance_before,"card_trace":int(battle.get("trace",0)),"card_resonance":int(battle.get("resonance",0))}
	if route.is_empty():
		return {"ok":false,"error":"Choose an organ to begin routing.","resource_preview":resource_preview,"trace":int(battle.get("trace",0)),"resonance":int(battle.get("resonance",0)),"route_steps":[]}
	if damage>0:
		damage+=_effect(state,"damage")
		if battle.first_play: damage+=_effect(state,"first_damage")
		if route.size()==1: damage+=_effect(state,"short_route")
		if route.size()==3: damage+=_effect(state,"long_route")
	if heal>0: heal+=_effect(state,"heal")
	var split=false
	var redirect=0
	var route_steps=[]
	var other_living=false
	for i in range(battle.enemies.size()):
		if i!=target_index and int(battle.enemies[i].hp)>0: other_living=true
	for index in route:
		var before_payload=[damage,heal,disrupt,redirect,split,ward_gain]
		var before_trace=int(battle.get("trace",0))
		var before_resonance=int(battle.get("resonance",0))
		match organ(int(index)).id:
			"lens":
				if damage>0: damage+=3
			"fork": split=true
			"echo":
				damage=int(floor(damage*1.5))
				heal=int(floor(heal*1.5))
				if damage>0: damage+=_effect(state,"echo")
			"mend": heal+=1
			"hush": disrupt+=2
			"prism": redirect+=3
			"scribe": battle.trace=mini(6,int(battle.trace)+2)
			"splice":
				if int(battle.trace)>=2: split=true
				elif damage>0: damage+=2
			"recall":
				if damage>0:
					damage+=int(battle.trace)*2+_effect(state,"echo")
					battle.trace=0
			"palimend":
				if int(battle.trace)>0:
					battle.trace-=1
					heal+=2
			"redact":
				if int(battle.trace)>0:
					battle.trace-=1
					disrupt+=3
				else: disrupt+=1
			"rewrite":
				if int(battle.trace)>=2:
					battle.trace-=2
					damage+=int(floor(int(battle.last_payload.get("damage",0))/2.0))
					heal+=int(floor(int(battle.last_payload.get("heal",0))/2.0))
					disrupt+=int(floor(int(battle.last_payload.get("disrupt",0))/2.0))
			"conductor":
				if previous_kind.is_empty() or previous_kind!=definition.kind: battle.resonance=mini(3,int(battle.resonance)+1)
			"chorus":
				if int(battle.resonance)>=2: split=true
				elif damage>0: damage+=1
			"crescendo":
				var spent=int(battle.resonance)
				battle.resonance=0
				if damage>0: damage+=spent*2+_effect(state,"echo")
				if heal>0: heal+=spent*2
			"rest":
				if definition.kind!="attack":
					heal+=1
					battle.resonance=mini(3,int(battle.resonance)+1)
			"dissonance": disrupt+=1+int(battle.resonance)
			"cadence":
				if int(battle.resonance)>=2:
					battle.resonance-=2
					ward_gain=3
		var payload_changed=before_payload!=[damage,heal,disrupt,redirect,split,ward_gain]
		var id=str(organ(int(index)).id)
		if id in ["fork","splice","chorus"] and split: payload_changed=damage>0 and other_living and (int(floor(damage/2.0))+_effect(state,"fork"))>0
		if id=="prism": payload_changed=other_living and int(battle.enemies[target_index].redirect)<3
		if id=="cadence": payload_changed=ward_gain>int(before_payload[5]) and int(battle.ward)<3
		var resource_gained=int(battle.get("trace",0))>before_trace or int(battle.get("resonance",0))>before_resonance
		var resource_spent=int(battle.get("trace",0))<before_trace or int(battle.get("resonance",0))<before_resonance
		var status="active" if payload_changed or resource_gained else "wasted" if resource_spent else "inactive"
		if status=="active" and ((id=="redact" and before_trace==0) or (id=="splice" and before_trace<2) or (id=="chorus" and before_resonance<2)): status="fallback"
		var reasons={"lens":"Needs damage", "fork":"No split target", "echo":"No damage/repair", "prism":"No redirect available", "scribe":"Trace full", "splice":"No split target", "recall":"Needs damage/Trace", "palimend":"Needs 1 Trace", "rewrite":"Needs Trace/base", "conductor":"Same kind or full", "chorus":"No split target", "crescendo":"No gain from spending", "rest":"Needs non-attack", "cadence":"Needs resource/ward room"}
		var reason="Effect applied" if status=="active" else "Fallback applied" if status=="fallback" else "Spent without benefit" if status=="wasted" else str(reasons.get(id,"No payload change"))
		route_steps.append({"organ":int(index),"status":status,"reason":reason,"trace_before":before_trace,"trace_after":int(battle.get("trace",0)),"resonance_before":before_resonance,"resonance_after":int(battle.get("resonance",0)),"payload_before":before_payload,"payload_after":[damage,heal,disrupt,redirect,split,ward_gain]})
	if disrupt>0: disrupt+=_effect(state,"disrupt")
	var target=battle.enemies[target_index]
	var events=[]
	var presentation=[]
	battle.command_points-=cost
	events.append("Spend %d command point(s); %d remain."%[cost,int(battle.command_points)])
	if vessel_id=="palimpsest":
		presentation.append({"kind":"trace","before":trace_before,"after":int(battle.trace),"amount":int(battle.trace)-trace_before})
		events.append("Trace %d → %d."%[trace_before,int(battle.trace)])
	elif vessel_id=="hollow_choir":
		presentation.append({"kind":"resonance","before":resonance_before,"after":int(battle.resonance),"amount":int(battle.resonance)-resonance_before})
		events.append("Resonance %d → %d."%[resonance_before,int(battle.resonance)])
	var actual_damage=0
	var hull_before=int(state.hull)
	if int(battle.mark)>0 and battle.last_route==route:
		var before_mark=int(state.hull)
		var mark_hit=_hurt(state,int(battle.mark),false)
		presentation.append({"kind":"hull_damage","amount":mark_hit.damage,"absorbed":mark_hit.absorbed,"source":"mark"})
		if mark_hit.restored>0: presentation.append({"kind":"heal","amount":mark_hit.restored,"source":"emergency"})
		var hull_delta=int(state.hull)-before_mark
		if hull_delta>0: events.append("Repeated route triggers your last ember: hull restored to %d."%int(state.hull))
		else: events.append("Repeated route: %d hull lost."%-hull_delta)
	if damage>0:
		var dealt=_damage_enemy(state,target_index,damage,route.size())
		actual_damage+=dealt
		presentation.append({"kind":"damage","target_index":target_index,"amount":dealt,"split":false})
		events.append("%s: %d damage." % [target.name,dealt])
		if split:
			var splash=int(floor(damage/2.0))+_effect(state,"fork")
			for i in range(battle.enemies.size()):
				if i!=target_index and int(battle.enemies[i].hp)>0:
					var split_dealt=_damage_enemy(state,i,splash,route.size(),true)
					actual_damage+=split_dealt
					presentation.append({"kind":"damage","target_index":i,"amount":split_dealt,"split":true})
					events.append("%s: %d split damage." % [battle.enemies[i].name,split_dealt])
	var repaired=mini(int(state.max_hull)-int(state.hull),heal) if int(state.hull)>0 else 0
	state.hull+=repaired
	if repaired>0:
		presentation.append({"kind":"heal","amount":repaired,"source":"command"})
		events.append("Repair %d hull."%repaired)
	if ward_gain>0 and int(state.hull)>0:
		var gained=mini(ward_gain,maxi(0,3-int(battle.ward)))
		battle.ward+=gained
		if gained>0: presentation.append({"kind":"ward","amount":gained})
	if int(target.hp)>0:
		target.disrupt+=disrupt
		if disrupt>0:
			presentation.append({"kind":"disrupt","target_index":target_index,"amount":disrupt})
			events.append("%s: +%d disruption for this enemy phase (combined defense caps at half an attack)."%[target.name,disrupt])
			if int(target.intent.get("interrupt",0))>0:
				events.append("%s: action interrupted."%target.name if int(target.disrupt)>=int(target.intent.interrupt) else "%s: %d more disruption interrupts this action."%[target.name,int(target.intent.interrupt)-int(target.disrupt)])
		other_living=false
		for i in range(battle.enemies.size()):
			if i!=target_index and int(battle.enemies[i].hp)>0: other_living=true
		var added_redirect=mini(3,int(target.redirect)+redirect)-int(target.redirect) if other_living else 0
		if added_redirect>0:
			target.redirect+=added_redirect
			presentation.append({"kind":"redirect","target_index":target_index,"amount":added_redirect})
			events.append("Redirect up to %d of %s's next attack into another foe this phase."%[int(target.redirect),target.name])
	var cooled=[]
	for i in range(6):
		cooled.append(mini(int(battle.strain[i]),vent))
		battle.strain[i]=maxi(0,int(battle.strain[i])-vent)
	if vent>0: presentation.append({"kind":"cooling","amounts":cooled})
	var pure_utility_upgrade=effective.first_free
	for i in range(route.size()):
		if not (pure_utility_upgrade and i==0): battle.strain[int(route[i])]+=1
	if vent>0: events.append("Cool every organ by %d before route strain."%vent)
	if definition.get("link",false):
		battle.severed.clear()
		presentation.append({"kind":"link","route":route.duplicate()})
		if route.size()>1 and not _edge_exists(battle.edges,int(route[0]),int(route[-1])): battle.edges.append([int(route[0]),int(route[-1])])
		events.append("Connections restored; route endpoints linked for this battle.")
	battle.discard.append(battle.hand.pop_at(hand_index))
	presentation.append({"kind":"discard_card","card":instance.duplicate(true),"hand_index":hand_index,"draw_count":battle.draw.size(),"discard_count":battle.discard.size()})
	_draw(state,int(definition.get("draw",0)),presentation)
	if vessel_id=="palimpsest": battle.last_payload=plain_payload
	if vessel_id=="hollow_choir": battle.last_command_kind=definition.kind
	battle.last_command={"card":instance.duplicate(true),"kind":definition.kind,"base":plain_payload.duplicate(),"resolved":{"damage":actual_damage,"heal":repaired,"disrupt":disrupt if int(target.hp)>0 else 0}}
	battle.last_route=route.duplicate()
	battle.first_play=false
	state.tutorial_step=maxi(1,int(state.tutorial_step))
	_clean_enemies(state,presentation)
	var finish_heal=mini(int(state.max_hull)-int(state.hull),_effect(state,"repair_after")) if battle.enemies.is_empty() and int(state.hull)>0 else 0
	if finish_heal>0:
		presentation.append({"kind":"heal","amount":finish_heal,"source":"repair_after"})
		events.append("After combat: repair %d hull."%finish_heal)
	_log(state,definition.name+": "+" ".join(events))
	return {"ok":true,"error":"","next":state,"summary":"\n".join(events),"damage":actual_damage,"heal":int(state.hull)-hull_before+finish_heal,"disrupt":disrupt,"cost":cost,"attack_reduction":incoming_before-_incoming_damage(state),"command_points":int(battle.command_points),"strain":battle.strain.duplicate(),"events":events,"presentation":presentation,"resource_preview":resource_preview,"trace":int(battle.get("trace",0)),"resonance":int(battle.get("resonance",0)),"route_steps":route_steps}

func preview_card(hand_index: int, route: Array, target_index: int) -> Dictionary:
	var result=_simulate_card(run.duplicate(true),hand_index,route,target_index,true)
	result.erase("next")
	return result

func play_card(hand_index: int, route: Array, target_index: int) -> Dictionary:
	var result=_simulate_card(run.duplicate(true),hand_index,route,target_index)
	if not result.ok: return result
	run=result.next
	_check_battle_end()
	save()
	result.erase("next")
	return result

func _damage_enemy(state: Dictionary, index: int, amount: int, route_length: int = 0, split_hit: bool = false) -> int:
	if amount<=0: return 0
	var target=state.battle.enemies[index]
	var tactics=enemy(target.id).get("tactics",{})
	var weakness=tactics.get("weakness","")
	if (weakness=="short" and route_length==1) or (weakness=="long" and route_length==3) or (weakness=="split" and split_hit):
		amount+=int(tactics.get("bonus",0))
	amount=maxi(0,amount+int(target.intent.get("exposed",0))-int(target.intent.get("armor",0)))
	# Parliament members share protection while attendants survive.
	if target.id=="salvage_parliament":
		var living=0
		for foe in state.battle.enemies:
			if foe.id!="salvage_parliament" and int(foe.hp)>0: living+=1
		amount=maxi(0,amount-living*2)
	var actual=mini(int(target.hp),maxi(0,amount))
	target.hp=maxi(0,int(target.hp)-amount)
	return actual

func _clean_enemies(state: Dictionary, presentation: Array = []) -> void:
	var living=[]
	for foe in state.battle.enemies:
		if int(foe.hp)>0: living.append(foe)
		else:
			var repaired=mini(int(state.max_hull)-int(state.hull),_effect(state,"kill_heal")) if int(state.hull)>0 else 0
			state.hull+=repaired
			if repaired>0: presentation.append({"kind":"heal","amount":repaired,"source":"kill"})
			_log(state,foe.name+" dissolves into the wake.")
	state.battle.enemies=living

func _hurt(state: Dictionary, amount: int, use_ward: bool = true) -> Dictionary:
	var absorbed=mini(int(state.battle.get("ward",0)),amount) if use_ward else 0
	state.battle.ward=int(state.battle.get("ward",0))-absorbed
	var damage=mini(int(state.hull),maxi(0,amount-absorbed))
	state.hull-=damage
	var restored=0
	if state.hull<=0 and not state.battle.get("emergency_used",false) and _effect(state,"emergency")>0:
		restored=mini(int(state.max_hull),_effect(state,"emergency"))
		state.hull=restored
		state.battle.emergency_used=true
		_log(state,"The last ember rekindles your hull.")
	return {"damage":damage,"absorbed":absorbed,"restored":restored}

func enemy_attack_preview(source_index: int) -> Dictionary:
	return _forecast_attack(run,source_index)

func _strain_targets(strain: Array) -> Array:
	var indices=[0,1,2,3,4,5]
	indices.sort_custom(func(a,b): return int(strain[a])>int(strain[b]) if strain[a]!=strain[b] else a<b)
	return indices

func _forecast_attack(state: Dictionary, source_index: int) -> Dictionary:
	# Earlier strain actions can empower an overload attack in the same phase.
	var strain=state.battle.strain.duplicate()
	for i in range(source_index):
		var foe=state.battle.enemies[i]
		if int(foe.hp)<=0 or foe.intent.kind!="strain": continue
		if int(foe.intent.get("interrupt",0))>0 and int(foe.disrupt)>=int(foe.intent.interrupt): continue
		var targets=_strain_targets(strain)
		for j in range(mini(int(foe.intent.amount),6)):
			strain[targets[j]]=mini(int(state.battle.capacity),int(strain[targets[j]])+2)
	return _attack_payload(state,source_index,strain)

func _attack_payload(state: Dictionary, source_index: int, projected_strain: Array = []) -> Dictionary:
	var foe=state.battle.enemies[source_index]
	var raw=int(foe.intent.get("amount",0)) if foe.intent.kind=="attack" and int(foe.hp)>0 else 0
	if raw>0:
		for strain in (state.battle.strain if projected_strain.is_empty() else projected_strain):
			if int(strain)>=int(state.battle.capacity): raw+=int(foe.intent.get("overload",0))
	# Combined defenses can prevent at most half an attack; Prism needs another foe.
	var budget=int(floor(raw/2.0))
	var disrupted=mini(budget,maxi(0,int(foe.disrupt)))
	var other=-1
	for i in range(state.battle.enemies.size()):
		if i!=source_index and int(state.battle.enemies[i].hp)>0:
			other=i
			break
	var redirected=mini(budget-disrupted,mini(3,maxi(0,int(foe.redirect)))) if other>=0 else 0
	return {"raw":raw,"damage":raw-disrupted-redirected,"disrupted":disrupted,"redirected":redirected,"redirect_target":other}

func _incoming_damage(state: Dictionary) -> int:
	var amount=0
	for i in range(state.battle.enemies.size()): amount+=int(_forecast_attack(state,i).damage)
	return amount

func end_turn() -> Dictionary:
	if not _mode("combat"): return _fail("There is no active battle.")
	var battle=run.battle
	var presentation=[]
	for i in range(battle.hand.size()):
		var instance=battle.hand[i]
		battle.discard.append(instance)
		presentation.append({"kind":"discard_card","card":instance.duplicate(true),"hand_index":i,"draw_count":battle.draw.size(),"discard_count":battle.discard.size()})
	battle.hand.clear()
	battle.severed.clear()
	var count=battle.enemies.size()
	for i in range(count):
		var foe=battle.enemies[i]
		if int(foe.hp)<=0: continue
		if foe.id=="_egg":
			foe.egg_timer-=1
			if foe.egg_timer<=0:
				battle.enemies[i]=_make_enemy("_hatchling")
				_log(run,"An ember cocoon hatches into a Newborn Flare.")
			foe.disrupt=0
			foe.redirect=0
			continue
		var intent=foe.intent
		var amount=int(intent.get("amount",0))
		if int(intent.get("interrupt",0))>0 and int(foe.disrupt)>=int(intent.interrupt):
			_log(run,"%s: %s interrupted by disruption."%[foe.name,str(intent.label).get_slice(" · ",0)])
			presentation.append({"kind":"interrupted","source_index":i,"amount":int(foe.disrupt)})
			foe.disrupt=0
			foe.redirect=0
			continue
		match intent.kind:
			"attack":
				var attack=_attack_payload(run,i)
				if attack.redirected>0:
					var dealt=_damage_enemy(run,int(attack.redirect_target),int(attack.redirected))
					presentation.append({"kind":"damage","source_index":i,"target_index":int(attack.redirect_target),"amount":dealt,"split":false})
				var hit=_hurt(run,int(attack.damage))
				presentation.append({"kind":"enemy_attack","source_index":i,"target_index":-1,"amount":hit.damage,"absorbed":hit.absorbed,"disrupted":attack.disrupted,"redirected":attack.redirected})
				if hit.restored>0: presentation.append({"kind":"heal","amount":hit.restored,"source":"emergency"})
				_log(run,"%s strikes: %d hull damage, %d ward absorbed, %d disrupted, %d redirected."%[foe.name,hit.damage,hit.absorbed,attack.disrupted,attack.redirected])
				if intent.get("drain",false) and int(foe.hp)>0:
					var restored=mini(int(foe.max_hp)-int(foe.hp),int(hit.damage))
					foe.hp+=restored
					if restored>0:
						presentation.append({"kind":"enemy_heal","source_index":i,"target_index":i,"amount":restored})
						_log(run,"%s drains %d hull to repair itself."%[foe.name,restored])

			"strain":
				var indices=_strain_targets(battle.strain)
				var added=[0,0,0,0,0,0]
				for j in range(mini(amount,6)):
					added[indices[j]]=mini(2,int(battle.capacity)-int(battle.strain[indices[j]]))
					battle.strain[indices[j]]+=added[indices[j]]
				presentation.append({"kind":"strain","source_index":i,"amounts":added})
				_log(run,foe.name+" floods organs with strain.")
			"sever":
				var open=[]
				# Cut the last command's conduits first, in route order; then use
				# the stable circuit order. Players can bait cuts with a spare route.
				for j in range(1,battle.last_route.size()):
					var a=int(battle.last_route[j-1])
					var b=int(battle.last_route[j])
					if _edge_exists(battle.edges,a,b) and not _edge_exists(battle.severed,a,b): open.append([a,b])
				for edge in battle.edges:
					if not _edge_exists(battle.severed,int(edge[0]),int(edge[1])) and not _edge_exists(open,int(edge[0]),int(edge[1])): open.append(edge)
				for ignored in range(mini(amount,open.size())):
					var edge=open.pop_front().duplicate()
					battle.severed.append(edge)
					presentation.append({"kind":"sever","source_index":i,"edge":edge})
				_log(run,foe.name+" severs a connection for your next turn.")
			"incubate":
				if battle.enemies.size()<5:
					battle.enemies.append(_make_enemy("_egg"))
					presentation.append({"kind":"incubate","source_index":i,"target_index":battle.enemies.size()-1,"amount":int(battle.enemies[-1].hp)})
					_log(run,foe.name+" incubates an Ember Cocoon. It hatches in two turns.")
			"rebuild":
				for j in range(battle.enemies.size()):
					var other=battle.enemies[j]
					if int(other.hp)>0:
						var repaired=mini(int(other.max_hp)-int(other.hp),amount)
						other.hp+=repaired
						if repaired>0: presentation.append({"kind":"enemy_heal","source_index":i,"target_index":j,"amount":repaired})
				_log(run,foe.name+" rebuilds the living wrecks.")
			"mark":
				battle.mark=maxi(int(battle.mark),amount)
				presentation.append({"kind":"mark","source_index":i,"amount":amount})
				_log(run,"The Witness remembers. Repeating your previous route costs %d hull."%amount)
		foe.disrupt=0
		foe.redirect=0
		if int(run.hull)<=0: break
	_clean_enemies(run,presentation)
	battle.ward=0
	var cooled=[]
	for i in range(6):
		cooled.append(mini(int(battle.strain[i]),int(character().cooling)+_effect(run,"cooling")))
		battle.strain[i]=maxi(0,int(battle.strain[i])-1-_effect(run,"cooling"))
	presentation.append({"kind":"cooling","amounts":cooled})
	battle.turn+=1
	battle.first_play=true
	battle.command_points=int(battle.max_command_points)
	run.turns+=1
	run.tutorial_step=maxi(2,int(run.tutorial_step))
	for foe in battle.enemies:
		foe.intent=_intent_for(foe.id,int(battle.turn))
		if foe.id=="_egg": foe.intent.label="Hatches in %d turn(s)"%int(foe.egg_timer)
	var before_finish=int(run.hull)
	_check_battle_end()
	if int(run.hull)>before_finish: presentation.append({"kind":"heal","amount":int(run.hull)-before_finish,"source":"repair_after"})
	if _mode("combat"): _draw(run,5,presentation)
	save()
	return {"ok":true,"error":"","presentation":presentation,"strain":battle.strain.duplicate()}

func _check_battle_end() -> void:
	if int(run.hull)<=0:
		_finish_run(false)
	elif run.battle.enemies.is_empty():
		_finish_battle()

func _available_cards() -> Array:
	var result=[]
	for definition in catalog.cards:
		if int(definition.get("unlock",0))<=int(run.get("pool_tier",profile.unlocks)) and definition.get("character","cartographer")==run.get("character","cartographer"): result.append(definition.id)
	return result

func _available_powerups() -> Array:
	var result=[]
	for definition in catalog.powerups:
		if int(definition.get("unlock",0))<=int(run.get("pool_tier",profile.unlocks)) and not definition.id in run.powerups: result.append(definition.id)
	return result

func _finish_battle() -> void:
	run.tutorial_step=4
	var kind=run.battle.kind
	run.battles+=1
	run.hull=mini(int(run.max_hull),int(run.hull)+_effect(run,"repair_after"))
	var salvage=18+int(run.region)*7+_effect(run,"salvage")
	if kind=="elite": salvage+=15
	if kind=="boss": salvage+=30
	run.salvage+=salvage
	_log(run,"Recovered %d salvage."%salvage)
	var choices=[]
	var pool=_available_cards()
	_shuffle(run,pool,"rewards")
	var card_choices=(2 if kind in ["elite","boss"] else 3)+_effect(run,"reward_choices")
	for i in range(mini(card_choices,pool.size())): choices.append({"kind":"card","id":pool[i]})
	if kind in ["elite","boss"]:
		var powers=_available_powerups()
		_shuffle(run,powers,"rewards")
		for i in range(mini(2,powers.size())): choices.append({"kind":"powerup","id":powers[i]})
	run.reward={"choices":choices,"boss":kind=="boss"}
	run.mode="reward"

func _grant_powerup(id: String) -> void:
	if id in run.powerups: return
	run.powerups.append(id)
	_log(run,"Integrated "+powerup(id).name+".")

func choose_reward(choice_index: int) -> Dictionary:
	if not _mode("reward"): return _fail("There is no pending reward.")
	if choice_index < -1 or choice_index>=run.reward.choices.size(): return _fail("Choose a visible reward, or skip.")
	if choice_index>=0:
		var reward=run.reward.choices[choice_index]
		if reward.kind=="card": run.deck.append(_instance(run,reward.id))
		else: _grant_powerup(reward.id)
	var boss=run.reward.boss
	run.reward={}
	if boss:
		if int(run.region)==2: _finish_run(true)
		else: run.mode="transition"
	else: run.mode="map"
	save()
	return _ok()

func continue_region() -> Dictionary:
	if not _mode("transition"): return _fail("There is no region transition pending.")
	run.region+=1
	run.layer=-1
	run.current_node=""
	run.hull=mini(int(run.max_hull),int(run.hull)+25)
	run.map=_generate_map(run)
	run.mode="map"
	_log(run,"Entered "+region().name+". Repaired 25 hull.")
	save()
	return _ok()

func _make_shop() -> void:
	run.mode="shop"
	var items=[]
	var cards=_available_cards()
	_shuffle(run,cards,"shop")
	for i in range(2): items.append({"kind":"card","id":cards[i],"cost":35+i*8,"sold":false})
	var powers=_available_powerups()
	_shuffle(run,powers,"shop")
	for i in range(mini(2,powers.size())): items.append({"kind":"powerup","id":powers[i],"cost":75,"sold":false})
	items.append({"kind":"remove","id":"","cost":30,"sold":false})
	items.append({"kind":"upgrade","id":"","cost":35,"sold":false})
	for item in items: item.cost=maxi(1,int(round(item.cost*(1.0-_effect(run,"shop_discount")/100.0))))
	run.shop={"items":items}

func buy(index: int) -> Dictionary:
	if not _mode("shop"): return _fail("You are not at a salvage exchange.")
	if index<0 or index>=run.shop.items.size(): return _fail("Choose a listed exchange.")
	var item=run.shop.items[index]
	if item.sold: return _fail("That exchange is already complete.")
	if int(run.salvage)<int(item.cost): return _fail("Not enough salvage.")
	if item.kind in ["remove","upgrade"]:
		if item.kind=="remove" and run.deck.size()<=5: return _fail("Keep at least five cards in your deck.")
		if item.kind=="upgrade" and not _can_upgrade(): return _fail("Every command is already evolved.")
		run.mode="modify"
		run.modify_kind=item.kind
		run.modify_return="shop"
		run.modify_shop_index=index
	else:
		run.salvage-=int(item.cost)
		item.sold=true
		if item.kind=="card": run.deck.append(_instance(run,item.id))
		else: _grant_powerup(item.id)
	save()
	return _ok()

func _can_upgrade() -> bool:
	for instance in run.deck:
		if int(instance.level)==0: return true
	return false

func modify_card(deck_index: int) -> Dictionary:
	if not _mode("modify"): return _fail("No deck modification is pending.")
	if deck_index<0 or deck_index>=run.deck.size(): return _fail("Choose a card in your deck.")
	if run.modify_kind=="remove" and run.deck.size()<=5: return _fail("Keep at least five cards.")
	if run.modify_kind=="upgrade" and int(run.deck[deck_index].level)>0: return _fail("This command is already evolved.")
	if run.modify_return=="shop":
		var item=run.shop.items[int(run.modify_shop_index)]
		if item.sold or int(run.salvage)<int(item.cost): return _fail("That exchange is no longer available.")
		item.sold=true
		run.salvage-=int(item.cost)
	if run.modify_kind=="remove": run.deck.remove_at(deck_index)
	else: run.deck[deck_index].level=1
	run.mode="shop" if run.modify_return=="shop" else "map"
	run.modify_return=""
	run.modify_kind=""
	save()
	return _ok()

func cancel_modify() -> Dictionary:
	if not _mode("modify"): return _fail("No modification is pending.")
	run.mode=run.modify_return
	run.modify_return=""
	run.modify_kind=""
	save()
	return _ok()

func recover(choice: String) -> Dictionary:
	if not _mode("recovery"): return _fail("You are not at a recovery site.")
	if choice=="repair":
		run.hull=mini(int(run.max_hull),int(run.hull)+30)
		run.mode="map"
	elif choice=="upgrade":
		if not _can_upgrade(): return _fail("Every command is already evolved.")
		run.mode="modify"
		run.modify_kind="upgrade"
		run.modify_return="recovery"
	else: return _fail("Choose repair or evolution.")
	save()
	return _ok()

func event_choice(index: int) -> Dictionary:
	if not _mode("event"): return _fail("There is no unresolved event.")
	var event={}
	for definition in catalog.events:
		if definition.id==run.event_id: event=definition
	if event.is_empty() or index<0 or index>=event.choices.size(): return _fail("Choose an available event response.")
	var choice=event.choices[index]
	var value=int(choice.get("value",0))
	var effect=choice.effect
	if effect=="repair_trade" and int(run.salvage)<25: return _fail("This repair costs 25 salvage.")
	if effect=="capacity_trade" and int(run.max_hull)<=20: return _fail("Your hull cannot sustain that sacrifice.")
	if effect=="remove" and run.deck.size()<=5: return _fail("Keep at least five cards.")
	if effect=="upgrade" and not _can_upgrade(): return _fail("Every command is already evolved.")
	match effect:
		"heal": run.hull=mini(int(run.max_hull),int(run.hull)+value)
		"salvage": run.salvage+=value
		"hurt_salvage":
			run.hull=maxi(0,int(run.hull)-10)
			run.salvage+=value
		"repair_trade":
			run.salvage-=25
			run.hull=mini(int(run.max_hull),int(run.hull)+35)
		"card":
			var pool=_available_cards()
			run.deck.append(_instance(run,pool[_pick(run,pool.size(),"events")]))
		"powerup","capacity_trade":
			var pool=_available_powerups()
			if pool.is_empty(): return _fail("You have already integrated every available powerup.")
			if effect=="capacity_trade":
				run.max_hull-=8
				run.hull=mini(int(run.hull),int(run.max_hull))
			_grant_powerup(pool[_pick(run,pool.size(),"events")])
		"upgrade","remove":
			run.mode="modify"
			run.modify_return="event"
			run.modify_kind=effect
		_: return _fail("This event response is not supported.")
	_log(run,event.name+": "+choice.label)
	if int(run.hull)<=0: _finish_run(false)
	elif run.mode!="modify": run.mode="map"
	save()
	return _ok()

func leave_location() -> Dictionary:
	if not run.get("mode","") in ["shop","event","recovery"]: return _fail("Resolve this encounter before leaving.")
	run.mode="map"
	save()
	return _ok()

func _finish_run(won: bool) -> void:
	if run.get("finished",false): return
	_tick_time()
	run.finished=true
	run.mode="victory" if won else "defeat"
	if not run.get("seeded",false): profile.unlocks=mini(3,int(profile.unlocks)+1)
	profile.history.push_front({"id":run.id,"seed":run.seed,"seeded":run.get("seeded",false),"won":won,"region":run.region,"turns":run.turns,"battles":run.battles,"seconds":run.elapsed_seconds,"date":int(Time.get_unix_time_from_system()),"deck_size":run.deck.size(),"character":run.get("character","cartographer"),"route_regions":run.get("route_regions",[0,1,2]).duplicate()})
	if profile.history.size()>30: profile.history.resize(30)
	_log(run,"The signal answers. You are no longer alone." if won else "Your wake fades. Something remembers the route.")

func abandon() -> Dictionary:
	if run.is_empty() or run.get("finished",false): return _fail("There is no active expedition.")
	_finish_run(false)
	save()
	return _ok()

func _tick_time() -> void:
	var now=Time.get_ticks_msec()
	if not run.is_empty() and not run.get("finished",false) and _last_clock>0:
		var seconds=int((now-_last_clock)/1000)
		if seconds>0:
			run.elapsed_seconds=int(run.get("elapsed_seconds",0))+seconds
			_last_clock+=seconds*1000
	else: _last_clock=now

func save() -> bool:
	_tick_time()
	var result=store.write(profile,run)
	save_error=store.error
	return result

func set_settings(settings: Dictionary) -> void:
	for key in ["reduced_motion","fullscreen"]:
		if settings.has(key) and settings[key] is bool: profile.settings[key]=settings[key]
	for key in ["volume","music_volume","combat_volume","interface_volume"]:
		if settings.has(key) and (settings[key] is float or settings[key] is int) and is_finite(float(settings[key])):
			profile.settings[key]=clampf(float(settings[key]),0.0,1.0)
	save()

func run_exists() -> bool:
	return not run.is_empty() and not run.get("finished",false)

func load_saved() -> bool:
	store.primary_verified=false
	for candidate in store.candidates():
		var saved=candidate.data
		var legacy_expansion=not saved.run.has("character") and not saved.run.has("route_regions")
		if not saved.run.is_empty() and legacy_expansion:
			saved.run.character="cartographer"
			saved.run.route_regions=[0,1,2]
			if saved.run.get("battle") is Dictionary and not saved.run.battle.is_empty():
				var battle=saved.run.battle
				if not battle.has("trace"): battle.trace=0
				if not battle.has("last_payload"): battle.last_payload={}
				if not battle.has("resonance"): battle.resonance=0
				if not battle.has("last_command_kind"): battle.last_command_kind=""
		# Older combat saves prove only whether no card has been played this turn.
		if saved.run.get("mode","")=="combat" and saved.run.get("battle") is Dictionary:
			var battle=saved.run.battle
			if not battle.has("command_points") and not battle.has("max_command_points"):
				battle.max_command_points=3
				battle.command_points=3 if battle.get("first_play",false)==true else 0
		if not _valid_profile(saved.profile) or not _valid_run(saved.run):
			store.error="A save contains incomplete game data. Your existing files have been preserved."
			continue
		store.primary_verified=not candidate.backup
		profile=saved.profile
		run=_restore_integers(saved.run)
		_last_clock=Time.get_ticks_msec()
		if candidate.backup: save_error="Recovered your previous save from the backup."
		else: save_error=store.error
		return not run.is_empty()
	save_error=store.error
	return false

# JSON numbers reload as floats; route/pile equality requires integral game-state values.
func _restore_integers(value):
	if value is float: return int(value)
	if value is Array:
		var result=[]
		for item in value: result.append(_restore_integers(item))
		return result
	if value is Dictionary:
		var result={}
		for key in value: result[key]=_restore_integers(value[key])
		return result
	return value

func _number(value) -> bool: return (value is int or value is float) and is_finite(float(value)) and value==floor(value)

func _valid_instance(instance) -> bool:
	return instance is Dictionary and _cards.has(instance.get("id","")) and _number(instance.get("uid")) and _number(instance.get("level")) and int(instance.level) in [0,1]

func _valid_last_command(value) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not _valid_instance(value.get("card")): return false
	if value.get("kind")!=card(value.card.id).kind: return false
	for payload in ["base","resolved"]:
		if not value.get(payload) is Dictionary: return false
		for field in ["damage","heal","disrupt"]:
			if not _number(value[payload].get(field)) or value[payload][field]<0: return false
	return true

func _valid_itinerary(value) -> bool:
	if not value is Array or value.size()!=3: return false
	var seen=[]
	for area in value:
		if not _number(area) or int(area)<0 or int(area)>=catalog.regions.size() or int(area) in seen: return false
		seen.append(int(area))
	return true

func _valid_profile(value) -> bool:
	if not value is Dictionary or not _number(value.get("unlocks")) or not value.get("history") is Array or not value.get("settings") is Dictionary: return false
	if int(value.unlocks)<0 or int(value.unlocks)>3: return false
	if value.history.size()>30: return false
	for item in value.history:
		if not item is Dictionary: return false
		if not _number(item.get("seed")) and not (item.get("seed") is String and SeedEngine.valid(item.seed)): return false
		if item.has("seeded") and not item.seeded is bool: return false
		for key in ["region","turns","battles","seconds","date","deck_size"]:
			if not _number(item.get(key)): return false
		if not item.get("won") is bool: return false
		if item.has("character") and (not item.character is String or character(item.character).is_empty()): return false
		if item.has("route_regions") and not _valid_itinerary(item.route_regions): return false
	var settings=value.settings
	for key in ["music_volume","combat_volume","interface_volume"]:
		if not settings.has(key): continue # Existing profiles inherit full category volume.
		if not (settings[key] is float or settings[key] is int) or not is_finite(float(settings[key])) or float(settings[key])<0 or float(settings[key])>1: return false
	return settings.get("reduced_motion") is bool and settings.get("fullscreen") is bool and (settings.get("volume") is float or settings.get("volume") is int) and is_finite(float(settings.volume)) and float(settings.volume)>=0 and float(settings.volume)<=1

func _valid_run(value) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not value.get("character") is String or character(value.character).is_empty(): return false
	if not _valid_itinerary(value.get("route_regions")): return false
	if value.get("seed") is String:
		if not SeedEngine.valid_state(value): return false
	elif not _number(value.get("seed")) or value.has("rng_version") or value.has("rng_streams") or value.has("seeded") or value.has("pool_tier"): return false
	for key in ["region","layer","hull","max_hull","salvage","turns","started_at","elapsed_seconds","tutorial_step","next_uid","battles"]:
		if not _number(value.get(key)): return false
	if int(value.region)<0 or int(value.region)>2 or int(value.layer)<-1 or int(value.layer)>11: return false
	if int(value.hull)<0 or int(value.hull)>int(value.max_hull) or int(value.max_hull)<1 or int(value.max_hull)>1000: return false
	if not value.get("mode","") in MODES or not value.get("finished") is bool: return false
	for key in ["id","current_node","event_id","modify_return","modify_kind"]:
		if not value.get(key) is String: return false
	if not value.has("rng_version") and (not value.get("rng_state") is String or not value.rng_state.is_valid_int()): return false
	for key in ["deck","powerups","map","visited","log"]:
		if not value.get(key) is Array: return false
	if value.deck.size()<5 or value.deck.size()>200 or value.map.size()!=12: return false
	var uids=[]
	var originals={}
	for instance in value.deck:
		if not _valid_instance(instance) or instance.uid in uids: return false
		if card(instance.id).get("character","cartographer")!=value.character: return false
		uids.append(instance.uid)
		originals[int(instance.uid)]=instance
	for id in value.powerups:
		if not _powerups.has(id): return false
	for depth in range(12):
		if not value.map[depth] is Array or value.map[depth].is_empty() or value.map[depth].size()>4: return false
		for node in value.map[depth]:
			if not node is Dictionary or not node.get("id") is String or not _number(node.get("layer")) or int(node.layer)!=depth or not _number(node.get("column")): return false
			if not node.get("edges") is Array or not node.get("enemy_ids") is Array: return false
			if not node.get("type","") in ["battle","elite","event","shop","recovery","boss"]: return false
			for id in node.enemy_ids:
				if not _enemies.has(id): return false
	for key in ["battle","reward","shop"]:
		if not value.get(key) is Dictionary: return false
	if value.mode=="combat":
		var battle=value.battle
		for key in ["hand","draw","discard","enemies","strain","edges","severed","last_route"]:
			if not battle.get(key) is Array: return false
		if battle.strain.size()!=6 or battle.enemies.is_empty() or battle.enemies.size()>8 or battle.hand.size()>10: return false
		for key in ["capacity","ward","turn","mark","command_points","max_command_points","trace","resonance"]:
			if not _number(battle.get(key)): return false
		if int(battle.capacity)<1 or int(battle.capacity)>20: return false
		if int(battle.max_command_points)!=3 or int(battle.command_points)<0 or int(battle.command_points)>3: return false
		if int(battle.trace)<0 or int(battle.trace)>6 or int(battle.resonance)<0 or int(battle.resonance)>3: return false
		if not battle.get("last_payload") is Dictionary or not battle.get("last_command_kind") is String: return false
		if not _valid_last_command(battle.get("last_command",{})): return false
		if not battle.last_command_kind in ["","attack","repair","utility"]: return false
		for field in ["damage","heal","disrupt"]:
			if battle.last_payload.has(field) and (not _number(battle.last_payload[field]) or battle.last_payload[field]<0): return false
		if not battle.get("kind","") in ["battle","elite","boss"]: return false
		if not battle.get("first_play") is bool or not battle.get("emergency_used") is bool: return false
		for node in battle.last_route:
			if not _number(node) or node<0 or node>5: return false
		var piles=[]
		for key in ["hand","draw","discard"]:
			for instance in battle[key]:
				if not _valid_instance(instance) or not instance.uid in uids or instance.uid in piles: return false
				var original=originals[int(instance.uid)]
				if instance.id!=original.id or int(instance.level)!=int(original.level): return false
				piles.append(instance.uid)
		if piles.size()!=uids.size(): return false
		for strain in battle.strain:
			if not _number(strain) or strain<0 or strain>battle.capacity: return false
		for key in ["edges","severed"]:
			for edge in battle[key]:
				if not edge is Array or edge.size()!=2: return false
				for node in edge:
					if not _number(node) or node<0 or node>5: return false
		for foe in battle.enemies:
			if not foe is Dictionary or enemy(foe.get("id","")).is_empty() or not foe.get("name") is String or not foe.get("intent") is Dictionary: return false
			for key in ["hp","max_hp","disrupt","redirect","egg_timer"]:
				if not _number(foe.get(key)): return false
			if not foe.intent.get("label") is String: return false
			if not foe.intent.get("kind","") in ["attack","strain","sever","incubate","rebuild","mark"] or not _number(foe.intent.get("amount")): return false
			for field in ["armor","exposed","interrupt","overload"]:
				if foe.intent.has(field) and (not _number(foe.intent[field]) or foe.intent[field]<0 or foe.intent[field]>20): return false
			if foe.intent.has("drain") and not foe.intent.drain is bool: return false
	if value.mode=="reward":
		if not value.reward.get("choices") is Array or not value.reward.get("boss") is bool: return false
		for choice in value.reward.choices:
			if not choice is Dictionary or not choice.get("kind","") in ["card","powerup"]: return false
			if choice.kind=="card" and (not _cards.has(choice.get("id","")) or card(choice.id).get("character","cartographer")!=value.character): return false
			if choice.kind=="powerup" and not _powerups.has(choice.get("id","")): return false
	if value.mode=="shop" or (value.mode=="modify" and value.modify_return=="shop"):
		if not value.shop.get("items") is Array: return false
		for item in value.shop.items:
			if not item is Dictionary or not item.get("kind","") in ["card","powerup","remove","upgrade"] or not _number(item.get("cost")) or not item.get("sold") is bool or not item.get("id") is String: return false
			if item.kind=="card" and (not _cards.has(item.id) or card(item.id).get("character","cartographer")!=value.character): return false
			if item.kind=="powerup" and not _powerups.has(item.id): return false
	if value.mode=="modify":
		if not value.modify_return in ["shop","event","recovery"] or not value.modify_kind in ["upgrade","remove"]: return false
		if value.modify_return=="shop" and (not _number(value.get("modify_shop_index")) or int(value.modify_shop_index)<0 or int(value.modify_shop_index)>=value.shop.items.size()): return false
	return true
