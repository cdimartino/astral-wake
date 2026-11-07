extends RefCounted

# A finite semantic vocabulary; only callbacks built by the visible controller
# are executable. No network-provided property or method is ever evaluated.
const LABELS := {
	"?":"open_help", "Settings":"open_settings", "Menu":"open_menu",
	"New expedition":"new_expedition", "Run history":"open_history", "Discoveries":"open_discoveries",
	"Continue expedition  →":"continue_expedition", "Back":"back", "Begin →":"begin_expedition",
	"Keep expedition":"close_overlay", "Replace and begin":"confirm_replace",
	"Console view":"toggle_anatomy", "Anatomy view":"toggle_anatomy",
	"Confirm [Space]":"confirm", "Undo":"undo_route", "Cancel":"cancel_selection", "End turn [E]":"end_turn",
	"Take discovery":"take_discovery", "Skip reward →":"skip_reward",
	"Leave the signal behind →":"leave_location", "Return to the chart →":"leave_location",
	"Repair +30 hull":"repair", "Choose an upgrade":"choose_upgrade", "Leave without resting":"leave_location",
	"Remove":"modify_card", "Upgrade":"modify_card", "Cancel selection":"cancel_modify",
	"← Previous":"previous_page", "Next →":"next_page", "Cross the threshold →":"continue_region",
	"Return to title":"return_to_title", "Close  [Esc]":"close_overlay", "Resume expedition":"close_overlay",
	"How to play":"open_help", "Save and return to title":"save_and_title",
	"Abandon expedition…":"request_abandon", "Keep sailing":"close_overlay", "Abandon and record defeat":"confirm_abandon"
}
var main
var revision := 0
var fingerprint := ""
var bindings: Dictionary = {}

func _init(owner):
	main = owner

func _command(button: Button) -> String:
	var n := str(button.name)
	if n in ["DrawPile", "DiscardPile", "ExhaustedPile", "InstalledPile"]: return "inspect_pile"
	if n == "LastCommand": return "inspect_last_command"
	if button.text == "Choose cards [Space]": return "confirm"
	if button.text == "Choose evolution": return "modify_card"
	if button.text == "Cancel · back to deck chooser": return "close_overlay"
	if button.text in ["Cancel · spend nothing [Esc]", "Cancel  [Esc]"]: return "cancel_known_selection"
	if button.text.begins_with("Confirm · spend "): return "confirm_known_selection"
	if button.text.begins_with("UID ") or button.text == "None (authored optional choice)": return "choose_known_card"
	if is_instance_valid(main.overlay) and main.overlay.get_meta("mcp_title", "").begins_with("Choose one evolution") and button.text.begins_with("Confirm "): return "choose_evolution"
	if button.text.begins_with("Retry seed · "): return "retry_expedition"
	if button.text == "Travel here →": return "choose_node"
	for pair in [["CharacterChoice", "select_character"], ["CharacterDetails", "character_details"], ["Destination", "choose_node"], ["Organ", "select_organ"], ["Hand", "select_card"], ["EnemyTarget", "select_target"]]:
		if n.begins_with(pair[0]) and n.trim_prefix(pair[0]).is_valid_int(): return pair[1]
	if button.text.begins_with("Deck ·"): return "open_deck"
	if button.text.begins_with("Buy ·"): return "buy"
	if button.text == "Details": return "character_details"
	if LABELS.has(button.text): return LABELS[button.text]
	if main.game.run.get("mode", "") == "event" and not is_instance_valid(main.overlay): return "event_choice"
	return ""

func snapshot() -> Dictionary:
	bindings.clear()
	var legal: Array = []
	var texts: Array = []
	var root = main.overlay if is_instance_valid(main.overlay) else main.page
	var hidden_pile: bool = root.get_meta("mcp_title", "") == "Draw pile"
	var busy: bool = main.presentation_busy() or is_instance_valid(main.opening_film)
	for node in root.find_children("*", "", true, false):
		if node is Label and node.is_visible_in_tree() and not _private(node) and not hidden_pile: texts.append(node.text)
		if not node is Button or node is CheckBox or not node.is_visible_in_tree(): continue
		var command := _command(node)
		if hidden_pile and command != "close_overlay": continue
		if command.is_empty(): continue
		if not bindings.has(command): bindings[command] = []
		bindings[command].append(node)
	if not busy:
		for command in bindings:
			var options: Array = []
			for i in range(bindings[command].size()):
				var button: Button = bindings[command][i]
				if not button.disabled: options.append({"index":i, "label":button.text, "description":button.tooltip_text, "control":str(button.name)})
			if not options.is_empty(): legal.append({"action":command, "args":{"index":{"type":"integer", "options":options}}, "description":"Activate the corresponding visible " + command + " control. index defaults to 0."})
		if is_instance_valid(main.overlay) and main.overlay.get_meta("mcp_title", "") == "Settings":
			legal.append({"action":"set_setting", "args":{"key":{"options":["reduced_motion", "fullscreen", "volume", "music_volume", "combat_volume", "interface_volume"]}, "value":{"description":"boolean for motion/fullscreen; finite number 0..1 for volume"}}})
	var state := {"busy":busy, "ui":{"screen":"character" if main.choosing_character else "title" if main.menu else str(main.game.run.get("mode", "title")), "overlay":root.get_meta("mcp_title", "") if root == main.overlay else "", "selection":{"card":main.selected_card, "route":main.route.duplicate(), "target":main.target, "character":main.selected_character, "modify_page":main.modify_page, "anatomy_view":main.anatomy_view}, "notice":main.notice, "text":texts}, "run":_public_run(), "profile":_public_profile(), "legal_actions":legal}
	state = _blind(state)
	var encoded := JSON.stringify(state)
	if encoded != fingerprint:
		revision += 1
		fingerprint = encoded
	state["revision"] = revision
	return state

func error(code: String, message: String) -> Dictionary:
	return {"ok":false, "error":{"code":code, "message":message}, "state":snapshot()}

func request(method: String, params: Dictionary) -> Dictionary:
	var state := snapshot()
	if method == "get_state":
		if not params.is_empty(): return error("invalid_args", "get_state takes no arguments")
		return {"ok":true, "state":state, "result":{}}
	if method == "preview":
		if not params.is_empty(): return error("invalid_args", "preview uses the live selection")
		if state.ui.screen != "combat" or main.selected_card < 0: return error("unavailable", "Select a combat card first")
		var result: Dictionary = main.game.preview_selection() if main.game.selection_pending() else main.game.preview_card(main.selected_card, main.route, main.target)
		return {"ok":true, "state":state, "result":_public_preview(result)}
	if method != "act": return error("invalid_request", "Unknown method")
	if params.size() != 3 or not params.get("action") is String or not params.get("args") is Dictionary or not _integer(params.get("expected_revision")):
		return error("invalid_args", "act requires action, args and integer expected_revision")
	if params.expected_revision != revision: return error("stale_revision", "Read current state before acting")
	if state.busy: return error("busy", "Presentation is in progress")
	var action: String = params.action
	var args: Dictionary = params.args
	if action == "set_setting":
		if state.ui.overlay != "Settings": return error("unavailable", "Open settings first")
		if args.size() != 2 or not args.get("key") is String: return error("invalid_args", "Expected key and value")
		var key: String = args.key
		var value = args.get("value")
		if key in ["reduced_motion", "fullscreen"]:
			if not value is bool: return error("invalid_args", "Expected boolean")
		elif key in ["volume", "music_volume", "combat_volume", "interface_volume"]:
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 1: return error("invalid_args", "Expected finite volume 0..1")
		else: return error("invalid_args", "Unknown setting")
		main.game.set_settings({key:value})
		main._apply_settings()
		main._open_settings()
	else:
		if not bindings.has(action): return error("unknown_action", "Action is not visible")
		if args.size() > 1 or (args.size() == 1 and not args.has("index")) or not _integer(args.get("index", 0)): return error("invalid_args", "Expected optional integer index")
		var index := int(args.get("index", 0))
		if index < 0 or index >= bindings[action].size(): return error("invalid_args", "Index is outside visible options")
		var button: Button = bindings[action][index]
		if button.disabled: return error("unavailable", "Control is disabled")
		button.pressed.emit()
	return {"ok":true, "state":snapshot(), "result":{}}

func _integer(value) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992.0)

func _private(node: Node) -> bool:
	while node != null:
		if node.get_meta("mcp_private", false): return true
		node = node.get_parent()
	return false

# Explicit boundaries: never export save/replay internals or simulation output.
func _fields(source: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key in keys:
		if source.has(key): result[key] = source[key]
	return result.duplicate(true)

func _public_run() -> Dictionary:
	var run: Dictionary = main.game.run
	var result := _fields(run, ["character", "region", "layer", "mode", "hull", "max_hull", "salvage", "deck", "powerups", "current_node", "visited", "log", "turns", "elapsed_seconds", "tutorial_step", "modify_return", "modify_kind", "finished", "battles", "reward_generation", "rare_offer_misses", "seeded", "pool_tier", "content_pool_revision"])
	if run.is_empty(): return result
	result.map = []
	for layer in run.get("map", []):
		var visible: Array = []
		for node in layer: visible.append(_fields(node, ["id", "layer", "column", "type", "edges"]))
		result.map.append(visible)
	var battle: Dictionary = run.get("battle", {})
	result.battle = _fields(battle, ["enemies", "hand", "discard", "exhausted", "installed", "strain", "capacity", "edges", "severed", "ward", "turn", "last_route", "mark", "first_play", "emergency_used", "kind", "command_points", "max_command_points", "trace", "last_payload", "resonance", "last_command_kind", "last_command", "engine_routes", "engine_counters"])
	if not battle.is_empty(): result.battle.draw_count = battle.get("draw", []).size()
	# Offers are public only while actually in that room.
	if run.get("mode") == "reward": result.reward = run.get("reward", {}).duplicate(true)
	if run.get("mode") == "shop" or run.get("modify_return") == "shop": result.shop = run.get("shop", {}).duplicate(true)
	if run.get("mode") == "event": result.event_id = run.get("event_id", "")
	result.pending_selection = _fields(run.get("pending_selection", {}), ["source_uid", "route", "target_index", "target_guard", "definition", "choices"])
	return result

func _public_profile() -> Dictionary:
	var result := _fields(main.game.profile, ["version", "unlocks"])
	result.settings = _fields(main.game.profile.get("settings", {}), ["reduced_motion", "fullscreen", "volume", "music_volume", "combat_volume", "interface_volume", "mcp_enabled", "mcp_port"])
	result.history = []
	for record in main.game.profile.get("history", []):
		result.history.append(_fields(record, ["character", "won", "region", "turns", "seeded", "battles", "seconds", "date", "deck_size", "reward_generation", "content_pool_revision"]))
	return result

func _public_preview(result: Dictionary) -> Dictionary:
	# In particular omit next, presentation (including future draw identities),
	# events and summary. Return only the deterministic, player-facing forecast.
	return _blind(_fields(result, ["ok", "error", "damage", "heal", "disrupt", "cost", "attack_reduction", "command_points", "strain", "resource_preview", "trace", "resonance", "route_steps", "ward", "conditional_damage", "command_cooling", "selection_required"]))

# Scrub replay codes repeated in public UI labels/history, not arbitrary keys.
func _blind(value):
	if value is Dictionary:
		var clean := {}
		for key in value:
			clean[key] = _blind(value[key])
		return clean
	if value is Array:
		var clean: Array = []
		for item in value: clean.append(_blind(item))
		return clean
	if value is String:
		var text: String = value
		# Public labels/history can repeat a replay code; suppress it there too.
		var seeds: Array = [main.game.run.get("seed", "")]
		for record in main.game.profile.get("history", []): seeds.append(record.get("seed", ""))
		for seed_value in seeds:
			if seed_value is String and not seed_value.is_empty(): text = text.replace(seed_value, "[hidden]")
		# Legacy numeric seeds must not erase unrelated damage/count digits.
		var pattern := RegEx.new()
		pattern.compile("(?i)\\bseed\\s*[·:]?\\s+[a-z0-9]+\\b")
		text = pattern.sub(text, "Seed [hidden]", true)
		return text
	return value
