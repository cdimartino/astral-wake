extends SceneTree
## Drives the real UI through voyages and checks what telemetry would send.
## A recorder stands in for the Glitchless autoload: nothing leaves the machine.
const Telemetry = preload("res://scripts/telemetry.gd")
const SEED := "ZQ7K9M"

class Recorder extends RefCounted:
	var calls: Array = []
	var history: Array = []
	var open_level := ""
	var problems: Array[String] = []
	func _add(entry: Array) -> void:
		calls.append(entry.duplicate(true))
		history.append(entry.duplicate(true))
	func init(a, b, c, d, e) -> void: _add(["init", a, b, c, d, e])
	func set_enabled(on) -> void: _add(["enabled", on])
	func set_properties(props) -> void: _add(["properties", props])
	func set_group(kind, id = "") -> String:
		_add(["group", kind, id])
		return "r_test"
	func set_zone(zone) -> void: _add(["zone", zone])
	func set_context(gauges) -> void: _add(["context", gauges])
	func level_start(id, attrs := {}) -> void:
		if not open_level.is_empty(): problems.append("level_start %s while %s is open" % [id, open_level])
		if attrs.size() > 12: problems.append("level_start has %d attributes" % attrs.size())
		open_level = id
		_add(["level_start", id, attrs])
	func _close(kind: String, id) -> void:
		if open_level != id: problems.append("%s %s while '%s' is open" % [kind, id, open_level])
		open_level = ""
		_add([kind, id])
	func level_complete(id) -> void: _close("level_complete", id)
	func level_fail(id, _cause) -> void: _close("level_fail", id)
	func level_abandon(id) -> void: _close("level_abandon", id)
	func death(_x, _y, cause) -> void: _add(["death", cause])
	func track(event, attrs := {}) -> void:
		if attrs.size() > 12: problems.append("%s has %d attributes" % [event, attrs.size()])
		if event == "purchase" or attrs.has("currency"): problems.append(event + " would count as real money")
		_add(["track", event, attrs])
	func count(event, attrs := {}) -> void: _add(["count", event, attrs])
	func named(event: String) -> Array:
		return calls.filter(func(c): return c[0] == "track" and c[1] == event)
	func of(kind: String) -> Array:
		return calls.filter(func(c): return c[0] == kind)

var ui
var recorder := Recorder.new()
var failures := 0
var checks := 0
var secrets: Array[String] = []

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	# Always a fresh folder: an expedition another test left would count as replaced.
	var parent := OS.get_environment("ASTRAL_SAVE_DIR")
	if parent.is_empty(): parent = OS.get_environment("TMPDIR")
	OS.set_environment("ASTRAL_SAVE_DIR", parent.path_join("astral-telemetry-%d" % Time.get_ticks_usec()))
	call_deferred("check")

func act(action: Callable, kind: String = "") -> void:
	ui.resolving = false
	ui.chart_travel_pending = false
	ui._perform(action, kind)
	secrets.append(str(ui.game.run.get("id", "")))
	if ui.chart_travel_pending: ui._finish_chart_travel(ui.chart_travel_to)

func travel() -> void:
	for layer in ui.game.run.map:
		for node in layer:
			if ui.game.reachable(node):
				act(func(): return ui.game.choose_node(str(node.id)), "chart_travel")
				return
	require(false, "no reachable destination")

func fight() -> void:
	var game = ui.game
	for enemy in game.run.battle.enemies: enemy.hp = 1
	var routes: Array = []
	for a in range(6):
		routes.append([a])
		for b in range(6):
			if a != b: routes.append([a, b])
	for hand_index in range(game.run.battle.hand.size()):
		for route in routes:
			for target in range(game.run.battle.enemies.size()):
				var preview: Dictionary = game.preview_card(hand_index, route, target)
				if preview.get("ok", false) and int(preview.get("damage", 0)) > 0 and not preview.get("selection_required", false):
					ui.selected_card = hand_index
					ui.route.assign(route)
					ui.target = target
					act(func(): return game.play_card(hand_index, route, target), "command")
					return
	act(func(): return game.end_turn(), "enemy_phase")

## Plays until the voyage ends or max_battles are won.
func voyage(max_battles: int = 999) -> void:
	var game = ui.game
	for step in range(2000):
		if game.run.get("finished", false) or int(game.run.battles) >= max_battles: return
		game.run.hull = game.run.max_hull
		match str(game.run.mode):
			"map": travel()
			"combat": fight()
			"reward":
				var pick := 0 if int(game.run.battles) % 2 == 1 and not game.run.reward.choices.is_empty() else -1
				act(func(): return game.choose_reward(pick))
			"transition": act(func(): return game.continue_region())
			"shop":
				game.run.salvage = 500
				if not game.run.shop.items[0].sold: act(func(): return game.buy(0), "purchase")
				act(func(): return game.leave_location())
			"recovery":
				game.run.hull = 10
				act(func(): return game.recover("repair"))
			"event":
				game.run.salvage = 500
				act(func(): return game.event_choice(0))
				if game.run.mode == "event": act(func(): return game.leave_location())
			"modify":
				if game.run.modify_kind == "remove": act(func(): return game.modify_card(0))
				else:
					for instance in game.run.deck:
						if int(instance.level) == 0:
							var branches: Array = game.evolution_choices(instance)
							if branches.is_empty(): act(func(): return game.modify_card(game.run.deck.find(instance)))
							else: act(func(): return game.evolve_card(instance.uid, str(branches[0].id)))
							break
	require(false, "voyage did not finish: mode %s, battles %d, notice %s" % [game.run.mode, game.run.battles, ui.notice])

func check() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	for i in range(3): await process_frame
	var autoload := root.get_node_or_null("Glitchless")
	require(autoload != null, "the Glitchless autoload is missing")
	require(autoload != null and not autoload.is_enabled(), "a debug test run must send nothing")
	ui.telemetry = Telemetry.new(ui, recorder)

	# A whole practice voyage, from ship selection to victory.
	ui.expedition_seed = SEED
	ui.resolving = false
	ui._new_run()
	secrets.append(SEED)
	require(recorder.named("run_start").size() == 1, "one run_start for a new voyage")
	require(recorder.named("run_resume").is_empty(), "a new voyage is not a resume")
	voyage()
	require(ui.game.run.mode == "victory", "the weakened voyage ends in victory")
	require(recorder.open_level.is_empty(), "no level stays open after victory")
	var battles := recorder.named("battle_end")
	require(battles.size() == int(ui.game.run.battles), "one battle_end per battle won")
	require(recorder.of("level_complete").size() == battles.size(), "every battle completes its level")
	require(battles.all(func(c): return c[2].won and c[2].practice), "battle_end marks wins and practice")
	require(recorder.named("reward_choice").size() == battles.size(), "one reward_choice per reward")
	require(recorder.named("reward_choice").any(func(c): return c[2].picked), "a taken reward is reported as picked")
	require(recorder.named("reward_choice").any(func(c): return not c[2].picked), "a skipped reward is reported as skipped")
	require(not recorder.named("stop_chosen").is_empty(), "chart stops are tracked")
	require(recorder.of("count").any(func(c): return c[1] == "command"), "commands are counted")
	require(recorder.of("count").any(func(c): return c[1] == "organ_routed"), "organ use is counted")
	for event in ["salvage_exchange", "event_choice", "recovery_choice", "card_evolved"]:
		require(not recorder.named(event).is_empty(), event + " is tracked")
	var ends := recorder.named("run_end")
	require(ends.size() == 1 and ends[0][2].won and ends[0][2].outcome == "victory", "one winning run_end")

	# Leaving a fight for the title abandons it; continuing starts it again.
	recorder.calls.clear()
	ui.expedition_seed = ""
	ui.resolving = false
	ui._new_run()
	travel()
	require(not recorder.open_level.is_empty(), "arriving at a battle starts a level")
	ui.menu = true
	ui._render()
	require(recorder.open_level.is_empty() and recorder.of("level_abandon").size() == 1, "returning to title abandons the level")
	ui.menu = false
	ui._render()
	ui._render()
	require(recorder.of("level_start").size() == 2, "continuing starts the level once more")

	# Abandoning the expedition is neither a death nor a battle result.
	act(func(): return ui.game.abandon())
	require(recorder.open_level.is_empty(), "abandoning closes the level")
	require(recorder.of("level_fail").is_empty() and recorder.of("death").is_empty() and recorder.named("battle_end").is_empty(), "abandoning is not a loss in battle")
	require(recorder.named("run_end")[0][2].outcome == "abandoned", "run_end says abandoned")

	# Defeat.
	recorder.calls.clear()
	ui.resolving = false
	ui._new_run()
	travel()
	ui.game.run.hull = 1
	ui.game.run.battle.ward = 0
	for turn in range(20):
		if ui.game.run.get("finished", false): break
		act(func(): return ui.game.end_turn(), "enemy_phase")
	require(ui.game.run.mode == "defeat", "the one-hull ship is destroyed")
	require(recorder.of("level_fail").size() == 1 and recorder.of("death").size() == 1, "defeat fails the level and records a death")
	require(recorder.named("battle_end").size() == 1 and not recorder.named("battle_end")[0][2].won, "defeat sends a lost battle_end")
	require(recorder.named("run_end")[0][2].outcome == "defeat", "run_end says defeat")

	await check_sharing_switch()

	# Nothing sent may name a replay seed, or the run ID that contains it.
	var sent := JSON.stringify(recorder.history)
	for secret in secrets:
		if not secret.is_empty(): require(not sent.contains(secret), "telemetry leaked a seed or run ID")
	require(recorder.problems.is_empty(), "\n".join(recorder.problems))
	print("TELEMETRY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func share_box() -> CheckBox:
	ui._open_settings()
	return ui.overlay.find_child("SharePerformanceData", true, false) as CheckBox

func check_sharing_switch() -> void:
	recorder.calls.clear()
	ui.telemetry.start()
	require(recorder.of("enabled").is_empty(), "starting while sharing never forces the switch")
	var box := share_box()
	require(box != null and box.button_pressed, "sharing is on until the player turns it off")
	if box == null: return
	box.button_pressed = false
	require(recorder.of("enabled") == [["enabled", false]], "turning the switch off reaches the SDK")
	var saved = load("res://scripts/game.gd").new(OS.get_environment("ASTRAL_SAVE_DIR"))
	require(saved.profile.settings.get("share_performance_data") == false, "the choice survives a reload")
	require(not share_box().button_pressed, "Settings shows the saved choice")
	require(not ui.mcp_controller.snapshot().legal_actions.any(func(a): return JSON.stringify(a).contains("share_performance_data")), "an MCP client cannot change the choice")
	recorder.calls.clear()
	ui.telemetry.start()
	require(recorder.calls.size() >= 2 and recorder.calls[0] == ["enabled", false] and recorder.calls[1][0] == "init", "an opted-out launch turns off before init")
	recorder.calls.clear()
	share_box().button_pressed = true
	require(recorder.of("enabled") == [["enabled", true]], "the player can turn sharing back on")
	ui._close_overlay()
	ui.resolving = false
	require(ui.hull_admin.enter(), "the sandbox opens")
	require(share_box() == null, "the sandbox does not offer the switch")
	ui._close_overlay()
	ui._leave_admin()
	for i in range(3): await process_frame

