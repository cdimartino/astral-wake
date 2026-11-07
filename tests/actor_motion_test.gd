extends SceneTree
const Main = preload("res://scripts/main.gd")
const Game = preload("res://scripts/game.gd")
var ui
var failures := 0
var checks := 0

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	call_deferred("check")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(5): await process_frame

func fixture(count: int) -> void:
	ui.game.new_run(7163)
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.game.run.tutorial_step = 4
	ui.game.profile.settings.reduced_motion = false
	ui.game.run.battle.enemies.clear()
	for i in range(count): ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
	ui.menu = false
	ui._render()

func check() -> void:
	ui = Main.new()
	ui.game = Game.new("/tmp/astral-actor-motion-%d" % Time.get_ticks_usec())
	root.add_child(ui)
	root.size = Vector2i(1440, 900)
	await settle()
	fixture(3)
	await settle()
	require(is_instance_valid(ui.player_art) and ui.player_art.has_meta("idle_tween"), "Player ship needs an idle motion")
	require(ui.player_art.get_meta("idle_tween").is_running(), "Player ship idle motion is not running")
	for image in ui.enemy_art:
		require(image.has_meta("idle_tween") and image.get_meta("idle_tween").is_running(), "Every enemy needs its own idle motion")
	var resting_y: float = ui.enemy_art[0].position.y
	await create_timer(0.7).timeout
	require(absf(ui.enemy_art[0].position.y - resting_y) > 0.2, "Idle enemies do not visibly drift")

	# Acting enemies and ships carry enough source information to animate the right artwork.
	var before := {"battle": {"enemies": [{"id": "cinder_mite"}], "strain": [0, 0, 0, 0, 0, 0]}}
	var result := {"presentation": [{"kind": "enemy_attack", "source_index": 0, "target_index": 0, "amount": 4}]}
	var plan: Array = ui._feedback_plan(before, result, "enemy_phase", [], 0, {})
	var charges := plan.filter(func(cue): return str(cue.get("kind", "")) == "charge")
	var attacks := plan.filter(func(cue): return str(cue.get("kind", "")) == "enemy_shot")
	require(charges.size() == 1 and int(charges[0].get("source_index", -1)) == 0, "Enemy charge must name the acting enemy")
	require(attacks.size() == 1 and int(attacks[0].get("source_index", -1)) == 0, "Enemy attack must name the acting enemy")

	var enemy: TextureRect = ui.enemy_art[0]
	var enemy_x := enemy.position.x
	ui._animate_cue_actor({"kind": "enemy_shot", "source_index": 0})
	await create_timer(0.08).timeout
	require(enemy.position.x < enemy_x - 0.5, "Acting enemy should lunge toward the ship")
	await create_timer(0.36).timeout
	require(absf(enemy.position.x - enemy_x) < 0.5, "Acting enemy should settle back into its idle position")

	var ship: TextureRect = ui.player_art
	var ship_x := ship.position.x
	ui._animate_cue_actor({"kind": "shot"})
	await create_timer(0.08).timeout
	require(ship.position.x > ship_x + 0.5, "Firing ship should recoil away from the target")
	await create_timer(0.36).timeout
	require(absf(ship.position.x - ship_x) < 0.5, "Firing ship should settle back into its idle position")

	var struck: TextureRect = ui.enemy_art[1]
	ui._impact_art(struck, Color("f39789"), true)
	await create_timer(0.07).timeout
	require(not struck.scale.is_equal_approx(Vector2.ONE), "Struck artwork should briefly squash")
	await create_timer(0.3).timeout
	require(struck.scale.is_equal_approx(Vector2.ONE), "Struck artwork should recover its resting scale")

	ui.game.profile.settings.reduced_motion = true
	ui._sync_motion()
	for image in [ui.player_art] + ui.enemy_art:
		require(image.has_meta("idle_tween") and not image.get_meta("idle_tween").is_running(), "Reduced motion left idle movement running")
		require(is_equal_approx(image.position.y, float(image.get_meta("idle_y"))), "Reduced motion left artwork displaced")
		require(is_zero_approx(image.rotation), "Reduced motion left artwork tilted")
		require(image.scale.is_equal_approx(Vector2.ONE), "Reduced motion left artwork scaled")
	var still_x: float = ui.player_art.position.x
	ui._animate_cue_actor({"kind": "shot"})
	await create_timer(0.1).timeout
	require(is_equal_approx(ui.player_art.position.x, still_x), "Reduced motion still animated an action")

	ui.game.profile.settings.reduced_motion = false
	ui._sync_motion()
	require(ui.player_art.get_meta("idle_tween").is_running(), "Re-enabling motion did not restart ship idle movement")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	await create_timer(0.15).timeout
	ui.queue_free()
	await settle()
	print("ACTOR_MOTION_TESTS ", checks, " checks ", failures, " failures")
	quit(0 if failures == 0 else 1)
