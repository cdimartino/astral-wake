extends SceneTree
const Main = preload("res://scripts/main.gd")
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(5): await process_frame

func canvas_z(node: CanvasItem) -> int:
	var result := node.z_index
	if node.z_as_relative and node.get_parent() is CanvasItem: result += canvas_z(node.get_parent())
	return result

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-overlay-%d" % Time.get_ticks_usec())
	check.call_deferred()

func check() -> void:
	var ui = Main.new()
	root.add_child(ui)
	await settle()
	for window in [Vector2i(1440, 900), Vector2i(1100, 720)]:
		root.size = window
		for ship in ["cartographer", "palimpsest", "hollow_choir"]:
			ui.game.new_run(2026, ship)
			ui.game.choose_node(ui.game.run.map[0][0].id)
			ui.game.run.battle.hand = ui.game.run.deck.duplicate(true)
			ui.game.run.battle.draw.clear()
			ui.menu = false
			for raised in [-1, 0, 9]:
				ui._clear_selection()
				ui._render()
				if raised >= 0:
					ui._select_card(raised)
					ui.hover_card = raised
					ui._arrange_hand()
				var before = ui.game.run.duplicate(true)
				var selected = ui.selected_card
				ui._open_deck()
				await settle()
				require(ui.page.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED, "Deck allows underlying keyboard focus")
				require(root.gui_get_focus_owner() != null and ui.overlay.is_ancestor_of(root.gui_get_focus_owner()), "Deferred combat focus escapes the deck overlay")
				for hand in ui.hand_buttons:
					require(canvas_z(ui.overlay) > canvas_z(hand), "Hand draws above deck overlay")
				var scroll = ui.overlay.find_children("*", "ScrollContainer", true, false)[0]
				scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
				await settle()
				var grid = scroll.find_children("*", "GridContainer", true, false)[0]
				var last_card = grid.get_child(grid.get_child_count() - 1)
				require(scroll.get_global_rect().grow(1).encloses(last_card.get_global_rect()), "Final deck card cannot be scrolled fully into view")
				for code in [KEY_1, KEY_E, KEY_SPACE]:
					var event := InputEventKey.new()
					event.pressed = true
					event.keycode = code
					ui._input(event)
				require(ui.selected_card == selected and ui.game.run == before, "Deck overlay permits combat input")
				ui._close_overlay()
				require(ui.overlay == null and ui.page.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_INHERITED, "Closing deck does not restore interaction")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	await settle()
	print("DECK OVERLAY: ", failures, " failures")
	quit(1 if failures else 0)
