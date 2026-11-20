extends SceneTree

const Main = preload("res://scripts/main.gd")
var ui
var checks := 0
var failures := 0

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR").path_join("astral-ascension-ui-%d" % Time.get_ticks_usec()))
	run_test.call_deferred()

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for _i in range(6): await process_frame

func verify_unlock_label_clear() -> void:
	var reason: Label
	for label in ui.page.find_children("*", "Label", true, false):
		if label.text.begins_with("Ordinary A"): reason = label
	require(reason != null, "Locked-rank reason remains visible")
	if reason == null: return
	require(reason.get_theme_font_size("font_size") >= 14, "Locked-rank reason meets minimum text size")
	for button in ui.page.find_children("*", "Button", true, false):
		var reason_rect: Rect2 = reason.get_global_rect()
		var button_rect: Rect2 = button.get_global_rect()
		require(not reason_rect.intersects(button_rect), "Unlock reason %s does not overlap %s %s" % [reason_rect, button.name, button_rect])

func run_test() -> void:
	ui = Main.new()
	root.add_child(ui)
	await settle()
	ui.game.profile.ascension_unlocks = {"cartographer":11, "hollow_choir":2, "palimpsest":0}
	for viewport_size in [Vector2i(1440, 900), Vector2i(1100, 720)]:
		root.size = viewport_size
		ui._request_new()
		await settle()
		var rank10 = ui.page.find_child("AscensionRank10", true, false)
		var rank11 = ui.page.find_child("AscensionRank11", true, false)
		require(rank10 != null and rank11 != null, "A10 and A11 controls exist")
		require(rank10.get_meta("ascension_rank", -1) == 10 and rank11.get_meta("ascension_rank", -1) == 11, "Late ranks expose stable typed metadata")
		require(not rank10.get_meta("locked") and not rank11.get_meta("locked"), "Unlocked late ranks are visibly selectable")
		require(rank10.focus_mode == Control.FOCUS_ALL and rank11.focus_mode == Control.FOCUS_ALL, "Late rank controls support keyboard focus")
		for button in [rank10, rank11]:
			require(root.get_visible_rect().encloses(button.get_global_rect()), "%s fits at %s" % [button.name, viewport_size])
		rank10.pressed.emit()
		await settle()
		require(ui.selected_ascension == 10, "A10 activates from the visible button")
		var rules_button
		for button in ui.page.find_children("*", "Button", true, false):
			if button.text == "Rules": rules_button = button
		rules_button.pressed.emit()
		await settle()
		var rules_text := ""
		for label in ui.overlay.find_children("*", "Label", true, false): rules_text += label.text + " "
		require(rules_text.contains("A1 ·") and rules_text.contains("A10 ·"), "Rules view shows the complete cumulative ladder")
		ui._close_overlay()
		rank11 = ui.page.find_child("AscensionRank11", true, false)
		rank11.pressed.emit()
		await settle()
		require(ui.selected_ascension == 11, "A11 activates from its keyboard-focusable control")
		var ship_button
		for choice in ui.page.find_children("*", "Button", true, false):
			if choice.get_meta("ship", "") == "hollow_choir": ship_button = choice
		require(ship_button != null, "Hollow Choir ship choice is visible")
		ship_button.pressed.emit()
		await settle()
		require(ui.selected_ascension == 0, "Switching to a ship with lower unlocks resets invalid rank")
		var locked = ui.page.find_child("AscensionRank3", true, false)
		require(locked != null and locked.get_meta("locked"), "Unavailable rank is marked locked")
		verify_unlock_label_clear()
		var unlock_reason: Label
		for label in ui.page.find_children("*", "Label", true, false):
			if label.text.begins_with("Ordinary A2 voyage win"): unlock_reason = label
		require(unlock_reason != null and root.get_visible_rect().encloses(unlock_reason.get_global_rect()), "Locked-rank explanation fits both tested viewports")
		locked.pressed.emit()
		await settle()
		require(ui.selected_ascension == 0 and ui.notice.contains("locked"), "Activating a locked rank explains its requirement")
		ui.selected_character = "cartographer"
		ui.game.profile.ascension_unlocks.cartographer = 10
		ui.selected_ascension = 10
		ui._render()
		await settle()
		var rank10_late = ui.page.find_child("AscensionRank10", true, false)
		var rank11_late = ui.page.find_child("AscensionRank11", true, false)
		require(rank10_late != null and rank11_late != null and not rank10_late.get_meta("locked") and rank11_late.get_meta("locked"), "A10/A11 lock state reflects the unlock frontier")
		verify_unlock_label_clear()
		var late_reason: Label
		for label in ui.page.find_children("*", "Label", true, false):
			if label.text.begins_with("Ordinary A10 voyage win"): late_reason = label
		require(late_reason != null and root.get_visible_rect().encloses(late_reason.get_global_rect()), "A10/A11 reason fits both viewports")
		ui.game.profile.ascension_unlocks.cartographer = 11
		ui.selected_ascension = 11
		ui._render()
		await settle()
		ui._render()
		await settle()
		var seed_input = ui.page.find_child("ExpeditionSeed", true, false)
		seed_input.text = "RANK11"
		seed_input.text_changed.emit(seed_input.text)
		ui._new_run()
		await settle()
		require(ui.game.run.get("ascension_rank", -1) == 11 and ui.game.run.seeded, "Entered practice seed starts at selected A11")
		ui.game.run.mode = "victory"
		ui._render()
		await settle()
		var record = ui.page.find_child("ExpeditionRecord", true, false)
		require(record != null and record.text.contains("A11"), "Outcome record displays active rank")
		ui.game.profile.history = [{"won":true, "seed":"OLDER1", "character":"cartographer", "ascension_rank":10, "region":2, "turns":22, "battles":8, "seconds":80}]
		ui._open_history()
		await settle()
		var history_text := ""
		for label in ui.overlay.find_children("*", "Label", true, false): history_text += label.text + " "
		require(history_text.contains("A10"), "History entry displays its completed rank")
		ui._close_overlay()
		ui._retry_seed()
		await settle()
		require(ui.game.run.get("ascension_rank", -1) == 11 and ui.game.run.seed == "RANK11", "Seed retry preserves the exact rank and seed")
		var previous_run = ui.game.run.duplicate(true)
		ui._request_new()
		await settle()
		ui.selected_character = "cartographer"
		ui.selected_ascension = 11
		ui.expedition_seed = "NEW111"
		ui._begin_character_run()
		await settle()
		require(ui.overlay != null and ui.game.run == previous_run, "Ranked replacement requires confirmation")
		var replace_button
		for button in ui.overlay.find_children("*", "Button", true, false):
			if button.text == "Replace and begin": replace_button = button
		require(replace_button != null, "Confirmed replacement action is available")
		replace_button.pressed.emit()
		await settle()
		require(ui.game.run.get("ascension_rank", -1) == 11 and ui.game.run.seed == "NEW111", "Confirmed replacement starts the chosen rank and practice seed")
		ui.game.abandon()
	ui.hull_audio.stop_all()
	await settle()
	print("ASCENSION_UI_TESTS ", checks, " checks, ", failures, " failures")
	ui.queue_free()
	await settle()
	quit(1 if failures else 0)
