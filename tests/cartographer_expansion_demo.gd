extends SceneTree
## Native TEST DECK entry only; no production cheat hook, no fixture definitions.
func _initialize() -> void:
	var directory=OS.get_environment("ASTRAL_SAVE_DIR")
	var existing=DirAccess.open(directory) if not directory.is_empty() else null
	if directory.is_empty() or (existing!=null and (not existing.get_files().is_empty() or not existing.get_directories().is_empty())):
		push_error("Set ASTRAL_SAVE_DIR to a fresh scratch directory, never a player save.")
		quit(1)
		return
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	show_demo.call_deferred()
func show_demo() -> void:
	var package="survey"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--package="): package=arg.trim_prefix("--package=")
	var packages=preload("res://tests/cartographer_package_evidence.gd").PACKAGES
	if not package in packages:
		push_error("Choose survey, thermal, interception or hybrid")
		quit(1)
		return
	var ui=preload("res://scripts/main.gd").new()
	root.add_child(ui)
	ui.game.new_run("0093CG")
	ui.game.run.deck=[]
	for id in packages[package]: ui.game.run.deck.append(ui.game._instance(ui.game.run,id))
	for arg in OS.get_cmdline_user_args():
		if arg in ["--evolution=0","--evolution=1"]:
			var branch_index=int(arg.right(1))
			for instance in ui.game.run.deck:
				instance.level=1
				instance.evolution=ui.game.card(instance.id).evolutions[branch_index].id
	ui.game._start_battle({"type":"battle","enemy_ids":["cinder_mite","cinder_mite"]})
	ui.game.run.battle.hand=ui.game.run.deck.slice(0,5).duplicate(true)
	ui.game.run.battle.draw=ui.game.run.deck.slice(5).duplicate(true)
	ui.game.run.battle.strain=[2,1,0,0,0,0]
	ui.game.save()
	ui.menu=false
	ui.notice="#16 TEST DECK · "+package+" · production cards / content1 · NOT a drafted expedition"
	for arg in OS.get_cmdline_user_args():
		if arg=="--small": root.size=Vector2i(1100,720)
	ui._render()
