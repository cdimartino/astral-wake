extends SceneTree
## Three actual seeded public-map projections for design review. Every run writes
## only to a fresh temporary save directory; chart input is the allowlisted view.
const Game = preload("res://scripts/game.gd")
const StarChartScript = preload("res://scripts/star_chart.gd")
const ChartStopView = preload("res://scripts/chart_stop_view.gd")
const OUT = "res://tests/artifacts/star-chart-variants"
const SEEDS := ["NEBULA", "VOYAGE", "HULL07"]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for seed in SEEDS:
		var save_dir := OS.get_user_data_dir().path_join("star-chart-review-%s-%d" % [seed, Time.get_ticks_usec()])
		var isolated_game = Game.new(save_dir)
		var result: Dictionary = isolated_game.new_run(seed, "cartographer")
		if not result.get("ok", false):
			push_error("Could not create isolated chart fixture.")
			quit(1)
			return
		var chart: Control = StarChartScript.new()
		root.add_child(chart)
		chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chart.configure(
			ChartStopView.project(isolated_game.run),
			str(isolated_game.run.get("current_node", "")),
			str(isolated_game.region().get("name", "Frontier")),
		)
		for _frame in range(4):
			await process_frame
		var texture := root.get_texture()
		if texture == null:
			push_error("No rendered viewport for chart review capture.")
			quit(1)
			return
		var path := ProjectSettings.globalize_path(OUT + "/" + seed.to_lower() + ".png")
		if texture.get_image().save_png(path) != OK:
			push_error("Could not save public chart view.")
			quit(1)
			return
		chart.queue_free()
		await process_frame
		isolated_game = null
	print("Three isolated seeded public chart views saved in tests/artifacts/star-chart-variants/")
	quit()
