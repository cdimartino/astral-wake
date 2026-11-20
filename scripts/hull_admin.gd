extends RefCounted
## Owned by the local scene, never by a bridge or an MCP request handler.
const Game = preload("res://scripts/game.gd")
const Registry = preload("res://scripts/hull_admin_registry.gd")
const Edits = preload("res://scripts/hull_admin_game.gd")
const Files = preload("res://scripts/hull_scenarios.gd")
const MAX_STEPS := 256
const UI_FIELDS := ["menu","choosing_character","selected_character","expedition_seed","anatomy_view","selected_card","target","route","notice","modify_page","focus_key","last_feedback"]
const PLAYER_ACTIONS := ["choose_node","select_card","select_organ","select_target","confirm","end_turn","undo_route","cancel_selection","choose_known_card","confirm_known_selection","cancel_known_selection","take_discovery","skip_reward","event_choice","leave_location","repair","choose_upgrade","modify_card","choose_evolution","cancel_modify","next_page","previous_page","buy","continue_region","continue_expedition","toggle_anatomy","close_overlay"]
var active := false
var replaying := false
var replay_status := ""
var ui
var hull
var _original
var _original_ui := {}
var _original_overlay := ""
var _entered_at := 0
var _scratch := ""
var _files := ""
var _checkpoint := {}
var _checkpoint_history: Array = []
var _sequence: Array = []
var _fresh_branch := false
var _inside_command := false
var _generation := 0

func setup(owner, audio) -> void:
	ui = owner
	hull = audio

func enter() -> bool:
	if active: return true
	if ui == null or ui.presentation_busy() or is_instance_valid(ui.opening_film): return false
	_original = ui.game
	_files = _original.store.directory.path_join("hull-workshop")
	_scratch = _files.path_join("sessions/%s" % Crypto.new().generate_random_bytes(12).hex_encode())
	var sandbox = Game.new(_scratch)
	sandbox.run = _original.run.duplicate(true)
	sandbox.profile = _original.profile.duplicate(true)
	for key in sandbox.profile.settings.keys():
		if str(key).begins_with("mcp_"): sandbox.profile.settings.erase(key)
	_entered_at = Time.get_ticks_msec()
	sandbox._last_clock = _entered_at
	if not sandbox.save():
		Files.clean_session(_scratch)
		_original = null
		return false
	_original_ui = _capture_ui()
	_original_overlay = str(ui.overlay.get_meta("mcp_title","")) if is_instance_valid(ui.overlay) else ""
	active = true
	ui.game = sandbox
	ui._render()
	_checkpoint_here()
	return true

func leave() -> void:
	if not active: return
	_generation += 1
	replaying = false
	# The original expedition's clock has been paused while the sandbox is open.
	if _original._last_clock > 0: _original._last_clock += Time.get_ticks_msec() - _entered_at
	ui.game = _original
	_original = null
	active = false
	_restore_ui(_original_ui)
	ui._render()
	# Actual entry points are Settings and the pause menu. Rebuild their controls
	# from the restored game, never keep callbacks bound to a sandbox Game.
	match _original_overlay:
		"Settings": ui._open_settings()
		"Expedition paused": ui._open_menu()
	_original_ui.clear()
	_checkpoint.clear()
	_checkpoint_history.clear()
	_sequence.clear()
	Files.clean_session(_scratch)

func _capture_ui() -> Dictionary:
	var values := {}
	for key in UI_FIELDS:
		var value = ui.get(key)
		values[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return values

func _restore_ui(values: Dictionary) -> void:
	for key in UI_FIELDS:
		if key == "route" and values.has(key): ui.route.assign(values.route)
		elif values.has(key): ui.set(key, values[key].duplicate(true) if values[key] is Array else values[key])

func _checkpoint_here() -> void:
	var selection := _capture_ui()
	# UI-only animation/focus/notice data are not portable scenario data.
	for key in ["last_feedback","focus_key","notice"]: selection.erase(key)
	_checkpoint = {"run":ui.game.run.duplicate(true),"unlocks":int(ui.game.profile.unlocks),"ui":selection}
	_checkpoint_history = ui.game.profile.history.duplicate(true)
	_sequence = []
	_fresh_branch = false
	replay_status = "Recording from checkpoint."

func _restore_checkpoint() -> bool:
	var game = ui.game
	var restored: Dictionary = _checkpoint.run.duplicate(true)
	var profile: Dictionary = game.profile.duplicate(true)
	profile.unlocks = _checkpoint.unlocks
	profile.history = _checkpoint_history.duplicate(true)
	if not game.store.write(profile,restored):
		game.save_error = game.store.error
		return false
	game.run = restored
	game.profile = profile
	game.save_error = ""
	game._last_clock = Time.get_ticks_msec()
	_restore_ui(_checkpoint.ui)
	ui.notice = ""
	ui.last_feedback = []
	ui.focus_key = ""
	ui._render()
	return true

func _record(line: String) -> void:
	if _fresh_branch:
		_sequence.clear()
		_fresh_branch = false
	if _sequence.size() < MAX_STEPS: _sequence.append(line)
	else: replay_status = "Recording full (%d steps); create a new checkpoint." % MAX_STEPS

func record_player_action(before: Dictionary, kind: String, card: Dictionary, route: Array, target: int) -> void:
	if not active or _inside_command: return
	if replaying:
		_generation += 1
		replaying = false
		replay_status = "Replay stopped by manual play."
		return
	if kind == "enemy_phase": _record("phase end")
	if kind == "command" and not card.is_empty():
		var choices: Array = before.get("pending_selection", {}).get("choices", [])
		var ids := PackedStringArray()
		for uid in choices: ids.append("none" if uid == null else str(uid))
		# Re-stage manual combat gestures separately so all accepted organ contacts
		# get their own replay frame. A checkpoint may already be in a chooser.
		if before.get("pending_selection",{}).is_empty():
			_record("stage card %d" % card.uid)
			for organ in route: _record("stage organ %d" % organ)
			_record("stage target %d" % target)
		var line := "play %d %s %d" % [card.uid, ",".join(PackedStringArray(route)), target]
		_record(line if ids.is_empty() else line + " " + ",".join(ids))

func execute(line: String) -> String:
	if not active: return "Error: Enter local admin mode first."
	if replaying and line.strip_edges() not in ["scenario stop","inspect scenario","inspect effects","audio voices","audio trace"]:
		return "Error: Scenario replay in progress; use scenario stop."
	return _execute(line, false)

func _execute(line: String, replay: bool) -> String:
	if line.length() > 1024: return "Error: Command is too long."
	var parsed := Registry.tokens(line.strip_edges())
	if not parsed.closed: return "Error: Close the quoted argument."
	var words: PackedStringArray = parsed.words
	var command := Registry.find_command(words)
	if command.is_empty(): return "Error: Unknown command. Type help."
	var args := words.slice(command.count(" ") + 1)
	var spec: Array = Registry.COMMANDS[command]
	if command == "help": return Registry.help(" ".join(args))
	if command == "audio":
		if args.is_empty() or args == PackedStringArray(["help"]): return Registry.audio_help()
		var error := Registry.audio_error(args)
		if not error.is_empty(): return "Error: " + error
		return hull.command(args)
	if ui.presentation_busy() and command not in ["inspect","scenario stop","scenario list"]:
		return "Error: Presentation is in progress."
	if spec[1] == "expedition" and not ui.game.run_exists(): return "Error: Start an active sandbox expedition first."
	if spec[1] == "combat" and ui.game.run.get("mode","") != "combat": return "Error: This command requires combat."
	if ui.game.selection_pending() and spec[2] and not command in ["act","play","effect","scenario wait"]:
		return "Error: Confirm or cancel the pending selection first."
	var types: PackedStringArray = spec[0].split(" ",false)
	var required := 0
	for type in types:
		if not type.ends_with("?"): required += 1
	if args.size() < required or args.size() > types.size(): return "Error: Use " + Registry.usage(command)
	for i in args.size():
		var type := types[i].trim_suffix("?")
		var error := _arg_error(type, args[i], args.slice(0,i))
		if not error.is_empty(): return "Error: " + error
	var was_inside := _inside_command
	_inside_command = true
	var result := _dispatch(command, args)
	_inside_command = was_inside
	if spec[2] and not replay and not result.begins_with("Error:"): _record(" ".join(words))
	return result

func _arg_error(type: String, token: String, previous: PackedStringArray) -> String:
	match type:
		"number","option","count","seconds":
			var upper := 10 if type == "count" else 30 if type == "seconds" else 99999
			var lower := 1 if type in ["count","seconds"] else 0
			if not token.is_valid_int() or token.length() > 6 or int(token) < lower or int(token) > upper:
				return "Expected %s in range %d..%d." % [type, lower, upper]
		"seed":
			if not Game.SeedEngine.valid(token.to_upper()): return "Use a seed of six letters or digits."
		"name","scenario","comparison":
			if not Files.safe_name(token): return "Use 1–64 letters, digits, hyphens or underscores for the name."
		"route":
			var parts := token.split(",")
			if parts.size() > 3: return "Route through one to three organs."
			for part in parts:
				if not part in Registry.OPTIONS.organ: return "Expected comma-separated organ indices 0..5."
		"choices":
			var parts := token.split(",")
			if parts.size() > 10: return "Too many choices."
			for part in parts:
				if part != "none" and (not part.is_valid_int() or int(part) <= 0): return "Expected comma-separated choice UIDs or none."
		_:
			if not token in _options(type,previous): return "Invalid %s: %s. Use Tab for available values." % [type, token]
	return ""

func _options(type: String, previous: PackedStringArray) -> PackedStringArray:
	if Registry.OPTIONS.has(type): return PackedStringArray(Registry.OPTIONS[type])
	var game = ui.game
	var run: Dictionary = game.run
	var battle: Dictionary = run.get("battle", {})
	var result := PackedStringArray()
	match type:
		"vessel","region","event","powerup":
			var key: String = {"vessel":"characters","region":"regions","event":"events","powerup":"powerups"}[type]
			for item in game.catalog[key]: result.append(item.id)
		"node":
			for layer in run.get("map",[]):
				for node in layer: result.append(node.id)
		"regular","elite","boss","enemy":
			for foe in game.catalog.enemies:
				if type == "enemy" or foe.role == type: result.append(foe.id)
		"resource":
			result = PackedStringArray(["hull","salvage"])
			if run.get("mode") == "combat":
				result.append_array(["ward","command_points"])
				if run.character == "hollow_choir": result.append("resonance")
				if run.character == "palimpsest": result.append("trace")
		"actor","foe":
			if type == "actor": result.append("player")
			for i in battle.get("enemies",[]).size(): result.append(str(i))
		"card":
			for c in game.catalog.cards:
				if not run.is_empty() and game._pool_card(run,c.id): result.append(c.id)
		"uid","hand_uid":
			for c in (run.get("deck",[]) if type == "uid" else battle.get("hand",[])): result.append(str(c.uid))
		"status": result = PackedStringArray(["ward","mark"] if not previous.is_empty() and previous[0] == "player" else ["disrupt","redirect"])
		"action":
			for entry in ui.mcp_controller.snapshot().legal_actions:
				if entry.action in PLAYER_ACTIONS: result.append(entry.action)
		"option":
			if not previous.is_empty():
				for entry in ui.mcp_controller.snapshot().legal_actions:
					if entry.action == previous[0]:
						for opt in entry.args.index.options: result.append(str(opt.index))
		"scenario","comparison": return Files.names(_files, type == "comparison")
		"count": result = PackedStringArray(["1","2","3","4","5","6","7","8","9","10"])
		"route": result = PackedStringArray(Registry.OPTIONS.organ)
	return result

func complete(line: String) -> PackedStringArray:
	var result := PackedStringArray()
	if not active: return result
	var text := line.lstrip(" \t").replace("\t"," ")
	if text.begins_with("audio "): return Registry.complete_audio(text, hull)
	var words := text.split(" ",false)
	var prefix := ""
	if not text.ends_with(" ") and not words.is_empty():
		prefix = words[-1]
		words = words.slice(0,-1)
	for command in Registry.COMMANDS:
		var parts: PackedStringArray = command.split(" ")
		if words.size() < parts.size() and parts.slice(0, words.size()) == words and parts[words.size()].begins_with(prefix):
			if not result.has(command): result.append(command)
	var command := Registry.find_command(words)
	if not command.is_empty():
		var args := words.slice(command.count(" ") + 1)
		var types: PackedStringArray = Registry.COMMANDS[command][0].split(" ",false)
		if args.size() < types.size():
			for value in _options(types[args.size()].trim_suffix("?"), args):
				if value.begins_with(prefix): result.append(" ".join(words) + " " + value)
	result.sort()
	return result

func _dispatch(command: String, a: PackedStringArray) -> String:
	if command.begins_with("scenario "): return _scenario(command.trim_prefix("scenario "), a)
	if command == "inspect": return _inspect(a[0])
	if command == "act" or command == "preview": return _controller(command, a)
	if command.begins_with("stage "):
		if ui.menu or ui.choosing_character: return "Error: Continue the expedition before staging."
		match command:
			"stage card": ui._select_card(ui.game.Selections.index(ui.game.run.battle.hand,int(a[0])))
			"stage organ": ui._select_organ(int(a[0]))
			"stage target": ui._select_target(int(a[0]))
		return "Staged: %s %s" % [command.trim_prefix("stage "),a[0]] if ui.notice.is_empty() else "Error: " + str(ui.notice)
	if command == "effect":
		var cue := {"kind":a[0], "label":a[0].to_upper(), "from":Vector2(435,350),"to":Vector2(1050,320),"color":Color("#99d9df"),"route":[0,1,2]}
		ui._play_cue(cue)
		return "Previewed effect: " + a[0]
	if command == "phase end" or command == "play":
		if ui.menu or ui.choosing_character: return "Error: Continue the expedition before playing a turn."
		if command == "phase end": ui._end_turn()
		else:
			var selected: int = ui.game.Selections.index(ui.game.run.battle.hand,int(a[0]))
			var ordered: Array[int] = []
			for index in a[1].split(","): ordered.append(int(index))
			var choices := []
			if a.size() == 4:
				for token in a[3].split(","): choices.append(null if token == "none" else int(token))
			var pending: Dictionary = ui.game.run.get("pending_selection", {})
			if not pending.is_empty():
				if pending.source_uid != int(a[0]) or pending.route != ordered or pending.target_index != int(a[2]) or choices.slice(0, pending.choices.size()) != pending.choices:
					return "Error: Command differs from the staged known-card selection."
				# Preview against a detached copy before advancing the staged choice.
				var state: Dictionary = ui.game.run.duplicate(true)
				state.pending_selection = {}
				var check: Dictionary = ui.game._simulate_card(state,selected,ordered,int(a[2]),true,choices)
				if not check.ok: return "Error: " + str(check.error)
				for uid in choices.slice(pending.choices.size()):
					var result: Dictionary = ui.game.select_uid(uid)
					if not result.ok: return "Error: " + str(result.error)
			var forecast: Dictionary = ui.game.preview_selection() if not pending.is_empty() else ui.game.preview_card(selected,ordered,int(a[2]),choices)
			if not forecast.ok: return "Error: " + str(forecast.get("error","Invalid card selection."))
			ui.selected_card = selected
			ui.route.assign(ordered)
			ui.target = int(a[2])
			ui._perform(func(): return ui.game.confirm_selection() if not pending.is_empty() else ui.game.play_card(selected,ordered,int(a[2]),choices), "command")
		return "Committed: %s · %s" % [command,ui.game.run.mode]
	var game = ui.game
	if command in ["damage","heal","card draw"]:
		if ui.menu or ui.choosing_character: return "Error: Continue the expedition before presenting a combat effect."
		var outcome := {"text":""}
		ui._clear_selection()
		ui._perform(func():
			var events := []
			var result := _commit_edit(game,command,a,events)
			outcome.text = result
			return {"ok":not result.begins_with("Error:"),"error":result,"presentation":events})
		return outcome.text
	var before: Dictionary = game.run.duplicate(true)
	var result := _commit_edit(game,command,a)
	if result.begins_with("Error:"): return result
	ui.menu = false
	ui.choosing_character = false
	ui._clear_selection()
	ui.notice = ""
	var old_mode := str(before.get("mode",""))
	if command.begins_with("encounter ") or command == "node jump": old_mode = "map"
	ui._spot_action(old_mode, game.run.mode, "", before)
	ui._render()
	return result

func _commit_edit(game, command: String, args: PackedStringArray, events: Array = []) -> String:
	var before: Dictionary = game.run.duplicate(true)
	var profile: Dictionary = game.profile.duplicate(true)
	var result := Edits.edit(game,command,args,events)
	if result.begins_with("Error:"): return result
	if not game._valid_run(game.run) or not game._valid_profile(game.profile) or not game.save():
		game.run = before
		game.profile = profile
		return "Error: Could not validate or save the sandbox edit."
	return result

func _controller(command: String, a: PackedStringArray) -> String:
	var response: Dictionary
	if command == "preview": response = ui.mcp_controller.request("preview",{})
	else:
		var state: Dictionary = ui.mcp_controller.snapshot()
		var params := {"expected_revision":state.revision,"action":a[0],"args":{"index":int(a[1]) if a.size() > 1 else 0}}
		response = ui.mcp_controller.request("act", params)
	if not response.ok: return "Error: " + str(response.error.message)
	if command == "preview":
		return JSON.stringify(response.result) if response.result.get("ok", false) else "Error: " + str(response.result.get("error", "Invalid preview."))
	return "Activated %s · %s%s" % [a[0],response.state.ui.screen," · " + str(ui.notice) if not ui.notice.is_empty() else ""]

func _inspect(section: String) -> String:
	var run: Dictionary = ui.game.run
	var b: Dictionary = run.get("battle", {})
	match section:
		"screen": return str(ui.mcp_controller.snapshot().ui.screen)
		"selection": return JSON.stringify(ui.mcp_controller.snapshot().ui.selection)
		"piles":
			var piles := {"deck":run.get("deck",[])}
			for zone in Game.COMBAT_ZONES: piles[zone] = b.get(zone,[])
			return JSON.stringify(piles,"\t")
		"organs": return JSON.stringify({"organs":ui.game.character().organs,"strain":b.get("strain",[]),"edges":b.get("edges",[]),"severed":b.get("severed",[])}, "\t")
		"battle": return JSON.stringify(b,"\t")
		"run": return JSON.stringify(ui.mcp_controller.snapshot().run,"\t")
		"powerups": return JSON.stringify(run.get("powerups",[]))
		"effects": return JSON.stringify({"effects":ui.last_feedback,"audio":hull.trace},"\t")
		"scenario": return "%s\n%d steps:\n%s" % [replay_status,_sequence.size(),"\n".join(_sequence)]
	return ""

func _scenario(op: String, a: PackedStringArray) -> String:
	match op:
		"wait": return "Listening pause: %s seconds." % a[0]
		"checkpoint":
			_checkpoint_here()
			return replay_status
		"restore":
			if not _restore_checkpoint(): return "Error: Could not save restored checkpoint."
			_fresh_branch = true
			return "Restored checkpoint. Replay keeps the recording; a new command starts a branch."
		"stop":
			_generation += 1
			replaying = false
			replay_status = "Replay stopped."
			return replay_status
		"replay":
			if _sequence.is_empty(): return "Error: No recorded steps. Checkpoint, then play a turn or enter a command."
			if not _restore_checkpoint(): return "Error: Could not save restored checkpoint."
			_generation += 1
			replaying = true
			_fresh_branch = false
			replay_status = "Replaying %d steps." % _sequence.size()
			_replay_step(_generation, 0)
			return replay_status
		"list":
			return "Scenarios: %s\nComparisons: %s\nFolder: %s" % [", ".join(Files.names(_files,false)),", ".join(Files.names(_files,true)),_files]
		"save","export":
			var bundle := {"format":"astral-wake/scenario-v1","checkpoint":_checkpoint,"sequence":_sequence}
			if op == "export": bundle.preset = hull.preset_snapshot()
			return Files.write(_files,a[0],op == "export",bundle)
		"load","import":
			var bundle := Files.load_file(_files,a[0],op == "import",ui.game)
			if bundle.has("error"): return "Error: " + bundle.error
			var old_preset: Dictionary = hull.preset_snapshot() if op == "import" else {}
			if op == "import" and not hull.apply_preset(bundle.preset): return "Error: Incompatible preset; original mix retained."
			var old_checkpoint := _checkpoint
			var old_history := _checkpoint_history
			_checkpoint = bundle.checkpoint
			_checkpoint_history = []
			if not _restore_checkpoint():
				_checkpoint = old_checkpoint
				_checkpoint_history = old_history
				if op == "import": hull.apply_preset(old_preset)
				return "Error: Could not save restored scenario."
			_sequence = bundle.sequence
			_fresh_branch = true
			replay_status = "Loaded %s · %d steps." % [a[0],_sequence.size()]
			return replay_status
	return "Error: Unknown scenario command."

func _replay_step(generation: int, index: int, waited := 0) -> void:
	if not active or generation != _generation or not replaying: return
	if ui.presentation_busy():
		if waited >= 300:
			replay_status = "Error: Timed out waiting for presentation."
			replaying = false
			return
		ui.get_tree().create_timer(0.1).timeout.connect(_replay_step.bind(generation,index,waited + 1))
		return
	if index >= _sequence.size():
		replay_status = "Replayed %d steps." % index
		replaying = false
		return
	var result := _execute(_sequence[index], true)
	if result.begins_with("Error:"):
		replay_status = "Error: Step %d (%s): %s" % [index+1,_sequence[index],result.trim_prefix("Error: ")]
		replaying = false
		return
	# Leave room for the visual/audio cue and the normal scene's deferred redraw.
	var interval := 0.9 if str(_sequence[index]).begins_with("effect ") else 0.12
	if str(_sequence[index]).begins_with("scenario wait "): interval = float(str(_sequence[index]).get_slice(" ",2))
	ui.get_tree().create_timer(interval).timeout.connect(_replay_step.bind(generation,index + 1))
