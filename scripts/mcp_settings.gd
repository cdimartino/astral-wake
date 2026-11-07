extends RefCounted

## Adds saved local MCP controls to the existing Settings modal.
static func populate(main: Control, body: VBoxContainer) -> void:
	var bridge = main.get("mcp_bridge")
	if bridge == null:
		body.add_child(main.call("_text", "Local AI control is unavailable.", 16))
		return

	body.add_child(main.call("_label", "Local AI control (MCP)", 20))
	body.add_child(main.call("_text", "Allow an AI client to control this game on this Mac. Your choice and connection details are saved for future launches.", 16))
	var enable := CheckBox.new()
	enable.name = "MCP_Enabled"
	enable.text = "Enable local AI control"
	enable.button_pressed = main.game.profile.get("settings", {}).get("mcp_enabled", false) or bridge.connection_info().get("enabled", false)
	enable.tooltip_text = "Only listens on this Mac (127.0.0.1). Turning this off disconnects clients."
	body.add_child(enable)
	var port_row := HBoxContainer.new()
	port_row.add_child(main.call("_label", "Port (0 = choose automatically)", 16))
	var port_input := SpinBox.new()
	port_input.name = "MCP_Port"
	port_input.min_value = 0
	port_input.max_value = 65535
	port_input.step = 1
	var saved_port = main.game.profile.get("settings", {}).get("mcp_port", 0)
	port_input.value = float(saved_port) if (saved_port is int or saved_port is float) and is_finite(float(saved_port)) else 0
	port_input.custom_minimum_size = Vector2(110, 40)
	port_row.add_child(port_input)
	body.add_child(port_row)

	var status: Label = main.call("_text", "", 16)
	status.name = "MCP_Status"
	body.add_child(status)
	var address: Label = main.call("_text", "", 16)
	address.name = "MCP_Address"
	body.add_child(address)
	var credential: Label = main.call("_text", "", 16)
	credential.name = "MCP_Token"
	credential.set_meta("mcp_private", true)
	credential.add_theme_color_override("font_color", Color("e7c381"))
	body.add_child(credential)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	var reveal := Button.new()
	reveal.name = "MCP_Reveal"
	reveal.custom_minimum_size.y = 44
	reveal.focus_mode = Control.FOCUS_ALL
	actions.add_child(reveal)
	var copy := main.call("_button", "Copy client config", func(): pass, "Copies the local connection details, including the token, to the clipboard.") as Button
	copy.name = "MCP_CopyConfig"
	actions.add_child(copy)
	var copied: Label = main.call("_text", "", 16)
	copied.name = "MCP_Copied"
	body.add_child(copied)

	var reveal_state := {"visible": false}
	var refresh := func(error_message: String = ""):
		var info: Dictionary = bridge.connection_info()
		var active: bool = info.get("enabled", false)
		if error_message.is_empty(): error_message = str(info.get("error", ""))
		if not error_message.is_empty():
			status.text = "Couldn't start local control: %s. Turn the setting off and on to try again, or pick another port." % error_message
			status.add_theme_color_override("font_color", Color("f39789"))
		elif active:
			status.text = "Active · this session only" if info.get("session_only", true) else "Active · saved in settings"
			status.add_theme_color_override("font_color", Color("7be0ca"))
		else:
			status.text = "Off · no AI client is connected"
			status.add_theme_color_override("font_color", Color("b5c6d2"))
		address.text = "Local bridge: %s:%s (MCP uses the stdio server)" % [info.get("host", "127.0.0.1"), str(info.get("port", "—"))] if active else "Endpoint appears here when enabled."
		credential.text = "Authentication token: %s" % (str(info.get("token", "")) if reveal_state.visible and active else ("(hidden — reveal to view)" if active else "(not available while off)"))
		reveal.text = "Hide token" if reveal_state.visible else "Reveal token"
		reveal.disabled = not active
		copy.disabled = not active
		if not active: reveal_state.visible = false

	refresh.call()
	reveal.pressed.connect(func():
		reveal_state.visible = not reveal_state.visible
		refresh.call()
	)
	enable.toggled.connect(func(pressed: bool):
		copied.text = ""
		if pressed:
			var result: Dictionary = bridge.enable_saved(int(port_input.value))
			if not result.get("ok", false):
				refresh.call(str(result.get("error", "Unknown bind error")))
				return
			port_input.set_value_no_signal(bridge.connection_info().port)
		else:
			bridge.disable_saved()
		refresh.call()
	)
	port_input.value_changed.connect(func(value: float):
		if not enable.button_pressed: return
		bridge.enable_saved(int(value))
		if bridge.connection_info().enabled: port_input.set_value_no_signal(bridge.connection_info().port)
		refresh.call()
	)
	copy.pressed.connect(func():
		var info: Dictionary = bridge.connection_info()
		if not info.get("enabled", false): return
		# Match docs/mcp.md: the shipped server is a stdio process, not HTTP.
		var server_path := ProjectSettings.globalize_path("res://") + "tools/astral_mcp.py"
		var config := {"mcpServers": {"astral-wake": {
			"command": "/usr/bin/env",
			"args": ["python3", server_path, "--port", str(info.port)],
			"env": {"ASTRAL_MCP_TOKEN": str(info.token)}}}}
		DisplayServer.clipboard_set(JSON.stringify(config, "\t"))
		copied.text = "Client config copied. Treat it like a password; it contains your token." if FileAccess.file_exists(server_path) else "Client config copied. The MCP server ships with the game source; point args at tools/astral_mcp.py in your checkout."
	)
