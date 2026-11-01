extends RefCounted
## Printed stat replacements only. No executable effects or nested definitions.
const LEGACY = "legacy"
const STATS = ["cost", "damage", "heal", "vent", "disrupt", "draw", "trace", "resonance"]

static func valid_definition(definition: Dictionary) -> bool:
	if not definition.has("evolutions"): return true
	var branches = definition.evolutions
	if not branches is Array or branches.size()!=2: return false
	var ids=[]
	for branch in branches:
		if not branch is Dictionary or branch.size()!=4: return false
		if not branch.get("id") is String or branch.id.is_empty() or branch.id==LEGACY or branch.id in ids: return false
		if not branch.id.is_valid_identifier() or branch.id!=branch.id.to_lower(): return false
		if not branch.get("name") is String or branch.name.strip_edges().is_empty(): return false
		if not branch.get("description") is String or branch.description.strip_edges().is_empty(): return false
		if not branch.get("stats") is Dictionary or branch.stats.is_empty(): return false
		for key in branch.stats:
			var value=branch.stats[key]
			if not key in STATS or not (value is int or value is float): return false
			if not is_finite(float(value)) or value!=floor(value) or value<0 or value>99: return false
			if key=="cost" and not int(value) in [1,2]: return false
			if key=="trace" and (definition.get("character","")!="palimpsest" or value>6): return false
			if key=="resonance" and (definition.get("character","")!="hollow_choir" or value>3): return false
		if definition.kind=="attack" and branch.stats.get("damage",definition.get("damage",0))<=0: return false
		if definition.kind=="repair" and branch.stats.get("heal",definition.get("heal",0))<=0: return false
		ids.append(branch.id)
	return true

static func branch(definition: Dictionary, id: String) -> Dictionary:
	for choice in definition.get("evolutions",[]):
		if choice.id==id: return choice
	return {}

static func valid_instance(definition: Dictionary, instance: Dictionary) -> bool:
	var identity=instance.get("evolution", "")
	if not identity is String: return false
	if instance.level==0: return identity.is_empty()
	return identity==LEGACY or not branch(definition,identity).is_empty()
