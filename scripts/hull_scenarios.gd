extends RefCounted
## JSON only. Never deserialize objects, absolute paths, profile settings, or
## arbitrary UI properties. Shared recordings accept only replayable commands.
const Registry = preload("res://scripts/hull_admin_registry.gd")
const LIMIT := 2 * 1024 * 1024
const BUILTIN := "res://data"

static func safe_name(value: String) -> bool:
	if value.is_empty() or value.length() > 64: return false
	for char_ in value:
		if not char_ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return false
	return true

static func names(root: String, comparison: bool) -> PackedStringArray:
	var result := PackedStringArray()
	var suffix := ".comparison.json" if comparison else ".scenario.json"
	for path in [root, BUILTIN]:
		if not DirAccess.dir_exists_absolute(path): continue
		for filename in DirAccess.get_files_at(path):
			var name := filename.trim_suffix(suffix)
			if filename.ends_with(suffix) and safe_name(name) and not name in result: result.append(name)
	result.sort()
	return result

static func write(root: String, name: String, comparison: bool, data: Dictionary) -> String:
	if not safe_name(name) or DirAccess.make_dir_recursive_absolute(root) != OK: return "Error: Invalid scenario folder or name."
	var path := root.path_join(name + (".comparison.json" if comparison else ".scenario.json"))
	var text := JSON.stringify(data,"\t")
	if text.to_utf8_buffer().size() > LIMIT: return "Error: Scenario exceeds 2 MiB."
	var f := FileAccess.open(path + ".pending",FileAccess.WRITE)
	if f == null: return "Error: Cannot write scenario."
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK or DirAccess.rename_absolute(path + ".pending",path) != OK: return "Error: Cannot finish scenario write."
	return "Saved " + path

static func clean_session(path: String) -> void:
	for file in ["save.json","save.backup.json","save.pending.json","save.backup.pending.json"]:
		if FileAccess.file_exists(path.path_join(file)): DirAccess.remove_absolute(path.path_join(file))
	if DirAccess.dir_exists_absolute(path): DirAccess.remove_absolute(path)

static func load_file(root: String, name: String, comparison: bool, game) -> Dictionary:
	if not safe_name(name): return {"error":"Invalid scenario name."}
	var filename := name + (".comparison.json" if comparison else ".scenario.json")
	var path := root.path_join(filename)
	if not FileAccess.file_exists(path): path = BUILTIN.path_join(filename)
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null or f.get_length() > LIMIT: return {"error":"Missing or oversized file: " + filename}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK: return {"error":"Invalid JSON at line %d." % json.get_error_line()}
	var data = json.data
	if not data is Dictionary or data.get("format") != "astral-wake/scenario-v1" or not data.get("checkpoint") is Dictionary or not data.get("sequence") is Array or data.sequence.size() > 256:
		return {"error":"Unsupported scenario format."}
	if comparison and not data.get("preset") is Dictionary: return {"error":"Shared comparison is missing its preset."}
	var point: Dictionary = data.checkpoint
	if point.size() != 3 or not point.get("run") is Dictionary or not point.get("ui") is Dictionary or not _int_in(point.get("unlocks"),0,3):
		return {"error":"Invalid checkpoint."}
	if not _safe_run(game,point.run) or not _valid_ui(game,point.run,point.ui):
		return {"error":"Invalid expedition or UI selection in checkpoint."}
	for line in data.sequence:
		if not line is String or line.length() > 1024 or "\n" in line: return {"error":"Invalid recorded command."}
		var words: PackedStringArray = line.split(" ",false)
		var command := Registry.find_command(words)
		if command.is_empty() or not Registry.COMMANDS[command][2]: return {"error":"Command cannot be replayed: " + str(line)}
	data.checkpoint = game._restore_integers(point)
	return data

static func _int_in(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(value) == value and value >= low and value <= high

static func _safe_run(game, run: Dictionary) -> bool:
	if run.is_empty(): return true
	if not game._valid_run(run): return false
	# The ordinary save validator intentionally accepts some loose legacy map
	# fields; a shared file must also be safe for rendering and node traversal.
	var events := {}
	for event in game.catalog.events: events[event.id] = true
	var ids := {}
	for layer in run.map:
		for i in layer.size():
			var node = layer[i]
			if node.column != i or ids.has(node.id) or node.id.is_empty(): return false
			if node.type in ["battle","boss","elite"] and (node.enemy_ids.is_empty() or node.enemy_ids.size() > 5): return false
			if node.type == "event" and not events.has(node.get("event_id")): return false
			ids[node.id] = node.layer
	for layer in run.map:
		for node in layer:
			for edge in node.edges:
				if not edge is String or ids.get(edge,-1) != node.layer + 1: return false
	if run.current_node != "" and ids.get(run.current_node,-1) != run.layer: return false
	if run.mode == "event" and not events.has(run.event_id): return false
	if run.finished != (run.mode in ["victory","defeat"]): return false
	for item in run.log:
		if not item is String: return false
	for card in run.deck:
		if not _int_in(card.uid,1,2147483646) or card.uid >= run.next_uid: return false
	if not run.battle.is_empty():
		var b: Dictionary = run.battle
		if run.mode == "combat":
			for foe in b.enemies:
				if not _int_in(foe.hp,1,99999) or not _int_in(foe.max_hp,foe.hp,99999): return false
	return true

static func _valid_ui(game, run: Dictionary, view: Dictionary) -> bool:
	var keys := ["menu","choosing_character","selected_character","expedition_seed","anatomy_view","selected_card","target","route","modify_page"]
	if view.size() != keys.size(): return false
	for key in keys:
		if not view.has(key): return false
	for key in ["menu","choosing_character","anatomy_view"]:
		if not view[key] is bool: return false
	if not view.selected_character is String or game.character(view.selected_character).is_empty() or not view.expedition_seed is String: return false
	if not view.route is Array or view.route.size() > 3 or not _int_in(view.modify_page,0,200): return false
	for i in view.route:
		if not _int_in(i,0,5): return false
	if run.get("mode") == "combat":
		return _int_in(view.selected_card,-1,run.battle.hand.size()-1) and _int_in(view.target,0,run.battle.enemies.size()-1)
	return view.selected_card == -1 and view.target == 0 and view.route.is_empty()
