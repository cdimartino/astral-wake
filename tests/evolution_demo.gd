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
	preload("res://tests/evolution_fixtures.gd").setup(ui.game)
	ui.menu=false
	ui._render()
