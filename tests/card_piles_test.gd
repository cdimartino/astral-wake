extends SceneTree
const Main = preload("res://scripts/main.gd")
const Game = preload("res://scripts/game.gd")
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(5): await process_frame

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-piles-%d" % Time.get_ticks_usec())
	check.call_deferred()

func check() -> void:
	var ui = Main.new()
	root.add_child(ui)
	await settle()
	for ship in ["cartographer", "palimpsest", "hollow_choir"]:
		for reduced in [false, true]:
			ui.game.new_run(2026, ship)
			ui.game.choose_node(ui.game.run.map[0][0].id)
			ui.game.profile.settings.reduced_motion = reduced
			ui.game.run.battle.discard = ui.game.run.battle.draw.duplicate(true)
			ui.game.run.battle.draw.clear()
			ui.menu = false
			ui._clear_selection()
			ui._render()
			await settle()
			ui._end_turn()
			var records = ui.last_feedback
			require(records.filter(func(cue): return cue.kind == "discard_card").size() == 5, "Missing discard animations")
			require(records.filter(func(cue): return cue.kind == "draw_card").size() == 5, "Missing draw animations")
			require(records.filter(func(cue): return cue.kind == "shuffle").size() == 1, "Missing reshuffle")
			if ship == "cartographer" and not reduced and OS.get_cmdline_user_args().has("--capture"):
				await create_timer(0.18).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/card-discard-animation.png")
				var draw_cue = records.filter(func(cue): return cue.kind == "draw_card")[0]
				await create_timer(maxf(0.01, float(draw_cue.delay) - 0.18 + 0.15)).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/card-draw-animation.png")
			ui._select_card(0)
			require(ui.selected_card == -1, "Input accepted during card movement")
			var deadline := Time.get_ticks_msec() + 10000
			while ui.presentation_busy() and Time.get_ticks_msec() < deadline: await process_frame
			require(not ui.presentation_busy(), "Card sequence never completed")
			await settle()
			for pile in ["draw", "discard"]:
				var button = ui.page.find_child("DrawPile" if pile == "draw" else "DiscardPile", true, false)
				require(button.text.ends_with(str(ui.game.run.battle[pile].size())), "Pile counter differs from rules")
			var restored = Game.new(OS.get_environment("ASTRAL_SAVE_DIR"))
			require(restored.run.battle.hand == ui.game.run.battle.hand and restored.run.battle.draw == ui.game.run.battle.draw, "Presentation changed saved draw order")
			ui._end_turn()
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			ui._input(escape)
			require(not ui.presentation_busy(), "Escape does not skip card movement")
			await settle()
			ui.game.run.battle.hand = ui.game.run.deck.duplicate(true)
			ui._render()
			for window in [Vector2i(1440, 900), Vector2i(1100, 720)]:
				root.size = window
				for i in range(10):
					ui.hover_card = i
					ui._arrange_hand()
					await settle()
					for name in ["DrawPile", "DiscardPile"]:
						var pile = ui.page.find_child(name, true, false)
						require(not pile.get_global_rect().intersects(ui.hand_buttons[i].get_global_rect()), "Raised card obscures a pile")
			var events: Array = []
			ui.game._draw(ui.game.run, 3, events)
			require(events.is_empty(), "Hand-limit draw emitted phantom cards")
	ui.game.new_run(2026)
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.game.run.hull = 1
	for enemy in ui.game.run.battle.enemies: enemy.intent = {"kind":"attack","amount":999,"label":"Defeat fixture"}
	var defeat = ui.game.end_turn()
	require(ui.game.run.mode == "defeat" and defeat.presentation.filter(func(event): return event.kind == "draw_card").is_empty(), "Cards drawn after combat ended")
	ui.game.new_run(2026)
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.game.run.battle.hand = [{"id":"cold_breath","uid":999,"level":0}]
	var forecast = ui.game.preview_card(0, [0], 0)
	var committed = ui.game.play_card(0, [0], 0)
	require(forecast.presentation == committed.presentation and committed.presentation.any(func(event): return event.kind == "draw_card"), "Command-driven draw records differ from preview")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	await settle()
	print("CARD PILES: ", failures, " failures")
	quit(1 if failures else 0)
