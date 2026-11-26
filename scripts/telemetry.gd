extends RefCounted
## What Astral Wake tells Glitchless about a voyage.
##
## It only reads the game, before and after an action the rules accepted. Send
## authored content IDs and game numbers, never run.seed or run.id (the ID
## contains the seed), and nothing the player typed. The Sound Desk sandbox is
## not play, so nothing in it is sent.

const SERVICE := "astral-wake"
const INTAKE := "https://api.glitchless.gg"
## Public and write-only: safe to ship in the game.
const CLIENT_TOKEN := "gl_pub_hUscD4XBqaj5RBStT5CoZWR2"

var main
var sink: Object
var _run_id := ""
var _encounter := ""
var _level := ""

## A test passes its own recorder; the game uses the Glitchless autoload.
func _init(owner, recorder: Object = null) -> void:
	main = owner
	sink = recorder

func start() -> void:
	if sink == null: sink = main.get_node_or_null("/root/Glitchless")
	if sink == null: return
	# Only ever turn it off here. The SDK keeps the player's choice itself, so a
	# reset or recovered profile must not turn an opted-out player back on.
	if not sharing(): sink.set_enabled(false)
	# "" takes application/config/version, so each release is its own version.
	sink.init(SERVICE, "", "prod", INTAKE, {"client_token": CLIENT_TOKEN})

## The player's "Share performance data" setting, on until they turn it off.
func sharing() -> bool:
	return main.game.profile.get("settings", {}).get("share_performance_data", true) != false

func set_sharing(on: bool) -> void:
	main.game.set_settings({"share_performance_data": on})
	if sink != null: sink.set_enabled(on)

## The parts of the expedition an action can change, copied before it runs.
func snapshot() -> Dictionary:
	if sink == null or main.hull_admin.active: return {}
	return main.game.run.duplicate(true)

## Matches the open level, screen and gauges to what is on screen.
func sync() -> void:
	if sink == null: return
	if main.hull_admin.active:
		_leave_level()
		sink.set_zone("sound_desk")
		return
	var run: Dictionary = main.game.run
	var playing: bool = not main.menu and not main.choosing_character and not run.is_empty() and not run.get("finished", false)
	if playing: _attach(run)
	var screen := "ship_select" if main.choosing_character else "title" if main.menu or run.is_empty() else str(run.mode)
	# Before level_start, so a battle's events and frames carry its own screen.
	sink.set_zone(screen)
	var encounter := ""
	if playing and run.mode == "combat": encounter = "%s|%s" % [run.id, run.current_node]
	if encounter != _encounter:
		_leave_level()
		if not encounter.is_empty(): _enter_level(encounter, run)
	var battle: Dictionary = run.get("battle", {}) if playing and run.mode == "combat" else {}
	sink.set_context({"deck_size": run.get("deck", []).size(), "hand_size": battle.get("hand", []).size(), "enemies": battle.get("enemies", []).size()})

## Called once per accepted action, with the state from before it.
func observe(before: Dictionary, action_kind: String, card: Dictionary, played_route: Array) -> void:
	if sink == null or main.hull_admin.active: return
	var run: Dictionary = main.game.run
	if run.is_empty(): return
	if run.id != before.get("id", ""):
		if not before.is_empty() and not before.get("finished", false):
			_leave_level()
			_run_end(before, "replaced")
		_attach(run, false)
		sink.track("run_start", _run_facts(run))
		return
	_attach(run)
	match str(before.mode):
		"map":
			if run.current_node != before.current_node: _stop_chosen(run)
		"combat": _combat(before, run, action_kind, card, played_route)
		"reward": _reward(before, run)
		"event": _event(before, run)
		"shop": _exchange(before, run)
		"recovery": _recovery(before, run)
		"modify": _modified(before, run)
	if run.get("finished", false) and not before.get("finished", false):
		var outcome := "victory" if run.mode == "victory" else "defeat" if int(run.hull) <= 0 else "abandoned"
		_run_end(run, outcome)

## Names the voyage's properties and run group. A voyage seen first in sync()
## was started in an earlier launch or before returning from the sandbox.
func _attach(run: Dictionary, resumed: bool = true) -> void:
	if run.id == _run_id or run.get("finished", false): return
	_run_id = run.id
	var mcp: bool = main.game.profile.get("settings", {}).get("mcp_enabled", false)
	sink.set_properties({"ship": str(run.get("character", "cartographer")), "ascension": int(run.get("ascension_rank", 0)), "practice": bool(run.get("seeded", false)), "mcp_enabled": mcp})
	# Anonymous mode gives each launch a new run ID, so nothing is saved for it.
	sink.set_group("run")
	if resumed: sink.track("run_resume", _run_facts(run))

func _enter_level(encounter: String, run: Dictionary) -> void:
	_encounter = encounter
	_level = "%s.%s" % [_area(run), run.battle.kind]
	var facts := _run_facts(run)
	facts.merge({"depth": int(run.layer) + 1, "enemies": _ids(run.battle.enemies), "turn": int(run.battle.turn), "hull_band": _hull_band(run)})
	sink.level_start(_level, facts)

func _leave_level() -> void:
	if _encounter.is_empty(): return
	sink.level_abandon(_level)
	_encounter = ""
	_level = ""

func _combat(before: Dictionary, run: Dictionary, action_kind: String, card: Dictionary, played_route: Array) -> void:
	var ship := str(run.get("character", "cartographer"))
	if action_kind == "command" and card.has("id"):
		sink.count("command", {"card": str(card.id), "ship": ship})
		var organs: Array = main.game.character(ship).organs
		for index in played_route:
			sink.count("organ_routed", {"organ": str(organs[index].id), "ship": ship})
	var lost := maxi(0, int(before.hull) - int(run.hull))
	if action_kind == "enemy_phase":
		sink.count("enemy_phase", {"ship": ship, "hull_lost": lost})
	var dead := int(run.hull) <= 0
	# A voyage abandoned mid-fight leaves enemies standing and hull above zero.
	var cleared: bool = run.mode in ["reward", "victory"]
	if not dead and not cleared: return
	var battle: Dictionary = before.battle
	var enemies := _ids(battle.enemies)
	if not _level.is_empty():
		if dead:
			var cause: String = enemies[0] if not enemies.is_empty() else "unknown"
			sink.death(0.0, 0.0, cause)
			sink.level_fail(_level, cause)
		else:
			sink.level_complete(_level)
		_encounter = ""
		_level = ""
	var facts := _run_facts(before)
	facts.merge({"won": not dead, "kind": str(battle.kind), "area": _area(before), "enemies": enemies, "turns": int(run.battle.get("turn", battle.turn)), "hull_lost": lost})
	# Twelve attributes is the limit per event.
	facts.erase("deck_size")
	sink.track("battle_end", facts)

func _stop_chosen(run: Dictionary) -> void:
	for layer in run.map:
		for node in layer:
			if node.id == run.current_node:
				sink.track("stop_chosen", {"type": str(node.type), "area": _area(run), "stage": int(run.region) + 1, "depth": int(node.layer) + 1, "hull_band": _hull_band(run)})
				return

func _reward(before: Dictionary, run: Dictionary) -> void:
	if run.mode == "reward": return
	var offered: Array = []
	for choice in before.reward.get("choices", []): offered.append(str(choice.id))
	var choice := "skip"
	var kind := "skip"
	if run.deck.size() > before.deck.size():
		choice = str(run.deck.back().id)
		kind = "card"
	for id in run.powerups:
		if not id in before.powerups:
			choice = str(id)
			kind = "powerup"
	sink.track("reward_choice", {"picked": kind != "skip", "choice": choice, "kind": kind, "offered": offered, "ship": str(run.character), "stage": int(before.region) + 1})

func _event(before: Dictionary, run: Dictionary) -> void:
	for definition in main.game.catalog.events:
		if definition.id != before.event_id: continue
		for index in range(definition.choices.size()):
			var line: String = str(definition.name) + ": " + str(definition.choices[index].label)
			# The log is capped, so compare counts of this line rather than its length.
			if run.log.count(line) > before.log.count(line):
				sink.track("event_choice", {"event": str(definition.id), "effect": str(definition.choices[index].effect), "option": index + 1, "ship": str(run.character)})
				return

## Salvage spent. Not named "purchase": that name means real money to Glitchless.
func _exchange(before: Dictionary, run: Dictionary) -> void:
	var old_items: Array = before.shop.get("items", [])
	var items: Array = run.shop.get("items", [])
	for index in range(mini(old_items.size(), items.size())):
		if items[index].sold and not old_items[index].sold: _track_exchange(items[index], run)

func _track_exchange(item: Dictionary, run: Dictionary) -> void:
	var id: String = str(item.id) if not str(item.id).is_empty() else str(item.kind)
	sink.track("salvage_exchange", {"kind": str(item.kind), "item": id, "salvage_cost": int(item.cost), "ship": str(run.character), "stage": int(run.region) + 1})

func _recovery(before: Dictionary, run: Dictionary) -> void:
	if run.mode == "recovery": return
	# "none" is leaving, or repairing a hull that was already full: nothing gained.
	var choice := "upgrade" if run.mode == "modify" else "repair" if int(run.hull) > int(before.hull) else "none"
	sink.track("recovery_choice", {"choice": choice, "hull_band": _hull_band(before), "ship": str(run.character)})

func _modified(before: Dictionary, run: Dictionary) -> void:
	if run.mode == "modify": return
	var remaining := {}
	for instance in run.deck: remaining[int(instance.uid)] = instance
	for instance in before.deck:
		var now: Dictionary = remaining.get(int(instance.uid), {})
		if now.is_empty():
			sink.track("card_removed", {"card": str(instance.id), "ship": str(run.character)})
		elif int(now.level) > int(instance.level):
			sink.track("card_evolved", {"card": str(instance.id), "evolution": str(now.get("evolution", "")), "ship": str(run.character)})
	if before.modify_return == "shop": _exchange(before, run)

func _run_end(run: Dictionary, outcome: String) -> void:
	var cards: Array = []
	for instance in run.deck: cards.append(str(instance.id))
	var facts := _run_facts(run)
	facts.merge({"won": outcome == "victory", "outcome": outcome, "battles": int(run.battles), "turns": int(run.turns), "duration_s": int(run.get("elapsed_seconds", 0)), "deck": cards, "powerups": run.powerups.duplicate()})
	# Twelve attributes is the limit per event.
	facts.erase("deck_size")
	sink.track("run_end", facts)
	sink.set_group("run", null)

func _run_facts(run: Dictionary) -> Dictionary:
	return {"ship": str(run.get("character", "cartographer")), "ascension": int(run.get("ascension_rank", 0)), "practice": bool(run.get("seeded", false)), "stage": int(run.region) + 1, "deck_size": run.deck.size()}

func _area(run: Dictionary) -> String:
	var tier := int(run.region)
	return str(main.game.catalog.regions[int(run.get("route_regions", [0, 1, 2])[tier])].id)

func _hull_band(run: Dictionary) -> String:
	var percent := 100 * int(run.hull) / maxi(1, int(run.max_hull))
	return "0-24" if percent < 25 else "25-49" if percent < 50 else "50-74" if percent < 75 else "75-100"

func _ids(enemies: Array) -> Array:
	var ids: Array = []
	for enemy in enemies: ids.append(str(enemy.id))
	return ids
