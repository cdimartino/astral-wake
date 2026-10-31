extends SceneTree
const Main = preload("res://scripts/main.gd")
var ui
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func start(ship: String, card_id: String) -> void:
	ui.game.new_run(2026, ship)
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.game.run.battle.hand = [{"id":card_id,"uid":1,"level":0}]
	ui.game.run.battle.enemies.resize(1)
	ui.game.run.hull -= 15
	ui.menu = false
	ui._clear_selection()

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-route-preview-%d" % Time.get_ticks_usec())
	check.call_deferred()

func check() -> void:
	ui = Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	start("palimpsest", "scar_note")
	ui.game.run.battle.trace = 1
	var before = ui.game.run.duplicate(true)
	var card_only = ui.game.preview_card(0, [], 0)
	require(not card_only.ok and card_only.trace == 2, "Card-only forecast missing or playable")
	var forecast = ui.game.preview_card(0, [3, 4, 5], 0)
	require(forecast.ok and forecast.trace == 0, "Incorrect final Trace")
	require(forecast.route_steps.map(func(step): return step.trace_after) == [1, 0, 0], "Trace did not flow through organs in order")
	require(forecast.route_steps.map(func(step): return step.status) == ["active", "active", "inactive"], "Rewrite appears powered without Trace")
	require(ui.game.run == before, "Preview mutated state or RNG")
	for size in [Vector2i(1440, 900), Vector2i(1100, 720)]:
		root.size = size
		for anatomy in [true, false]:
			ui.anatomy_view = anatomy
			ui.selected_card = 0
			ui.route.assign([3, 4, 5])
			ui._render()
			for unused in range(5): await process_frame
			require(ui.page.find_child("CharacterResource", true, false).text.contains("1 → 0"), "Resource readout ignores preview")
			require(ui.page.find_child("Organ5", true, false).get_meta("effect_status") == "inactive", "Inactive organ styling missing")
			require(ui.page.find_child("Organ3", true, false).get_meta("effect_status") == "active", "Active organ styling missing")
			if anatomy and size.x == 1440 and OS.get_cmdline_user_args().has("--capture"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/palimpsest-resource-preview.png")
	var played = ui.game.play_card(0, [3, 4, 5], 0)
	require(played.route_steps == forecast.route_steps and ui.game.run.battle.trace == forecast.trace, "Preview and resolution disagree")
	start("hollow_choir", "choral_bolt")
	ui.game.run.battle.resonance = 3
	ui.game.run.battle.last_command_kind = "attack"
	forecast = ui.game.preview_card(0, [0], 0)
	require(forecast.resonance == 0 and forecast.route_steps[0].status == "inactive", "Choir repeat reset or Conductor condition missing")
	start("hollow_choir", "warm_refrain")
	ui.game.run.battle.resonance = 1
	forecast = ui.game.preview_card(0, [3, 2], 0)
	require(forecast.route_steps[0].resonance_after == 3 and forecast.resonance == 0, "Rest/Crescendo flow incorrect")
	start("palimpsest", "first_draft")
	forecast = ui.game.preview_card(0, [1], 0)
	require(forecast.route_steps[0].status == "inactive", "Splice split fires against lone enemy")
	start("cartographer", "hull_stitch")
	for index in [0, 1, 5]:
		forecast = ui.game.preview_card(0, [index], 0)
		require(forecast.route_steps[0].status == "inactive", "Conditional Cartographer organ fires without effect")
	start("palimpsest", "margin_knife")
	forecast = ui.game.preview_card(0, [1], 0)
	require(forecast.route_steps[0].status == "fallback", "Splice fallback indistinguishable")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	print("ROUTE RESOURCE PREVIEW: ", failures, " failures")
	quit(1 if failures else 0)
