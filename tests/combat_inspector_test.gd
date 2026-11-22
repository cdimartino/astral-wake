extends SceneTree
const Main = preload("res://scripts/main.gd")
var failures := 0
var directory := OS.get_environment("TMPDIR").path_join("combat-inspector-%d" % Time.get_ticks_usec())
var screenshots := OS.get_environment("ASTRAL_INSPECTOR_SHOTS")

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(5): await process_frame

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", directory)
	if not screenshots.is_empty(): root.borderless = true
	check.call_deferred()

func click(ui, control: Control, button: int) -> void:
	var point := control.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = point
	event.global_position = point
	if root.size.x < 1400:
		# Headless Window.resize changes the canvas transform but does not move
		# the OS pointer surface. Feed the real hit-test path the transformed
		# control point; left activation still goes through Button.pressed.
		if button == MOUSE_BUTTON_RIGHT:
			ui._input(event)
		else:
			control.emit_signal("pressed")
	else:
		root.push_input(event)
		event.pressed = false
		root.push_input(event)

func check() -> void:
	if not screenshots.is_empty(): DirAccess.make_dir_recursive_absolute(screenshots)
	var ui = Main.new()
	root.add_child(ui)
	await settle()
	ui.game.new_run(2101, "hollow_choir")
	ui.game.run.route_regions = [5, 4, 0]
	var first_battle: Dictionary = {}
	for node in ui.game.run.map[0]:
		if ui.game.reachable(node) and node.type in ["battle", "elite", "boss"]:
			first_battle = node
			break
	require(not first_battle.is_empty(), "Fixture provides a reachable battle")
	ui.game.choose_node(str(first_battle.id))
	ui.menu = false
	ui.game.profile.settings.reduced_motion = true
	for i in range(4):
		ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
	var original_hand: Array = ui.game.run.battle.hand.duplicate(true)
	for i in range(10 - original_hand.size()):
		var extra: Dictionary = original_hand[i % original_hand.size()].duplicate(true)
		extra.uid = 10000 + i
		ui.game.run.battle.hand.append(extra)
	for viewport in [Vector2i(1440, 900), Vector2i(1100, 720)]:
		# Godot's macOS Window.size includes the native title-bar height while
		# the viewport texture excludes it. Keep the captured narrow client at
		# the requested 720px height.
		root.size = Vector2i(1100, 753) if not screenshots.is_empty() and viewport.y == 720 else viewport
		await settle()
		ui.anatomy_view = true
		ui._clear_selection()
		ui._render()
		await settle()
		if not screenshots.is_empty():
			print("CAPTURE viewport ", viewport, " window ", ui.get_window().size, " page ", ui.page.scale)
		var hand: Control = ui.page.find_child("Hand9", true, false)
		var organ: Control = ui.page.find_child("Organ0", true, false)
		click(ui, hand, MOUSE_BUTTON_RIGHT)
		await settle()
		require(ui.detail_kind == "card" and ui.page.find_child("CombatDetailDock", true, false) != null, "Actual hand right-click opens card detail dock " + str(viewport))
		require(ui.selected_card == -1 and ui.route.is_empty(), "Card inspection does not stage a command")
		hand = ui.page.find_child("Hand9", true, false)
		require(not str(hand.get_meta("mcp_description", "")).is_empty(), "Hand MCP help remains available as metadata")
		require(ui.page.find_child("CardDetailBack", true, false) != null, "Card details appear on a titled reverse face")
		var hull_text: Label = ui.page.find_child("PlayerHullText", true, false)
		require(hull_text.text.contains(str(ui.game.run.hull)) and hull_text.text.contains(str(ui.game.run.max_hull)), "Compact hull readout preserves current and maximum values")
		require(hull_text.get_visible_line_count() == 1, "Compact hull readout stays on one visible line")
		for organ_index in range(6):
			var organ_button: Control = ui.page.find_child("Organ%d" % organ_index, true, false)
			var organ_name: Label = organ_button.find_child("OrganName", true, false)
			var organ_effect: Label = organ_button.find_child("OrganEffect", true, false)
			var organ_strain: Label = organ_button.find_child("StrainReadout", true, false)
			require(organ_name.text == str(ui.game.organ(organ_index).name).trim_prefix("The "), "Full anatomy organ name remains visible: " + str(organ_name.text))
			require(organ_name.get_visible_line_count() == 1, "Anatomy organ name fits one line")
			require(organ_effect.get_visible_line_count() == 1 and organ_strain.get_visible_line_count() == 1, "Anatomy effect and strain each fit one line")
			require(not organ_name.get_global_rect().intersects(organ_effect.get_global_rect()), "Anatomy name and effect rows do not collide")
			require(not organ_effect.get_global_rect().intersects(organ_strain.get_global_rect()), "Anatomy effect and strain rows do not collide")
		if ui.detail_kind != "card":
			continue
		var dock: Control = ui.page.find_child("CombatDetailDock", true, false)
		if not screenshots.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(screenshots.path_join("%dx%d-card.png" % [viewport.x, viewport.y]))
		require(dock.position.x >= 1100, "Dock occupies reserved right-side region")
		require(hand.get_global_rect().end.x <= dock.get_global_rect().position.x, "Card never overlaps dock")
		for pattern in ["Hand*", "Organ*", "EnemyTarget*", "RouteConfirm", "RouteUndo", "RouteCancel", "EndTurnControl", "AnatomyViewToggle"]:
			for control in ui.page.find_children(pattern, "Control", true, false):
				if control is Button:
					require(not control.get_global_rect().intersects(dock.get_global_rect()), "%s overlaps dock at %s" % [control.name, viewport])
		click(ui, hand, MOUSE_BUTTON_RIGHT)
		await settle()
		require(ui.detail_kind == "", "Repeating right-click dismisses details")
		hand = ui.page.find_child("Hand9", true, false)
		hand.grab_focus()
		var inspect_key := InputEventKey.new()
		inspect_key.keycode = KEY_I
		inspect_key.pressed = true
		root.push_input(inspect_key)
		await settle()
		require(ui.detail_kind == "card", "Focused I opens details as keyboard equivalent")
		var close_key := InputEventKey.new()
		close_key.keycode = KEY_ESCAPE
		close_key.pressed = true
		root.push_input(close_key)
		await settle()
		require(ui.detail_kind == "", "Escape dismisses keyboard-opened details")
		hand = ui.page.find_child("Hand9", true, false)
		click(ui, hand, MOUSE_BUTTON_RIGHT)
		await settle()
		ui.selected_card = 1
		ui.route.assign([0])
		var staged: Array = ui.route.duplicate()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		await settle()
		require(ui.detail_kind == "" and ui.selected_card == 1 and ui.route == staged, "Escape closes details first and preserves staged route")
		ui._render()
		await settle()
		organ = ui.page.find_child("Organ0", true, false)
		click(ui, organ, MOUSE_BUTTON_RIGHT)
		await settle()
		require(ui.detail_kind == "organ", "Actual organ right-click opens organ details")
		require(ui.selected_card == 1 and ui.route == staged, "Organ inspection leaves the staged route unchanged")
		organ = ui.page.find_child("Organ0", true, false)
		require(str(organ.get_meta("mcp_description", "")).contains("Strain"), "Organ MCP help retains route-state summary")
		require(str(organ.get_meta("mcp_description", "")).contains("Preview:") and str(organ.get_meta("mcp_description", "")).contains("Damage"), "Organ detail keeps route-specific resource and payload preview")
		var selected_organ_name: Label = organ.find_child("OrganName", true, false)
		var order: Control = organ.find_child("RouteOrder", true, false)
		require(is_instance_valid(order) and not order.get_global_rect().intersects(selected_organ_name.get_global_rect()), "Selected route chip stays clear of the organ name")
		if not screenshots.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(screenshots.path_join("%dx%d-organ.png" % [viewport.x, viewport.y]))
		ui.anatomy_view = false
		ui._render()
		await settle()
		var console_hull: Label = ui.page.find_child("PlayerHullText", true, false)
		require(console_hull.text.contains(str(ui.game.run.hull)) and console_hull.text.contains(str(ui.game.run.max_hull)), "Console compact hull readout preserves both values")
		require(console_hull.get_visible_line_count() == 1, "Console compact hull readout stays on one line")
		var resource_readout: Control = ui.page.find_child("CharacterResource", true, false)
		require(not console_hull.get_global_rect().intersects(resource_readout.get_global_rect()), "Console hull and resource readouts do not overlap")
		for organ_index in range(6):
			var organ_button: Control = ui.page.find_child("Organ%d" % organ_index, true, false)
			var organ_name: Label = organ_button.find_child("OrganName", true, false)
			require(organ_name.text == str(ui.game.organ(organ_index).name).trim_prefix("The "), "Full console organ name remains visible: " + str(organ_name.text))
			var effect: Label = organ_button.find_child("OrganCondition", true, false)
			var console_effect: Label = organ_button.find_child("OrganEffect", true, false)
			var strain: Label = organ_button.find_child("StrainReadout", true, false)
			require(organ_name.get_visible_line_count() == 1 and console_effect.get_visible_line_count() == 1, "Console organ name/effect fit one line")
			require(not effect.get_global_rect().intersects(strain.get_global_rect()), "Console effect and strain rows do not collide")
			require(effect.get_global_rect().end.y <= organ_button.get_global_rect().end.y, "Console effect remains inside organ hit area")
		if not screenshots.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(screenshots.path_join("%dx%d-organ-console.png" % [viewport.x, viewport.y]))
		organ = ui.page.find_child("Organ0", true, false)
		click(ui, organ, MOUSE_BUTTON_LEFT)
		await settle()
		require(ui.route.is_empty(), "Left-clicking an already-routed organ still undoes that route")
		var final_dock: Control = ui.page.find_child("CombatDetailDock", true, false)
		var close_button: Button = final_dock.find_child("DetailClose", true, false)
		click(ui, close_button, MOUSE_BUTTON_LEFT)
		await settle()
		require(ui.detail_kind == "", "Explicit close button dismisses details")
		require(ui.page.find_child("CombatDetailDock", true, false) == null, "Closed inspection restores default combat layout")
	ui.hull_audio.stop_all()
	ui.queue_free()
	await settle()
	print("Combat inspector: %d failures" % failures)
	quit(1 if failures else 0)
