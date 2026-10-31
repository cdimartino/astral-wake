extends SceneTree

const Main = preload("res://scripts/main.gd")
const Game = preload("res://scripts/game.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-audio-settings-%d" % Time.get_ticks_usec())
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
	var legacy: Dictionary = ui.game.profile.duplicate(true)
	for key in ["music_volume", "combat_volume", "interface_volume"]: legacy.settings.erase(key)
	require(ui.game._valid_profile(legacy), "Legacy master-only settings must remain valid")
	for key in ["music_volume", "combat_volume", "interface_volume"]:
		for invalid in [-0.1, 1.1, INF, NAN, "loud", true]:
			var profile := legacy.duplicate(true)
			profile.settings[key] = invalid
			require(not ui.game._valid_profile(profile), "Reject invalid category volume: " + key)
	ui.game.profile = legacy
	ui._apply_settings()
	for category in ["Music", "Combat", "Interface"]:
		var bus := AudioServer.get_bus_index(category)
		require(not AudioServer.is_bus_mute(bus) and is_zero_approx(AudioServer.get_bus_volume_db(bus)), "Legacy category defaults to 100%")
	ui._open_settings()
	for i in range(5): await process_frame
	for key in ["volume", "music_volume", "combat_volume", "interface_volume"]:
		var slider := ui.overlay.find_child("Volume_" + key, true, false) as HSlider
		require(slider != null, "Settings exposes " + key)
		if slider != null: slider.value = {"volume":0.65, "music_volume":0.0, "combat_volume":0.35, "interface_volume":0.8}[key]
	require(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music mute applies immediately")
	require(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Combat")), "Music mute does not mute combat")
	require(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Combat"))), 0.35), "Combat gain applies independently")
	require(ui.ambience.bus == "Music" and ui.audio.bus == "Interface" and ui.combat_voices.all(func(voice): return voice.bus == "Combat"), "All players route to their category buses")
	var restored := Game.new(OS.get_environment("ASTRAL_SAVE_DIR"))
	for key in ["volume", "music_volume", "combat_volume", "interface_volume"]:
		require(is_equal_approx(float(restored.profile.settings[key]), float(ui.game.profile.settings[key])), "Volume survives reload: " + key)
	ui.overlay.find_child("Volume_volume", true, false).value = 0.0
	require(AudioServer.is_bus_mute(0), "Master zero mutes all categories")
	ui.game.set_settings({"volume":0.5, "music_volume":1.0, "combat_volume":1.0, "interface_volume":1.0})
	ui._apply_settings()
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	await create_timer(0.15).timeout
	ui.queue_free()
	await process_frame
	print("AUDIO_SETTINGS ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
