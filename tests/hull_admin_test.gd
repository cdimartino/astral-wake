extends SceneTree
## Real scene, game, controller, sound bank, save store and asynchronous combat
## presentation. Exercise the local boundary with a fresh disposable profile.
var failures := 0
var main
var desk
var folder := ""

func _initialize() -> void:
	var base := OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_cache_dir()
	folder = base.path_join("astral-hull-admin-" + Crypto.new().generate_random_bytes(12).hex_encode())
	OS.set_environment("ASTRAL_SAVE_DIR",folder)
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	OS.set_environment("ASTRAL_MCP_PORT","")
	OS.set_environment("ASTRAL_MCP_TOKEN","")
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func ok(line: String) -> String:
	var result: String = desk.execute(line)
	check(not result.begins_with("Error:"), line + " → " + result)
	return result

func reject(line: String) -> void:
	var before: Dictionary = main.game.run.duplicate(true)
	check(desk.execute(line).begins_with("Error:"), "Unexpectedly accepted " + line)
	check(main.game.run == before, "Rejected command mutated expedition: " + line)

func wait_replay(limit: int) -> void:
	for i in range(limit * 10):
		if not desk.replaying: break
		await create_timer(.1).timeout
	check(not desk.replaying and desk.replay_status.begins_with("Replayed"), desk.replay_status)

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	desk = main.hull_admin
	var original = main.game
	original.new_run("HOME01", "palimpsest")
	original.choose_node(original.run.map[0][0].id)
	main.menu = false
	main._render()
	main._select_card(0)
	main._select_organ(0)
	main._open_settings()
	var state_before: Dictionary = original.run.duplicate(true)
	var profile_before: Dictionary = original.profile.duplicate(true)
	var selection_before: Array = main.route.duplicate()
	var bytes := FileAccess.get_file_as_bytes(folder.path_join("save.json"))
	var backup := FileAccess.get_file_as_bytes(folder.path_join("save.backup.json"))
	check(desk.enter(), "Enter the local workshop")
	check(main.game != original and main.game.store.directory.begins_with(folder + "/hull-workshop/sessions/"), "Separate Game and storage")
	check(main.game.run == original.run and not is_same(main.game.run, original.run), "Deep run clone")
	check("encounter boss witness_array" in desk.complete("encounter boss wit"), "Boss ID completion")
	check('audio solo "hull contact"' in desk.complete("audio solo hull"), "Multiword audio target completion")
	ok('audio solo "hull contact"')
	check(main.hull_audio.solo == "hull contact", "Audio receives intact quoted track token")
	ok("audio solo off")
	check(ok("help strain").contains("organ strain"), "Searchable registry")
	ok("run start cartographer GLASS1")
	reject("room open shop warm_wreck")
	reject("player set ward 3")
	ok("region jump pale_aperture 0")
	check(main.game.region().id == "pale_aperture", "Selected Glass Beyond")
	ok("encounter boss witness_array")
	check(main.game.run.battle.kind == "boss", "Boss encounter generated")
	reject("encounter battle witness_array")
	reject("player set command_points 9")
	reject("organ link 1 1 connect")
	reject("card add unknown_card")
	ok("scenario checkpoint")
	var checkpoint: Dictionary = main.game.run.duplicate(true)
	ok("card add glass_murmur hand")
	ok("organ strain 3 1")
	ok("organ link 0 1 cut")
	ok("organ link 1 0 mend")
	ok("status 0 disrupt 2")
	ok("powerup give amber_sight")
	ok("player set ward 4")
	main._select_card(main.game.Selections.index(main.game.run.battle.hand,11))
	main._select_organ(0)
	main._select_organ(1)
	main._confirm()
	await create_timer(main.presentation_duration + .15).timeout
	check(ok("inspect scenario").contains("play 11 0,1 0"), "Manual staged card and route captured")
	main._end_turn() # Actual UI path, recorded without a console command.
	await create_timer(main.presentation_duration + .15).timeout
	check(ok("inspect scenario").contains("phase end"), "Manual turn recorded")
	var recorded: Dictionary = main.game.run.duplicate(true)
	ok("scenario save tune-one")
	ok("audio preset load alternate")
	var mix: Dictionary = main.hull_audio.preset_snapshot().duplicate(true)
	ok("scenario export cross-machine")
	var shared := folder.path_join("hull-workshop/cross-machine.comparison.json")
	var encoded := FileAccess.get_file_as_string(shared)
	check(not encoded.contains("mcp_token") and not encoded.contains("settings") and not encoded.contains("HOME01"), "Portable file omits real progress and settings")
	ok("scenario restore")
	check(main.game.run == checkpoint or main.game.run.battle == checkpoint.battle, "Checkpoint restored")
	ok("scenario load tune-one")
	ok("audio preset load factory")
	ok("scenario replay")
	await wait_replay(30)
	check(main.game.run.battle == recorded.battle and main.game.run.hull == recorded.hull, "Deterministic phase, RNG and piles")
	ok("scenario import cross-machine")
	check(main.hull_audio.preset_snapshot() == mix, "Imported scenario restores the exported sound preset")
	ok("scenario replay")
	await wait_replay(30)
	check(main.game.run.battle == recorded.battle, "Same recorded player command and phase under alternate preset")
	ok("player set ward 2")
	ok("damage player 3")
	check(main.presentation_busy() and main.game.run.battle.ward == 0, "Admin combat edit presents real ward absorption")
	await create_timer(main.presentation_duration + .15).timeout
	reject("scenario export ../bad")
	var data: Dictionary = JSON.parse_string(encoded)
	data.sequence = ["audio reload /elsewhere"]
	var f := FileAccess.open(folder.path_join("hull-workshop/bad.comparison.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	reject("scenario import bad")
	ok("scenario load glass-listening")
	ok("scenario replay")
	await wait_replay(60)
	check(main.game.run.get("battle",{}).get("kind") == "boss", "Built-in listening sequence reaches guardian")
	# Leave while replay callbacks and presentation timers are pending.
	ok("scenario replay")
	desk.leave()
	await create_timer(.35).timeout
	check(not desk.active and main.game == original, "Exact original Game restored")
	check(original.run == state_before and original.profile == profile_before, "Exact original expedition and profile restored")
	check(main.selected_card == 0 and main.route == selection_before, "Staged selection restored")
	check(is_instance_valid(main.overlay) and main.overlay.get_meta("mcp_title","") == "Settings", "Original settings modal restored")
	check(bytes == FileAccess.get_file_as_bytes(folder.path_join("save.json")) and backup == FileAccess.get_file_as_bytes(folder.path_join("save.backup.json")), "Original and backup save bytes unchanged")
	check(desk.execute("run start cartographer GLASS1").begins_with("Error:"), "Inactive console cannot mutate")
	print("HULL_ADMIN ", "PASS" if failures == 0 else "FAIL", " failures=",failures)
	desk = null
	main.queue_free()
	for i in 5: await process_frame
	await create_timer(2.5).timeout
	quit(1 if failures else 0)
