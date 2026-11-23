extends SceneTree

const Main = preload("res://scripts/main.gd")
var ui
var failures := 0
var card_uid := 4242
var directory := OS.get_environment("TMPDIR").path_join("astral-route-drag-%d" % Time.get_ticks_usec())
var capture_dir := OS.get_environment("ASTRAL_ROUTE_SHOTS")
var frame_number := 0
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
	check(false, "Timed out waiting for an actual rendered frame")
	quit(1)
	return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(4): await process_frame

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point * input_scale
	event.global_position = event.position
	root.push_input(event)

func pointer_move(from_point: Vector2, to_point: Vector2) -> void:
	var samples := 1 if capture_dir.is_empty() else 12
	for i in range(1, samples + 1):
		var point := from_point.lerp(to_point, float(i) / samples) * input_scale
		var prior := (from_point.lerp(to_point, float(i - 1) / samples) if i > 1 else from_point) * input_scale
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.relative = point - prior
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event)
		if not capture_dir.is_empty():
			if not await rendered_boundary(): return
			var image := root.get_texture().get_image()
			image.save_png(capture_dir.path_join("route-%04d.png" % frame_number))
			frame_number += 1

func click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	mouse_button(point, true)
	await settle()
	mouse_button(point, false)
	await settle()

func key_press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event)
	await settle()

func capture_frame(filename: String) -> void:
	if capture_dir.is_empty(): return
	if not await rendered_boundary(): return
	root.get_texture().get_image().save_png(capture_dir.path_join(filename))

func resize_to_viewport(target: Vector2i) -> void:
	DisplayServer.window_set_size(target)
	if DisplayServer.get_name() == "headless": root.size = target
	await settle()
	input_scale = root.get_final_transform().get_scale()
	print("ROUTE VIEWPORT ", target, " ACTUAL WINDOW ", root.size, " INPUT SCALE ", input_scale)
	if DisplayServer.get_name() != "headless":
		if not await rendered_boundary(): return
		var frame_size := root.get_texture().get_image().get_size()
		check(frame_size == target, "Rendered window viewport matches requested dimensions: %s" % str(frame_size))
	else:
		check(root.size == target, "Headless functional viewport matches requested dimensions (not pixel proof)")

func start(card_id: String, hull: int = 90) -> void:
	ui.game.new_run(2026, "palimpsest")
	ui.game.choose_node(ui.game.run.map[0][0].id)
	var foe: Dictionary = ui.game._make_enemy("cinder_mite")
	foe.hp = 40
	foe.max_hp = 40
	ui.game.run.battle.enemies = [foe]
	for unused in range(4):
		var additional: Dictionary = ui.game._make_enemy("cinder_mite")
		additional.hp = 40
		additional.max_hp = 40
		ui.game.run.battle.enemies.append(additional)
	ui.game.run.battle.hand = [{"id":card_id, "uid":card_uid, "level":0}]
	for i in range(9):
		var extra: Dictionary = ui.game.run.deck[i % ui.game.run.deck.size()].duplicate(true)
		extra.uid = 5000 + i
		ui.game.run.battle.hand.append(extra)
	ui.game.run.battle.trace = 0
	ui.game.run.battle.strain = [0, 0, 0, 0, 0, 0]
	ui.game.run.battle.command_points = 3
	ui.game.run.hull = hull
	ui.menu = false
	ui.resolving = false
	ui.selected_card = -1
	ui.route.clear()
	ui.target = 0
	ui.route_aim_uid = -1
	ui._render()
	await settle()

func drag_route(route: Array[int]) -> void:
	var hand: Control = ui.page.find_child("Hand0", true, false)
	var start_point := hand.get_global_rect().get_center()
	mouse_button(start_point, true)
	await settle()
	var previous := start_point
	if not route.is_empty():
		var first_organ: Control = ui.page.find_child("Organ%d" % route[0], true, false)
		var first_point := first_organ.get_global_rect().get_center()
		for waypoint in [Vector2(root.size.x - 16, start_point.y), Vector2(root.size.x - 16, 92), Vector2(first_point.x, 92), first_point]:
			await pointer_move(previous, waypoint)
			await settle()
			previous = waypoint
	for route_position in range(1 if not route.is_empty() else 0, route.size()):
		var organ_index := route[route_position]
		var organ: Control = ui.page.find_child("Organ%d" % organ_index, true, false)
		var point := organ.get_global_rect().get_center()
		await pointer_move(previous, point)
		await settle()
		previous = point
	mouse_button(previous, false)
	await settle()

func click_enemy() -> void:
	var enemy: Control = ui.page.find_child("EnemyTarget0", true, false)
	var point := enemy.get_global_rect().get_center()
	mouse_button(point, true)
	await settle()
	mouse_button(point, false)
	await settle()

func _initialize() -> void:
	if DisplayServer.get_name() == "headless" and not capture_dir.is_empty():
		push_error("ASTRAL_ROUTE_SHOTS requires a windowed renderer; headless cannot capture pixels")
		quit(1)
		return
	create_timer(120.0).timeout.connect(func():
		push_error("Combat route drag test watchdog expired")
		quit(1))
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", directory)
	if not capture_dir.is_empty(): root.borderless = true
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	check_run.call_deferred()

func check_run() -> void:
	ui = Main.new()
	root.add_child(ui)
	await settle()
	await resize_to_viewport(Vector2i(1440, 900))
	if not capture_dir.is_empty():
		capture_dir = capture_dir.path_join("1440x900")
		DirAccess.make_dir_recursive_absolute(capture_dir)

	await start("margin_knife")
	if not capture_dir.is_empty(): await capture_frame("idle.png")
	var hand: Control = ui.page.find_child("Hand0", true, false)
	var organ_scribe: Control = ui.page.find_child("Organ0", true, false)
	var organ_recall: Control = ui.page.find_child("Organ2", true, false)
	var enemy: Control = ui.page.find_child("EnemyTarget0", true, false)
	var stable_page_id: int = ui.page.get_instance_id()
	var stable_hand_id: int = hand.get_instance_id()
	var stable_organ_id: int = organ_scribe.get_instance_id()
	var stable_enemy_id: int = enemy.get_instance_id()
	check(ui.page.find_child("HeaderHull", true, false) == null, "Combat hull appears on the ship, not twice in the voyage header")
	check(ui.page.find_child("LastCommand", true, false) == null and ui.page.find_child("ShortcutHints", true, false) == null, "Empty command memory and repeated instruction strips stay out of the combat stage")
	check(not ui.page.find_child("RouteConfirm", true, false).visible and ui.page.find_child("EndTurnControl", true, false).visible, "Idle combat exposes End Turn, not a disabled command action bar")
	check(ui.page.find_child("CardPilesTray", true, false) != null, "Card piles share one compact tray beside the hand")
	var one_step: Dictionary = ui.game.preview_card(0, [0], 0)
	var full_route: Dictionary = ui.game.preview_card(0, [0, 2], 0)
	check(one_step.ok and one_step.damage == 8 and one_step.trace == 3, "Margin Knife → Scribe forecasts 8 damage and 3 Trace")
	check(full_route.ok and full_route.damage == 14 and full_route.trace == 0, "Margin Knife → Scribe → Recall forecasts 14 damage and 0 Trace")
	var before_hull := int(ui.game.run.battle.enemies[0].hp)
	var before_cp := int(ui.game.run.battle.command_points)
	var before_hand_size: int = ui.game.run.battle.hand.size()
	var start_point := hand.get_global_rect().get_center()
	mouse_button(start_point, true)
	await settle()
	var scribe_point := organ_scribe.get_global_rect().get_center()
	var previous := start_point
	for waypoint in [Vector2(root.size.x - 16, start_point.y), Vector2(root.size.x - 16, 92), Vector2(scribe_point.x, 92), scribe_point]:
		await pointer_move(previous, waypoint)
		await settle()
		previous = waypoint
	check(ui.route_gesture.dragging and ui.selected_card == 0 and ui.route == [0], "Viewport pointer lifts the exact hand card and catches Scribe")
	check(ui.page.find_child("RouteActionSurface", true, false).visible, "Picking up a card reveals its route consequence at the ship/hand boundary")
	await capture_frame("scribe-caught.png")
	check(ui.page.get_instance_id() == stable_page_id and ui.hand_buttons[0].get_instance_id() == stable_hand_id and ui.page.find_child("Organ0", true, false).get_instance_id() == stable_organ_id and ui.page.find_child("EnemyTarget0", true, false).get_instance_id() == stable_enemy_id, "Combat controls stay alive while pointer traces")
	check(int(ui.game.run.battle.enemies[0].hp) == before_hull and int(ui.game.run.battle.command_points) == before_cp, "Route staging spends nothing")
	await pointer_move(scribe_point, organ_recall.get_global_rect().get_center())
	await settle()
	check(ui.route == [0, 2], "Viewport pointer traces Recall as the second socket: %s" % str(ui.route))
	var preview: Dictionary = ui.game.preview_card(0, ui.route, 0)
	check(preview.ok and preview.damage == 14 and preview.trace == 0, "Live route preview matches exact Margin Knife example")
	await capture_frame("recall-traced.png")
	mouse_button(organ_recall.get_global_rect().get_center(), false)
	await settle()
	check(ui.route_aim_uid == card_uid and ui.selected_card == 0, "Targeted release arms the route without committing")
	check(str(ui.page.find_child("RoutePreviewSummary", true, false).text).begins_with("Click enemy"), "Armed route gives a single fresh-target instruction beside the hand")
	check(str(ui.page.find_child("AnatomyReadout", true, false).text).contains("Click a living enemy"), "Ship readout stays synchronized with the armed route")
	check(not ui.page.find_child("RouteConfirm", true, false).visible, "Targeted drag does not offer a redundant confirmation button")
	await capture_frame("armed-not-fired.png")
	check(int(ui.game.run.battle.enemies[0].hp) == before_hull and int(ui.game.run.battle.command_points) == before_cp and ui.game.run.battle.hand.size() == before_hand_size, "Mouse-up is never also a target click")
	await click_enemy()
	await capture_frame("target-hit.png")
	check(ui.route_aim_uid == -1 and ui.game.run.battle.enemies[0].hp == before_hull - 14, "Fresh enemy click commits one 14-damage hit")
	check(ui.game.run.battle.trace == 0 and ui.game.run.battle.command_points == before_cp - 1 and not ui.game.run.battle.hand.any(func(instance): return int(instance.uid) == card_uid), "Targeted commit spends once and moves the exact card")
	var drag_hp := int(ui.game.run.battle.enemies[0].hp)
	var drag_trace := int(ui.game.run.battle.trace)
	var drag_cp := int(ui.game.run.battle.command_points)

	await start("margin_knife")
	hand = ui.page.find_child("Hand0", true, false)
	await click_control(hand)
	await click_control(ui.page.find_child("Organ0", true, false))
	await click_control(ui.page.find_child("Organ2", true, false))
	await click_control(ui.page.find_child("EnemyTarget0", true, false))
	await click_control(ui.page.find_child("RouteConfirm", true, false))
	check(ui.game.run.battle.enemies[0].hp == drag_hp and ui.game.run.battle.trace == drag_trace and ui.game.run.battle.command_points == drag_cp, "Click-only stage/target/confirm matches pointer result")

	await start("margin_knife")
	await key_press(KEY_1)
	await key_press(KEY_Q)
	await key_press(KEY_E)
	await key_press(KEY_SPACE)
	check(ui.game.run.battle.enemies[0].hp == drag_hp and ui.game.run.battle.trace == drag_trace and ui.game.run.battle.command_points == drag_cp, "Keyboard stage/target/confirm matches pointer result")

	if not capture_dir.is_empty():
		capture_dir = OS.get_environment("ASTRAL_ROUTE_SHOTS").path_join("1100x720")
		DirAccess.make_dir_recursive_absolute(capture_dir)
	await resize_to_viewport(Vector2i(1100, 720))
	await start("margin_knife")
	if not capture_dir.is_empty(): await capture_frame("idle.png")
	await drag_route([0, 2])
	check(ui.route == [0, 2] and ui.route_aim_uid == card_uid, "1100×720 viewport pointer arms targeted route: route=%s uid=%s" % [str(ui.route), str(ui.route_aim_uid)])
	if not capture_dir.is_empty(): await capture_frame("armed-not-fired.png")
	var narrow_hp := int(ui.game.run.battle.enemies[0].hp)
	await click_enemy()
	check(ui.game.run.battle.enemies[0].hp == narrow_hp - 14, "1100×720 fresh target click commits one hit")
	if not capture_dir.is_empty(): await capture_frame("target-hit.png")

	await start("hull_stitch", 80)
	hand = ui.page.find_child("Hand0", true, false)
	var repair_scribe: Control = ui.page.find_child("Organ0", true, false)
	var repair_before := int(ui.game.run.hull)
	var self_route: Dictionary = ui.game.preview_card(0, [0], 0)
	check(self_route.ok and self_route.heal > 0, "Hull Stitch through Scribe is a valid self-only repair route")
	await drag_route([0])
	if not capture_dir.is_empty(): await capture_frame("self-only-release-commit.png")
	check(ui.game.run.hull == repair_before + int(self_route.heal) and ui.game.run.battle.command_points == 2, "Self-only release repairs immediately without a target click: hull=%d expected=%d cp=%d" % [ui.game.run.hull, repair_before + int(self_route.heal), ui.game.run.battle.command_points])
	check(not ui.game.run.battle.hand.any(func(instance): return int(instance.uid) == card_uid), "Self-only route commits the original UID exactly once: hand=%s route=%s" % [str(ui.game.run.battle.hand.map(func(instance): return instance.uid)), str(ui.route)])

	ui.hull_audio.stop_all()
	ui.queue_free()
	await settle()
	# Headless completes gestures faster than real-time feedback timers. Let the
	# fixture's already-scheduled callbacks drain after its scene is freed.
	await create_timer(2.5).timeout
	print("Combat route drag: %d failures" % failures)
	quit(1 if failures else 0)
