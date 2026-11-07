extends SceneTree

var failures := 0
var main
var wire_buffer := ""
var events: Array = []

func exchange(peer: StreamPeerTCP, request: Dictionary) -> Dictionary:
	peer.put_data((JSON.stringify(request) + "\n").to_utf8_buffer())
	for i in range(90):
		await process_frame
		peer.poll()
		var count := peer.get_available_bytes()
		if count > 0: wire_buffer += peer.get_utf8_string(count)
		while wire_buffer.contains("\n"):
			var end := wire_buffer.find("\n")
			var message = JSON.parse_string(wire_buffer.substr(0, end))
			wire_buffer = wire_buffer.substr(end + 1)
			if message.has("event"): events.append(message)
			elif message.get("id") == request.id: return message
	check(false, "timed out waiting for response")
	return {}

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	# Never use caller data directly or allow an empty override to select user://.
	# A fresh child also isolates this test from earlier check.sh save fixtures.
	var base := OS.get_environment("ASTRAL_SAVE_DIR")
	if base.is_empty(): base = OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_cache_dir()
	var isolated := base.path_join("astral-mcp-controller-" + Crypto.new().generate_random_bytes(16).hex_encode())
	if DirAccess.make_dir_recursive_absolute(isolated) != OK:
		push_error("Cannot create isolated MCP controller save directory")
		quit(1)
		return
	OS.set_environment("ASTRAL_SAVE_DIR", isolated)
	print("MCP_CONTROLLER_SAVE_DIR ", isolated)
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_MCP_PORT", "")
	OS.set_environment("ASTRAL_MCP_TOKEN", "")
	call_deferred("run")

func act(action: String, args: Dictionary = {}) -> Dictionary:
	var state: Dictionary = main.mcp_controller.snapshot()
	return main.mcp_controller.request("act", {"action":action, "args":args, "expected_revision":state.revision})

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var c = main.mcp_controller
	check(not main.mcp_bridge.connection_info().enabled, "default listener disabled")
	check(not main.game.profile.settings.get("mcp_enabled", false), "fresh or legacy profile defaults MCP disabled")
	check(c.snapshot().ui.screen == "title", "real scene title")
	var revision: int = c.snapshot().revision
	main._request_new()
	check(c.snapshot().revision > revision, "manual UI change revision")
	check(c.request("act", {"action":"begin_expedition", "args":{}, "expected_revision":revision}).error.code == "stale_revision", "stale rejected")
	check(act("select_character", {"index":1}).ok, "character selection")
	check(act("begin_expedition").ok, "begin run")
	check(c.snapshot().ui.screen == "map", "map logical state")
	check(act("open_menu").ok, "pause")
	check(act("open_settings").ok, "settings")
	check(act("set_setting", {"key":"volume", "value":{}}).error.code == "invalid_args", "malformed settings rejected")
	check(act("set_setting", {"key":"reduced_motion", "value":true}).ok, "settings change")
	check(act("close_overlay").ok, "close")
	check(act("choose_node").ok, "choose map node")
	check(c.snapshot().ui.screen == "combat", "combat scene")
	check(act("select_card", {"index":-1}).error.code == "invalid_args", "negative index")
	check(act("select_card", {"index":[]}).error.code == "invalid_args", "malformed index")
	check(act("select_card").ok, "select card")
	check(act("select_organ").ok, "route organ")
	check(c.request("preview", {}).ok, "preview live selection")
	check(act("confirm").ok, "play selected command")
	check(main.selected_card == -1, "logical post-action selection")
	check(main.presentation_busy(), "real command starts presentation")
	check(act("end_turn").error.code == "busy", "busy guarded")
	var busy_revision: int = c.snapshot().revision
	await create_timer(main.presentation_duration + 0.1).timeout
	check(not main.presentation_busy(), "real presentation timer completes")
	check(c.snapshot().revision > busy_revision, "completion revision")
	var started: Dictionary = main.mcp_bridge.enable()
	check(started.ok and started.connection.token.length() == 64 and started.connection.port > 0, "generated session connection")
	var peer := StreamPeerTCP.new()
	check(peer.connect_to_host("127.0.0.1", started.connection.port) == OK, "loopback connection")
	for i in range(5):
		await process_frame
		peer.poll()
	var response: Dictionary = await exchange(peer, {"id":"bad", "token":"wrong", "method":"get_state", "params":{}})
	check(response.get("error", {}).get("code") == "unauthorized" and not response.has("state"), "unauthorized hides state")
	var credential: String = started.connection.token
	response = await exchange(peer, {"id":"state", "token":credential, "method":"get_state", "params":{}})
	check(response.get("ok", false), "authenticated state")
	var mutation := {"id":"menu", "token":credential, "method":"act", "params":{"action":"open_menu", "args":{}, "expected_revision":response.state.revision}}
	var first: Dictionary = await exchange(peer, mutation)
	check(first.get("ok", false) and first.state.ui.overlay == "Expedition paused", "wire mutation immediate UI state")
	var repeated: Dictionary = await exchange(peer, mutation)
	check(repeated == first, "idempotent retry returns original response")
	mutation.params.action = "open_help"
	response = await exchange(peer, mutation)
	check(response.get("error", {}).get("code") == "duplicate_id", "different content rejects reused ID")
	main._close_overlay()
	await process_frame
	response = await exchange(peer, {"id":"manual", "token":credential, "method":"get_state", "params":{}})
	check(response.state.ui.overlay == "" and response.state.revision > first.state.revision, "manual update visible over wire")
	check(not events.is_empty(), "authenticated state change notifications")
	response = await exchange(peer, {"id":"turn", "token":credential, "method":"act", "params":{"action":"end_turn", "args":{}, "expected_revision":response.state.revision}})
	check(response.get("ok", false) and response.state.busy, "wire action reports immediate busy logical state")
	var turn_revision: int = response.state.revision
	await create_timer(main.presentation_duration + 0.1).timeout
	response = await exchange(peer, {"id":"completed", "token":credential, "method":"get_state", "params":{}})
	check(not response.state.busy and response.state.revision > turn_revision, "wire real presentation completion")
	var completion_event := false
	for event in events:
		if event.state.revision > turn_revision and not event.state.busy: completion_event = true
	check(completion_event, "presentation completion notification received")
	peer.put_data("not-json\n".to_utf8_buffer())
	await process_frame
	response = await exchange(peer, {"id":"malformed-followup", "token":credential, "method":"get_state", "params":{}})
	check(response.get("ok", false), "malformed line does not crash or desynchronize")
	main.mcp_bridge.disable()
	check(not main.mcp_bridge.connection_info().enabled and main.mcp_bridge.clients.is_empty(), "disable immediately disconnects")
	main.queue_free()
	for i in range(5): await process_frame
	await create_timer(2.5).timeout
	print("MCP controller real-scene checks: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
