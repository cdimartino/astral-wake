extends Node
## Approved opening B3 once, then its quiet breath only. No recurring glass call.
const PATH := "res://audio/preview/atmosphere/opening_title.wav"
const INTRO_FRAMES := 503808
const LOOP_END := 601557
const RATE := 44100.0
const CAPTURE_COMPENSATION_DB := 6.020599913
var hull: Node
var active := false
var opening_started := false
var opening_elapsed := 0.0
var _player: AudioStreamPlayer
var _level := 0.0
var _skip_pending := false

func setup(hull_audio: Node) -> void:
	hull = hull_audio

func _ensure_player() -> bool:
	if is_instance_valid(_player): return true
	var stream: AudioStreamWAV
	if FileAccess.file_exists(PATH): stream = AudioStreamWAV.load_from_file(PATH)
	else: stream = load(PATH) as AudioStreamWAV
	if stream == null: return false
	stream = stream.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = INTRO_FRAMES
	stream.loop_end = LOOP_END
	_player = AudioStreamPlayer.new()
	_player.name = "OpeningAndTitleBreath"
	_player.bus = "Music"
	_player.stream = stream
	_player.volume_db = -80.0
	add_child(_player)
	return true

func begin_opening() -> void:
	if opening_started or not _ensure_player(): return
	opening_started = true
	opening_elapsed = 0.0
	active = true
	_skip_pending = false
	# The approved head begins with a brief contact; don't fade its transient.
	_level = 1.0
	_player.volume_db = CAPTURE_COMPENSATION_DB
	_player.play(0.0)

func enter_title() -> void:
	active = true
	if _ensure_player() and not _player.playing:
		# Returning to the title/ship selection never replays the film's contact
		# or glass gesture. The forward loop contains just the approved breath.
		_player.play(INTRO_FRAMES / RATE)

func finish_opening(skipped: bool) -> void:
	enter_title()
	if skipped: _skip_pending = true

func leave() -> void:
	active = false
	_skip_pending = false

func _process(delta: float) -> void:
	if opening_started: opening_elapsed += delta
	if not is_instance_valid(_player) or not _player.playing: return
	var allowed := true
	if is_instance_valid(hull):
		allowed = not hull.muted.get("score_seam_air", false) and not hull.muted.get("regional atmospheres", false) and not hull.muted.get("second breath", false)
		if not hull.solo.is_empty() and hull.solo not in ["score_seam_air", "regional atmospheres", "second breath"]: allowed = false
	var desired := 1.0 if active and allowed and not _skip_pending else 0.0
	_level = move_toward(_level, desired, delta / (0.08 if _skip_pending else 0.15 if desired > _level else 0.35))
	_player.volume_db = maxf(-80.0, CAPTURE_COMPENSATION_DB + linear_to_db(maxf(0.0001, _level)))
	if _level <= 0.0:
		if _skip_pending:
			_skip_pending = false
			var period := (LOOP_END - INTRO_FRAMES) / RATE
			var phase := fposmod(_player.get_playback_position() - INTRO_FRAMES / RATE, period)
			_player.seek(INTRO_FRAMES / RATE + phase)
		elif not active: _player.stop()

func _exit_tree() -> void:
	if is_instance_valid(_player): _player.stop()
