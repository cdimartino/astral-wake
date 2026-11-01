extends SceneTree
const Main = preload("res://scripts/main.gd")
const Fixtures = preload("res://tests/defense_engine_fixtures.gd")
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("defense-ui-%d"%Time.get_ticks_usec())
func require(value: bool, message: String) -> void:
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	OS.set_environment("ASTRAL_SAVE_DIR",directory)
	check.call_deferred()
func collect_text(node: Node, values: Array) -> void:
	if node is Label or node is Button: values.append(node.text)
	for child in node.get_children(): collect_text(child,values)
func check() -> void:
	var ui=Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	Fixtures.register(ui.game)
	Fixtures.battle(ui.game)
	ui.menu=false
	ui.game.play_card(0,[0,1],0)
	ui.selected_card=1
	ui.route.assign([4])
	var preview=ui.game.preview_card(1,[4],0)
	for size in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=size
		ui._render()
		for unused in range(5): await process_frame
		var label=ui.page.find_child("RoutePreviewSummary",true,false)
		require(label.text.contains("Install UID 1 Ward +5"),"Native preview shows actual triggered cooling source")
		var detail=ui.game.Engines.detail(ui.game,ui.game.run.battle.installed[0])
		require(detail.contains("at least 2 actual strain") and detail.contains("+5 flat ward") and detail.contains("available this player turn") and not detail.contains("Dormant"),"Cooling installed detail has threshold/ward/latch")
	ui.game.play_card(1,[4],0)
	require(ui.game.Engines.detail(ui.game,ui.game.run.battle.installed[0]).contains("used this player turn"),"Cooling used status")
	ui.game.end_turn()
	ui.game.play_card(0,[3],0)
	var detail=ui.game.Engines.detail(ui.game,ui.game.run.battle.installed[1])
	require(detail.contains("SAME recipient") and detail.contains("+6 damage") and detail.contains("available next enemy phase") and not detail.contains("Dormant"),"Retaliation detail is phase-specific, no attack cap text")
	ui._clear_selection()
	for size in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=size
		ui._render()
		for unused in range(3): await process_frame
		ui.find_child("InstalledPile",true,false).pressed.emit()
		for unused in range(3): await process_frame
		var labels=[]
		collect_text(ui,labels)
		var text="\n".join(labels)
		require(text.contains("Phase Radiator") and text.contains("at least 2 actual strain") and text.contains("UID 1") and text.contains("Interception Loom") and text.contains("available next enemy phase"),"Actual Installed overlay native nodes at "+str(size))
		ui._close_overlay()
	var before=ui.game.run.duplicate(true)
	var synthetic={"presentation":[{"kind":"damage","engine":"redirect_retaliation","source_uid":2,"source_index":1,"target_index":0,"amount":4}]}
	# Live compacted array must not be used to relocate a snapshot recipient.
	ui.game.run.battle.enemies.remove_at(0)
	var cues=ui._feedback_plan(before,synthetic,"enemy_phase",[],-1,{})
	var extra=cues.filter(func(cue): return cue.has("source_uid"))
	require(extra.size()==1 and extra[0].target_index==0 and extra[0].source_index==1 and extra[0].source_uid==2 and extra[0].label.contains("UID 2") and not extra[0].echo,"Presentation binds snapshot recipient/source; no Echo")
	synthetic.presentation[0].target_index=99
	cues=ui._feedback_plan(before,synthetic,"enemy_phase",[],-1,{})
	require(not cues.any(func(cue): return cue.has("source_uid")),"Invalid snapshot index has no unsafe fallback")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	print("Defense engine UI: %d failures (node assertions, not graphical evidence)"%failures)
	quit(1 if failures else 0)
