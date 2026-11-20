extends "res://tests/mcp_controller_test.gd"

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var c = main.mcp_controller
	check(not main.mcp_bridge.connection_info().enabled, "fixture does not enable listener")
	# Eligible fixture profile only; actions still travel through visible controls.
	main.game.profile.ascension_unlocks = {"cartographer":3, "palimpsest":0, "choir":0}
	check(act("new_expedition").ok, "open real ship screen")
	var setup: Dictionary = c.snapshot()
	var ranks: Array = []
	for action in setup.legal_actions:
		if action.action == "select_ascension": ranks = action.args.index.options
	check(ranks.size() == 12, "all visible rank explanation controls advertised")
	if ranks.size() != 12:
		quit(1)
		return
	check(ranks[3].ascension_rank == 3 and ranks[3].ship == "cartographer" and not ranks[3].locked, "rank options expose public identity")
	check(act("select_ascension", {"index":3}).ok, "activate A3 visible control")
	var seed_input = main.page.find_child("ExpeditionSeed", true, false)
	check(seed_input != null, "real seed entry exists")
	check(c.request("act", {"action":"select_ascension", "args":{"index":0}, "expected_revision":setup.revision}).error.code == "stale_revision", "rank change invalidates old revision")
	check(ranks[4].locked, "locked control labeled")
	check(act("select_ascension", {"index":4}).ok, "locked explanation control activates")
	check(main.selected_ascension == 3, "locked control cannot change rank")
	check(not c.snapshot().ui.notice.is_empty(), "locked control explains requirement visibly")
	check(act("select_ascension", {"rank":11}).error.code == "invalid_args", "no direct rank setter bypass")
	check(act("select_character", {"index":1}).ok, "existing ship action remains compatible")
	setup = c.snapshot()
	for action in setup.legal_actions:
		if action.action == "select_ascension":
			check(action.args.index.options.size() == 12 and action.args.index.options[1].locked, "ship switch refreshes eligible ranks")
	check(act("begin_expedition").ok, "ordinary start on switched ship")
	check(c.snapshot().run.ascension_rank == 0 and not c.snapshot().run.seeded, "ship switch cannot carry ineligible rank")
	main.menu = true
	main._request_new()
	check(act("select_character", {"index":0}).ok, "return to eligible ship")
	check(act("select_ascension", {"index":3}).ok, "select eligible practice rank")
	seed_input = main.page.find_child("ExpeditionSeed", true, false)
	seed_input.text = "Z9Q8X7"
	seed_input.text_changed.emit(seed_input.text)
	check(act("begin_expedition").ok, "request replacement through UI")
	check(act("confirm_replace").ok, "confirm replacement through UI")
	check(c.snapshot().run.ascension_rank == 3 and c.snapshot().run.seeded, "entered seed retains selected rank")
	check(c.snapshot().profile.ascension_unlocks.cartographer == 3, "practice start cannot award progression")
	main.game.new_run("Z9Q8X7", "cartographer")
	main.menu = false
	main._render()
	main.game.run.rng_state = "PRIVATE-ASCENSION-RNG"
	main.game.profile.history = [
		{"character":"cartographer", "won":false, "seed":"PRIVATE-HISTORY-SEED", "rng_state":"PRIVATE-HISTORY-RNG"},
		{"character":"cartographer", "won":true, "seeded":true, "ascension_rank":3, "modifier_revision":1, "seed":"PRIVATE-PRACTICE-SEED"}
	]
	var state: Dictionary = c.snapshot()
	check(state.run.ascension_rank == 0, "default run exposes A0")
	check(state.run.has("modifier_revision"), "run exposes modifier revision")
	check(state.profile.history[0].ascension_rank == 0 and state.profile.history[0].modifier_revision == 0, "absent legacy history fields project as zero")
	check(state.profile.history[1].ascension_rank == 3 and state.profile.history[1].modifier_revision == 1, "history retains practice rank and revision")
	check(state.profile.history[1].seeded, "practice provenance remains public")
	var original: Dictionary = main.game.run.duplicate(true)
	main.game.run.erase("ascension_rank")
	main.game.run.erase("modifier_revision")
	state = c.snapshot()
	check(state.run.ascension_rank == 0 and state.run.modifier_revision == 0, "legacy run projects as A0 revision zero")
	check(not main.game.run.has("ascension_rank") and not main.game.run.has("modifier_revision"), "projection does not rewrite legacy run")
	main.game.run = original
	for response in [c.request("get_state", {}), c.request("act", {}), c.request("act", {"action":"select_ascension", "args":{"rank":11}, "expected_revision":c.snapshot().revision})]:
		var encoded := JSON.stringify(response)
		for secret in ["Z9Q8X7", "PRIVATE-ASCENSION-RNG", "PRIVATE-HISTORY-SEED", "PRIVATE-HISTORY-RNG", "PRIVATE-PRACTICE-SEED"]:
			check(not encoded.contains(secret), "ascension response hides " + secret)
		check(not response.state.run.has("seed") and not response.state.run.has("rng_state"), "run private fields absent")
		check(not response.state.profile.settings.has("mcp_token"), "credentials absent")
	main.queue_free()
	for i in range(5): await process_frame
	await create_timer(2.5).timeout
	print("ASCENSION MCP: %d failures" % failures)
	quit(1 if failures else 0)
