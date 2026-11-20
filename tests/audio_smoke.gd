extends SceneTree
const Hull = preload("res://scripts/hull_audio.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func capture_cue(hull: Node, id: String, capture: AudioEffectCapture) -> void:
	hull.stop_all()
	capture.clear_buffer()
	hull.play_cue(id)
	var timeout := Time.get_ticks_msec() + 15000
	while not hull.active_cues().is_empty() and Time.get_ticks_msec() < timeout:
		await create_timer(.02).timeout
	check(hull.active_cues().is_empty(), "One-shot ends: " + id)
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > .00001 and peak < .99, "Actual decoded cue is audible and unclipped: %s peak=%f" % [id, peak])

func _run() -> void:
	var directory := OS.get_environment("ASTRAL_SAVE_DIR")
	if directory.is_empty() or directory.begins_with(ProjectSettings.globalize_path("res://")):
		push_error("ASTRAL_SAVE_DIR must name an isolated external test directory")
		quit(1)
		return
	var hull = Hull.new()
	root.add_child(hull)
	hull.initialize(directory)
	check(not hull.bank.is_empty(), "Factory bank decodes")
	if hull.bank.is_empty():
		push_error(hull.last_error)
		quit(1)
		return
	hull.command(["preset", "load", "alternate"])
	hull.command(["stinger", "off"])
	hull.command(["preset", "save", "smoke-selected"])
	var second = Hull.new()
	root.add_child(second)
	second.initialize(directory)
	check(second.overrides == hull.overrides and not second.stingers_enabled, "Named selected preset survives service relaunch")
	second.queue_free()
	hull.command(["factory"])
	var captures := {}
	for bus in ["Music", "Combat", "Interface"]:
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 8
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), capture)
		captures[bus] = capture
	for id in hull.options("cues"):
		var cue: Dictionary = hull.bank.cues[id]
		var capture: AudioEffectCapture = captures[cue.bus]
		for patch in cue.variants:
			hull.command(["bind", id, patch])
			await capture_cue(hull, id, capture)
	hull.command(["factory"])
	for region in range(6):
		var id := "region_%d" % region
		if not hull.bank.scores.has(id):
			check(false, "Missing score " + id)
			continue
		hull.stop_all()
		var capture: AudioEffectCapture = captures.Music
		capture.clear_buffer()
		hull.set_score(id)
		hull.score_time = float(hull.bank.scores[id].length) - .1
		await create_timer(.5).timeout
		check(hull.score_time < 1, "Region timeline wraps: " + id)
		var frames := capture.get_buffer(capture.get_frames_available())
		check(not frames.is_empty(), "Mixer runs across score wrap: " + id)
		var peak := 0.0
		for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		# Sparse authored rests are intentional: zero at a seam is allowed.
		check(peak < .99, "Region wrap does not clip: " + id)
	hull.stop_all()
	hull.trace.clear()
	hull.stingers_enabled = false
	hull.play_stinger("guardian_2", "smoke-guardian-" + str(Time.get_ticks_usec()))
	await create_timer(.3).timeout
	check(not hull.trace.is_empty(), "Actual guardian preserves nonmusical contact with stinger disabled")
	for entry in hull.trace: check(entry.track == "hull contact", "Disabled guardian suppresses musical tracks")
	check(not hull.trace.is_empty(), "Playback traces actual sample voices")
	hull.stop_all()
	check(hull.active_cues().is_empty(), "Teardown releases all voices")
	await process_frame
	hull.queue_free()
	await create_timer(.2).timeout
	print("HULL AUDIO SMOKE: %d failures" % failures)
	quit(1 if failures else 0)
