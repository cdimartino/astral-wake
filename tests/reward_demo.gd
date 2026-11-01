extends SceneTree
## Native, explicitly labelled UI counterfactual. Not a production cheat hook.
func _initialize() -> void:
	var directory: String = OS.get_environment("ASTRAL_SAVE_DIR")
	var existing = DirAccess.open(directory) if not directory.is_empty() else null
	if directory.is_empty() or (existing != null and (not existing.get_files().is_empty() or not existing.get_directories().is_empty())):
		push_error("Set ASTRAL_SAVE_DIR to a fresh scratch directory; never a player save.")
		quit(1)
		return
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	show_demo.call_deferred()

func show_demo() -> void:
	var ship: String = "cartographer"
	var view: String = "reward"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.trim_prefix("--ship=")
		if arg.begins_with("--view="): view = arg.trim_prefix("--view=")
	if not ship in ["cartographer", "palimpsest", "hollow_choir"] or not view in ["reward", "shop", "pity", "guarantee"]:
		push_error("Use a production ship and --view=reward|shop|pity|guarantee.")
		quit(1)
		return
	var ui = preload("res://scripts/main.gd").new()
	root.add_child(ui)
	ui.game.new_run("0093CG", ship)
	var pockets: bool = "--pockets" in OS.get_cmdline_user_args()
	if pockets: ui.game.run.powerups.append("many_pockets")
	if view == "shop": ui.game._make_shop()
	elif view == "pity": ui.game.run.rare_offer_misses = 6
	else:
		ui.game.choose_node(ui.game.run.map[0][0].id)
		# Combat is not played; only the real reward generator is exercised.
		if view == "guarantee": ui.game.run.rare_offer_misses = 6
		ui.game._finish_battle()
	ui.game.save()
	ui.menu = false
	ui.notice = "DISTRIBUTION UI COUNTERFACTUAL · %s · 0093CG · %s%s · NOT a played expedition" % [ship, view, " + Pockets" if pockets else ""]
	ui._render()
	if view == "pity": ui._open_deck()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--capture="): continue
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
		quit()
