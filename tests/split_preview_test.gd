extends SceneTree
const Main = preload("res://scripts/main.gd")
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-split-preview-%d" % Time.get_ticks_usec())
	check.call_deferred()

func check() -> void:
	var ui = Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	for ship in ["cartographer", "palimpsest", "hollow_choir"]:
		for count in [1, 2, 3]:
			ui.game.new_run(2026, ship)
			ui.game.choose_node(ui.game.run.map[0][0].id)
			var card_id: String = {"cartographer":"needle", "palimpsest":"first_draft", "hollow_choir":"choral_bolt"}[ship]
			ui.game.run.battle.hand = [{"id":card_id,"uid":1,"level":0}]
			ui.game.run.battle.trace = 2
			ui.game.run.battle.resonance = 2
			var enemy = ui.game.run.battle.enemies[0].duplicate(true)
			ui.game.run.battle.enemies.clear()
			for i in range(count):
				var foe = enemy.duplicate(true)
				foe.hp = 1 if i == 2 else int(foe.max_hp)
				foe.intent.armor = 1 if i == 1 else 0
				foe.intent.exposed = 0
				ui.game.run.battle.enemies.append(foe)
			ui.menu = false
			ui._clear_selection()
			ui.selected_card = 0
			ui.route.assign([1])
			var result = ui.game.preview_card(0, [1], 0)
			var breakdown = ui._damage_breakdown(result)
			require(result.ok and breakdown.secondary.size() == count - 1, "Missing split recipients")
			var total = int(breakdown.primary)
			for hit in breakdown.secondary: total += int(hit.amount)
			require(total == result.damage, "Damage accounting changed")
			var summary = ui._command_preview_summary(result)
			require(summary.begins_with("Damage %d" % int(breakdown.primary)), "Preview still labels aggregate as primary damage")
			require(summary.contains("Split") == (count > 1), "Spurious or missing split summary")
			if count == 3: require(summary.contains("/1"), "Capped secondary damage hidden: " + summary)
			for size in [Vector2i(1440, 900), Vector2i(1100, 720)]:
				root.size = size
				ui._render()
				for unused in range(5): await process_frame
				var label = ui.page.find_child("RoutePreviewSummary", true, false)
				require(label.text == summary and label.get_line_count() == 1, "Split preview layout is not compact")
				if ship == "palimpsest" and count == 2 and size.x == 1440 and OS.get_cmdline_user_args().has("--capture"):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://docs/screenshots/split-damage-preview.png")
			var played = ui.game.play_card(0, [1], 0)
			require(ui._damage_breakdown(played) == breakdown, "Preview differs from resolved split damage")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	print("SPLIT PREVIEW: ", failures, " failures")
	quit(1 if failures else 0)
