extends SceneTree
## Instrument a disposable instance of the real main scene. Only the initial map
## is fixed here; the driver uses player-visible MCP actions for the entire take.
const Main = preload("res://scripts/main.gd")
var capture := AudioEffectCapture.new()
var samples := PackedVector2Array()
var folder := OS.get_environment("ASTRAL_LISTEN_DIR")

func _initialize() -> void:
	if folder.is_empty() or OS.get_environment("ASTRAL_SAVE_DIR").is_empty():
		push_error("Recording requires an isolated output and save directory")
		quit(1)
		return
	_start.call_deferred()

func _start() -> void:
	var ui = Main.new()
	root.add_child(ui)
	# Pick a reproducible Glass Beyond opening without changing either the map
	# rules or a deck. This is a comparison fixture, not a measured blind run.
	for n in range(100):
		ui.game.new_run("GL%04d" % n)
		if ui.game.run.route_regions[0] == 2: break
	assert(ui.game.run.route_regions[0] == 2)
	ui.menu = false
	ui._render()
	var origin_ms := Time.get_ticks_msec()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	while not FileAccess.file_exists(folder.path_join("stop")):
		await process_frame
		if capture.get_frames_available():
			samples.append_array(capture.get_buffer(capture.get_frames_available()))
		if samples.size() > AudioServer.get_mix_rate() * 180:
			push_error("Listening scenario timed out")
			quit(1)
			return
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 4)
	for i in range(samples.size()):
		pcm.encode_s16(i * 4, roundi(clampf(samples[i].x, -1, 1) * 32767))
		pcm.encode_s16(i * 4 + 2, roundi(clampf(samples[i].y, -1, 1) * 32767))
	var take := AudioStreamWAV.new()
	take.format = AudioStreamWAV.FORMAT_16_BITS
	take.mix_rate = AudioServer.get_mix_rate()
	take.stereo = true
	take.data = pcm
	var status := take.save_to_wav(folder.path_join("take.wav"))
	# A reviewer can comment on one instant of the recording. Save the cue
	# names beside it so that a tweak targets the right layer of the mix.
	if "hull_audio" in ui:
		var events: Array = ui.hull_audio.trace.duplicate(true)
		for event in events: event["time_s"] = (int(event.at_ms) - origin_ms) / 1000.0
		var trace_file := FileAccess.open(folder.path_join("cues.json"), FileAccess.WRITE)
		if trace_file: trace_file.store_string(JSON.stringify(events, "  "))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	if "hull_audio" in ui: ui.hull_audio.stop_all()
	ui.queue_free()
	await process_frame
	quit(status)
