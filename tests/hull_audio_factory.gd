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
	var hull = Hull.new()
	root.add_child(hull)
	hull.initialize(directory)
	check(not hull.bank.is_empty(), "Factory imports load")
	if hull.bank.is_empty():
		quit(1)
		return
	for region in range(6):
		hull.stop_all()
		hull.trace.clear()
		hull.stingers_enabled = false
		hull.play_stinger("guardian_%d" % region, "factory-contact-%d" % region)
		await create_timer(.1).timeout
		check(not hull.trace.is_empty(), "Guardian %d retains authored contact" % region)
		for record in hull.trace: check(record.track == "hull contact", "Music disabled leaves contact only")
	hull.stop_all()
	hull.stingers_enabled = true
	for id in hull.RENDERED_STINGERS:
		hull.stop_all()
		hull.play_stinger(id, "rendered-" + id)
		check(hull._rendered_seconds > 0.0 and hull.voices.size() == 1, "%s uses one approved rendered stinger" % id)
		if not hull.voices.is_empty():
			var voice: AudioStreamPlayer = hull.voices.back()
			check(voice.get_meta("rendered_stinger", false) and voice.bus == "Music", "%s rendered clip obeys Music settings" % id)
			check(voice.stream.resource_path == hull.RENDERED_STINGERS[id], "%s uses its approved clip" % id)
		hull.play_stinger(id, "rendered-" + id)
		check(hull.voices.size() == 1, "%s committed rendered stinger deduplicates" % id)
	hull.stop_all()
	hull.solo = "hull contact"
	hull.play_stinger("victory", "editable-solo")
	check(hull._rendered_seconds == 0.0, "Sound Desk solo retains editable timeline instead of flattened mix")
	hull.solo = ""
	hull.stop_all()
	hull.play_stinger("clear_0", "clear")
	hull.play_stinger("victory", "outcome")
	hull.play_stinger("clear_0", "late-clear")
	check(hull._stinger == "victory", "Voyage outcome wins over region clear")
	hull.stop_all()
	hull.set_score("region_2")
	await create_timer(.1).timeout
	var position: float = hull.score_time
	hull.set_score("region_2", true)
	check(hull.score_time == position, "Tension does not restart factory score")
	hull.set_score("")
	check(hull.score_id.is_empty(), "Ending can clear active score")
	hull.command(["preset", "load", "alternate"])
	hull.command(["stinger", "off"])
	hull.command(["preset", "save", "factory-test"])
	var snapshot: Dictionary = hull.preset_snapshot()
	hull.stop_all()
	hull.queue_free()
	await create_timer(.2).timeout
	var restored = Hull.new()
	root.add_child(restored)
	restored.initialize(directory)
	check(restored.preset_snapshot() == snapshot, "Selected named preset persists across restart")
	check(restored._seen.has("outcome"), "Committed stinger dedupe persists across restart")
	restored.queue_free()
	await create_timer(.2).timeout
	print("HULL FACTORY: %d failures" % failures)
	quit(1 if failures else 0)
