extends SceneTree
const Hull = preload("res://scripts/hull_audio.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := OS.get_environment("ASTRAL_SAVE_DIR")
	if directory.is_empty() or directory.begins_with(ProjectSettings.globalize_path("res://")):
		push_error("ASTRAL_SAVE_DIR must name an isolated external test directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(44100)
	for index in 22050: bytes.encode_s16(index * 2, int(sin(index * .04) * 2000))
	wav.data = bytes
	wav.save_to_wav(directory.path_join("take.wav"))
	var manifest := {"version": 1, "patches": {"a": {"file": "take.wav", "root": 60}, "b": {"file": "take.wav", "root": 60}}, "cues": {"hit": {"group": "combat", "bus": "Combat", "variants": ["a", "b"], "gain_db": -6}}, "scores": {"region_0": {"length": 2.0, "events": [{"time": 0, "duration": .3, "cue": "hit", "note": 60, "velocity": 100, "track": "hull"}]}, "victory": {"length": 1.0, "events": []}}}
	manifest.scores.guardian_0 = {"length": .5, "events": [{"time": 0, "duration": .2, "cue": "hit", "track": "hull contact"}, {"time": .02, "duration": .2, "cue": "hit", "track": "motif"}]}
	var file := FileAccess.open(directory.path_join("bank.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var hull = Hull.new()
	root.add_child(hull)
	hull.storage = directory
	check(hull.reload_bank(directory.path_join("bank.json")), "Valid PCM bank loads")
	var pack_dir := directory.path_join("banks/test-pack")
	DirAccess.make_dir_recursive_absolute(pack_dir)
	DirAccess.copy_absolute(directory.path_join("take.wav"), pack_dir.path_join("take.wav"))
	DirAccess.copy_absolute(directory.path_join("bank.json"), pack_dir.path_join("bank.json"))
	check(hull.command(["packs"]).contains("test-pack"), "Named packs are discoverable")
	check(hull.command(["bank", "test-pack"]) == "Bank active: test-pack", "Named external bank activates atomically")
	check(not hull.command(["reload", "/forbidden/bank.json"]).contains("/forbidden"), "Commands do not echo absolute paths")
	hull.command(["stinger", "guardian_0", "off"])
	check(hull.preset_snapshot().stinger_overrides.guardian_0 == false, "Per-ID stinger switch is saved in snapshot")
	check(hull.command(["bind", "hit", "b"]) == "Updated hit", "Bind valid patch")
	check(hull.command(["mix", "hit", "pan", ".5"]) == "Updated hit", "Pan accepted")
	check(hull.command(["mix", "hit", "pitch", "0"]) .begins_with("Invalid"), "Bad pitch rejected")
	hull.command(["preset", "save", "roundtrip"])
	hull.command(["factory"])
	hull.command(["preset", "load", "roundtrip"])
	check(hull.overrides.hit.patch == "b", "Preset round trip")
	var bus := AudioServer.get_bus_index("Combat")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Combat")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2
	AudioServer.add_bus_effect(bus, capture)
	hull.play_cue("hit")
	var voice = hull.voices[0]
	check(voice.bus.begins_with("HullVoice_"), "Stereo pan is physically applied")
	await create_timer(.2).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > .001 and peak < .99, "Real mixer decodes unclipped PCM")
	check(not hull.reload_bank(directory.path_join("missing.json")), "Broken reload rejected")
	check(voice.playing and hull.bank.cues.has("hit"), "Broken reload retains voices and bank")
	var incomplete: Dictionary = manifest.duplicate(true)
	incomplete.cues = {}
	file = FileAccess.open(directory.path_join("incomplete.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(incomplete))
	file.close()
	check(not hull.reload_bank(directory.path_join("incomplete.json")), "Incomplete cue catalog rejected")
	var invalid: Dictionary = manifest.duplicate(true)
	invalid.patches.a.file = "../escape.wav"
	file = FileAccess.open(directory.path_join("invalid.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	check(not hull.reload_bank(directory.path_join("invalid.json")), "Parent directory sample escape rejected")
	DirAccess.open(directory).create_link(directory.path_join("take.wav"), directory.path_join("link.wav"))
	invalid.patches.a.file = "link.wav"
	file = FileAccess.open(directory.path_join("invalid.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	check(not hull.reload_bank(directory.path_join("invalid.json")), "Symlink sample escape rejected")
	hull.set_score("region_0")
	await create_timer(.1).timeout
	var time: float = hull.score_time
	hull.set_score("region_0", true)
	check(hull.score_time == time, "Tension preserves phrase position")
	check(hull.trace.size() >= 2, "Scheduler plays score events")
	hull.play_stinger("victory", "final")
	hull.play_stinger("victory", "final")
	check(hull._seen.size() == 1, "Committed stinger deduplicates")
	var snapshot: Dictionary = hull.preset_snapshot()
	snapshot.stingers_enabled = false
	snapshot.muted = {"hit": true}
	check(hull.apply_preset(snapshot) and not hull.stingers_enabled and hull.muted.hit, "Scenario snapshot restores mutes and stingers")
	hull.command(["mute", "hit"])
	for index in range(15): hull.play_cue("hit")
	check(hull.voices.size() <= 12, "Combat voice pool is bounded at twelve")
	hull.stop_all()
	hull.trace.clear()
	hull.stingers_enabled = false
	hull.play_stinger("guardian_0", "reveal_without_music")
	await create_timer(.1).timeout
	check(hull.trace.size() == 1 and hull.trace[0].track == "hull contact", "Guardian A/B silence preserves authored hull contact only")
	hull.stop_all()
	check(hull.voices.is_empty(), "All voice resources released")
	await process_frame
	hull.queue_free()
	await create_timer(.2).timeout
	print("HULL RUNTIME: %d failures" % failures)
	quit(1 if failures else 0)
