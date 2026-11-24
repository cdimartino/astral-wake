extends Node
## Chart B body only. Travel punctuation belongs to actual presentation commits.
## Never loop a review recording (which also contains a jump and combat).
const BODY_PATH := "res://audio/preview/atmosphere/chart_body.wav"
# The approved PCM was captured after the default 0.5 Master fader. Recover its
# local level once; Music and Master sliders still operate normally at runtime.
const CAPTURE_COMPENSATION_DB := 6.020599913
const EXIT_FADE := 0.35
const MAX_OWNED := 6
var hull: Node
var active := false
var departure_token := 0
var _phase := "idle"
var _clock := 0.0
var _travel_length := 1.6
var _owned: Array[Dictionary] = []
var _body: AudioStreamPlayer
var _body_level := 0.0

func setup(hull_audio: Node) -> void:
	if hull == hull_audio: return
	_stop_owned()
	hull = hull_audio
	active = false
	departure_token += 1

func enter_chart() -> void:
	if active or not is_instance_valid(hull): return
	_stop_owned()
	active = true
	_phase = "idle"
	_clock = 0.0
	_start_body()

func _start_body() -> void:
	if not is_instance_valid(_body):
		var stream: AudioStreamWAV
		# Raw PCM is available in source; exported builds resolve the import.
		if FileAccess.file_exists(BODY_PATH):
			stream = AudioStreamWAV.load_from_file(BODY_PATH)
		else:
			stream = load(BODY_PATH) as AudioStreamWAV
		if stream == null: return
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_body = AudioStreamPlayer.new()
		_body.name = "ChartBody"
		_body.stream = stream
		_body.bus = "Music"
		_body.volume_db = -80.0
		add_child(_body)
	if not _body.playing:
		_body_level = 0.0
		_body.play()

func depart(duration_seconds: float = 1.6) -> void:
	if not active or _phase == "travel": return
	departure_token += 1
	_phase = "travel"
	_travel_length = clampf(duration_seconds, 0.15, 12.0) if is_finite(duration_seconds) else 1.6
	# Soft, bounded swell. Completion never schedules arrival: only the visible
	# transition owner can call arrive(), so skipped/cancelled travel has no echo.
	_emit("score_seam_air", "second breath", -13.0, 0.85, _travel_length + 0.4, minf(0.8, _travel_length * 0.55), 0.4)

func arrive() -> void:
	if not active or _phase != "travel": return
	departure_token += 1
	_phase = "idle"
	_emit("score_glass_fog", "vessel motif", -17.0, 0.75, 0.7, 0.08, 0.5, true)

func leave_chart() -> void:
	if not active: return
	active = false
	departure_token += 1
	_phase = "idle"
	for entry in _owned:
		entry["exit_left"] = EXIT_FADE
		entry["exit_level"] = float(entry.level)

func _emit(cue: String, track: String, gain: float, pitch: float, length: float, attack: float, release: float, arrival: bool = false) -> void:
	if not is_instance_valid(hull): return
	# Use HullAudio's validated sample-bank/mix path rather than loading sources.
	# Its existing track names remain Sound Desk mute/solo targets. _play and
	# _release are the shared local voice helpers; no global stop_all() calls.
	var before: Array = hull.voices.duplicate()
	hull._play(cue, gain, pitch, track, -1.0)
	for voice in hull.voices:
		if before.has(voice): continue
		if _owned.size() >= MAX_OWNED: _release_entry(_owned[0])
		var entry := {"voice": voice, "cue": cue, "track": track, "age": 0.0,
			"length": length, "attack": attack, "release": release,
			"base_db": voice.volume_db, "level": 0.0, "exit_left": -1.0, "arrival": arrival}
		voice.volume_db = -80.0
		_owned.append(entry)

func _allowed(entry: Dictionary) -> bool:
	var cue: Dictionary = hull.bank.get("cues", {}).get(entry.cue, {})
	var group := str(cue.get("group", ""))
	if hull.muted.get(entry.cue, false) or hull.muted.get(group, false) or hull.muted.get(entry.track, false): return false
	return hull.solo.is_empty() or hull.solo in [entry.cue, group, entry.track]

func _process(delta: float) -> void:
	if not is_instance_valid(hull): return
	if active: _clock += delta
	if is_instance_valid(_body) and _body.playing:
		var audible: bool = active and _allowed({"cue":"score_seam_air", "track":"second breath"})
		var desired := (0.38 if _phase == "travel" else 1.0) if audible else 0.0
		_body_level = move_toward(_body_level, desired, delta / (0.18 if desired > _body_level else EXIT_FADE))
		_body.volume_db = maxf(-80.0, CAPTURE_COMPENSATION_DB + linear_to_db(maxf(0.0001, _body_level)))
		if not active and _body_level <= 0.0: _body.stop()
	for entry in _owned.duplicate():
		var voice: AudioStreamPlayer = entry.voice
		if not is_instance_valid(voice) or not hull.voices.has(voice):
			_owned.erase(entry)
			continue
		entry.age += delta
		if not _allowed(entry):
			_release_entry(entry)
			continue
		var level := minf(1.0, float(entry.age) / float(entry.attack))
		level *= clampf((float(entry.length) - float(entry.age)) / float(entry.release), 0.0, 1.0)
		if float(entry.exit_left) >= 0.0:
			entry.exit_left -= delta
			var exit_level := float(entry.exit_level)
			# arrive()+leave_chart() happen in the same presentation callback.
			# Let only this explicit punctuation complete a short soft attack;
			# bed/departure voices never restart during exit or cancellation.
			if bool(entry.arrival): exit_level = level
			level = exit_level * maxf(0.0, float(entry.exit_left)) / EXIT_FADE
		entry.level = level
		if level <= 0.0:
			_release_entry(entry)
		else:
			voice.volume_db = maxf(-80.0, float(entry.base_db) + linear_to_db(level))

func _release_entry(entry: Dictionary) -> void:
	if is_instance_valid(hull) and is_instance_valid(entry.voice):
		hull._release(entry.voice)
	_owned.erase(entry)

func _stop_owned() -> void:
	for entry in _owned.duplicate(): _release_entry(entry)
	if is_instance_valid(_body):
		_body.stop()
	_body_level = 0.0

func _exit_tree() -> void:
	active = false
	departure_token += 1
	_stop_owned()
