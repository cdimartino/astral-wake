extends SceneTree

const Game = preload("res://scripts/game.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("check")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func check() -> void:
	var base := OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_user_data_dir()
	var fixture_dir := base.path_join("astral-wake-defeat-%d" % Time.get_ticks_usec())
	OS.set_environment("ASTRAL_SAVE_DIR", fixture_dir)
	var game = Game.new(fixture_dir)
	game.new_run(7163)
	game.choose_node(game.run.map[0][0].id)
	var enemies: Array = []
	for i in range(5):
		enemies.append(game._make_enemy(game.catalog.enemies[0].id))
	var enemies_before: Array = enemies.duplicate(true)
	enemies[1].hp = 0
	enemies[3].hp = 0
	game.run.battle.enemies = enemies
	var events: Array = []
	game._clean_enemies(game.run, events, enemies_before)
	var deaths := events.filter(func(event): return event.get("kind", "") == "enemy_defeated")
	require(deaths.size() == 2, "Only newly dead foes should emit defeat events")
	require(deaths[0].target_index == 1 and deaths[1].target_index == 3, "Defeat events must retain pre-compaction indices for same-type enemies")
	require(game.run.battle.enemies.size() == 3, "Defeat instrumentation must preserve normal compaction")
	var already_dead: Array = []
	game._clean_enemies(game.run, already_dead, game.run.battle.enemies.duplicate(true))
	require(already_dead.filter(func(event): return event.get("kind", "") == "enemy_defeated").is_empty(), "Already removed enemies must not emit another death")

	var ui = Main.new()
	ui.game = game
	root.add_child(ui)
	await process_frame
	require(is_instance_valid(ui.enemy_defeat_audio) and ui.enemy_defeat_audio.is_inside_tree(), "Defeat audio helper must survive initial Main render")
	ui._render()
	await process_frame
	require(is_instance_valid(ui.enemy_defeat_audio) and ui.enemy_defeat_audio.is_inside_tree(), "Defeat audio helper must survive redraw")
	var before := {"battle":{"enemies":enemies}}
	var result := {"presentation":deaths}
	var cues: Array = ui._feedback_plan(before, result, "command", [], 0, {})
	var defeat_cues := cues.filter(func(cue): return cue.get("kind", "") == "defeat")
	require(defeat_cues.size() == 2, "Committed presentation should create one distinct cue per defeat")
	require(defeat_cues[0].target_index == 1 and defeat_cues[1].target_index == 3, "Visual targets must use original roster indices")
	var preview_result := {"presentation":[]}
	cues = ui._feedback_plan(before, preview_result, "command", [], 0, {})
	require(cues.filter(func(cue): return cue.get("kind", "") == "defeat").is_empty(), "No defeat cue without committed defeat records")
	game.run.mode = "reward"
	cues = ui._feedback_plan(before, result, "command", [], 0, {})
	require(cues.any(func(cue): return cue.get("kind", "") == "victory"), "Encounter clear should add a shared victory flourish")
	var actor := TextureRect.new()
	root.add_child(actor)
	var actor_list: Array[TextureRect] = [actor]
	ui.enemy_art = actor_list
	ui._animate_cue_actor({"kind":"defeat","target_index":0})
	await create_timer(0.25).timeout
	require(actor.scale.x < 1.0 and actor.modulate.a < 1.0, "Defeat beat should visibly shrink and fade the local actor")
	game.run.mode = "combat"
	game.run.battle.enemies = enemies
	ui._feedback(before, result, "command", [], 0, {})
	var impact_wait := 0.0
	for cue in ui.last_feedback:
		if cue.get("kind", "") == "defeat": impact_wait = maxf(impact_wait, float(cue.get("delay", 0.0)))
	await create_timer(impact_wait + 0.05).timeout
	require(not ui.enemy_defeat_audio._seen.is_empty(), "Committed defeat impact must reach the grouped audio API")
	print("enemy defeat feedback checks complete: ", checks - failures, "/", checks)
	quit(1 if failures > 0 else 0)
