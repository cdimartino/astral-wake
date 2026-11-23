extends RefCounted

# The sole chart disclosure boundary. Never copy arbitrary authored stop data.
static func project(run: Dictionary) -> Dictionary:
	var layers: Array = []
	var outgoing: Array = []
	for layer in run.get("map", []):
		for node in layer:
			if node.get("id", "") == run.get("current_node", ""):
				outgoing = node.get("edges", [])
	for layer in run.get("map", []):
		var visible: Array = []
		for node in layer:
			var stop := {}
			for key in ["id", "layer", "column", "type", "edges"]:
				if node.has(key): stop[key] = node[key]
			stop = stop.duplicate(true)
			stop["reachable"] = run.get("mode", "") == "map" and run.get("pending_selection", {}).is_empty() and (int(node.get("layer", -2)) == 0 if int(run.get("layer", -1)) == -1 else node.get("id", "") in outgoing)
			stop["visited"] = node.get("id", "") in run.get("visited", [])
			stop["label"] = stop_label(stop)
			stop["description"] = stop_description(stop)
			visible.append(stop)
		layers.append(visible)
	return {"layers":layers}

static func stop_label(stop: Dictionary) -> String:
	match str(stop.get("type", "")):
		"battle": return "Hostile signal"
		"elite": return "High-risk contact"
		"boss": return "Guardian signal"
		"event": return "Unknown signal"
		"shop": return "Trading signal"
		"recovery": return "Safe harbor"
	return "Unknown signal"

static func stop_description(stop: Dictionary) -> String:
	return "%s · %s" % [stop_label(stop), "Visited" if stop.get("visited", false) else "Reachable" if stop.get("reachable", false) else "Not reachable"]
