extends SceneTree

const Main = preload("res://scripts/main.gd")

var ui
var failures := 0
var capture_root := OS.get_environment("ASTRAL_VOYAGE_SHOTS")
var save_dir := OS.get_environment("TMPDIR").path_join("astral-voyage-phase-d-%d" % Time.get_ticks_usec())
var input_scale := Vector2.ONE
var frame_drawn := false

func rendered_boundary() -> bool:
	if DisplayServer.get_name() == "headless":
		await settle()
		return false
	frame_drawn = false
	var mark := func(): frame_drawn = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	for unused in range(240):
		await process_frame
		if frame_drawn: return true
	if RenderingServer.frame_post_draw.is_connected(mark): RenderingServer.frame_post_draw.disconnect(mark)
	check(false, "Timed out waiting for an actual rendered voyage frame")
	quit(1)
	return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(5):
		await process_frame

func capture(path: String) -> void:
	if capture_root.is_empty():
		return
	if not await rendered_boundary(): return
	root.get_texture().get_image().save_png(capture_root.path_join(path))

func resize_window(size: Vector2i, folder: String) -> void:
	DisplayServer.window_set_size(size)
	if DisplayServer.get_name() == "headless": root.size = size
	await settle()
	input_scale = root.get_final_transform().get_scale()
	print("VOYAGE VIEWPORT ", size, " ACTUAL WINDOW ", root.size, " INPUT SCALE ", input_scale)
	if DisplayServer.get_name() != "headless":
		if not await rendered_boundary(): return
		var actual := root.get_texture().get_image().get_size()
		check(actual == size, "Voyage capture uses requested real-window dimensions: %s" % str(actual))
	else:
		check(root.size == size, "Headless voyage functional viewport matches request (not pixel proof)")
	if not capture_root.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_root.path_join(folder))

func pointer_click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	print("POINTER target=", control.get_path(), " rect=", control.get_global_rect(), " point=", point)
	var motion := InputEventMouseMotion.new()
	motion.position = point * input_scale
	motion.global_position = motion.position
	root.push_input(motion)
	await settle()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point * input_scale
		event.global_position = event.position
		root.push_input(event)
		await settle()
		if pressed:
			var hovered: Control = ui.get_viewport().gui_get_hovered_control()
			print("POINTER receiver=", hovered.get_path() if is_instance_valid(hovered) else "<none>")
			check(hovered == control, "Pointer reaches the intended Details button, not an overlapping control")

func details_button(parent: Node) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == "Details":
			return node
	return null

func check_action_alignment(prefix: String, count: int, label: String) -> void:
	var rows: Dictionary = {}
	for i in range(count):
		var actions := ui.page.find_child("%s%d" % [prefix, i], true, false) as Control
		check(is_instance_valid(actions), "%s %d has a shared action group" % [label, i])
		if is_instance_valid(actions):
			var primary: Button
			for candidate in actions.find_children("*", "Button", true, false):
				if candidate.text == "Take discovery" or candidate.text.begins_with("Buy ·") or candidate.text == "Sold":
					primary = candidate
			if prefix == "ShopActions" and is_instance_valid(primary):
				var row := floori(i / 3.0)
				if not rows.has(row): rows[row] = []
				rows[row].append(primary.get_global_rect().end.y)
				var panel := actions.get_parent() as Control
				print("ALIGN ", label, i, " panel=", panel.get_global_rect(), " actions=", actions.get_global_rect(), " primary=", primary.get_global_rect())
				check(primary.get_global_rect().end.y <= panel.get_global_rect().end.y - 17.0, "%s primary button stays inside panel bottom inset" % label)
			elif prefix == "RewardActions" and is_instance_valid(primary):
				if not rows.has(0): rows[0] = []
				rows[0].append(primary.get_global_rect().end.y)
				var panel := actions.get_parent() as Control
				check(primary.get_global_rect().end.y <= panel.get_global_rect().end.y - 17.0, "%s primary button stays inside panel bottom inset" % label)
	for row in rows.values():
		if row.size() > 1:
			for bottom in row:
				check(absf(bottom - row[0]) <= 1.0, "%s action groups share a bottom inset" % label)

func build_run() -> void:
	ui.game.new_run("0093CG", "cartographer")
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.game._finish_battle()
	ui.menu = false
	ui._clear_selection()

func run_capture_set(size: Vector2i, folder: String) -> void:
	await resize_window(size, folder)
	build_run()
	ui._render()
	await settle()
	check(ui.game.run.mode == "reward", "Fixture reaches the production reward screen")
	check_action_alignment("RewardActions", ui.game.run.reward.choices.size(), "Reward")
	await capture(folder + "/reward.png")
	var reward_before: Dictionary = ui.game.run.reward.duplicate(true)
	var reward_details := details_button(ui.page)
	check(is_instance_valid(reward_details), "Reward command has an explicit Details action")
	if is_instance_valid(reward_details):
		await pointer_click(reward_details)
		check(ui.game.run.reward == reward_before, "Inspecting a reward does not take or alter it")
		check(is_instance_valid(ui.overlay), "Reward Details opens an inspection panel")
		await capture(folder + "/reward-details.png")
		ui._close_overlay()

	ui.game._make_shop()
	ui.game.run.shop.items[0] = {"kind":"card", "id":"grand_concert", "cost":35, "sold":false}
	ui.game.run.mode = "shop"
	ui._render()
	await settle()
	check_action_alignment("ShopActions", ui.game.run.shop.items.size(), "Shop")
	var concert_box: Control = ui.page.find_child("ShopItem0", true, false)
	var concert_effect: String = ui.game.card_text({"id":"grand_concert", "level":0})
	var concert_label: Label
	for label in concert_box.find_children("*", "Label", true, false):
		if label.text == concert_effect:
			concert_label = label
			break
	check(is_instance_valid(concert_label) and concert_label.get_visible_line_count() == concert_label.get_line_count() and "per point spent." in concert_label.text, "Grand Concert shop effect, including its full Resonance bonus, remains visible")
	var concert_actions := ui.page.find_child("ShopActions0", true, false) as Control
	if is_instance_valid(concert_label) and is_instance_valid(concert_actions):
		print("LONGEST label=", concert_label.get_global_rect(), " actions=", concert_actions.get_global_rect(), " text-lines=", concert_label.get_visible_line_count(), "/", concert_label.get_line_count())
		check(concert_label.get_global_rect().end.y <= concert_actions.get_global_rect().position.y, "Longest inspected shop effect does not overlap its action group")
	await capture(folder + "/shop.png")
	await capture(folder + "/shop-grand-concert.png")
	var shop_details := details_button(ui.page)
	check(is_instance_valid(shop_details), "Shop command offer has an explicit Details action")
	if is_instance_valid(shop_details):
		var salvage_before := int(ui.game.run.salvage)
		var shop_before: Dictionary = ui.game.run.shop.duplicate(true)
		await pointer_click(shop_details)
		check(ui.game.run.salvage == salvage_before and ui.game.run.shop == shop_before, "Inspecting a shop offer neither spends salvage nor buys it")
		await capture(folder + "/shop-details.png")
		ui._close_overlay()

	ui.game.run.mode = "modify"
	ui.game.run.modify_kind = "upgrade"
	ui._render()
	await settle()
	await capture(folder + "/deck-upgrade.png")
	var deck_details := details_button(ui.page)
	if is_instance_valid(deck_details):
		await pointer_click(deck_details)
		await capture(folder + "/deck-upgrade-details.png")
		ui._close_overlay()

	ui.game.run.mode = "reward"
	ui._render()
	await settle()
	ui._open_deck()
	await settle()
	await capture(folder + "/deck.png")
	var owned_deck_details := details_button(ui.overlay)
	if is_instance_valid(owned_deck_details):
		await pointer_click(owned_deck_details)
		await capture(folder + "/deck-details.png")
		ui._close_overlay()
	else:
		check(false, "Owned deck entries keep explicit Details controls")
	ui._close_overlay()

	ui.game.run.mode = "transition"
	ui._render()
	await settle()
	await capture(folder + "/region-transition.png")

func _initialize() -> void:
	if DisplayServer.get_name() == "headless" and not capture_root.is_empty():
		push_error("ASTRAL_VOYAGE_SHOTS requires a windowed renderer; headless cannot capture pixels")
		quit(1)
		return
	create_timer(120.0).timeout.connect(func():
		push_error("Voyage screens test watchdog expired")
		quit(1))
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", save_dir)
	if not capture_root.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_root)
		root.borderless = true
	check_screens.call_deferred()

func check_screens() -> void:
	ui = Main.new()
	root.add_child(ui)
	await settle()
	await run_capture_set(Vector2i(1440, 900), "1440x900")
	await run_capture_set(Vector2i(1100, 720), "1100x720")
	ui.hull_audio.stop_all()
	ui.queue_free()
	await settle()
	# Headless screen traversal can finish before audio/feedback callbacks.
	await create_timer(2.5).timeout
	print("VOYAGE SCREENS PHASE D: %d failures" % failures)
	quit(1 if failures else 0)
