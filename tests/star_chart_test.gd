extends SceneTree

const StarChartScript = preload("res://scripts/star_chart.gd")
const ChartStopView = preload("res://scripts/chart_stop_view.gd")
const Game = preload("res://scripts/game.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)
	var first := _fixture(["secret-a"], "boss")
	var second := _fixture(["secret-b", "secret-c"], "boss")
	var projected_a: Dictionary = ChartStopView.project(first)
	var projected_b: Dictionary = ChartStopView.project(second)
	_check(projected_a == projected_b, "public model differs for hidden enemy rosters")

	var chart := StarChartScript.new()
	root.add_child(chart)
	chart.size = Vector2(1440, 900)
	chart.configure(projected_a, "n0", "Glass Beyond")
	await process_frame
	var focused: Array[String] = []
	var requested: Array[String] = []
	var arrivals: Array[String] = []
	var commits: Array[String] = []
	chart.focus_node.connect(func(id: String) -> void: focused.append(id))
	chart.travel_requested.connect(func(id: String) -> void: requested.append(id))
	chart.travel_presentation_finished.connect(func(id: String) -> void: arrivals.append(id))
	chart.travel_committed.connect(func(from_id: String, to_id: String) -> void: commits.append("%s>%s" % [from_id, to_id]))

	var hovered_beacon := await _move_to(chart._buttons["n1"])
	_check(hovered_beacon == chart._buttons["n1"], "real pointer could not hover beacon")
	await _click(chart._buttons["n1"])
	_check(focused == ["n1"], "pointer focus did not emit focus_node")
	_check(requested.is_empty(), "focus unexpectedly requested travel")
	_check(chart.is_inspection_open(), "keyboard focus did not open inspection")
	_check(chart._close_button.get_meta("mcp_control") == "close_inspection", "inspection close MCP action metadata mismatch")
	var hovered_close := await _move_to(chart._close_button)
	_check(hovered_close == chart._close_button, "full-rect layer blocked the Close hit target")
	await _click(chart._close_button)
	_check(not chart.is_inspection_open(), "Close did not hide the public readout")
	_check(chart._focused_id.is_empty(), "Close left the focus highlight active")
	_check(chart._current_id == "n0" and requested.is_empty(), "Close mutated location or requested travel")
	chart._buttons["n1"].grab_focus()
	await process_frame
	_check(chart.is_inspection_open(), "keyboard focus did not reopen inspection")
	chart.close_inspection()
	var hovered_other := await _move_to(chart._buttons["n0"])
	_check(hovered_other == chart._buttons["n0"], "pointer could not move onto beacon after Close")
	_check(chart.is_inspection_open(), "hover did not reopen inspection")
	_check(chart._focused_id == "n0", "hover reopen did not update public focus")
	_check(chart._current_id == "n0" and requested.is_empty(), "reopen inspection requested travel")
	await _move_to(chart._buttons["n1"])
	_check(chart._buttons["n1"].get_meta("mcp_control") == "inspect_node", "beacon MCP action metadata mismatch")
	_check(chart._buttons["n1"].get_meta("node_id") == "n1", "beacon target metadata mismatch")
	_check(chart._travel_button.get_meta("mcp_control") == "choose_node", "travel control metadata mismatch")
	_check(chart._travel_button.get_meta("node_id") == "n1", "travel target metadata mismatch")
	var hovered_travel := await _move_to(chart._travel_button)
	_check(hovered_travel == chart._travel_button, "full-rect layer blocked the Travel hit target")
	await _click(chart._travel_button)
	chart._request_travel()
	_check(requested == ["n1"], "explicit travel emitted more than once")
	_check(chart._current_id == "n0", "request mutated current location before commit")

	chart.apply_committed_travel("n0", "n1")
	_check(commits == ["n0>n1"], "commit phase signal did not emit once")
	_check(chart._current_id == "n0", "departure presentation changed location before arrival")
	chart.skip_travel()
	_check(chart._current_id == "n1", "skipping committed presentation did not arrive")
	chart.skip_travel()
	_check(chart._current_id == "n1", "second skip mutated location")
	chart.configure(ChartStopView.project(_long_fixture()), "L05C1", "Glass Beyond")
	await process_frame
	_check(chart._buttons.size() == 36, "full 12-layer fixture lost stops")
	chart._buttons["L06C0"].grab_focus()
	await process_frame
	var hovered_recenter := await _move_to(chart._recenter_button)
	_check(hovered_recenter == chart._recenter_button, "Recenter was not a physical pointer target")
	await _click(chart._recenter_button)
	_check(chart._focused_id == "L05C1", "recenter did not return signal readout to ship")
	_check(requested.size() == 1, "recenter unexpectedly requested travel")
	for viewport in [Vector2(1440, 900), Vector2(1100, 720)]:
		DisplayServer.window_set_size(Vector2i(viewport))
		chart.size = viewport
		root.size = Vector2i(viewport)
		for _frame in range(3): await process_frame
		var beacons: Array = chart._buttons.values()
		for i in range(beacons.size()):
			_check(Rect2(Vector2.ZERO, viewport).encloses(beacons[i].get_rect()), "beacon outside chart bounds")
			for j in range(i + 1, beacons.size()):
				_check(not beacons[i].get_rect().intersects(beacons[j].get_rect()), "full-chart beacon hit targets overlap")
	for seed in ["NEBULA", "VOYAGE", "HULL07"]:
		var real_map := _generated_public_map(seed)
		for viewport in [Vector2(1440, 900), Vector2(1100, 720)]:
			DisplayServer.window_set_size(Vector2i(viewport))
			root.size = Vector2i(viewport)
			chart.size = viewport
			chart.configure(real_map.projection, "", real_map.region)
			for _frame in range(3): await process_frame
			_check(chart._buttons.size() == real_map.stop_count, "generated public map lost stops")
			_check(_layout_is_clear(chart, viewport), "generated map hit targets overlap or clip at %s" % str(viewport))
			var start_stop: Dictionary = {}
			for stop in real_map.projection.layers[0]:
				if stop.reachable:
					start_stop = stop
					break
			if start_stop.is_empty():
				_check(false, "generated starting layer has no reachable beacon")
				continue
			chart.close_inspection()
			var beacon: Button = chart._buttons[start_stop.id]
			_check(await _move_to(beacon) == beacon, "generated beacon was not the actual hovered control")
			await _click(beacon)
			_check(chart.is_inspection_open(), "generated beacon click did not inspect")
			var close_button: Button = chart._close_button
			_check(await _move_to(close_button) == close_button, "generated-map Close hit target was occluded")
			await _click(close_button)
			_check(not chart.is_inspection_open(), "generated-map Close did not dismiss")
			chart._on_beacon_focused(str(start_stop.id))
			_check(await _move_to(chart._travel_button) == chart._travel_button, "generated-map Travel hit target was occluded")
			await _click(chart._travel_button)
			_check(requested.back() == str(start_stop.id), "generated-map Travel clicked the wrong node")
			chart.reject_travel_request()
			var request_count_before_recenter := requested.size()
			var hovered_seed_recenter := await _move_to(chart._recenter_button)
			_check(hovered_seed_recenter == chart._recenter_button, "generated-map Recenter was not reachable by pointer")
			await _click(chart._recenter_button)
			_check(chart._current_id.is_empty(), "Recenter changed the generated current location")
			_check(requested.size() == request_count_before_recenter, "Recenter requested travel")
		DisplayServer.window_set_size(Vector2i(1440, 900))
		root.size = Vector2i(1440, 900)
	chart.configure(ChartStopView.project(_long_fixture()), "L05C1", "Glass Beyond")
	await process_frame
	chart.set_reduced_motion(true)
	chart.apply_committed_travel("L05C1", "L06C1")
	_check(chart._current_id == "L06C1", "reduced-motion arrival did not update after commit")
	_check(arrivals == ["n1", "L06C1"], "arrival completion was not emitted exactly once per commit")
	_check(commits == ["n0>n1", "L05C1>L06C1"], "commit phase signal repeated or exposed extra data")
	chart.queue_free()
	print("StarChart tests: %s failures" % failures)
	quit(1 if failures else 0)

func _fixture(enemy_ids: Array, type: String) -> Dictionary:
	return {
		"mode": "map",
		"layer": 0,
		"current_node": "n0",
		"visited": ["n0"],
		"pending_selection": {},
		"map": [
			[{"id":"n0","layer":0,"column":0,"type":"recovery","edges":["n1"]}],
			[{"id":"n1","layer":1,"column":0,"type":type,"edges":[],
				"enemy_ids":enemy_ids,"enemy_roster":enemy_ids.duplicate()}],
		],
	}

func _long_fixture() -> Dictionary:
	var map: Array = []
	for layer in range(12):
		var stops: Array = []
		for column in range(3):
			var edges: Array[String] = []
			if layer < 11:
				edges.append("L%02dC%d" % [layer + 1, column])
			stops.append({
				"id":"L%02dC%d" % [layer, column], "layer":layer,
				"column":column, "type":"battle", "edges":edges,
			})
		map.append(stops)
	return {
		"mode":"map", "layer":5, "current_node":"L05C1",
		"visited":["L00C1","L01C1","L02C1","L03C1","L04C1","L05C1"],
		"pending_selection":{}, "map":map,
	}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _move_to(control: Control) -> Control:
	var center := control.get_global_rect().get_center()
	var event := InputEventMouseMotion.new()
	event.position = center
	event.global_position = center
	get_root().push_input(event, true)
	await process_frame
	var hovered: Control = get_root().gui_get_hovered_control()
	if hovered != control:
		print("POINTER_MISS target=%s rect=%s hovered=%s path=%s filter=%s visible=%s root=%s viewport=%s chart=%s" % [
			control.name, str(control.get_global_rect()),
			str(hovered.name if is_instance_valid(hovered) else "<none>"),
			str(hovered.get_path() if is_instance_valid(hovered) else "<none>"),
			str(hovered.mouse_filter if is_instance_valid(hovered) else -1),
			str(hovered.visible if is_instance_valid(hovered) else false),
			str(root.size), str(root.get_viewport().size), str((control.get_parent() as Control).size),
		])
		if control is Button:
			print("POINTER_CHILD path=%s pos=%s filter=%s disabled=%s visible=%s local=%s transform=%s parent_rect=%s" % [
				control.get_path(), str(control.position), str(control.mouse_filter),
				str(control.disabled), str(control.is_visible_in_tree()),
				str(control.get_local_mouse_position()), str(control.get_global_transform_with_canvas()),
				str(control.get_parent().get_global_rect()),
			])
			print("POINTER_TRANSFORMS window=%s final=%s viewport_final=%s screen_scale=%s" % [
				str(DisplayServer.window_get_size()), str(root.get_final_transform()),
				str(get_root().get_final_transform()), str(DisplayServer.screen_get_scale()),
			])
	return hovered

func _click(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = center
	down.global_position = center
	down.pressed = true
	get_root().push_input(down, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = center
	up.global_position = center
	up.pressed = false
	get_root().push_input(up, true)
	await process_frame

func _generated_public_map(seed: String) -> Dictionary:
	var save_dir := OS.get_environment("TMPDIR").path_join("star-chart-pointer-%s-%d" % [seed, Time.get_ticks_usec()])
	var game = Game.new(save_dir)
	var result: Dictionary = game.new_run(seed, "cartographer")
	if not result.get("ok", false):
		_check(false, "could not create isolated seeded map fixture")
		return {}
	var public_projection: Dictionary = ChartStopView.project(game.run)
	var count := 0
	for layer in public_projection.layers: count += layer.size()
	return {
		"projection": public_projection,
		"region": str(game.region().get("name", "Frontier")),
		"stop_count": count,
	}

func _layout_is_clear(chart: StarChart, viewport: Vector2) -> bool:
	var beacons: Array = chart._buttons.values()
	for i in range(beacons.size()):
		var rect: Rect2 = beacons[i].get_global_rect()
		if not Rect2(Vector2.ZERO, viewport).encloses(rect):
			return false
		if rect.intersects(chart._panel.get_global_rect()):
			return false
		for j in range(i + 1, beacons.size()):
			if rect.intersects(beacons[j].get_global_rect()):
				return false
	return true
