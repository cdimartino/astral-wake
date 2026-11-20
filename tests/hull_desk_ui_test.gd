extends SceneTree

const Desk = preload("res://scripts/hull_desk.gd")
var calls: Array[String] = []
var closed := false

class FakeAdmin:
	extends RefCounted
	var calls: Array[String] = []
	func execute(line: String) -> String:
		calls.append(line)
		return "ok: " + line
	func complete(line: String) -> PackedStringArray:
		return PackedStringArray([line + "combat.shield.catch"])

class FakeHull:
	extends RefCounted
	var playing := PackedStringArray()
	var trace: Array[Dictionary] = []
	var bank := {"cues": {"combat_shield": {"group": "combat"}, "interface_card_draw": {"group": "interface"}}}
	func options(kind: String) -> PackedStringArray:
		if kind == "groups": return PackedStringArray(["combat", "interface"])
		return PackedStringArray(["combat_shield", "interface_card_draw"])
	func active_cues() -> PackedStringArray:
		return playing

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var admin := FakeAdmin.new()
	var desk := Desk.new()
	var hull := FakeHull.new()
	root.add_child(desk)
	desk.setup(admin, hull)
	for i in range(3): await process_frame
	desk.close_requested.connect(func(): closed = true)
	assert(desk.find_child("CueTitle", true, false) != null)
	assert(desk._catalog.item_count == 2)
	assert(desk._entry.has_focus())
	desk._entry.text = "audio "
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	desk._entry_input(tab)
	assert(desk._entry.text.ends_with("combat.shield.catch"))
	desk._catalog.select(0)
	desk._select_cue(0)
	desk._catalog.select(0)
	desk._group = "combat"
	desk._query = ""
	hull.playing = PackedStringArray(["combat_shield", "interface_card_draw"])
	desk._update_playing()
	assert(desk._catalog.get_item_text(0).contains("Playing"))
	assert(desk._playing_badge.text.contains("interface_card_draw"))
	assert(desk._cue == "combat_shield" and desk._catalog.is_selected(0))
	hull.playing = PackedStringArray()
	hull.trace.append({"cue": "combat_shield", "at_ms": Time.get_ticks_msec()})
	for i in 101:
		hull.trace.append({"cue": "interface_card_draw", "at_ms": Time.get_ticks_msec()})
	desk._update_playing()
	assert(desk._cue_afterglow.has("combat_shield"), "Recent first event survives beyond 100 trace events")
	desk._cue_afterglow["combat_shield"] = Time.get_ticks_msec() - 1
	desk._update_playing()
	assert(not desk._cue_afterglow.has("combat_shield"))
	desk._audition()
	assert(admin.calls.size() == 3 and admin.calls[0] == "audio audition combat_shield")
	desk._entry.text = "help"
	desk._run_command("help")
	assert(admin.calls.size() == 4 and admin.calls[3] == "help")
	assert(desk._history.size() == 1 and desk._output.get_parsed_text().contains("ok: help"))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	desk._unhandled_key_input(escape)
	assert(closed)
	desk.queue_free()
	print("HULL_DESK_UI 9 checks, 0 failures")
	quit()
