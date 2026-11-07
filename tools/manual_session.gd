extends RefCounted
## Manual-only adapter around the real Game. No tactical selection lives here.
const Game = preload("res://scripts/game.gd")
const VERSION = 1
var game
var journal: Dictionary = {}

func _create_game(directory: String):
	return Game.new(directory)

static func failure(message: String) -> Dictionary:
	return {"ok":false, "error":message}

static func snapshot(state: Dictionary) -> Dictionary:
	var copy = state.duplicate(true)
	# Wall clocks and the generated run identity are not gameplay state.
	for key in ["id", "started_at", "elapsed_seconds"]: copy.erase(key)
	return copy

static func digest(value) -> String:
	return JSON.stringify(value, "", true).sha256_text()

static func restore_numbers(value):
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Array:
		var items = []
		for item in value: items.append(restore_numbers(item))
		return items
	if value is Dictionary:
		var fields = {}
		for key in value: fields[key] = restore_numbers(value[key])
		return fields
	return value

static func environment() -> Dictionary:
	var output = []
	var status = OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], output)
	var sources = {}
	for path in ["scripts/game.gd", "scripts/reward_distribution.gd", "scripts/evolutions.gd", "scripts/known_selections.gd", "scripts/install_engines.gd", "scripts/route_effects.gd", "scripts/seed_engine.gd", "scripts/save_store.gd", "data/catalog.json"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	return {"content_pool_revision":Game.CONTENT_POOL_REVISION, "game_revision":str(output[0]).strip_edges() if status == 0 and not output.is_empty() else "unknown", "sources":sources, "godot":Engine.get_version_info().string}

func start(directory: String, seed_value, ship: String, unlocks: int) -> Dictionary:
	# Even a completed save must be explicitly archived, never silently replaced.
	for name in ["save.json", "save.backup.json"]:
		if FileAccess.file_exists(directory.path_join(name)): return failure("Save already exists; resume or use a fresh session directory.")
	if unlocks < 0 or unlocks > 3: return failure("Unlocks must be 0 through 3.")
	if not ((seed_value is String and Game.SeedEngine.valid(Game.SeedEngine.canonical(seed_value))) or (seed_value is int and seed_value > 0)):
		return failure("Supply an explicit six-character practice code or positive legacy numeric seed.")
	game = _create_game(directory)
	game.profile.unlocks = unlocks
	var result = game.new_run(seed_value, ship)
	if not result.ok: return result
	if not game.save_error.is_empty(): return failure(game.save_error)
	journal = {"version":VERSION, "environment":environment(), "seed":seed_value, "ship":ship, "unlocks":unlocks, "initial":snapshot(game.run), "entries":[], "errors":[]}
	return inspect()

func guard() -> Dictionary:
	return {"step":journal.entries.size() + journal.errors.size(), "state":digest(snapshot(game.run))}

func inspect() -> Dictionary:
	var hand = []
	for instance in game.run.get("battle", {}).get("hand", []):
		hand.append({"uid":instance.uid, "effective_card":game.effective_card(instance)})
	var enemies = []
	var foes = game.run.get("battle", {}).get("enemies", [])
	for i in range(foes.size()): enemies.append({"slot":i, "id":foes[i].id, "hp":foes[i].hp})
	var view={"ok":true, "expect":guard(), "state":snapshot(game.run), "hand":hand, "targets":enemies, "reward_policy":Game.Distribution.policy(game.run) if not game.run.is_empty() else ""}
	if game.run.get("mode","")=="modify" and game.run.modify_kind=="upgrade":
		view.evolutions=[]
		for instance in game.run.deck:
			if instance.level!=0: continue
			var choices=[]
			for branch in game.evolution_choices(instance):
				var after=instance.duplicate(true)
				after.level=1
				after.evolution=branch.id
				choices.append({"branch":branch.id,"effective_card":game.effective_card(after),"text":game.card_text(after)})
			if not choices.is_empty(): view.evolutions.append({"uid":instance.uid,"before":game.effective_card(instance),"choices":choices})
	if game.selection_pending(): view.selection=game.selection_view()
	return view

func _integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value)

func _index(items: Array, uid: int) -> int:
	var found = -1
	for i in range(items.size()):
		if int(items[i].uid) == uid:
			if found >= 0: return -1
			found = i
	return found

func _validate(command: Dictionary) -> String:
	if not command.get("op") is String: return "Command requires an op."
	var fields = {
		"play":["uid", "route", "target"], "preview":["uid", "route", "target"],
		"begin_selection":["uid", "route", "target"], "select_uid":["choice_uid"],
		"confirm_selection":[], "cancel_selection":[], "selection_preview":[],
		"modify":["uid", "branch"], "choose_node":["node"], "reward":["choice"],
		"buy":["choice"], "event":["choice"], "recover":["choice"],
		"end_turn":[], "continue_region":[], "cancel_modify":[], "leave":[], "abandon":[]}
	if not fields.has(command.op): return "Unknown manual operation."
	for key in command:
		if key not in ["op", "expect"] and key not in fields[command.op]: return "Unexpected command field: " + str(key)
	for key in fields[command.op]:
		if key=="branch": continue # Optional only for unbranched legacy compatibility.
		if not command.has(key): return "Missing command field: " + key
	if command.has("branch") and (not command.branch is String or command.branch.is_empty()): return "branch must be an explicit evolution ID."
	if not command.get("expect") is Dictionary or command.expect != guard(): return "Stale or missing expected state; inspect before selecting again."
	if command.has("uid") and (not _integer(command.uid) or command.uid <= 0): return "uid must be a positive integer."
	if command.has("choice_uid") and command.choice_uid!=null and (not _integer(command.choice_uid) or command.choice_uid<=0): return "choice_uid must be a positive integer or authored optional null."
	if command.has("node") and not command.node is String: return "node must be a destination ID."
	if command.op in ["reward", "buy", "event"] and not _integer(command.choice): return "choice must be an integer."
	if command.op == "recover" and not command.choice is String: return "Recovery choice must be repair or upgrade."
	if command.op in ["play", "preview", "begin_selection"]:
		if game.run.get("mode") != "combat": return "There is no active battle."
		if not command.route is Array: return "route must be an ordered organ-index array."
		for organ in command.route:
			if not _integer(organ): return "Route indices must be integers."
		if not command.target is Dictionary or command.target.size() != 2 or not command.target.get("id") is String or not _integer(command.target.get("slot")):
			return "target requires an explicit enemy id and integer slot."
		var slot = int(command.target.slot)
		var foes = game.run.battle.enemies
		if slot < 0 or slot >= foes.size() or foes[slot].id != command.target.id: return "Target no longer matches that enemy slot."
	return ""

func apply(command: Dictionary) -> Dictionary:
	# JSON decodes integral numbers as floats; normalize without truncating invalid
	# fractional inputs before comparing the exact expected-state guard.
	command = restore_numbers(command)
	var before = snapshot(game.run)
	var error = _validate(command)
	var result = failure(error)
	var effective = {}
	if error.is_empty():
		var uid = int(command.get("uid", -1))
		match command.op:
			"play", "preview", "begin_selection":
				var index = _index(game.run.battle.hand, uid)
				if index < 0: result = failure("Card UID is not uniquely present in the current hand.")
				else:
					effective = game.effective_card(game.run.battle.hand[index])
					var route = game._restore_integers(command.route)
					if command.op == "preview": result = game.preview_card(index, route, int(command.target.slot))
					elif command.op == "begin_selection": result = game.begin_selection(uid,route,int(command.target.slot),game.run.battle.enemies[int(command.target.slot)].duplicate(true))
					else: result = game.play_card(index, route, int(command.target.slot))
			"select_uid": result = game.select_uid(command.choice_uid)
			"confirm_selection": result = game.confirm_selection()
			"cancel_selection": result = game.cancel_selection()
			"selection_preview": result = game.preview_selection()
			"modify":
				var index = _index(game.run.deck, uid)
				if index < 0: result = failure("Card UID is not uniquely present in the deck.")
				else:
					effective = game.effective_card(game.run.deck[index])
					result = game.evolve_card(uid,command.branch) if command.has("branch") else game.modify_card(index)
					if result.ok and _index(game.run.deck,uid)>=0: effective=game.effective_card(game.run.deck[_index(game.run.deck,uid)])
			"choose_node": result = game.choose_node(command.node)
			"reward": result = game.choose_reward(int(command.choice))
			"buy": result = game.buy(int(command.choice))
			"event": result = game.event_choice(int(command.choice))
			"recover": result = game.recover(command.choice)
			"end_turn": result = game.end_turn()
			"continue_region": result = game.continue_region()
			"cancel_modify": result = game.cancel_modify()
			"leave": result = game.leave_location()
			"abandon": result = game.abandon()
	# Previews, including failed ones, are queries: no journal or RNG changes.
	if command.get("op") in ["preview","selection_preview"]: return {"ok":result.ok, "result":result, "view":inspect()}
	var entry = {"sequence":guard().step, "command":command.duplicate(true), "before":before, "after":snapshot(game.run), "effective_card":effective, "result":result}
	if result.ok: journal.entries.append(entry)
	else: journal.errors.append(entry)
	return {"ok":result.ok, "result":result, "save_error":game.save_error, "view":inspect()}

func write(path: String) -> Dictionary:
	var temporary = path + ".pending"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return failure("Cannot write journal: " + temporary)
	file.store_string(JSON.stringify(journal, "\t", true))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, path) != OK: return failure("Cannot commit journal; stop and preserve the session for inspection.")
	return {"ok":true}

func read_journal(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version") != VERSION or not parsed.get("entries") is Array or not parsed.get("errors") is Array or not parsed.get("initial") is Dictionary:
		return failure("Invalid or unsupported journal.")
	for key in ["seed", "ship", "unlocks", "environment"]:
		if not parsed.has(key): return failure("Incomplete journal header.")
	parsed = restore_numbers(parsed)
	if parsed.environment != environment(): return failure("Revision, source fingerprints or Godot version differ; replay with the recorded environment.")
	if not parsed.ship is String or not _integer(parsed.unlocks) or parsed.unlocks < 0 or parsed.unlocks > 3: return failure("Invalid journal ship or discovery tier.")
	for collection in ["entries", "errors"]:
		for entry in parsed[collection]:
			if not entry is Dictionary or not entry.get("sequence") is int or not entry.get("command") is Dictionary or not entry.get("before") is Dictionary or not entry.get("after") is Dictionary or not entry.get("effective_card") is Dictionary or not entry.get("result") is Dictionary:
				return failure("Malformed journal attempt.")
			if entry.result.get("ok") != (collection == "entries") or entry.command.get("op") in ["preview","selection_preview"]: return failure("Misclassified journal attempt.")
	var attempts = ordered_attempts(parsed)
	var previous = parsed.initial
	for i in range(attempts.size()):
		if attempts[i].sequence != i or attempts[i].before != previous: return failure("Broken journal sequence or snapshot chain at step %d." % i)
		previous = attempts[i].after
	journal = parsed
	return {"ok":true}

func resume(directory: String, path: String) -> Dictionary:
	var result = read_journal(path)
	if not result.ok: return result
	game = _create_game(directory)
	if not game.save_error.is_empty(): return failure(game.save_error)
	var expected = journal.initial
	var attempts = ordered_attempts(journal)
	if not attempts.is_empty():
		if not attempts.back() is Dictionary or not attempts.back().get("after") is Dictionary: return failure("Invalid journal tail.")
		expected = attempts.back().after
	if snapshot(game.run) != expected: return failure("Save and journal disagree; refusing to restart or resume an unaudited state.")
	return inspect()

func replay(path: String, directory: String) -> Dictionary:
	var loaded = read_journal(path)
	if not loaded.ok: return loaded
	var recorded = journal.duplicate(true)
	var seed_value = recorded.seed
	if _integer(seed_value): seed_value = int(seed_value)
	var result = start(directory, seed_value, str(recorded.ship), int(recorded.unlocks))
	if not result.ok: return result
	if journal.initial != recorded.initial: return failure("Initial state diverged.")
	var attempts = ordered_attempts(recorded)
	for i in range(attempts.size()):
		var entry = attempts[i]
		if not entry is Dictionary or not entry.get("command") is Dictionary or entry.command.get("op") in ["preview","selection_preview"]: return failure("Invalid committed entry at step %d." % i)
		apply(entry.command)
		var actual = journal.entries.back() if journal.errors.is_empty() or (not journal.entries.is_empty() and journal.entries.back().sequence > journal.errors.back().sequence) else journal.errors.back()
		if actual != entry: return failure("Replay diverged at step %d." % i)
	return {"ok":true, "verified_entries":recorded.entries.size(), "verified_errors":recorded.errors.size(), "view":inspect()}

func ordered_attempts(recorded: Dictionary) -> Array:
	var attempts = recorded.entries.duplicate() + recorded.errors.duplicate()
	attempts.sort_custom(func(a, b): return a.get("sequence", -1) < b.get("sequence", -1) if a is Dictionary and b is Dictionary else false)
	return attempts
