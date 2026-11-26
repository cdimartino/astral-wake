extends Node
## Presentation-only spotting. Caller supplies committed resolution batches;
## this helper never detects deaths, reads enemies or writes run/save data.
const HISTORY_LIMIT := 64
var hull: Node
var combat_preview = preload("res://scripts/combat_audio_preview.gd").new()
var _seen: Array[String] = []
var _clear_left := -1.0

func setup(hull_audio: Node) -> void:
	if hull == hull_audio: return
	cancel()
	hull = hull_audio
	combat_preview.setup(hull)
	if combat_preview.get_parent() == null: add_child(combat_preview)
	_seen.clear()

func play_combat(cue: Dictionary, launch: bool, level: float) -> bool:
	return combat_preview.combat(cue, launch, level)

func resolved_batch(event_key: String, defeated_count: int, encounter_cleared: bool = false) -> void:
	if not is_instance_valid(hull) or event_key.is_empty() or defeated_count <= 0 or _seen.has(event_key): return
	_seen.append(event_key)
	if _seen.size() > HISTORY_LIMIT: _seen.pop_front()
	# Native reviewed kill: one 0.38s damped collapse/latch, independent of count.
	combat_preview.play("kill")
	if encounter_cleared and combat_preview.music_allowed():
		# Same reviewed separation from the final kill. R2 is a compact 1.70s
		# held minor breath/glass response, not the rejected melodic phrase.
		_clear_left = 0.45

func _process(delta: float) -> void:
	if _clear_left < 0.0: return
	if not combat_preview.music_allowed():
		_clear_left = -1.0
		return
	_clear_left -= delta
	if _clear_left <= 0.0:
		_clear_left = -1.0
		combat_preview.play("clear")

func cancel() -> void:
	_clear_left = -1.0
	if is_instance_valid(combat_preview): combat_preview.stop_all()

func _exit_tree() -> void:
	cancel()
