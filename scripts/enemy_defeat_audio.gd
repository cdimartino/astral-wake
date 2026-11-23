extends Node
## Presentation-only spotting. Caller supplies committed resolution batches;
## this helper never detects deaths, reads enemies or writes run/save data.
const HISTORY_LIMIT := 64
var hull: Node
var _seen: Array[String] = []
var _pending: Array[Dictionary] = []
var _owned: Array[AudioStreamPlayer] = []

func setup(hull_audio: Node) -> void:
	if hull == hull_audio: return
	cancel()
	hull = hull_audio
	_seen.clear()

func resolved_batch(event_key: String, defeated_count: int, encounter_cleared: bool = false) -> void:
	if not is_instance_valid(hull) or event_key.is_empty() or defeated_count <= 0 or _seen.has(event_key): return
	_seen.append(event_key)
	if _seen.size() > HISTORY_LIMIT: _seen.pop_front()
	# Count never multiplies gain/voices: simultaneous deaths are one release,
	# not a stack of explosions. Leave the existing impact cue to the main mix.
	_emit("combat_vent", "", -4.0, 0.82, 0.45, false)
	if _music_allowed():
		_pending.clear()
		# Warm recorded wood, root -> major third -> fifth. No beam scrape,
		# bowed-string or glass material, and no reuse of the voyage-end score.
		# A quieter two-note reply distinguishes an ordinary defeat from the
		# player's standalone vent. Stinger-off retains only the dry release.
		var notes := [[0.10, 1.0, -9.0], [0.32, pow(2.0, 4.0 / 12.0), -11.0], [0.54, pow(2.0, 7.0 / 12.0), -12.0]] if encounter_cleared else [[0.10, 1.0, -14.0], [0.28, pow(2.0, 7.0 / 12.0), -16.0]]
		for note in notes:
			_pending.append({"left": float(note[0]), "pitch": float(note[1]), "gain": float(note[2])})

func _music_allowed() -> bool:
	# Do not claim HullAudio's single stinger slot or replace a guardian phrase.
	# An actual voyage ending supersedes this small encounter comment.
	return hull.stingers_enabled and hull._stinger not in ["victory", "defeat"]

func _emit(cue: String, track: String, gain: float, pitch: float, duration: float, musical: bool) -> void:
	var before: Array = hull.voices.duplicate()
	hull._play(cue, gain, pitch, track, duration)
	for voice in hull.voices:
		if before.has(voice): continue
		voice.set_meta("enemy_defeat_musical", musical)
		# Existing ending-priority logic may fade these; regional score selection
		# should not cut off this short already-committed comment.
		if musical: voice.set_meta("stinger", true)
		_owned.append(voice)

func _voice_allowed(voice: AudioStreamPlayer) -> bool:
	var id := str(voice.get_meta("cue", ""))
	var group := str(hull.bank.get("cues", {}).get(id, {}).get("group", ""))
	var track := str(voice.get_meta("track", ""))
	if hull.muted.get(id, false) or hull.muted.get(group, false) or hull.muted.get(track, false): return false
	if not hull.solo.is_empty() and hull.solo not in [id, group, track]: return false
	return not voice.get_meta("enemy_defeat_musical", false) or _music_allowed()

func _process(delta: float) -> void:
	if not is_instance_valid(hull): return
	if not _music_allowed(): _pending.clear()
	var due: Dictionary = {}
	for note in _pending.duplicate():
		note.left -= delta
		if float(note.left) <= 0.0:
			due = note
			_pending.erase(note)
	# A suspended frame must not bunch a cadence into a chord/transient pile.
	if not due.is_empty():
		_emit("score_wood_ember", "vessel motif", float(due.gain), float(due.pitch), 0.36, true)
	for index in range(_owned.size() - 1, -1, -1):
		var voice = _owned[index]
		if not is_instance_valid(voice) or not hull.voices.has(voice):
			_owned.remove_at(index)
		elif not _voice_allowed(voice):
			hull._release(voice)
			_owned.remove_at(index)

func cancel() -> void:
	_pending.clear()
	if is_instance_valid(hull):
		for voice in _owned:
			if is_instance_valid(voice): hull._release(voice)
	_owned.clear()

func _exit_tree() -> void:
	cancel()
