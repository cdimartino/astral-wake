extends SceneTree
const Main = preload("res://scripts/main.gd")
const Keywords = preload("res://scripts/keywords.gd")
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(5): await process_frame

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-keywords-%d" % Time.get_ticks_usec())
	check.call_deferred()

func check() -> void:
	var ui = Main.new()
	root.add_child(ui)
	await settle()
	for card in ui.game.catalog.cards:
		for keyword in Keywords.for_card(card): require(Keywords.DEFINITIONS.has(keyword), "Missing card definition: " + keyword)
	for ship in ui.game.catalog.characters:
		for organ in ship.organs:
			for keyword in Keywords.for_organ(organ.id): require(Keywords.DEFINITIONS.has(keyword), "Missing organ definition: " + keyword)
	require(Keywords.DEFINITIONS.Disruption.contains("half") and Keywords.DEFINITIONS.Resonance.contains("resets"), "Glossary omits rule limits")
	require(Keywords.DEFINITIONS.Rewrite.contains("upgraded base") and Keywords.DEFINITIONS["Split damage"].contains("not divided"), "Glossary misrepresents payload mechanics")
	for window in [Vector2i(1440, 900), Vector2i(1100, 720)]:
		root.size = window
		for id in ["cut_sentence", "carbon_breath", "overwrite", "bright_canon", "hushed_chord", "unbroken_song"]:
			var definition = ui.game.card(id)
			ui.game.new_run(2026, definition.get("character", "cartographer"))
			ui.game.choose_node(ui.game.run.map[0][0].id)
			ui.game.run.battle.hand = [{"id":id,"uid":1,"level":1}]
			ui.menu = false
			ui._clear_selection()
			ui._render()
			await settle()
			var card = ui.hand_buttons[0]
			require(not card is Main.CardTooltip and card.tooltip_text.is_empty(), "Combat hand does not expose unsolicited rich tooltips")
			card.grab_focus()
			await settle()
			require(not card is Main.CardTooltip, "Focus alone does not expose rich card details")
			ui._show_combat_detail("card", 0)
			await settle()
			var detail_labels: Array = ui.page.find_children("*", "Label", true, false)
			var detail_text := ""
			for label in detail_labels: detail_text += str(label.text) + "\n"
			for keyword in Keywords.for_card(definition): require(detail_text.contains(Keywords.DEFINITIONS[keyword]), "Explicit card back omits keyword: " + keyword)
			if id == "cut_sentence" and window.x == 1440 and OS.get_cmdline_user_args().has("--capture"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/card-keyword-definitions.png")
			ui._show_combat_detail("card", 0)
			await settle()
			ui.game.run.battle.command_points = 0
			ui._select_card(0)
			await settle()
			card = ui.hand_buttons[0]
			require(not card.disabled and card.focus_mode == Control.FOCUS_ALL and not card is Main.CardTooltip and ui.selected_card == -1 and ui.game.run.battle.command_points == 0, "Unaffordable card stays focusable and unselected without spending or auto tooltip")
			ui._open_deck()
			await settle()
			require(not card is Main.CardTooltip, "Combat card does not create a tooltip over deck overlay")
			var details = ui.overlay.find_children("*", "Button", true, false).filter(func(button): return button.get_meta("mcp_control", "") == "inspect_card")
			require(not details.is_empty(), "Deck lacks explicit keyboard-accessible Details control")
			ui._close_overlay()
	ui.hull_audio.stop_all()
	OS.delay_msec(200)
	ui.queue_free()
	await settle()
	print("KEYWORD TOOLTIPS: ", failures, " failures")
	quit(1 if failures else 0)
