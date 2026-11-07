extends SceneTree

const Main = preload("res://scripts/main.gd")
const MCPSettings = preload("res://scripts/mcp_settings.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_MCP_PORT", "")
	OS.set_environment("ASTRAL_MCP_TOKEN", "")
	var base := OS.get_environment("ASTRAL_SAVE_DIR")
	if base.is_empty(): base = OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_cache_dir()
	var isolated := base.path_join("astral-mcp-settings-" + Crypto.new().generate_random_bytes(16).hex_encode())
	if DirAccess.make_dir_recursive_absolute(isolated) != OK:
		push_error("Cannot create isolated MCP settings save directory")
		quit(1)
		return
	OS.set_environment("ASTRAL_SAVE_DIR", isolated)
	print("MCP_SETTINGS_SAVE_DIR ", isolated)
	run_checks.call_deferred()

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run_checks() -> void:
	var ui := Main.new()
	root.add_child(ui)
	for i in range(5): await process_frame
	var body := VBoxContainer.new()
	MCPSettings.populate(ui, body)
	root.add_child(body)
	var bridge = ui.mcp_bridge
	var toggle := body.find_child("MCP_Enabled", true, false) as CheckBox
	var status := body.find_child("MCP_Status", true, false) as Label
	var address := body.find_child("MCP_Address", true, false) as Label
	var token_label := body.find_child("MCP_Token", true, false) as Label
	var reveal := body.find_child("MCP_Reveal", true, false) as Button
	var copy := body.find_child("MCP_CopyConfig", true, false) as Button
	var port_input := body.find_child("MCP_Port", true, false) as SpinBox
	require(toggle != null and not toggle.button_pressed, "MCP defaults to disabled")
	require(status != null and status.text.contains("Off"), "Disabled state is clear")
	require(address != null and not address.text.contains("http://127.0.0.1:"), "Endpoint is not advertised while disabled")
	toggle.button_pressed = true
	require(bridge.connection_info().enabled and not bridge.connection_info().session_only, "Enabling starts saved MCP")
	require(status.text == "Active · saved in settings", "Saved status is explicit")
	var saved_port: int = bridge.connection_info().port
	require(saved_port > 0 and int(port_input.value) == saved_port, "Automatic port becomes stable saved endpoint")
	require(status.text.contains("Active") and address.text.contains("127.0.0.1"), "Active state and usable loopback endpoint are shown")
	var token: String = bridge.connection_info().token
	require(token.length() >= 32 and token_label.text.contains("hidden"), "Generated token stays hidden by default")
	require(token_label.get_meta("mcp_private", false), "Token label is excluded from MCP snapshots")
	reveal.pressed.emit()
	require(token_label.text.contains(token), "Deliberate reveal shows the generated token")
	require(token_label.get_meta("mcp_private", false), "Revealed token remains snapshot-private")
	ui._open_settings()
	var actual_reveal := ui.overlay.find_child("MCP_Reveal", true, false) as Button
	actual_reveal.pressed.emit()
	require(not JSON.stringify(ui.mcp_controller.request("get_state", {})).contains(token), "Serialized get_state never includes saved token even after reveal")
	# Recreate the real controller using the same isolated save directory.
	body.queue_free()
	ui.queue_free()
	for i in range(5): await process_frame
	ui = Main.new()
	root.add_child(ui)
	for i in range(5): await process_frame
	bridge = ui.mcp_bridge
	require(bridge.connection_info().enabled and bridge.connection_info().port == saved_port and bridge.connection_info().token == token, "Restart restores enabled listener, stable port and credential")
	body = VBoxContainer.new()
	MCPSettings.populate(ui, body)
	root.add_child(body)
	toggle = body.find_child("MCP_Enabled", true, false)
	status = body.find_child("MCP_Status", true, false)
	reveal = body.find_child("MCP_Reveal", true, false)
	copy = body.find_child("MCP_CopyConfig", true, false)
	port_input = body.find_child("MCP_Port", true, false)
	require(int(port_input.value) == saved_port, "Settings opens with saved port")
	toggle.button_pressed = false
	require(not bridge.connection_info().enabled and status.text.contains("Off"), "Disabling closes the listener")
	require(reveal.disabled and copy.disabled, "Credential actions are unavailable while disabled")
	require(not ui.game.profile.settings.mcp_enabled and ui.game.profile.settings.mcp_token == token, "Disable persists consent off while keeping credential")
	# Force a bind failure by occupying the selected port, then verify useful inline feedback.
	var blocker := TCPServer.new()
	var bind_status := blocker.listen(0, "127.0.0.1")
	if bind_status == OK:
		var occupied_port := blocker.get_local_port()
		port_input.value = occupied_port
		toggle.button_pressed = true
		require(not bridge.connection_info().enabled and status.text.contains("Couldn't start") and status.text.contains("unavailable") and ui.game.profile.settings.mcp_enabled, "Bind failure preserves enabled preference and persistent error")
		body.queue_free()
		ui.queue_free()
		for i in range(5): await process_frame
		ui = Main.new()
		root.add_child(ui)
		for i in range(5): await process_frame
		bridge = ui.mcp_bridge
		require(not bridge.connection_info().enabled and not bridge.connection_info().error.is_empty() and int(ui.game.profile.settings.mcp_port) == occupied_port, "Restart bind failure retains endpoint and error without fallback")
		blocker.stop()
		bridge.enable_saved(occupied_port)
		require(bridge.connection_info().enabled and bridge.connection_info().token == token, "Retry reuses saved token")
	else:
		require(false, "Could not reserve loopback port for bind feedback check")
	bridge.disable_saved()
	ui.queue_free()
	for i in range(5): await process_frame
	ui = Main.new()
	root.add_child(ui)
	for i in range(5): await process_frame
	require(not ui.mcp_bridge.connection_info().enabled, "Disable survives restart")
	ui.queue_free()
	for i in range(5): await process_frame
	var env_port_server := TCPServer.new()
	env_port_server.listen(0, "127.0.0.1")
	var env_port := env_port_server.get_local_port()
	env_port_server.stop()
	OS.set_environment("ASTRAL_MCP_PORT", str(env_port))
	OS.set_environment("ASTRAL_MCP_TOKEN", "environment-only-credential-1234567890")
	ui = Main.new()
	root.add_child(ui)
	for i in range(5): await process_frame
	require(ui.mcp_bridge.connection_info().enabled and ui.mcp_bridge.connection_info().session_only, "Environment path remains session only")
	require(not ui.game.profile.settings.mcp_enabled and ui.game.profile.settings.mcp_token == token, "Environment path leaves saved consent and token untouched")
	ui.game.profile.settings.mcp_enabled = true
	ui.game.profile.settings.mcp_port = "invalid"
	ui.game.profile.settings.mcp_token = []
	ui.game.save()
	ui.queue_free()
	for i in range(5): await process_frame
	OS.set_environment("ASTRAL_MCP_PORT", "")
	OS.set_environment("ASTRAL_MCP_TOKEN", "")
	ui = Main.new()
	root.add_child(ui)
	for i in range(5): await process_frame
	require(not ui.mcp_bridge.connection_info().enabled and ui.mcp_bridge.connection_info().error.contains("Invalid saved port"), "Malformed persisted endpoint safely fails closed")
	require(ui.mcp_bridge.enable_saved(0).ok and ui.mcp_bridge.connection_info().token.length() == 64, "Invalid saved credential replaced with random token on explicit retry")
	ui.mcp_bridge.disable_saved()
	ui.queue_free()
	for i in range(5): await process_frame
	await create_timer(2.5).timeout
	print("MCP_SETTINGS ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
