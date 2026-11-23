extends SceneTree
## Normal-speed chart-only review clip using one real seeded public projection.
## The run and its controller commits stay in a unique temporary save directory.
const Game = preload("res://scripts/game.gd")
const StarChartScript = preload("res://scripts/star_chart.gd")
const ChartStopView = preload("res://scripts/chart_stop_view.gd")
const OUT = "res://tests/artifacts/star-chart-motion-review-20261122"

var chart: StarChart
var game
var focus_id := ""

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var scratch := OS.get_environment("TMPDIR")
	if scratch.is_empty(): scratch = OS.get_cache_dir()
	var isolated_save := scratch.path_join("astral-star-chart-motion-%d" % Time.get_ticks_usec())
	game = Game.new(isolated_save)
	var result: Dictionary = game.new_run("NEBULA", "cartographer")
	if not result.get("ok", false):
		push_error("Could not create isolated voyage source fixture.")
		quit(1)
		return
	var projection: Dictionary = ChartStopView.project(game.run)
	var first_stop: Dictionary = {}
	for stop in projection.layers[0]:
		if stop.reachable:
			first_stop = stop
			break
	if first_stop.is_empty():
		push_error("Generated public map has no reachable first beacon.")
		quit(1)
		return
	var current_id := str(first_stop.id)
	var destination: Dictionary = {}
	for layer in projection.layers:
		for stop in layer:
			if stop.reachable and str(stop.id) != current_id:
				destination = stop
				break
		if not destination.is_empty():
			break
	if destination.is_empty():
		push_error("Generated public map has no reachable destination beyond the ship.")
		quit(1)
		return
	focus_id = str(destination.id)
	chart = StarChartScript.new()
	root.add_child(chart)
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chart.configure(projection, current_id, str(game.region().get("name", "Frontier")))
	for idle_frame in range(18):
		await create_timer(0.175).timeout
		await process_frame
		await _save("idle-%02d.png" % idle_frame)
	chart._on_beacon_focused(focus_id)
	for focus_frame in range(4):
		await create_timer(0.12).timeout
		await process_frame
		await _save("inspect-%02d.png" % focus_frame)
	chart.travel_requested.connect(func(node_id: String) -> void:
		chart.apply_committed_travel(current_id, node_id)
	)
	chart._request_travel()
	if not chart._traveling:
		push_error("Chart did not accept focused beacon %s: %s" % [focus_id, str(chart._node_by_id(focus_id))])
		quit(1)
		return
	for travel_frame in range(12):
		await create_timer(0.052).timeout
		await process_frame
		await _save("travel-%02d.png" % travel_frame)
	await create_timer(0.16).timeout
	await process_frame
	await _save("arrival.png")
	print("Normal-speed seeded public chart frames saved under tests/artifacts/star-chart-motion-review-20261122/")
	quit()

func _save(filename: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		push_error("No rendered viewport for motion review capture.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUT + "/" + filename)
	if texture.get_image().save_png(path) != OK:
		push_error("Could not save motion review frame.")
		quit(1)
