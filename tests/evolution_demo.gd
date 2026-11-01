extends SceneTree
## Native workshop demo; requires an explicit empty scratch save directory.
func _initialize() -> void:
	var directory=OS.get_environment("ASTRAL_SAVE_DIR")
	var existing=DirAccess.open(directory) if not directory.is_empty() else null
	if directory.is_empty() or (existing!=null and (not existing.get_files().is_empty() or not existing.get_directories().is_empty())):
		push_error("Set ASTRAL_SAVE_DIR to a fresh scratch directory; never a player save.")
		quit(1)
		return
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	show_demo.call_deferred()

func show_demo() -> void:
	var ui=preload("res://scripts/main.gd").new()
	root.add_child(ui)
	var ship="cartographer"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship=arg.trim_prefix("--ship=")
	if not ship in ["cartographer","palimpsest","hollow_choir"]:
		push_error("Demo supports cartographer, palimpsest or hollow_choir only.")
		quit(1)
		return
	ui.game.new_run("0093CG",ship)
	# Labelled workshop counterfactual, not a played expedition or balance capture.
	ui.game.run.mode="recovery"
	ui.game.save()
	ui.menu=false
	ui.notice="RECOVERY COUNTERFACTUAL · %s · 0093CG · production starters, not a played expedition"%ship
	ui._render()
