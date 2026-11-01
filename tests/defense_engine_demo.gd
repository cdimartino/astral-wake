extends SceneTree
## Explicit fixture-only native entry; --capture executes documented legal commands.
func _initialize() -> void:
	var directory=OS.get_environment("ASTRAL_SAVE_DIR")
	var existing=DirAccess.open(directory) if not directory.is_empty() else null
	if directory.is_empty() or (existing!=null and (not existing.get_files().is_empty() or not existing.get_directories().is_empty())):
		push_error("Set ASTRAL_SAVE_DIR to a fresh scratch directory; never a player save.")
		quit(1)
		return
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	show_demo.call_deferred()

func capture(ui, name: String, installed: bool = false) -> void:
	ui._clear_selection()
	ui._render()
	for ignored in range(8): await process_frame
	if installed:
		ui.find_child("InstalledPile",true,false).pressed.emit()
		for ignored in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var path=OS.get_environment("ASTRAL_SAVE_DIR").path_join(name+".png")
	var image=root.get_texture().get_image()
	image.save_png(path)
	print("NATIVE_CAPTURE_GEOMETRY "+JSON.stringify({"window":str(DisplayServer.window_get_size()),"viewport_png":str(image.get_size())}))
	print("NATIVE_FIXTURE_CAPTURE "+path)
	if installed: ui._close_overlay()

func show_demo() -> void:
	var ui=preload("res://scripts/main.gd").new()
	root.add_child(ui)
	if "--small" in OS.get_cmdline_user_args():
		for ignored in range(5): await process_frame
		root.size=Vector2i(1100,720)
	preload("res://tests/defense_engine_fixtures.gd").register(ui.game)
	preload("res://tests/defense_engine_fixtures.gd").battle(ui.game)
	ui.menu=false
	ui.notice="#14/#16 FIXTURE ONLY · Phase Radiator / Interception Loom · unchanged production pools"
	ui._render()
	if not "--capture" in OS.get_cmdline_user_args(): return
	ui.game.play_card(0,[0,1],0) # UID 1: cost-2 radiator, strains two organs.
	var cooling=ui.game.play_card(1,[4],0) # UID 3: actual vent removes >=2.
	ui.notice="FIXTURE ONLY · Phase Radiator UID 1 triggered: +5 flat ward · installed source inspection available"
	print("NATIVE_COOLING "+JSON.stringify({"result":cooling,"counters":ui.game.run.battle.engine_counters,"ward":ui.game.run.battle.ward}))
	await capture(ui,"cooling-ward")
	await capture(ui,"cooling-source-counter",true)
	ui.game.end_turn()
	ui.game.play_card(0,[3],0) # UID 2: install Loom on turn 2 (Cinder strain phase).
	ui.game.end_turn()
	var index=ui.game.Selections.index(ui.game.run.battle.hand,4)
	# Legal known choice: UID 5 is retained and known; this command routes Prism.
	ui.game.play_card(index,[5],0,[5])
	var phase=ui.game.end_turn()
	ui.notice="FIXTURE ONLY · Interception Loom UID 2: redirect +6 to SAME recipient after attack · see source counters/log"
	print("NATIVE_REDIRECT "+JSON.stringify({"result":phase,"counters":ui.game.run.battle.engine_counters,"enemies":ui.game.run.battle.enemies}))
	await capture(ui,"redirect-retaliation")
	await capture(ui,"redirect-source-counters",true)
	ui.ambience.stop()
	ui.audio.stop()
	ui.queue_free()
	for ignored in range(5): await process_frame
	quit()
