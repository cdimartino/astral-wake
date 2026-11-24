extends Node
const MAX_VOICES := 48
const FACTORY_BANK := "res://audio/hull/bank.json"
# Reviewed stereo mixes are pre-Master. The ordinary Music/Master sliders
# supply their playback gain; they are not another instrument in the bank.
const RENDERED_STINGERS := {
	"victory":"res://audio/preview/ending_victory.wav",
	"defeat":"res://audio/preview/ending_defeat.wav",
	"clear_0":"res://audio/preview/warp_0.wav", "clear_1":"res://audio/preview/warp_0.wav",
	"clear_2":"res://audio/preview/warp_1.wav", "clear_3":"res://audio/preview/warp_1.wav",
	"clear_4":"res://audio/preview/warp_2.wav", "clear_5":"res://audio/preview/warp_2.wav",
}
## Sample-bank player and local-only Sound Desk. Existing voices own their streams:
## replacing mappings or reloading the bank never cuts off an active note.

var bank: Dictionary = {}
var overrides: Dictionary = {}
var trace: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer] = []
var storage := ""
var bank_path := FACTORY_BANK
var score_id := ""
var score_loops := true
var score_time := 0.0
var tension := false
var muted: Dictionary = {}
var solo := ""
var stingers_enabled := true
var stinger_overrides: Dictionary = {}
var last_error := ""
var _streams: Dictionary = {}
var _history: Array[Dictionary] = []
var _seen: Dictionary = {}
var _last_cue: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _stinger := ""
var _stinger_time := 0.0
var _stinger_priority := 0
var _stinger_contact_only := false
var _rendered_seconds := 0.0
var _ab: Dictionary = {}
var _take_index: Dictionary = {}
var _levels: Dictionary = {}

func _rms(stream: AudioStreamWAV) -> float:
	if stream.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
		# Decode imported codecs through Godot too; compressed bytes are not PCM.
		var playback := stream.instantiate_playback()
		playback.start()
		var decoded := playback.mix_audio(1.0, mini(220500, ceili(stream.get_length() * AudioServer.get_mix_rate())))
		playback.stop()
		var energy := 0.0
		for frame in decoded: energy += frame.length_squared() * .5
		return sqrt(energy / maxi(1, decoded.size()))
	var data := stream.data
	var energy := 0.0
	var count := 0
	var step := 64 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 32
	for offset in range(0, data.size() - 1, step):
		var sample := float(data.decode_s16(offset)) / 32768 if stream.format == AudioStreamWAV.FORMAT_16_BITS else (float(data[offset]) - 128) / 128
		energy += sample * sample
		count += 1
	return sqrt(energy / maxi(1, count))
const PARAMETERS := ["gain_db", "pitch", "pitch_range", "pan", "variation"]

func initialize(storage_dir: String) -> void:
	storage = storage_dir.path_join("hull_audio")
	DirAccess.make_dir_recursive_absolute(storage)
	_rng.randomize()
	var seen_path := storage.path_join("committed_stingers.json")
	if FileAccess.file_exists(seen_path):
		var seen = JSON.parse_string(FileAccess.get_file_as_string(seen_path))
		if seen is Dictionary and seen.size() <= 4096: _seen = seen
	for bus in ["Music", "Combat", "Interface"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	reload_bank(bank_path)
	var bank_selection := storage.path_join("selected_bank.txt")
	if FileAccess.file_exists(bank_selection):
		var name := FileAccess.get_file_as_string(bank_selection).strip_edges()
		if name != "factory" and options("packs").has(name):
			reload_bank(storage.path_join("banks").path_join(name).path_join("bank.json"))
	var selected := storage.path_join("selected.json")
	if FileAccess.file_exists(selected):
		var name := FileAccess.get_file_as_string(selected).strip_edges()
		_preset(PackedStringArray(["load", name]))

func stop_all() -> void:
	score_id = ""
	_stinger = ""
	_rendered_seconds = 0.0
	for voice in voices.duplicate(): _release(voice)

func _exit_tree() -> void:
	stop_all()

func active_cues() -> PackedStringArray:
	var result := PackedStringArray()
	for voice in voices:
		if voice.playing: result.append(str(voice.get_meta("cue", "")))
	return result

func options(kind: String) -> PackedStringArray:
	var result := PackedStringArray()
	if kind == "packs":
		result.append("factory")
		var directory := DirAccess.open(storage.path_join("banks"))
		if directory != null:
			for name in directory.get_directories():
				if name == name.validate_filename() and not directory.is_link(name) and FileAccess.file_exists(storage.path_join("banks").path_join(name).path_join("bank.json")): result.append(name)
	elif kind == "groups":
		for cue in bank.get("cues", {}).values():
			if not result.has(str(cue.get("group", ""))): result.append(str(cue.get("group", "")))
	else:
		for id in bank.get(kind, {}): result.append(str(id))
	result.sort()
	return result

func _relative(path: String) -> bool:
	return not path.is_absolute_path() and not path.contains("..") and not path.contains(":") and path.get_extension().to_lower() == "wav"

func reload_bank(path: String) -> bool:
	if not FileAccess.file_exists(path):
		last_error = "Bank manifest not found"
		return false
	var manifest_file := FileAccess.open(path, FileAccess.READ)
	if manifest_file == null:
		last_error = "Cannot read bank manifest"
		return false
	if manifest_file.get_length() > 4 * 1024 * 1024:
		last_error = "Manifest exceeds 4 MiB"
		return false
	if not path.begins_with("res://"):
		if storage.is_empty() or not path.simplify_path().begins_with(storage.simplify_path().trim_suffix("/") + "/"):
			last_error = "User bank must be inside the audio folder"
			return false
		var manifest_dir := DirAccess.open(path.get_base_dir())
		if manifest_dir != null and manifest_dir.is_link(path.get_file()):
			last_error = "Symlink manifest forbidden"
			return false
		var base := path.get_base_dir()
		# Check only the owned storage subtree. macOS legitimately exposes its
		# per-user temporary/save directories through /var -> /private/var.
		while base == storage or base.begins_with(storage.trim_suffix("/") + "/"):
			var parent := DirAccess.open(base.get_base_dir())
			if parent != null and parent.is_link(base.get_file()):
				last_error = "Symlink bank directory forbidden"
				return false
			if base == storage: break
			base = base.get_base_dir()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version") != 1:
		last_error = "Invalid bank version"
		return false
	for field in ["patches", "cues", "scores"]:
		if not parsed.get(field) is Dictionary:
			last_error = "Missing bank dictionary: " + field
			return false
		if parsed[field].size() > 1024:
			last_error = "Bank catalog too large: " + field
			return false
	if not bank.is_empty():
		for field in ["cues", "scores"]:
			for id in bank[field]:
				if not parsed[field].has(id):
					last_error = "Incomplete bank: missing %s %s" % [field, id]
					return false
	var streams := {}
	var decoded_bytes := 0
	for id in parsed.get("patches", {}):
		var patch = parsed.patches[id]
		if not patch is Dictionary or not _relative(str(patch.get("file", ""))) or not (patch.get("root", 60) is float or patch.get("root", 60) is int):
			last_error = "Invalid relative PCM WAV for patch " + str(id)
			return false
		var sample_path: String = path.get_base_dir().path_join(patch.file)
		var walk := sample_path
		while walk != path.get_base_dir() and not walk.is_empty():
			var parent := DirAccess.open(walk.get_base_dir())
			if parent != null and parent.is_link(walk.get_file()):
				last_error = "Symlink forbidden for patch " + str(id)
				return false
			walk = walk.get_base_dir()
		var stream: AudioStreamWAV
		if path.begins_with("res://"):
			stream = ResourceLoader.load(sample_path) as AudioStreamWAV
		else:
			var sample_file := FileAccess.open(sample_path, FileAccess.READ)
			if sample_file == null or sample_file.get_length() > 32 * 1024 * 1024:
				last_error = "Missing or oversized patch " + str(id)
				return false
			stream = AudioStreamWAV.load_from_file(sample_path)
		if stream == null or (not path.begins_with("res://") and stream.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]):
			last_error = "Cannot decode PCM patch " + str(id)
			return false
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		decoded_bytes += ceili(stream.get_length() * stream.mix_rate) * (2 if stream.stereo else 1) * 2
		if decoded_bytes > 128 * 1024 * 1024 or stream.get_length() > 120 or not is_finite(float(patch.get("root", 60))) or float(patch.get("root", 60)) < 0 or float(patch.get("root", 60)) > 127:
			last_error = "Patch exceeds bank limits " + str(id)
			return false
		streams[id] = stream
	for id in parsed.get("cues", {}):
		var cue = parsed.cues[id]
		if not cue is Dictionary or not cue.get("variants") is Array or cue.variants.is_empty() or cue.get("bus") not in ["Music", "Combat", "Interface"] or not (cue.get("gain_db", -6) is float or cue.get("gain_db", -6) is int):
			last_error = "Invalid cue " + str(id)
			return false
		if not cue.get("group") is String or str(cue.group).is_empty():
			last_error = "Missing group for cue " + str(id)
			return false
		for patch in cue.variants:
			if not streams.has(patch):
				last_error = "Cue %s references missing patch %s" % [id, patch]
				return false
		if not is_finite(float(cue.get("gain_db", -6))) or float(cue.get("gain_db", -6)) < -80 or float(cue.get("gain_db", -6)) > 12:
			last_error = "Invalid cue gain " + str(id)
			return false
		if not cue.get("round_robin", []) is Array:
			last_error = "Invalid round robin " + str(id)
			return false
		for patch in cue.get("round_robin", []):
			if not streams.has(patch):
				last_error = "Missing round robin patch for cue " + str(id)
				return false
	for group in options("groups"):
		var present := false
		for cue in parsed.cues.values():
			if cue.group == group: present = true
		if not present:
			last_error = "Incomplete bank: missing group " + group
			return false
	for id in parsed.get("scores", {}):
		var score = parsed.scores[id]
		if not score is Dictionary or not score.get("length") is float and not score.get("length") is int:
			last_error = "Invalid score " + str(id)
			return false
		if float(score.length) <= 0 or not score.get("events") is Array:
			last_error = "Invalid score timeline " + str(id)
			return false
		if not is_finite(float(score.length)) or float(score.length) > 3600 or score.events.size() > 100000:
			last_error = "Score exceeds runtime limits " + str(id)
			return false
		for event in score.events:
			if not event is Dictionary:
				last_error = "Invalid event in score " + str(id)
				return false
			for field in ["time", "duration", "note", "velocity"]:
				var value = event.get(field, 60 if field == "note" else 100 if field == "velocity" else -1)
				if not (value is float or value is int) or not is_finite(float(value)) or (field in ["note", "velocity"] and (value < 0 or value > 127)) or (field == "duration" and value > 120):
					last_error = "Invalid %s in score %s" % [field, id]
					return false
			if not parsed.cues.has(event.get("cue", "")) or float(event.get("time", -1)) < 0 or float(event.get("time", 0)) >= float(score.length) or float(event.get("duration", -1)) < 0:
				last_error = "Invalid event in score " + str(id)
				return false
	if not _valid_overrides(overrides, parsed):
		last_error = "Bank incompatible with current preset"
		return false
	bank = parsed
	_streams = streams
	_levels = {}
	for id in streams: _levels[id] = _rms(streams[id])
	bank_path = path
	if not score_id.is_empty(): score_time = fmod(score_time, float(bank.scores[score_id].length))
	last_error = ""
	return true

func _valid_overrides(data: Dictionary, candidate: Dictionary) -> bool:
	for id in data:
		if not candidate.get("cues", {}).has(id) or not data[id] is Dictionary: return false
		for key in data[id]:
			var value = data[id][key]
			if key == "patch":
				if not candidate.get("patches", {}).has(value): return false
			elif key in PARAMETERS:
				if not (value is float or value is int) or not is_finite(float(value)): return false
				if key == "gain_db" and (value < -80 or value > 12): return false
				if key == "pitch" and (value < .25 or value > 4): return false
				if key in ["variation", "pitch_range"] and (value < 0 or value > 1): return false
				if key == "pan" and absf(value) > 1: return false
			else: return false
	return true

func _remember() -> void:
	_history.append(preset_snapshot())
	if _history.size() > 32: _history.pop_front()

func preset_snapshot() -> Dictionary:
	return {"version": 1, "overrides": overrides.duplicate(true), "muted": muted.duplicate(true), "solo": solo, "stingers_enabled": stingers_enabled, "stinger_overrides": stinger_overrides.duplicate(true)}

func _target_exists(id: String) -> bool:
	if bank.get("cues", {}).has(id) or options("groups").has(id): return true
	for score in bank.get("scores", {}).values():
		for event in score.events:
			if event.get("track", "") == id: return true
	return false

func apply_preset(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("overrides") is Dictionary or not _valid_overrides(data.overrides, bank):
		return false
	if not data.get("muted", {}) is Dictionary or not data.get("solo", "") is String or not data.get("stingers_enabled", true) is bool:
		return false
	if not data.get("stinger_overrides", {}) is Dictionary: return false
	for id in data.get("stinger_overrides", {}):
		if not bank.get("scores", {}).has(id) or not data.stinger_overrides[id] is bool: return false
	for id in data.get("muted", {}):
		if not id is String or not data.muted[id] is bool or not _target_exists(id): return false
	if not str(data.get("solo", "")).is_empty() and not _target_exists(data.solo): return false
	_remember()
	overrides = data.overrides.duplicate(true)
	muted = data.get("muted", {}).duplicate(true)
	solo = data.get("solo", "")
	stingers_enabled = data.get("stingers_enabled", true)
	stinger_overrides = data.get("stinger_overrides", {}).duplicate(true)
	return true

func play_cue(id: String, gain_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	_play(id, gain_offset_db, pitch, "", -1)

func _play(id: String, gain: float, pitch: float, track: String, duration: float, score_patch: String = "", placement: float = 0.0) -> void:
	if not bank.get("cues", {}).has(id): return
	var cue: Dictionary = bank.cues[id]
	var group := str(cue.get("group", ""))
	if muted.get(id, false) or muted.get(group, false) or muted.get(track, false): return
	if not solo.is_empty() and solo not in [id, group, track]: return
	var now := Time.get_ticks_msec()
	if id == "click" and now - int(_last_cue.get(id, -1000)) < 40: return
	_last_cue[id] = now
	var mix: Dictionary = overrides.get(id, {})
	var variants: Array = cue.variants
	# Alternatives are designer choices, not interchangeable takes. Only explicit
	# round_robin members rotate, and score notes always retain their authored patch.
	var patch := str(mix.get("patch", variants[0]))
	if not score_patch.is_empty(): patch = score_patch
	if score_patch.is_empty() and track.is_empty() and not mix.has("patch") and float(mix.get("variation", 1)) > 0:
		var takes: Array = cue.get("round_robin", [])
		if not takes.is_empty():
			var take := int(_take_index.get(id, 0))
			patch = str(takes[take % takes.size()])
			_take_index[id] = take + 1
	var voice := AudioStreamPlayer.new()
	voice.stream = _streams[patch]
	voice.bus = cue.bus
	voice.volume_db = clampf(float(mix.get("gain_db", cue.get("gain_db", -6))) + gain, -80, 12)
	voice.pitch_scale = clampf(pitch * float(mix.get("pitch", 1)) * pow(2, _rng.randf_range(-1, 1) * float(mix.get("pitch_range", 0))), .125, 8)
	# A private bus makes pan a real stereo operation without changing other cues.
	var pan := float(mix.get("pan", placement))
	if pan != 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		var bus_name := "HullVoice_%s" % voice.get_instance_id()
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, cue.bus)
		var effect := AudioEffectPanner.new()
		effect.pan = pan
		AudioServer.add_bus_effect(index, effect)
		voice.bus = bus_name
		voice.set_meta("private_bus", bus_name)
	add_child(voice)
	voice.set_meta("cue", id)
	voice.set_meta("patch", patch)
	voice.set_meta("category", cue.bus)
	voice.set_meta("track", track)
	voices.append(voice)
	voice.finished.connect(_release.bind(voice))
	voice.play()
	if duration > 0:
		var tween := create_tween()
		voice.set_meta("tail_tween", tween)
		tween.tween_interval(duration)
		tween.tween_property(voice, "volume_db", -80.0, .15)
		tween.tween_callback(_release.bind(voice))
	if cue.bus == "Combat":
		var combat: Array[AudioStreamPlayer] = []
		for playing in voices:
			if playing.get_meta("category") == "Combat": combat.append(playing)
		if combat.size() > 12: _release(combat[0])
	elif voices.size() > MAX_VOICES:
		_release(voices[0])
	_record_voice(voice)

func _record_voice(voice: AudioStreamPlayer) -> void:
	var record := {"cue": voice.get_meta("cue"), "patch": voice.get_meta("patch"), "track": voice.get_meta("track"), "gain_db": voice.volume_db, "at_ms": Time.get_ticks_msec(), "peak_bus_db": -80.0}
	voice.set_meta("trace_record", record)
	trace.append(record)
	if trace.size() > 100: trace.pop_front()

func _release(voice: AudioStreamPlayer) -> void:
	if not is_instance_valid(voice) or not voices.has(voice): return
	voices.erase(voice)
	if voice.has_meta("tail_tween"): voice.get_meta("tail_tween").kill()
	voice.stop()
	voice.stream = null
	if voice.has_meta("private_bus"):
		var index := AudioServer.get_bus_index(voice.get_meta("private_bus"))
		if index >= 0: AudioServer.remove_bus(index)
	voice.queue_free()

func set_score(id: String, with_tension: bool = false, loop: bool = true) -> void:
	score_loops = loop
	tension = with_tension
	if id == score_id: return
	for voice in voices:
		if voice.get_meta("category") == "Music" and not voice.get_meta("stinger", false):
			if voice.has_meta("tail_tween"): voice.get_meta("tail_tween").kill()
			var fade := create_tween()
			voice.set_meta("tail_tween", fade)
			fade.tween_property(voice, "volume_db", -80.0, 1.2)
			fade.tween_callback(_release.bind(voice))
	score_id = id if bank.get("scores", {}).has(id) else ""
	score_time = -.000001

func play_stinger(id: String, event_key: String) -> void:
	if _seen.has(event_key): return
	_seen[event_key] = true
	if _seen.size() > 4096: _seen.erase(_seen.keys()[0])
	if not storage.is_empty():
		var seen_file := FileAccess.open(storage.path_join("committed_stingers.json"), FileAccess.WRITE)
		if seen_file != null: seen_file.store_string(JSON.stringify(_seen))
	if not bank.get("scores", {}).has(id): return
	var contact_only: bool = not stingers_enabled or not stinger_overrides.get(id, true)
	if contact_only:
		if not id.begins_with("guardian_"): return
		var found := false
		for event in bank.scores[id].events:
			if event.get("track", "") == "hull contact": found = true
		if not found: return
	var priority := 3 if id in ["victory", "defeat"] else (2 if id.begins_with("clear_") else 1)
	if not _stinger.is_empty() and priority < _stinger_priority: return
	for voice in voices.duplicate():
		if voice.get_meta("rendered_stinger", false) or (priority == 3 and voice.get_meta("stinger", false) and voice.get_meta("track", "") != "hull contact"):
			if voice.has_meta("tail_tween"): voice.get_meta("tail_tween").kill()
			var fade := create_tween()
			voice.set_meta("tail_tween", fade)
			fade.tween_property(voice, "volume_db", -80.0, .12)
			fade.tween_callback(_release.bind(voice))
	_stinger = id
	_stinger_contact_only = contact_only
	_stinger_time = -.000001
	_stinger_priority = priority
	_rendered_seconds = _start_rendered_stinger(id)

func _start_rendered_stinger(id: String) -> float:
	if _stinger_contact_only or bank_path != FACTORY_BANK or not RENDERED_STINGERS.has(id) or not solo.is_empty(): return 0.0
	# A single printed mix cannot implement per-part mute, alternate patch,
	# pan or pitch. Give affected Sound Desk selections the editable timeline.
	for event in bank.scores[id].events:
		var cue: String = event.cue
		if overrides.has(cue) or muted.get(cue, false) or muted.get(event.track, false) or muted.get(bank.cues[cue].group, false): return 0.0
	var path: String = RENDERED_STINGERS[id]
	var clip := load(path) as AudioStreamWAV
	if clip == null: return 0.0
	var voice := AudioStreamPlayer.new()
	voice.stream = clip
	voice.bus = "Music"
	voice.set_meta("cue", id)
	voice.set_meta("patch", path.get_file().get_basename())
	voice.set_meta("category", "Music")
	voice.set_meta("track", "rendered score")
	voice.set_meta("stinger", true)
	voice.set_meta("rendered_stinger", true)
	add_child(voice)
	voices.append(voice)
	voice.finished.connect(_release.bind(voice))
	if voices.size() > MAX_VOICES: _release(voices[0])
	voice.play()
	_record_voice(voice)
	return clip.get_length()

func _timeline(id: String, start: float, finish: float) -> void:
	var score: Dictionary = bank.scores[id]
	for event in score.events:
		var time := float(event.time)
		var track := str(event.get("track", ""))
		if id == _stinger and _stinger_contact_only and track != "hull contact": continue
		if time > start and time <= finish and (track != "tension" or tension):
			var cue: Dictionary = bank.cues[event.cue]
			var patch := str(overrides.get(event.cue, {}).get("patch", cue.variants[0]))
			var root_note := float(bank.patches[patch].get("root", 60))
			var velocity := clampf(float(event.get("velocity", 100)) / 127, 0, 1)
			if velocity > 0:
				# Match the slight left/right spacing of the published reference
				# mix. Direct interface and combat contacts stay in the center.
				var channel: int = int(score.get("tracks", {}).get(track, {}).get("channel", 0))
				var placement: float = {1:-.14, 2:.19, 3:.04, 4:-.09}.get(channel, 0.0)
				var previous_voice: AudioStreamPlayer = voices.back() if not voices.is_empty() else null
				_play(event.cue, linear_to_db(velocity), pow(2, (float(event.get("note", 60)) - root_note) / 12), track, float(event.duration), patch, placement)
				if id == _stinger and not voices.is_empty() and voices.back() != previous_voice: voices.back().set_meta("stinger", true)

func _process(delta: float) -> void:
	for voice in voices:
		var index := AudioServer.get_bus_index(voice.bus)
		if index >= 0:
			var record: Dictionary = voice.get_meta("trace_record")
			record.peak_bus_db = maxf(float(record.peak_bus_db), maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0)))
	if not score_id.is_empty() and bank.get("scores", {}).has(score_id):
		var length := float(bank.scores[score_id].length)
		var finish := score_time + delta
		if not score_loops: finish = minf(finish, length)
		while score_loops and finish >= length:
			_timeline(score_id, score_time, length)
			finish -= length
			score_time = -.000001
		_timeline(score_id, score_time, finish)
		score_time = finish
	if not _stinger.is_empty():
		var finish := _stinger_time + delta
		if _rendered_seconds <= 0.0: _timeline(_stinger, _stinger_time, finish)
		_stinger_time = finish
		if finish >= maxf(float(bank.scores[_stinger].length), _rendered_seconds):
			_stinger = ""
			_stinger_priority = 0
			_rendered_seconds = 0.0

func command(words: PackedStringArray) -> String:
	if words.is_empty(): return "audio: packs bank groups cues patches scores variants bind audition group mix solo mute ab preset undo factory reload trace voices stinger"
	var op := words[0]
	var args := words.slice(1)
	if op in ["packs", "groups", "cues", "patches", "scores"]: return "\n".join(options(op))
	if op == "bank":
		if args.size() != 1 or not options("packs").has(args[0]): return "Use bank NAME from audio packs"
		var path := "res://audio/hull/bank.json" if args[0] == "factory" else storage.path_join("banks").path_join(args[0]).path_join("bank.json")
		if not reload_bank(path): return last_error.replace(storage, "<audio>")
		var selection := FileAccess.open(storage.path_join("selected_bank.txt"), FileAccess.WRITE)
		if selection != null: selection.store_string(args[0])
		return "Bank active: " + args[0]
	if op == "trace": return JSON.stringify(trace)
	if op == "voices":
		var peaks := {}
		var active := []
		for voice in voices:
			active.append({"cue": voice.get_meta("cue"), "patch": voice.get_meta("patch"), "track": voice.get_meta("track"), "gain_db": voice.volume_db, "pitch": voice.pitch_scale})
		for bus in ["Music", "Combat", "Interface"]:
			var index := AudioServer.get_bus_index(bus)
			peaks[bus] = maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0))
		return JSON.stringify({"active": voices.size(), "voices": active, "peaks_db": peaks, "score": score_id, "position": score_time})
	if op == "reload":
		if not args.is_empty() and (args[0].is_absolute_path() or args[0].contains("..") or args[0].contains(":")): return "Reload expects a relative path inside the audio folder"
		var path := bank_path if args.is_empty() else storage.path_join(args[0])
		return "Bank reloaded" if reload_bank(path) else last_error.replace(storage, "<audio>")
	if op == "undo":
		if _history.is_empty(): return "Nothing to undo"
		var previous: Dictionary = _history.pop_back()
		overrides = previous.overrides
		muted = previous.muted
		solo = previous.solo
		stingers_enabled = previous.stingers_enabled
		stinger_overrides = previous.get("stinger_overrides", {})
		return "Undone"
	if op == "factory":
		return _preset(PackedStringArray(["load", "factory"]))
	if op in ["solo", "mute"] and args.size() >= 1:
		if not _target_exists(args[0]) and not (op == "solo" and args[0] in ["off", "none"]): return "Unknown cue, group or score track"
		_remember()
		if op == "solo": solo = "" if args[0] in ["off", "none"] else args[0]
		else: muted[args[0]] = not muted.get(args[0], false)
		return "%s: %s" % [op, args[0]]
	if op == "stinger" and args.size() == 1:
		if args[0] not in ["on", "off"]: return "Use stinger on|off or stinger ID on|off"
		_remember()
		stingers_enabled = args[0] != "off"
		return "Stingers " + str(stingers_enabled)
	if op == "stinger" and args.size() == 2:
		if not bank.get("scores", {}).has(args[0]) or args[1] not in ["on", "off"]: return "Unknown stinger or expected on|off"
		_remember()
		stinger_overrides[args[0]] = args[1] == "on"
		return "Stinger %s: %s" % [args[0], args[1]]
	if op == "ab" and args.size() >= 1:
		if args[0] == "store": _ab = preset_snapshot()
		elif args[0] == "swap":
			if _ab.is_empty(): return "Use ab store first"
			var previous := preset_snapshot()
			if not apply_preset(_ab): return "Stored A/B preset no longer matches bank"
			_ab = previous
		elif args[0] == "silence": stingers_enabled = not stingers_enabled
		else: return "Use ab store|swap|silence"
		return "A/B switched (cue gain preserved)"
	if op == "preset": return _preset(args)
	if op == "group" and args.size() == 2:
		if not options("groups").has(args[0]) or args[1] not in ["factory", "alternate"]: return "Unknown group or preset"
		_remember()
		for id in bank.cues:
			if bank.cues[id].get("group") == args[0]:
				var variants: Array = bank.cues[id].variants
				overrides[id] = {"patch": variants[mini(1, variants.size() - 1)] if args[1] == "alternate" else variants[0]}
		return "Group switched"
	if op == "mix" and args.size() == 3 and args[2].is_valid_float() and (args[0] == "all" or options("groups").has(args[0])):
		var candidate := overrides.duplicate(true)
		for cue_id in bank.cues:
			if args[0] == "all" or bank.cues[cue_id].get("group") == args[0]:
				if not candidate.has(cue_id): candidate[cue_id] = {}
				candidate[cue_id][args[1]] = args[2].to_float()
		if not _valid_overrides(candidate, bank): return "Invalid group mix parameter"
		_remember()
		overrides = candidate
		return "Group mix updated"
	if args.is_empty() or not bank.get("cues", {}).has(args[0]): return "Unknown cue or command"
	var id := args[0]
	if op == "variants": return ", ".join(PackedStringArray(bank.cues[id].variants))
	if op == "audition":
		_last_cue.erase(id)
		var default_patch: String = bank.cues[id].variants[0]
		var selected: String = overrides.get(id, {}).get("patch", default_patch)
		var adjustment := clampf(linear_to_db(maxf(.000001, float(_levels.get(default_patch, 1)))) - linear_to_db(maxf(.000001, float(_levels.get(selected, 1)))), -18, 18)
		play_cue(id, adjustment)
		return "Audition: " + id
	var candidate := overrides.duplicate(true)
	if not candidate.has(id): candidate[id] = {}
	if op == "bind" and args.size() == 2: candidate[id]["patch"] = args[1]
	elif op == "mix" and args.size() == 3 and args[2].is_valid_float(): candidate[id][args[1]] = args[2].to_float()
	else: return "Use variants CUE | audition CUE | bind CUE PATCH | mix CUE PARAM VALUE"
	if not _valid_overrides(candidate, bank): return "Invalid patch or parameter value"
	_remember()
	overrides = candidate
	return "Updated " + id

func _preset(args: PackedStringArray) -> String:
	if args.size() != 2 or args[0] not in ["save", "load", "export", "import"]: return "preset save|load|export|import NAME"
	var name := args[1]
	if name.is_empty() or name != name.validate_filename() or name.contains(".."): return "Invalid preset name"
	if args[0] == "load" and name in ["factory", "alternate"]:
		var data := {"version": 1, "overrides": {}, "muted": {}, "solo": "", "stingers_enabled": true}
		if name == "alternate":
			for id in bank.cues:
				var variants: Array = bank.cues[id].variants
				data.overrides[id] = {"patch": variants[mini(1, variants.size() - 1)]}
		if not apply_preset(data): return "Invalid built-in preset"
		var selection := FileAccess.open(storage.path_join("selected.json"), FileAccess.WRITE)
		if selection != null: selection.store_string(name)
		return "Loaded " + name
	var path := storage.path_join(name + ".json")
	if args[0] in ["save", "export"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null: return "Cannot write preset"
		file.store_string(JSON.stringify(preset_snapshot(), "\t"))
		var selection := FileAccess.open(storage.path_join("selected.json"), FileAccess.WRITE)
		if selection != null: selection.store_string(name)
		return "Saved preset " + name
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not apply_preset(data): return "Invalid preset; current settings retained"
	var selection := FileAccess.open(storage.path_join("selected.json"), FileAccess.WRITE)
	if selection != null: selection.store_string(name)
	return "Loaded " + name
