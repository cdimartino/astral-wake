extends SceneTree
## Fixture-only native capture entry, never loaded by production main.
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
	preload("res://tests/route_effect_fixtures.gd").demo(ui.game)
	ui.menu=false
	ui.notice="#16 FIXTURE ONLY · ward starts at 8 · Heat Sink adds 5 · no new Install engines"
	ui._render()
