extends SceneTree
const Hull = preload("res://scripts/hull_audio.gd")
const Voyage = preload("res://scripts/voyage_audio.gd")
var hull: Node
var voyage: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var storage := OS.get_environment("ASTRAL_SAVE_DIR")
	assert(not storage.is_empty(), "Use a fresh isolated ASTRAL_SAVE_DIR")
	hull = Hull.new()
	root.add_child(hull)
	hull.initialize(storage)
	hull.set_process(false)
	assert(hull.last_error.is_empty())
	voyage = Voyage.new()
	root.add_child(voyage)
	voyage.setup(hull)
	voyage.set_process(false)
	var bank_before: Dictionary = hull.bank.duplicate(true)
	var preferences: Dictionary = hull.preset_snapshot()
	hull.play_cue("combat_attack")
	# A known non-voyage voice verifies that cancellation is narrowly owned.
	hull.play_cue("score_reed_mist")
	var other: AudioStreamPlayer = hull.voices.back()
	voyage.enter_chart()
	voyage._process(0.1)
	assert(voyage._owned.size() == 1)
	voyage.enter_chart()
	voyage._process(0.1)
	assert(voyage._owned.size() == 1, "Repeated render must not restart bed")
	voyage.depart(2.0)
	var token: int = voyage.departure_token
	var count: int = hull.voices.size()
	voyage.depart(2.0)
	assert(voyage.departure_token == token and hull.voices.size() == count)
	voyage._process(0.2)
	voyage.leave_chart()
	assert(voyage.departure_token > token)
	token = voyage.departure_token
	voyage.leave_chart()
	assert(voyage.departure_token == token, "Repeated leave must not extend tails")
	voyage.arrive()
	voyage._process(0.36)
	assert(voyage._owned.is_empty() and hull.voices.has(other))
	count = hull.voices.size()
	voyage._process(30.0)
	assert(hull.voices.size() == count, "No delayed travel/arrival after leave")
	for target in ["score_seam_air", "regional atmospheres", "second breath"]:
		hull.muted[target] = true
		voyage.enter_chart()
		voyage._process(0.1)
		assert(voyage._owned.is_empty(), "Honor cue/group/track mute")
		voyage.leave_chart()
		hull.muted.clear()
	hull.solo = "score_reed_mist"
	voyage.enter_chart()
	voyage._process(0.1)
	assert(voyage._owned.is_empty())
	voyage.leave_chart()
	hull.solo = "second breath"
	hull.overrides["score_seam_air"] = {"gain_db": -21.0, "pitch": 0.8, "patch": "pressure"}
	voyage.enter_chart()
	voyage._process(0.1)
	assert(voyage._owned.size() == 1)
	var voice: AudioStreamPlayer = voyage._owned[0].voice
	assert(voice.get_meta("patch") == "pressure")
	assert(is_equal_approx(voice.pitch_scale, 0.6))
	assert(is_equal_approx(float(voyage._owned[0].base_db), -39.0))
	assert(voice.bus == "Music")
	hull.muted["second breath"] = true
	voyage._process(0.1)
	assert(voyage._owned.is_empty(), "Live mute applies to existing voyage voice")
	hull.muted.clear()
	hull.solo = ""
	hull.overrides.clear()
	voyage.leave_chart()
	voyage.enter_chart()
	voyage._process(0.1)
	voyage.depart(1.0)
	voyage.arrive()
	count = hull.voices.size()
	voyage.arrive()
	assert(hull.voices.size() == count, "Arrival is one-shot per departure")
	voyage.leave_chart()
	voyage._process(0.36)
	hull.set_score("region_2")
	var other_level: float = other.volume_db
	voyage.enter_chart()
	voyage._process(0.1)
	voyage.depart(0.62)
	voyage._process(0.62)
	voyage.arrive()
	voyage.leave_chart()
	voyage.arrive()
	voyage._process(0.1)
	var audible_arrival := false
	for entry in voyage._owned:
		if entry.arrival and entry.voice.volume_db > -80.0: audible_arrival = true
	assert(audible_arrival, "Same-callback arrival/leave keeps a soft bounded punctuation")
	voyage._process(0.26)
	assert(voyage._owned.is_empty())
	assert(hull.score_id == "region_2" and other.volume_db == other_level and hull.voices.has(other))
	# Rapid skip: no elapsed travel frame, followed by the same once-only finish.
	voyage.enter_chart()
	voyage.depart(0.62)
	voyage.arrive()
	voyage.leave_chart()
	voyage._process(0.36)
	assert(voyage._owned.is_empty() and hull.voices.has(other))
	voyage.enter_chart()
	voyage._process(0.1)
	voyage.depart(0.62)
	voyage.queue_free()
	await process_frame
	assert(hull.voices.has(other))
	for remaining in hull.voices:
		assert(remaining == other or remaining.get_meta("category") == "Combat")
	assert(hull.bank == bank_before and hull.preset_snapshot() == preferences)
	hull.stop_all()
	hull.queue_free()
	await process_frame
	await process_frame
	# Let the audio thread release stopped playbacks before engine shutdown.
	await create_timer(0.15).timeout
	print("PASS voyage lifecycle, cancellation, ownership, mix controls and bank invariants")
	quit(0)
