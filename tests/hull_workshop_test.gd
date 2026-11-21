extends SceneTree

const Main = preload("res://scripts/main.gd")
var failures := 0

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_temp_dir().path_join("hull-workshop-%d" % Time.get_ticks_usec()))
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	_run.call_deferred()

func _run() -> void:
	var ui = Main.new()
	root.add_child(ui)
	await process_frame
	var original = ui.game
	ui._open_settings()
	var snapshot: Dictionary = ui.mcp_controller.snapshot()
	check(not JSON.stringify(snapshot).contains("Sound Desk"), "Admin tools are not player-visible MCP actions")
	ui._enter_admin()
	await process_frame
	check(ui.hull_admin.active and ui.game != original and is_instance_valid(ui.hull_desk), "Settings opens a private, live sound desk")
	var state: Dictionary = ui.mcp_bridge._network_state()
	check(state.busy and state.run.is_empty() and state.legal_actions.is_empty(), "Network cannot see or act on the sandbox")
	var fake_client := {"authenticated":true, "cache":{}, "order":[], "output":PackedByteArray()}
	var command := {"id":"workshop","token":ui.mcp_bridge.token,"method":"act","params":{"action":"close_overlay","args":{},"expected_revision":state.revision}}
	ui.mcp_bridge._handle(fake_client, JSON.stringify(command))
	var denied = JSON.parse_string(fake_client.output.get_string_from_utf8())
	check(denied != null and not denied.ok and denied.error.code == "busy", "An authenticated remote action is refused during local tuning")
	ui._hide_desk()
	ui._render()
	check(ui.hull_admin.active and ui.page.find_children("*", "Button", true, false).any(func(b): return b.text == "Sound Desk"), "Sandbox can be played with the desk hidden")
	ui._show_desk()
	ui._leave_admin()
	check(ui.game == original and not ui.hull_admin.active and not is_instance_valid(ui.hull_desk), "Leaving restores the original session")
	check(not ui.mcp_bridge._network_state().busy, "Player bridge resumes after leaving")
	ui.hull_audio.stop_all()
	ui.queue_free()
	await process_frame
	await create_timer(.4).timeout
	print("LIVE WORKSHOP: ", failures, " failures")
	quit(1 if failures else 0)
