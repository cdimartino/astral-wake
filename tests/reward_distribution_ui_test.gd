extends "res://tests/evolutions_ui_test.gd"

func run_test() -> void:
	var ui = preload("res://scripts/main.gd").new()
	root.add_child(ui)
	ui.game.new_run("0093CG")
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.game._finish_battle()
	ui.menu = false
	ui._render()
	var text: String = all_text(ui.page)
	require("Rewards v1" in text and "rare pity" in text and "resets on offer" in text, "reward exposes actual generation/counter/policy")
	for choice in ui.game.run.reward.choices:
		if choice.kind != "card": continue
		require("Primary: " + ui.game.card(choice.id).primary_role in text, "reward primary roles visible without tooltip")
		var tip: String = ui._card_tip({"id":choice.id,"level":0})
		for branch in ui.game.card(choice.id).evolutions:
			require(branch.name in tip and branch.description in tip, "offered card has both evolved inspections, not a recommended pick")
	ui.game.run.rare_offer_misses = 6
	ui._open_deck()
	text = all_text(ui.overlay)
	require("6/6" in text and "next eligible" in text and "Elite/boss" in text, "deck inspection exposes capped guarantee outside rewards")
	ui._close_overlay()
	ui.game._make_shop()
	ui._render()
	text = all_text(ui.page)
	require("generation v1" in text and "otherwise" in text, "shop active generation and fallback transparent")
	for item in ui.game.run.shop.items:
		if item.kind == "card": require("Primary: " + ui.game.card(item.id).primary_role in text and str(item.cost) + " salvage" in text, "shop roles/actual prices visible")
	ui.game.run.reward_generation = 0
	ui.game.run.rare_offer_misses = 0
	ui._open_deck()
	require("legacy uniform" in all_text(ui.overlay) and "no pity" in all_text(ui.overlay), "legacy policy honest")
	for player in ui.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	ui.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("REWARD_DISTRIBUTION_UI %d checks, %d failures (node assertions, not graphical evidence)" % [checks, failures])
	quit(1 if failures else 0)
