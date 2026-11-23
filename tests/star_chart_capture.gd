extends SceneTree
## Source-only render fixture. It never boots or mutates a player expedition.
const StarChartScript = preload("res://scripts/star_chart.gd")
const ChartStopView = preload("res://scripts/chart_stop_view.gd")
const OUT = "res://tests/artifacts/star-chart-slice"

var chart: Control

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	chart = StarChartScript.new()
	root.add_child(chart)
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chart.configure(ChartStopView.project(_fixture()), "L05C1", "GLASS BEYOND")
	chart._on_beacon_focused("L06C0")
	await _settle()
	await _shot("01-focus.png")
	chart.apply_committed_travel("L05C1", "L06C0")
	for frame_index in range(11):
		await create_timer(0.055).timeout
		await _settle()
		await _shot("motion-%02d.png" % frame_index)
	await create_timer(0.1).timeout
	await _settle()
	await _shot("03-arrival.png")
	DisplayServer.window_set_size(Vector2i(1100, 720))
	await create_timer(0.1).timeout
	await _settle()
	await _shot("04-arrival-1100x720.png")
	print("StarChart source screenshots saved under tests/artifacts/star-chart-slice/")
	quit()

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _shot(filename: String) -> void:
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("No rendered viewport texture; run this with the windowed renderer.")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUT + "/" + filename))
	if error != OK:
		push_error("Could not save " + filename)
		quit(1)

func _fixture() -> Dictionary:
	var map: Array = []
	for layer in range(12):
		var stops: Array = []
		for column in range(3):
			var id := "L%02dC%d" % [layer, column]
			var edges: Array[String] = []
			if layer < 11:
				edges.append("L%02dC%d" % [layer + 1, maxi(0, column - 1)])
				edges.append("L%02dC%d" % [layer + 1, column])
			var kinds := ["recovery", "shop", "event", "battle", "elite", "boss"]
			stops.append({
				"id": id, "layer": layer, "column": column,
				"type": kinds[(layer + column) % kinds.size()],
				"edges": edges, "enemy_ids": ["fixture-hidden-roster"],
			})
		map.append(stops)
	return {
		"mode": "map", "layer": 5, "current_node": "L05C1",
		"visited": ["L00C1", "L01C1", "L02C1", "L03C1", "L04C1", "L05C1"],
		"pending_selection": {}, "map": map,
	}
