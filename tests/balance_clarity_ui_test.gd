extends SceneTree

const Main = preload("res://scripts/main.gd")
const Fixtures = preload("res://tests/route_effect_fixtures.gd")
var failures := 0
var directory := OS.get_environment("TMPDIR").path_join("balance-clarity-ui-%d" % Time.get_ticks_usec())

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", directory)
	check.call_deferred()

func check() -> void:
	var ui = Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	Fixtures.demo(ui.game)
	ui.game.run.character = "hollow_choir"
	for prior_ward in [0, 2, 3]:
		ui.game.run.battle.hand = [{"id":"warm_refrain", "uid":1, "level":0}]
		ui.game.run.battle.enemies = [ui.game._make_enemy("cinder_mite")]
		ui.game.run.battle.resonance = 2
		ui.game.run.battle.last_command_kind = "attack"
		ui.game.run.battle.ward = prior_ward
		ui.game.run.battle.command_points = 3
		ui.game.run.battle.strain = [0, 0, 0, 0, 0, 0]
		var forecast: Dictionary = ui.game.preview_card(0, [5], 0)
		var expected_gain := mini(3, maxi(0, 3 - prior_ward))
		require(forecast.ward_gained == expected_gain, "public Cadence request preview reports applied ward at prior ward %d" % prior_ward)
		require("Ward +%d total" % expected_gain in ui._command_preview_summary(forecast), "Cadence forecast shows actual ward at prior ward %d" % prior_ward)
		ui.menu = false
		ui.selected_card = 0
		ui.route.assign([5])
		ui._render()
		for unused in range(3): await process_frame
		var rendered: Label = ui.page.find_child("RoutePreviewSummary", true, false)
		require(rendered.text.contains("Ward +%d total" % expected_gain), "rendered Cadence preview includes current ward cap")
		var api: Dictionary = ui.mcp_controller.request("preview", {})
		require(api.ok and api.result.get("ward_gained", -1) == expected_gain, "same applied gain across live preview boundary")
		var committed: Dictionary = ui.game.play_card(0, [5], 0)
		require(committed.ward_gained == expected_gain and int(ui.game.run.battle.ward) == prior_ward + expected_gain, "Cadence commit agrees with preview at prior ward %d" % prior_ward)
	# An unrelated utility with no ward gain does not clutter its forecast with zero.
	ui.game.run.battle.hand = [{"id":"silent_measure", "uid":2, "level":0}]
	var no_ward: Dictionary = ui.game.preview_card(0, [0], 0)
	require(no_ward.ok and no_ward.ward_gained == 0 and not ui._command_preview_summary(no_ward).contains("Ward +0 total"), "zero ward omitted for unrelated legal commands")
	var mixed := {"ward_gained":9,"flat_ward_requested":5,"flat_ward_applied":5,"command_cooling":2,"presentation":[{"kind":"ward","amount":5},{"kind":"ward","amount":4,"source_uid":81}],"heal":0,"disrupt":0,"command_points":2}
	var mixed_summary: String = ui._command_preview_summary(mixed)
	require("Ward +9 total" in mixed_summary and "Install UID 81" in mixed_summary, "mixed total and install source remain distinguishable")
	require("Printed 5/5 · Cool 2" in mixed_summary, "printed ward detail remains available")
	Fixtures.demo(ui.game)
	ui.game.run.character = "hollow_choir"
	ui.game.run.battle.resonance = 2
	ui.game.run.battle.last_command_kind = "attack"
	ui.game.run.battle.ward = 0
	var mixed_actual: Dictionary = ui.game.preview_card(0, [5], 0)
	require(mixed_actual.ward_gained == 8 and "Ward +8 total" in ui._command_preview_summary(mixed_actual), "real Cadence plus printed ward is forecast once as actual total")
	require("Printed 5/5" in ui._command_preview_summary(mixed_actual), "real mixed forecast retains printed ward detail")
	ui.game._make_shop()
	ui.game.run.shop.items[0].sold = true
	ui.game.run.mode = "shop"
	ui._render()
	for unused in range(3): await process_frame
	var text := all_text(ui.page)
	require(not text.contains("generation v") and not text.contains("audit floor") and not text.contains("pool fill"), "shop omits developer generation and audit language")
	require("take it immediately" in text and "choose the card before you pay" in text and "Prices include discounts" in text, "shop purchase timing guidance matches shop rules")
	var purchase_buttons: Array = ui.page.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("purchase_slot"))
	require(purchase_buttons.size() == ui.game.run.shop.items.size(), "every shop slot has a purchase button, including sold items")
	for button in purchase_buttons:
		var slot := int(button.get_meta("purchase_slot"))
		var item: Dictionary = ui.game.run.shop.items[slot]
		require(button.get_meta("purchase_price") == int(item.cost), "purchase metadata carries displayed price for slot %d" % slot)
		require(not str(button.get_meta("purchase_name")).is_empty(), "purchase metadata carries visible item/service name for slot %d" % slot)
	for player in ui.find_children("*", "AudioStreamPlayer", true, false): player.stop()
	ui.queue_free()
	await process_frame
	print("BALANCE_CLARITY_UI %d failures" % failures)
	quit(1 if failures else 0)

func all_text(node: Node) -> String:
	var result := ""
	if node is Label: result += node.text + " "
	for child in node.get_children(): result += all_text(child)
	return result
