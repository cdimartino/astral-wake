extends RefCounted
## Local-only console grammar. Arguments are named types (a trailing ? is optional).
## Columns: argument types, required state, record in a scenario, result/help.
const COMMANDS := {
	"help":["query?", "desk", false, "List commands or search their names, arguments and descriptions."],
	"inspect":["section", "desk", false, "Inspect the screen, selection, resources, battle, piles, powerups, effects or scenario."],
	"run start":["vessel seed", "desk", true, "Start a seeded sandbox expedition; never replace the real expedition."],
	"region jump":["region tier?", "expedition", true, "Place a region at this itinerary tier and generate a fresh chart."],
	"node jump":["node", "expedition", true, "Travel to a chart node, including unreachable nodes."],
	"room open":["room event?", "expedition", true, "Open a shop, event, recovery room or ordinary encounter reward."],
	"encounter battle":["regular", "expedition", true, "Start a regular encounter with a catalog enemy."],
	"encounter elite":["elite", "expedition", true, "Start an elite encounter with its normal rewards."],
	"encounter boss":["boss", "expedition", true, "Reveal a guardian and its authored attendants."],
	"player set":["resource number", "expedition", true, "Set hull, salvage, ward, command points or a vessel-specific meter."],
	"organ strain":["organ number", "combat", true, "Set the strain on one organ (0 to current capacity)."],
	"organ link":["organ organ connection", "combat", true, "Connect, cut or mend a conduit between two different organs."],
	"card add":["card zone?", "expedition", true, "Add a new card UID to the deck; in combat also place it in a pile (default: draw)."],
	"card remove":["uid", "expedition", true, "Remove a non-installed deck UID and its combat copy; keep at least five cards."],
	"card move":["uid zone", "combat", true, "Move an existing combat card UID. Use normal play to install cards."],
	"card draw":["count", "combat", true, "Draw up to ten cards with normal reshuffle and hand limits."],
	"powerup give":["powerup", "expedition", true, "Grant a catalog powerup. Start-of-battle bonuses apply next encounter."],
	"powerup remove":["powerup", "expedition", true, "Remove an owned powerup."],
	"foe spawn":["enemy", "combat", true, "Add a scaled enemy with the current turn’s intent (maximum eight)."],
	"foe remove":["foe", "combat", true, "Remove a foe; removing the last foe resolves the encounter."],
	"damage":["actor number", "combat", true, "Apply damage to player or a zero-based foe index using normal defenses."],
	"heal":["actor number", "combat", true, "Repair a player or enemy up to maximum hull."],
	"status":["actor status number", "combat", true, "Set player mark/ward or foe disrupt/redirect."],
	"phase end":["", "combat", true, "End the turn using the ordinary player controller."],
	"resolve":["outcome", "expedition", true, "Resolve a battle win, voyage victory, or voyage defeat."],
	"act":["action option?", "desk", true, "Activate a currently visible ordinary player action by option index."],
	"stage card":["hand_uid", "combat", true, "Select a hand UID using the normal card control."],
	"stage organ":["organ", "combat", true, "Route through an organ using the normal control and its contact sound."],
	"stage target":["foe", "combat", true, "Select a target by zero-based encounter index."],
	"preview":["", "combat", false, "Preview the staged command through the ordinary controller."],
	"play":["hand_uid route foe choices?", "combat", true, "Commit a card by UID through the game's normal play/presentation path; use comma-separated organ indices and optional choice UIDs."],
	"effect":["effect", "combat", true, "Preview a visual effect and its mapped sound without changing combat."],
	"scenario checkpoint":["", "desk", false, "Capture the sandbox and begin a fresh command recording."],
	"scenario restore":["", "desk", false, "Restore the checkpoint; keep the recording available for replay."],
	"scenario replay":["", "desk", false, "Restore the checkpoint and run recorded commands against the current sound bank."],
	"scenario wait":["seconds", "desk", true, "Insert 1–30 seconds of listening time between replay steps."],
	"scenario stop":["", "desk", false, "Stop replay before its next command."],
	"scenario list":["", "desk", false, "List named scenario and shared comparison files."],
	"scenario save":["name", "desk", false, "Save the checkpoint and recording to a named scenario file."],
	"scenario load":["scenario", "desk", false, "Load a named scenario at its checkpoint, preserving the current bank."],
	"scenario export":["name", "desk", false, "Write a shareable JSON comparison with scenario and current sound preset."],
	"scenario import":["comparison", "desk", false, "Restore the scenario and sound preset from a shared comparison."],
	"audio":["audio_args", "desk", false, "Use the Sound Desk command vocabulary; audio help lists mixer operations."],
}
const OPTIONS := {
	"section":["screen","selection","run","battle","piles","organs","powerups","effects","scenario"],
	"tier":["0","1","2"], "room":["shop","event","recovery","reward"],
	"organ":["0","1","2","3","4","5"], "connection":["connect","cut","mend"],
	"zone":["hand","draw","discard","exhausted"], "outcome":["battle","victory","defeat"],
	"effect":["shot","beam","enemy_shot","shield","repair","vent","sever","disrupt","phase","link","route"],
}

static func usage(command: String) -> String:
	var parts := PackedStringArray([command])
	for arg in COMMANDS[command][0].split(" ", false):
		parts.append("[%s]" % arg.trim_suffix("?") if arg.ends_with("?") else "<%s>" % arg)
	return " ".join(parts)

static func find_command(words: PackedStringArray) -> String:
	if words.size() > 1:
		var pair := "%s %s" % [words[0], words[1]]
		if COMMANDS.has(pair): return pair
	return words[0] if not words.is_empty() and COMMANDS.has(words[0]) else ""

static func help(query: String) -> String:
	var lines := PackedStringArray()
	for key in COMMANDS:
		var line := "%s · %s" % [usage(key), COMMANDS[key][3]]
		if query.to_lower() in line.to_lower(): lines.append(line)
	for key in AUDIO:
		var line := ("audio %s %s" % [key,AUDIO[key]]).strip_edges()
		if query.to_lower() in line: lines.append(line)
	return "\n".join(lines) if not lines.is_empty() else "No matching commands."

const AUDIO := {
	"packs":"","bank":"pack","groups":"","cues":"","patches":"","scores":"","voices":"","trace":"",
	"variants":"cue","audition":"cue","bind":"cue variant","group":"group mapping",
	"mix":"scope parameter value","solo":"voice","mute":"voice","stinger":"stinger-or-switch [switch]",
	"ab":"comparison","preset":"operation name","factory":"","undo":"","reload":"[manifest]",
}

static func audio_help() -> String:
	var lines := PackedStringArray()
	for key in AUDIO: lines.append(("audio %s %s" % [key,AUDIO[key]]).strip_edges())
	return "\n".join(lines)

static func audio_error(words: PackedStringArray) -> String:
	if words.is_empty(): return ""
	var op := words[0]
	if not AUDIO.has(op): return "Unknown audio operation. Use audio help."
	var spec: PackedStringArray = AUDIO[op].split(" ",false)
	var args := words.slice(1)
	var minimum := spec.size()
	if minimum > 0 and spec[-1].begins_with("["): minimum -= 1
	if args.size() < minimum or args.size() > spec.size(): return ("Use audio %s %s" % [op, AUDIO[op]]).strip_edges()
	if op == "stinger":
		if (args.size() == 1 and not args[0] in ["on","off"]) or (args.size() == 2 and (args[0] in ["on","off"] or not args[1] in ["on","off"])):
			return "Use audio stinger [ID] on|off."
	return ""

# Track names and custom bank paths can contain spaces. This is a token reader,
# not a shell: quoting never evaluates expressions, paths, or substitutions.
static func tokens(text: String) -> Dictionary:
	var words := PackedStringArray()
	var token := ""
	var quote := ""
	var started := false
	for c in text:
		if quote.is_empty() and c in [" ","\t"]:
			if started: words.append(token)
			token = ""
			started = false
		elif quote.is_empty() and c in ["\"", "'"]:
			quote = c
			started = true
		elif c == quote: quote = ""
		else:
			token += c
			started = true
	if started: words.append(token)
	return {"words":words, "closed":quote.is_empty(), "boundary":not started}

static func _quoted(token: String) -> String:
	return "\"%s\"" % token if token.contains(" ") or token.contains("\t") else token

static func complete_audio(text: String, hull) -> PackedStringArray:
	var parsed := tokens(text)
	var words: PackedStringArray = parsed.words
	var prefix := ""
	if not parsed.boundary and not words.is_empty():
		prefix = words[-1]
		words = words.slice(0,-1)
	var values := PackedStringArray()
	if words.size() == 1:
		values = PackedStringArray(AUDIO.keys())
		values.append("help")
	elif AUDIO.has(words[1]):
		var args: PackedStringArray = AUDIO[words[1]].split(" ",false)
		if words.size()-2 < args.size():
			match args[words.size()-2]:
				"pack":
					values = hull.options("packs")
					if not "factory" in values: values.append("factory")
				"stinger-or-switch":
					values = PackedStringArray(["on","off"])
					for id in hull.options("scores"):
						if id.begins_with("guardian_") or id.begins_with("clear_") or id in ["victory","defeat"]: values.append(id)
				"[switch]":
					if not words[2] in ["on","off"]: values = PackedStringArray(["on","off"])
				"cue","group": values = hull.options("groups" if args[words.size()-2] == "group" else "cues")
				"variant": values = PackedStringArray(hull.bank.get("cues",{}).get(words[2],{}).get("variants",[]))
				"scope","voice":
					values = hull.options("cues")
					values.append_array(hull.options("groups"))
					if words[1] == "mix": values.append("all")
					if words[1] == "solo": values.append("off")
					if words[1] in ["solo","mute"]:
						for score in hull.bank.get("scores",{}).values():
							for event in score.get("events",[]):
								if event.has("track") and not values.has(str(event.track)): values.append(str(event.track))
				"parameter": values = PackedStringArray(["gain_db","pitch","pitch_range","pan","variation"])
				"mapping": values = PackedStringArray(["factory","alternate"])
				"switch": values = PackedStringArray(["on","off"])
				"comparison": values = PackedStringArray(["store","swap","silence"])
				"operation": values = PackedStringArray(["save","load","export","import"])
				"name":
					values = PackedStringArray(["factory","alternate"])
					if DirAccess.dir_exists_absolute(hull.storage):
						for filename in DirAccess.get_files_at(hull.storage):
							if filename.ends_with(".json") and filename != "selected.json": values.append(filename.get_basename())
	var result := PackedStringArray()
	var prepared := PackedStringArray()
	for word in words: prepared.append(_quoted(word))
	for value in values:
		if value.begins_with(prefix): result.append(" ".join(prepared) + " " + _quoted(value))
	result.sort()
	return result
