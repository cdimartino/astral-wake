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
	var busy: bool = main.presentation_busy() or is_instance_valid(main.opening_film)
	for node in root.find_children("*", "", true, false):
		if node is Label and node.is_visible_in_tree() and not _private(node): texts.append(node.text)
		if not node is Button or node is CheckBox or not node.is_visible_in_tree(): continue
		var command := _command(node)
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
	var state := {"busy":busy, "ui":{"screen":"character" if main.choosing_character else "title" if main.menu else str(main.game.run.get("mode", "title")), "overlay":root.get_meta("mcp_title", "") if root == main.overlay else "", "selection":{"card":main.selected_card, "route":main.route.duplicate(), "target":main.target, "character":main.selected_character, "modify_page":main.modify_page, "anatomy_view":main.anatomy_view}, "notice":main.notice, "text":texts}, "run":main.game.run.duplicate(true), "profile":main.game.profile.duplicate(true), "legal_actions":legal}
	state.profile.get("settings", {}).erase("mcp_token")
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
		return {"ok":true, "state":state, "result":main.game.preview_card(main.selected_card, main.route, main.target)}
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
