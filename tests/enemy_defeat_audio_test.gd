extends SceneTree
const Hull = preload("res://scripts/hull_audio.gd")
const Defeat = preload("res://scripts/enemy_defeat_audio.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var storage := OS.get_environment("ASTRAL_SAVE_DIR")
	assert(not storage.is_empty(), "Fresh isolated ASTRAL_SAVE_DIR required")
	var hull := Hull.new()
	root.add_child(hull)
	hull.initialize(storage)
	hull.set_process(false)
	var helper := Defeat.new()
	root.add_child(helper)
	helper.setup(hull)
	helper.set_process(false)
	var bank: Dictionary = hull.bank.duplicate(true)
	var preset: Dictionary = hull.preset_snapshot()
	var buses := AudioServer.bus_count
	var master := AudioServer.get_bus_volume_db(0)
	hull.play_cue("score_reed_mist")
	var other: AudioStreamPlayer = hull.voices.back()
	helper.resolved_batch("not-dead", 0, true)
	helper.resolved_batch("", 2, true)
	assert(helper._owned.is_empty() and helper._pending.is_empty())
	helper.resolved_batch("one", 1)
	assert(helper._owned.size() == 1 and helper._pending.size() == 2)
	assert(helper._owned[0].bus == "Combat")
	assert(is_equal_approx(helper._owned[0].volume_db, -14.0))
	helper.resolved_batch("one", 5, true)
	assert(helper._owned.size() == 1 and helper._pending.size() == 2, "Stable key deduplicates")
	helper.cancel()
	assert(hull.voices.has(other))
	helper.resolved_batch("simultaneous", 8)
	assert(helper._owned.size() == 1, "Eight simultaneous deaths are one contact")
	helper.cancel()
	# A guardian retains its exact slot and timing; no play_stinger/persistence.
	hull._stinger = "guardian_2"
	hull._stinger_time = 1.25
	helper.resolved_batch("clear", 3, true)
	assert(helper._pending.size() == 3)
	helper._process(0.11)
	assert(helper._owned.size() == 2 and helper._pending.size() == 2)
	helper._process(0.22)
	helper._process(0.22)
	assert(helper._pending.is_empty() and helper._owned.size() == 4)
	assert(hull._stinger == "guardian_2" and hull._stinger_time == 1.25)
	assert(hull._seen.is_empty(), "No committed-stinger/save side effect")
	helper.cancel()
	hull.stingers_enabled = false
	helper.resolved_batch("no-music", 1, true)
	assert(helper._owned.size() == 1 and helper._pending.is_empty())
	helper.cancel()
	hull.stingers_enabled = true
	hull._stinger = "victory"
	helper.resolved_batch("voyage-end", 1, true)
	assert(helper._pending.is_empty(), "Voyage ending remains authoritative")
	helper.cancel()
	hull._stinger = ""
	for target in ["combat_vent", "support/status"]:
		hull.muted[target] = true
		helper.resolved_batch("mute-" + target, 1)
		assert(helper._owned.is_empty())
		hull.muted.clear()
	hull.solo = "vessel motif"
	helper.resolved_batch("track-solo", 1, true)
	assert(helper._owned.is_empty())
	helper._process(0.11)
	assert(helper._owned.size() == 1 and helper._owned[0].bus == "Music")
	hull.muted["vessel motif"] = true
	helper._process(0.01)
	assert(helper._owned.is_empty())
	helper.cancel()
	hull.muted.clear()
	hull.solo = ""
	hull.overrides["combat_vent"] = {"gain_db": -20.0, "pitch": 0.5, "patch": "combat_vent_hollow"}
	helper.resolved_batch("override", 1)
	assert(helper._owned[0].get_meta("patch") == "combat_vent_hollow")
	assert(is_equal_approx(helper._owned[0].volume_db, -24.0))
	assert(is_equal_approx(helper._owned[0].pitch_scale, 0.41))
	helper.cancel()
	hull.overrides.clear()
	helper.resolved_batch("cancel", 1, true)
	helper.cancel()
	var count := hull.voices.size()
	helper._process(2.0)
	assert(hull.voices.size() == count and hull.voices.has(other))
	helper.resolved_batch("suspended-frame", 7, true)
	helper._process(2.0)
	assert(helper._owned.size() == 2 and helper._pending.is_empty(), "A long frame emits at most one due musical note")
	helper.cancel()
	helper.resolved_batch("natural-finish", 1, true)
	helper.set_process(true)
	await create_timer(1.5).timeout
	assert(helper._owned.is_empty() and helper._pending.is_empty(), "Naturally freed playback is retired without typed-array errors")
	helper.set_process(false)
	helper.resolved_batch("detach", 1, true)
	helper.queue_free()
	await process_frame
	assert(hull.voices.size() == 1 and hull.voices.has(other))
	assert(hull.bank == bank and hull.preset_snapshot() == preset)
	assert(AudioServer.bus_count == buses and AudioServer.get_bus_volume_db(0) == master)
	hull.stop_all()
	hull.queue_free()
	await create_timer(1.0).timeout
	print("PASS enemy defeat audio: dedup, simultaneous deaths, clear cadence, guardian/ending priority, mix controls, cancel/detach and no bank/master/save mutations")
	quit(0)
