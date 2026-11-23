extends SceneTree

var failures := 0
var main

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var base := OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_cache_dir()
	var isolated := base.path_join("astral-chart-scene-" + Crypto.new().generate_random_bytes(16).hex_encode())
	if DirAccess.make_dir_recursive_absolute(isolated) != OK:
		quit(1)
		return
	OS.set_environment("ASTRAL_SAVE_DIR", isolated)
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_MCP_PORT", "")
	OS.set_environment("ASTRAL_MCP_TOKEN", "")
	call_deferred("run")

func act(action: String, index: int = 0) -> Dictionary:
	var state: Dictionary = main.mcp_controller.snapshot()
	return main.mcp_controller.request("act", {"action":action, "args":{"index":index}, "expected_revision":state.revision})

func options(action: String) -> Array:
	for entry in main.mcp_controller.snapshot().legal_actions:
		if entry.action == action: return entry.args.index.options
	return []

func public_state() -> Dictionary:
	var state: Dictionary = main.mcp_controller.snapshot().duplicate(true)
	state.erase("revision")
	return normalize_allocations(state)

func normalize_allocations(value):
	if value is Dictionary:
		var result := {}
		for key in value:
			if key in ["name", "control"] and value[key] is String and value[key].begins_with("@"):
				result[key] = value[key].get_slice("@", 1)
			else: result[key] = normalize_allocations(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(normalize_allocations(item))
		return result
	return value

func differences(a, b, path: String = "") -> void:
	if a == b: return
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key): print("DIFF ", path, "/", key, " missing")
			else: differences(a[key], b[key], path + "/" + str(key))
	elif a is Array and b is Array and a.size() == b.size():
		for i in range(a.size()): differences(a[i], b[i], path + "/" + str(i))
	else: print("DIFF ", path, ": ", str(a).left(250), " <> ", str(b).left(250))

# Capture rendered and assistive properties, metadata and resource identities;
# no screenshots or hidden roster-derived control fields are excluded.
func surface() -> Array:
	var output: Array = []
	for node in main.page.find_children("*", "", true, false):
		if not node is Control or not node.is_visible_in_tree(): continue
		var row := {"name":str(node.name), "metadata":{}}
		for key in node.get_meta_list(): row.metadata[str(key)] = node.get_meta(key)
		for property in node.get_property_list():
			var key: String = property.name
			if key in ["text", "tooltip_text"] or key.begins_with("accessibility_"):
				row[key] = node.get(key)
			if key in ["texture", "icon"]:
				var resource = node.get(key)
				row[key] = resource.resource_path if resource is Resource else ""
		output.append(row)
	return normalize_allocations(output)

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._request_new()
	check(act("begin_expedition").ok, "begin real scene")
	main.game.set_settings({"reduced_motion":true})
	var original: Dictionary = main.game.run.duplicate(true)
	var alternate := original.duplicate(true)
	for layer in alternate.map:
		for node in layer:
			if node.type in ["battle", "elite", "boss"]:
				node.enemies = ["FUTURE_ROSTER_CANARY", "OTHER_FUTURE_CANARY"]
			if node.type == "event": node.event_id = "FUTURE_EVENT_CANARY"
	main.game.run = original.duplicate(true)
	main._render()
	await process_frame
	var first_state := public_state()
	var first_surface := surface()
	var first_error: Dictionary = act("choose_node", -1)
	first_error.state.erase("revision")
	first_error = normalize_allocations(first_error)
	main.game.run = alternate.duplicate(true)
	main._render()
	await process_frame
	check(public_state() == first_state, "unvisited roster/event changes preserve entire public state")
	check(surface() == first_surface, "unvisited roster/event changes preserve text, tooltips, metadata, accessibility and resources")
	differences(first_state, public_state(), "state")
	differences(first_surface, surface(), "surface")
	var other_error: Dictionary = act("choose_node", -1)
	other_error.state.erase("revision")
	other_error = normalize_allocations(other_error)
	check(first_error == other_error, "failed actions preserve differential errors")
	# Inspect every beacon, including elites/bosses and reachable hostiles.
	for option in options("inspect_node"):
		var before: Dictionary = main.game.run.duplicate(true)
		check(act("inspect_node", option.index).ok, "inspect beacon")
		check(main.game.run == before, "inspection never commits travel")
		check(not JSON.stringify(public_state()).contains("CANARY"), "future identity absent while focused")
		check(not JSON.stringify(surface()).contains("CANARY"), "future identity absent from focused surface")
	# Restore real roster for accepted combat; focus the first reachable stop.
	main.game.run = original.duplicate(true)
	main._render()
	await process_frame
	var destination := ""
	for layer in main.game.run.map:
		for node in layer:
			if main.game.reachable(node):
				destination = node.id
				break
		if not destination.is_empty(): break
	for option in options("inspect_node"):
		if option.get("node_id", "") == destination:
			check(act("inspect_node", option.index).ok, "focus reachable signal")
			break
	check(not options("choose_node").is_empty(), "explicit travel advertised after focus")
	# Exercise an actual rules rejection after visible binding creation, not just
	# malformed protocol arguments. Re-render must unlock the chart for retry.
	var selected_node: Dictionary = main.game.run.map[0][0]
	for node in main.game.run.map[0]:
		if node.id == destination: selected_node = node
	var original_layer: int = selected_node.layer
	selected_node.layer = 99
	var visited_before: Array = main.game.run.visited.duplicate()
	check(act("choose_node").ok, "visible travel callback dispatched for rules rejection")
	check(main.game.run.visited == visited_before and not main.chart_travel_pending, "failed rules request does not commit or lock travel")
	selected_node.layer = original_layer
	main._render()
	await process_frame
	for option in options("inspect_node"):
		if option.get("node_id", "") == destination:
			check(act("inspect_node", option.index).ok, "refocus after rejected travel")
			break
	var old_revision: int = main.mcp_controller.snapshot().revision
	check(act("choose_node", -1).error.code == "invalid_args", "failed travel request rejects invalid index")
	check(act("choose_node").ok, "retry explicit travel accepted")
	check(main.game.run.current_node == destination and main.game.run.visited.count(destination) == 1, "travel commits exactly once")
	var stale: Dictionary = main.mcp_controller.request("act", {"action":"choose_node", "args":{}, "expected_revision":old_revision})
	check(stale.error.code == "stale_revision", "stale travel cannot repeat")
	await process_frame
	check(main.game.run.mode == "combat", "combat identity revealed only after travel commit")
	check(not main.mcp_controller.snapshot().run.battle.enemies.is_empty(), "arrived combat enemies public")
	check(act("select_card").ok, "existing card selection retained")
	await process_frame
	var selected: int = main.selected_card
	var route: Array = main.route.duplicate()
	# The visible contextual Details button is deliberately not an arbitrary UID setter.
	var card_details := options("inspect_card")
	check(not card_details.is_empty(), "visible card Details advertised")
	if not card_details.is_empty():
		check(card_details[0].has("card_uid"), "card inspection stable UID")
		var revision: int = main.mcp_controller.snapshot().revision
		check(act("inspect_card").ok, "card Details callback")
		check(main.mcp_controller.snapshot().revision > revision, "inspection changes revision")
		check(main.selected_card == selected and main.route == route, "inspection preserves combat staging")
		check(act("close_inspection").ok, "explicit close inspection")
	var organ_selection := act("select_organ")
	check(organ_selection.ok, "existing organ selection retained")
	var immediate_details: Array = []
	for entry in organ_selection.state.legal_actions:
		if entry.action == "inspect_organ": immediate_details = entry.args.index.options
	check(not immediate_details.is_empty(), "select_organ returned state immediately advertises visible organ Details without a frame wait")
	if not immediate_details.is_empty():
		check(not main.route.is_empty() and immediate_details[0].get("organ_index", -1) == main.route.back(), "immediate organ Details identity matches selected organ")
	check(main.detail_kind == "", "normal organ selection does not automatically open inspection")
	var organ_details := options("inspect_organ")
	check(not organ_details.is_empty(), "visible organ Details advertised")
	if not organ_details.is_empty():
		check(organ_details[0].has("organ_index"), "organ inspection stable index")
		check(not main.route.is_empty() and organ_details[0].get("organ_index", -1) == main.route.back(), "organ Details identity matches selected route organ")
		var staged_route: Array = main.route.duplicate()
		var preview_before: Dictionary = main.mcp_controller.request("preview", {}).result
		check(act("inspect_organ").ok, "organ Details callback")
		check(main.route == staged_route and main.mcp_controller.request("preview", {}).result == preview_before, "organ inspection preserves staged route and preview")
		check(act("close_inspection").ok, "close organ inspection")
	check(main.mcp_controller.request("preview", {}).ok, "staged combat preview retained")
	main.queue_free()
	await process_frame
	print("Chart scene projection tests: ", failures, " failures")
	quit(1 if failures else 0)
