extends "res://tests/mcp_controller_test.gd"

const SECRETS := ["Z9Q8X7", "HIDDEN-DRAW-IDENTITY", "1987654321", "1876543210", "PRIVATE-RUN-ID"]

func blind(value, label: String) -> void:
	var encoded := JSON.stringify(value)
	for secret in SECRETS: check(not encoded.contains(secret), label + " hides " + secret)

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.game.new_run("Z9Q8X7", "cartographer")
	main.game.choose_node(main.game.run.map[0][0].id)
	main.menu = false
	main.game.profile.settings.reduced_motion = true
	main._render()
	var c = main.mcp_controller
	var run_state: Dictionary = main.game.run
	run_state.id = "PRIVATE-RUN-ID"
	run_state.rng_state = "1876543210"
	run_state.rng_streams.cards = 1987654321
	run_state.battle.draw[-1].id = "HIDDEN-DRAW-IDENTITY"
	var original := run_state.duplicate(true)
	var state: Dictionary = c.snapshot()
	blind(state, "snapshot")
	check(state.run.battle.draw_count == run_state.battle.draw.size(), "draw count retained")
	check(not state.run.battle.has("draw"), "draw inventory absent")
	check(state.run.deck == run_state.deck, "public full owned deck retained")
	check(state.run.battle.discard == run_state.battle.discard, "public discard retained")
	blind(c.request("get_state", {}), "get_state")
	blind(c.request("preview", {}), "preview unavailable error")
	blind(c.request("not-a-method", {}), "unknown method error")
	check(c._blind({"next":"public next option", "guard":"public guard stat"}).size() == 2, "no recursive generic key deletion")
	blind(c.request("act", {}), "invalid arguments")
	blind(c.request("act", {"action":"open_menu", "args":{}, "expected_revision":-1}), "stale error")
	blind(c.request("act", {"action":"unsupported", "args":{}, "expected_revision":c.snapshot().revision}), "unknown action")
	# A real draw preview simulates the hidden top card without committing it.
	for definition in main.game.catalog.cards:
		if int(definition.get("draw", 0)) > 0 and not definition.has("selections"):
			run_state.battle.hand[0].id = definition.id
			break
	main.selected_card = 0
	main.route.clear()
	main.route.append(0)
	main.target = 0
	var raw: Dictionary = main.game.preview_card(0, [0], 0)
	check(raw.ok, "real draw preview succeeds")
	check(JSON.stringify(raw).contains("HIDDEN-DRAW-IDENTITY"), "fixture exercises future draw identity")
	var preview: Dictionary = c.request("preview", {})
	blind(preview, "preview state/result")
	check(preview.result.ok and preview.result.damage == raw.damage, "public preview forecast retained")
	check(not preview.result.has("presentation") and not preview.result.has("events") and not preview.result.has("summary"), "no simulation identity channels")
	blind(c._public_preview({"ok":true, "summary":"HIDDEN-DRAW-IDENTITY", "events":["HIDDEN-DRAW-IDENTITY"], "next":{"rng_state":"1876543210"}, "presentation":[{"kind":"draw_card", "card":{"id":"HIDDEN-DRAW-IDENTITY"}}]}), "forecast allowlist rejects alternate simulation channels")
	check(run_state.battle.draw == original.battle.draw and run_state.rng_streams == original.rng_streams, "projection/preview do not mutate hidden state")
	# Even manually opening the native composition inspector cannot leak it.
	var body = main._modal("Draw pile")
	body.add_child(main._text("HIDDEN-DRAW-IDENTITY"))
	blind(c.snapshot(), "draw overlay text")
	check(c.snapshot().ui.text.is_empty(), "draw inspector labels suppressed")
	main._close_overlay()
	main._clear_selection()
	var started: Dictionary = main.mcp_bridge.enable()
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", started.connection.port)
	for i in range(5):
		await process_frame
		peer.poll()
	var response: Dictionary = await exchange(peer, {"id":"blind-state", "token":started.connection.token, "method":"get_state", "params":{}})
	blind(response, "wire state (host resource source)")
	response = await exchange(peer, {"id":"blind-act", "token":started.connection.token, "method":"act", "params":{"action":"open_menu", "args":{}, "expected_revision":response.state.revision}})
	check(response.get("ok", false), "wire action succeeds")
	blind(response, "wire action success")
	response = await exchange(peer, {"id":"blind-error", "token":started.connection.token, "method":"act", "params":{}})
	blind(response, "wire action error")
	check(not events.is_empty(), "real state_changed observed")
	for event in events: blind(event, "state_changed")
	main.mcp_bridge.disable()
	# Newer main's visible evolution/pile/known-card controls remain usable.
	main._close_overlay()
	main.game.new_run("ABC123", "cartographer")
	main.game.run.mode = "modify"
	main.game.run.modify_kind = "upgrade"
	main.game.run.modify_return = "recovery"
	main._render()
	check(act("modify_card").ok, "MCP opens evolution choices")
	check(act("choose_evolution").ok, "MCP commits named evolution")
	check(main.game.run.deck[0].level == 1, "evolution applied to selected copy")
	var fixtures = load("res://tests/selection_fixtures.gd")
	main.game = fixtures.FixtureGame.new(OS.get_environment("ASTRAL_SAVE_DIR").path_join("selections"))
	fixtures.setup(main.game, "fixture_pair")
	main.game.profile.settings.reduced_motion = true
	main._clear_selection()
	main._render()
	check(act("inspect_pile").ok, "MCP opens draw inspector")
	check(c.snapshot().ui.overlay == "Draw pile" and c.snapshot().ui.text.is_empty(), "draw inspector remains blind")
	check(act("close_overlay").ok, "MCP closes draw inspector")
	main.selected_card = 0
	main.route.append(0)
	main.target = 0
	main._render()
	check(act("confirm").ok and main.game.selection_pending(), "MCP starts known-card selection")
	check(act("cancel_known_selection").ok and not main.game.selection_pending(), "MCP cancels known-card selection")
	main.selected_card = 0
	main.route.append(0)
	main.target = 0
	main._render()
	check(act("confirm").ok and main.game.selection_pending(), "MCP restarts cancelled selection")
	for i in range(3): check(act("choose_known_card").ok, "MCP selects eligible known card %d" % i)
	check(c.request("preview", {}).result.ok, "MCP previews complete known choices")
	check(act("confirm_known_selection").ok, "MCP commits known choices")
	check(not main.game.selection_pending(), "selection completed")
	main.queue_free()
	for i in range(5): await process_frame
	print("MCP BLIND: %d failures" % failures)
	quit(1 if failures else 0)
