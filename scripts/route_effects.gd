extends RefCounted
## A closed set of printed effects, not an event/script language.

static func integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=low and value<=high

static func valid_definition(definition: Dictionary) -> bool:
	if definition.has("ward") and not integer(definition.ward,0,99): return false
	if definition.has("conditional_damage"):
		var spec=definition.conditional_damage
		if not spec is Dictionary or spec.size()!=2: return false
		if not spec.get("type") in ["novel_route","route_strain_two"] or not integer(spec.get("amount"),1,99): return false
		if definition.get("kind")!="attack" or not integer(definition.get("damage"),1,99): return false
	if definition.has("conditional_ward"):
		var spec=definition.conditional_ward
		if not spec is Dictionary or spec.size()!=2 or spec.get("type")!="prism_other_foe" or not integer(spec.get("amount"),1,99): return false
	if definition.has("route_cooling"):
		var spec=definition.route_cooling
		if not spec is Dictionary or spec.size()!=2 or spec.get("type")!="three_first" or not integer(spec.get("amount"),1,1): return false
	return true

static func damage(definition: Dictionary, battle: Dictionary, route: Array) -> int:
	if not definition.has("conditional_damage"): return 0
	var spec=definition.conditional_damage
	if spec.type=="novel_route": return int(spec.amount) if not route in battle.engine_routes else 0
	for index in route:
		if int(battle.strain[int(index)])==2: return int(spec.amount)
	return 0

static func ward(game, definition: Dictionary, battle: Dictionary, route: Array, target: int) -> int:
	var total=int(definition.get("ward",0))
	if not definition.has("conditional_ward"): return total
	var prism=false
	for index in route:
		if game.organ(int(index)).id=="prism": prism=true
	if prism:
		for i in range(battle.enemies.size()):
			if i!=target and int(battle.enemies[i].hp)>0: return total+int(definition.conditional_ward.amount)
	return total

static func cool(definition: Dictionary, battle: Dictionary, route: Array) -> Array:
	var removed=[0,0,0,0,0,0]
	if definition.has("route_cooling") and route.size()==3:
		var first=int(route[0])
		removed[first]=mini(int(battle.strain[first]),int(definition.route_cooling.amount))
		battle.strain[first]-=removed[first]
	return removed
