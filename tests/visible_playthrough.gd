"""Paced visible playtest; inherits the same decisions and public actions as headless runs."""
extends "res://tests/playthrough.gd"

const Main = preload("res://scripts/main.gd")
const VISIBLE_SEED = 2026
var ui
var visible_directory = ""
var ending_image = ""
var resumed = false

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	# Set the environment before Main constructs its Game, so user saves are never read.
	visible_directory="/tmp/astral-visible-%d-%d"%[VISIBLE_SEED,Time.get_ticks_usec()]
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--resume-dir="): continue
		var directory=arg.trim_prefix("--resume-dir=").simplify_path().trim_suffix("/")
		var prefix="astral-visible-%d-"%VISIBLE_SEED
		var temporary=DirAccess.open("/tmp")
		var suffix=directory.get_file().trim_prefix(prefix)
		if directory.get_base_dir()!="/tmp" or not directory.get_file().begins_with(prefix) or not suffix.is_valid_int() or suffix.to_int()<=0 or temporary==null or temporary.is_link(directory.get_file()):
			printerr("VISIBLE_RESUME_REJECTED: use an existing isolated /tmp/astral-visible-2026-<number> directory.")
			quit(1)
			return
		var saved_directory=DirAccess.open(directory)
		if saved_directory==null or saved_directory.is_link("save.json") or saved_directory.is_link("save.backup.json") or not (FileAccess.file_exists(directory.path_join("save.json")) or FileAccess.file_exists(directory.path_join("save.backup.json"))):
			printerr("VISIBLE_RESUME_REJECTED: isolated save files are missing or symlinked.")
			quit(1)
			return
		visible_directory=directory
		resumed=true
	OS.set_environment("ASTRAL_SAVE_DIR",visible_directory)
	call_deferred("_visible_run")

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _commit(action: Callable, action_kind: String = "") -> Dictionary:
	var outcome={}
	ui._perform(func():
		var result: Dictionary=action.call()
		outcome.merge(result)
		return result
	,action_kind)
	return outcome

func _visible_run() -> void:
	started=Time.get_ticks_msec()
	root.gui_disable_input=true
	ui=Main.new()
	root.add_child(ui)
	ui.set_process_input(false)
	game=ui.game
	if resumed:
		if game.run.is_empty() or int(game.run.get("seed",-1))!=VISIBLE_SEED or not game._valid_run(game.run):
			printerr("VISIBLE_RESUME_REJECTED: save must contain a valid seed-2026 expedition.")
			quit(1)
			return
		print("VISIBLE_RESUME seed=%d save_directory=%s mode=%s turns=%d battles=%d"%[VISIBLE_SEED,visible_directory,game.run.mode,game.run.turns,game.run.battles])
	else:
		print("VISIBLE_START seed=%d save_directory=%s"%[VISIBLE_SEED,visible_directory])
		await _wait(2.0)
		game.new_run(VISIBLE_SEED)
	prepare_routes()
	ui.menu=false
	ui._clear_selection()
	ui._render()
	while not game.run.mode in ["victory","defeat"] and actions<4000:
		var outcome={"ok":true}
		match game.run.mode:
			"combat":
				var planned=plan_combat_action()
				if planned.get("end_turn",false):
					await _wait(1.0)
				else:
					ui.selected_card=int(planned.hand)
					ui.target=int(planned.target)
					ui.route.clear()
					ui._render()
					await _wait(0.5)
					for organ_index in planned.route:
						ui.route.append(int(organ_index))
						ui._render()
						await _wait(0.25)
					await _wait(1.2)
				outcome=_commit(combat_action,"enemy_phase" if planned.get("end_turn",false) else "command")
				while ui.presentation_busy(): await process_frame
				await _wait(0.6)
			"map":
				ui._map_details(plan_path())
				await _wait(1.0)
				outcome=_commit(choose_path)
			"reward":
				await _wait(1.0)
				outcome=_commit(choose_reward)
			"transition":
				checkpoints.append({"region":game.run.region,"turns":game.run.turns,"hull":game.run.hull,"cards":game.run.deck.size()})
				print("VISIBLE_REGION_COMPLETE "+JSON.stringify(checkpoints[-1]))
				await _wait(2.0)
				outcome=_commit(func(): return game.continue_region())
			"recovery":
				await _wait(1.0)
				outcome=_commit(func(): return game.recover("repair" if game.run.hull<72 else "upgrade"))
			"modify":
				await _wait(1.0)
				outcome=_commit(modify)
			"shop":
				await _wait(1.0)
				outcome=_commit(shop)
			"event":
				await _wait(1.0)
				outcome=_commit(event)
			_:
				outcome={"ok":false,"error":"Unexpected playtest mode: "+str(game.run.mode)}
		if not outcome.ok or not game._valid_run(game.run):
			var message=str(outcome.get("error","Invalid state after action"))
			printerr("VISIBLE_ACTION_FAILED ",actions," ",game.run.mode," ",message)
			_write_result(message)
			quit(1)
			return
		actions+=1
		if actions%25==0:
			print("VISIBLE_PROGRESS %s=%d region=%d layer=%d hull=%d mode=%s"%["actions_since_resume" if resumed else "actions",actions,game.run.region+1,game.run.layer+1,game.run.hull,game.run.mode])
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var path=visible_directory.path_join("visible-ending.png")
		if not image.is_empty() and image.save_png(path)==OK:
			ending_image=path
			print("VISIBLE_ENDING_IMAGE "+path)
		else:
			printerr("VISIBLE_ENDING_IMAGE_FAILED "+path)
	_write_result()
	await _wait(8.0)
	quit(0 if game.run.mode=="victory" else 2)

func _write_result(error: String = "") -> void:
	var result={"seed":VISIBLE_SEED,"mode":game.run.mode,"region":game.run.region+1,"layer":game.run.layer+1,"turns":game.run.turns,"battles":game.run.battles,"resumed":resumed,"hull":game.run.hull,"deck":game.run.deck,"powerups":game.run.powerups,"save_directory":visible_directory,"ending_image":ending_image,"error":error}
	if resumed:
		result.merge({"cards_since_resume":cards_played,"actions_since_resume":actions,"max_cards_per_turn_since_resume":max_cards_per_turn,"checkpoints_since_resume":checkpoints,"wall_seconds_since_resume":(Time.get_ticks_msec()-started)/1000.0})
	else:
		result.merge({"cards_played":cards_played,"actions":actions,"max_cards_per_turn":max_cards_per_turn,"checkpoints":checkpoints,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0})
	var path=visible_directory.path_join("visible-summary.json")
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		printerr("VISIBLE_SUMMARY_WRITE_FAILED ",path)
	else:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	print("VISIBLE_PLAYTHROUGH "+JSON.stringify(result))
	print("VISIBLE_SUMMARY "+path)
