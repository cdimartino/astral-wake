extends SceneTree
const Session = preload("res://tools/manual_session.gd")

func _create_session(): return Session.new()

func _initialize() -> void:
	call_deferred("run_driver")

func fail(message: String) -> void:
	print(JSON.stringify(Session.failure(message)))
	quit(1)

func run_driver() -> void:
	var options = {}
	for arg in OS.get_cmdline_user_args():
		var pair = arg.trim_prefix("--").split("=", true, 1)
		if not arg.begins_with("--") or pair.size() != 2 or pair[0] not in ["session", "start", "ship", "unlocks", "resume", "replay", "commands", "command"] or options.has(pair[0]):
			fail("Use --session=DIR and exactly one of --start=SEED, --resume=true, --replay=JOURNAL; optional --command=JSON or --commands=JSONL.")
			return
		options[pair[0]] = pair[1]
	var modes = int(options.has("start")) + int(options.has("resume")) + int(options.has("replay"))
	if modes != 1 or str(options.get("session", "")).is_empty() or (options.has("commands") and options.has("command")):
		fail("Specify a session directory, exactly one mode, and at most one command source.")
		return
	if not options.has("start") and (options.has("ship") or options.has("unlocks")):
		fail("Ship and unlocks are start-only; resume never starts a new expedition.")
		return
	if options.has("replay") and (options.has("command") or options.has("commands")):
		fail("Replay verifies only; resume separately to add manual commands.")
		return
	var directory = str(options.session)
	if not directory.is_absolute_path(): directory = ProjectSettings.globalize_path("res://").path_join(directory)
	var journal_path = directory.path_join("trace.json")
	var save_directory = directory.path_join("saves")
	var session = _create_session()
	var result: Dictionary
	if options.has("start"):
		if DirAccess.dir_exists_absolute(directory):
			fail("Start requires a new session directory; existing sessions are never overwritten.")
			return
		var seed_value = options.start
		# Prefix numeric fixtures explicitly: a six-digit string is a modern code.
		if seed_value.begins_with("legacy:"):
			seed_value = seed_value.trim_prefix("legacy:")
			if not seed_value.is_valid_int():
				fail("Invalid legacy numeric seed.")
				return
			seed_value = int(seed_value)
		if not str(options.get("unlocks", "0")).is_valid_int():
			fail("Unlocks must be an integer.")
			return
		result = session.start(save_directory, seed_value, str(options.get("ship", "cartographer")), int(options.get("unlocks", "0")))
		if result.ok:
			var written = session.write(journal_path)
			if not written.ok: result = written
	elif options.has("resume"):
		if options.resume != "true":
			fail("Use --resume=true to explicitly resume the existing save and journal.")
			return
		result = session.resume(save_directory, journal_path)
	else:
		if DirAccess.dir_exists_absolute(directory):
			fail("Replay requires a fresh scratch session directory.")
			return
		result = session.replay(options.replay, save_directory)
		if result.ok:
			var written = session.write(journal_path)
			if not written.ok: result = written
	if not result.ok:
		print(JSON.stringify(result))
		quit(1)
		return
	print(JSON.stringify(result))
	var lines = []
	if options.has("command"): lines.append(options.command)
	if options.has("commands"):
		if not FileAccess.file_exists(options.commands):
			fail("Command file does not exist.")
			return
		lines.assign(FileAccess.get_file_as_string(options.commands).split("\n"))
	for line in lines:
		if str(line).strip_edges().is_empty(): continue
		var command = JSON.parse_string(line)
		if not command is Dictionary:
			fail("Expected a JSON object per command line; stopped before this line.")
			return
		result = session.apply(command)
		if command.get("op") not in ["preview","selection_preview"]:
			var written = session.write(journal_path)
			if not written.ok:
				print(JSON.stringify(written))
				quit(1)
				return
		print(JSON.stringify(result))
		if not result.ok or not session.game.save_error.is_empty():
			quit(1)
			return
	quit(0)
