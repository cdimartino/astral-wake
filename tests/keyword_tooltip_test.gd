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
			require(card is Main.CardTooltip, "Hand still uses plain repeating tooltip")
			for keyword in Keywords.for_card(definition): require(card.explanation.contains(Keywords.DEFINITIONS[keyword]), "Relevant keyword omitted")
			card.grab_focus()
			await settle()
			require(is_instance_valid(card.focus_tip) and root.get_visible_rect().grow(1).encloses(card.focus_tip.get_global_rect()), "Focused keyword panel leaves viewport")
			if id == "cut_sentence" and window.x == 1440 and OS.get_cmdline_user_args().has("--capture"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/card-keyword-definitions.png")
			var hover = card._make_custom_tooltip("")
			require(hover.find_children("*", "RichTextLabel", true, false).size() == 1, "Hover does not show rich definitions")
			hover.free()
			ui.game.run.battle.command_points = 0
			ui._select_card(0)
			await settle()
			card = ui.hand_buttons[0]
			require(card.disabled and is_instance_valid(card.focus_tip) and ui.selected_card == -1, "Unaffordable card cannot be inspected safely")
			ui._open_deck()
			await settle()
			require(not is_instance_valid(card.focus_tip), "Card tooltip obscures deck overlay")
			var headings = ui.overlay.find_children("*", "Button", true, false).filter(func(button): return button is Main.CardTooltip)
			require(not headings.is_empty(), "Deck lacks keyboard keyword inspection")
			ui._close_overlay()
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	await settle()
	print("KEYWORD TOOLTIPS: ", failures, " failures")
	quit(1 if failures else 0)
