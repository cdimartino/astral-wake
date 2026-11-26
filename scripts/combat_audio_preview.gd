extends Node
## Reviewed per-event Audio Preview assets. Never a mixed-sampler player.
## Existing cue/group/track controls remain the controls for each replacement.
const EVENTS := {
	"enemy_kinetic_launch": {"cue":"combat_kinetic_launch", "bus":"Combat", "seconds":0.30, "calibration":6.0205999133},
	"enemy_kinetic_hit": {"cue":"combat_kinetic_hit", "bus":"Combat", "seconds":0.76, "calibration":6.0205999133},
	"enemy_sonic_launch": {"cue":"combat_sonic_launch", "bus":"Combat", "seconds":0.30, "calibration":6.0205999133},
	"enemy_sonic_hit": {"cue":"combat_sonic_hit", "bus":"Combat", "seconds":0.91, "calibration":6.0205999133},
	"ward": {"cue":"combat_shield", "bus":"Combat", "seconds":0.73, "calibration":6.0205999133},
	"kill": {"cue":"combat_vent", "bus":"Combat", "seconds":0.38, "calibration":0.0},
	"clear": {"cue":"score_seam_air", "bus":"Music", "track":"vessel motif", "seconds":1.70, "calibration":0.0},
}
var hull: Node
var enabled := true
var last_error := ""
var _streams: Dictionary = {}
var _owned: Array[Dictionary] = []

func setup(service: Node) -> void:
	if hull == service: return
	stop_all()
	hull = service

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: stop_all()

func combat(cue: Dictionary, launch: bool, level: float) -> bool:
	if not enabled: return false
	var kind := str(cue.get("kind", ""))
	if kind == "shield" and not launch: return play("ward", level)
	if kind != "enemy_shot": return false
	var family := str(cue.get("style", "kinetic"))
	if family not in ["kinetic", "sonic"]: return false
	# Reference mock used a 16-damage kinetic and 9-damage sonic attack.
	# Preserve strength scaling around those reference levels, not another .88
	# pitch shift: the reviewed assets already contain their complete gesture.
	var reference := 0.4 if family == "kinetic" else -0.65
	return play("enemy_" + family + ("_launch" if launch else "_hit"), level - reference)

func music_allowed() -> bool:
	return enabled and is_instance_valid(hull) and hull.stingers_enabled and hull._stinger not in ["victory", "defeat"]

func _allowed(cue_id: String, track: String) -> bool:
	if not is_instance_valid(hull) or not hull.bank.get("cues", {}).has(cue_id): return false
	var group := str(hull.bank.cues[cue_id].get("group", ""))
	if hull.muted.get(cue_id, false) or hull.muted.get(group, false) or hull.muted.get(track, false): return false
	return hull.solo.is_empty() or hull.solo in [cue_id, group, track]

func play(event: String, gain_offset: float = 0.0) -> bool:
	if not enabled or not EVENTS.has(event) or not is_instance_valid(hull): return false
	var definition: Dictionary = EVENTS[event]
	var cue_id := str(definition.cue)
	var track := str(definition.get("track", ""))
	if event == "clear" and not music_allowed(): return true
	# A deliberately muted replacement still consumes the callback, otherwise
	# main would accidentally play its original underneath the mute.
	if not _allowed(cue_id, track): return true
	var mix: Dictionary = hull.overrides.get(cue_id, {})
	# Explicit user sample mappings/user banks take precedence over this factory
	# preview. Reuse validated HullAudio for that path, without editing its bank.
	if mix.has("patch") or not str(hull.bank_path).begins_with("res://"):
		var before: Array = hull.voices.duplicate()
		hull._play(cue_id, gain_offset, 1.0, track, float(definition.seconds))
		for voice in hull.voices:
			if before.has(voice): continue
			if event == "clear": voice.set_meta("stinger", true)
			_owned.append({"voice":voice, "event":event, "cue":cue_id, "track":track, "left":float(definition.seconds) + 0.2})
		return true
	if not _streams.has(event):
		var path := "res://audio/preview/combat/%s.wav" % event
		if not ResourceLoader.exists(path):
			last_error = "Audio Preview resource needs import: " + path
			return false
		_streams[event] = load(path) as AudioStreamWAV
	if _streams[event] == null:
		last_error = "Cannot decode Audio Preview event: " + event
		return false
	var cue: Dictionary = hull.bank.cues[cue_id]
	var voice := AudioStreamPlayer.new()
	voice.stream = _streams[event]
	voice.bus = definition.bus
	var authored_gain := float(cue.get("gain_db", -6))
	voice.volume_db = float(definition.calibration) + gain_offset + float(mix.get("gain_db", authored_gain)) - authored_gain
	voice.pitch_scale = clampf(float(mix.get("pitch", 1.0)) * pow(2.0, hull._rng.randf_range(-1, 1) * float(mix.get("pitch_range", 0))), .125, 8.0)
	var pan := float(mix.get("pan", 0.0))
	if pan != 0.0:
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		var name := "HullPreview_%s" % voice.get_instance_id()
		AudioServer.set_bus_name(bus, name)
		AudioServer.set_bus_send(bus, definition.bus)
		var panner := AudioEffectPanner.new()
		panner.pan = pan
		AudioServer.add_bus_effect(bus, panner)
		voice.bus = name
		voice.set_meta("private_bus", name)
	hull.add_child(voice)
	voice.set_meta("cue", cue_id)
	voice.set_meta("patch", "preview/" + event)
	voice.set_meta("category", definition.bus)
	voice.set_meta("track", track)
	voice.set_meta("preview_event", event)
	if event == "clear": voice.set_meta("stinger", true)
	var record := {"cue":cue_id, "patch":"preview/" + event, "track":track, "preview_event":event,
		"gain_db":voice.volume_db, "at_ms":Time.get_ticks_msec(), "peak_bus_db":-80.0}
	voice.set_meta("trace_record", record)
	hull.trace.append(record)
	if hull.trace.size() > 100: hull.trace.pop_front()
	hull.voices.append(voice)
	voice.finished.connect(hull._release.bind(voice))
	voice.play()
	_owned.append({"voice":voice, "event":event, "cue":cue_id, "track":track,
		"left":float(definition.seconds) / voice.pitch_scale + 0.15})
	# Preserve HullAudio's existing bounded polyphony policy.
	var combat_voices: Array = []
	for playing in hull.voices:
		if playing.get_meta("category") == "Combat": combat_voices.append(playing)
	if combat_voices.size() > 12: hull._release(combat_voices[0])
	elif hull.voices.size() > 48: hull._release(hull.voices[0])
	last_error = ""
	return true

func _process(delta: float) -> void:
	for entry in _owned.duplicate():
		var voice = entry.voice
		if not is_instance_valid(voice) or not is_instance_valid(hull) or not hull.voices.has(voice):
			_owned.erase(entry)
			continue
		entry.left -= delta
		if float(entry.left) <= 0.0 or not _allowed(entry.cue, entry.track) or (entry.event == "clear" and not music_allowed()):
			hull._release(voice)
			_owned.erase(entry)

func stop_all() -> void:
	if is_instance_valid(hull):
		for entry in _owned:
			if is_instance_valid(entry.voice): hull._release(entry.voice)
	_owned.clear()

func _exit_tree() -> void:
	stop_all()
