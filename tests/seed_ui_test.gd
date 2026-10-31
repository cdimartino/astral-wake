extends SceneTree
const Main = preload("res://scripts/main.gd")
var ui
var checks := 0
var failures := 0

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR").path_join("astral-seed-ui-%d" % Time.get_ticks_usec()))
	check.call_deferred()

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(6): await process_frame

func check() -> void:
	ui = Main.new()
	root.add_child(ui)
	await settle()
	for viewport_size in [Vector2i(1440, 900), Vector2i(1100, 720)]:
		root.size = viewport_size
		ui._request_new()
		await settle()
		var input = ui.page.find_child("ExpeditionSeed", true, false)
		require(input != null and input.max_length == 6, "Six-character seed input available")
		require(root.get_visible_rect().encloses(input.get_global_rect()), "Seed input fits viewport")
		input.text = "b4ttle"
		input.text_changed.emit(input.text)
		ui.selected_character = "hollow_choir"
		ui._render()
		await settle()
		require(ui.page.find_child("ExpeditionSeed", true, false).text == "b4ttle", "Seed entry survives changing ships")
		if ui.game.run_exists(): ui.game.abandon()
		ui._begin_character_run()
		await settle()
		require(ui.game.run.seed == "B4TTLE" and ui.game.run.seeded and ui.game.run.character == "hollow_choir", "Seed and vessel reach the game engine")
		var original = ui.game.run.duplicate(true)
		ui._request_new()
		ui.expedition_seed = "BAD!12"
		ui._begin_character_run()
		require(ui.game.run == original and ui.overlay == null, "Invalid seed cannot replace the current game")
		ui.expedition_seed = "A1B2C3"
		ui._begin_character_run()
		await settle()
		require(ui.overlay != null and ui.game.run == original, "Seeded replacement still requires confirmation")
		ui._close_overlay()
		ui._new_run()
		await settle()
		require(ui.game.run.seed == "A1B2C3", "Confirmed replacement uses entered seed")
		for won in [false, true]:
			ui.game.new_run("B4TTLE", "hollow_choir")
			var first = ui.game.run.map.duplicate(true)
			ui.game._finish_run(won)
			ui.menu = false
			ui.choosing_character = false
			ui._render()
			await settle()
			var record = ui.page.find_child("ExpeditionRecord", true, false)
			require(record != null and record.text.contains("B4TTLE"), "Victory/defeat screen visibly displays six-character seed")
			var retry
			for button in ui.page.find_children("*", "Button", true, false):
				if button.text.begins_with("Retry seed"):
					retry = button
					require(root.get_visible_rect().encloses(button.get_global_rect()), "Retry button fits viewport")
			require(retry != null, "Finished run offers direct seeded retry")
			retry.pressed.emit()
			await settle()
			require(ui.game.run.seed == "B4TTLE" and ui.game.run.seeded and ui.game.run.map == first, "Retry restores original map and practice mode")
		ui._request_new()
		require(ui.expedition_seed.is_empty(), "Fresh normal expedition clears previous practice seed")
	print("SEED_UI_TESTS ", checks, " checks, ", failures, " failures")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	await settle()
	quit(1 if failures else 0)
