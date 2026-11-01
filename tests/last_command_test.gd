extends SceneTree
const Game = preload("res://scripts/game.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var directory := OS.get_environment("TMPDIR") + "astral-memory-%d" % Time.get_ticks_usec()
	OS.set_environment("ASTRAL_SAVE_DIR", directory)
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	var ui = Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	var game = ui.game
	for ship in ["cartographer", "palimpsest", "hollow_choir"]:
		game.new_run(2026, ship)
		game.choose_node(game.run.map[0][0].id)
		var instance = game.run.battle.hand[0]
		var definition = game.card(instance.id)
		for enemy in game.run.battle.enemies: enemy.hp = 999
		game.run.hull -= 10
		instance.level = 1
		instance.evolution = "legacy"
		for card in game.run.deck:
			if card.uid == instance.uid:
				card.level = 1
				card.evolution = "legacy"
		var before = game.run.duplicate(true)
		game.preview_card(0, [0], 0)
		require(game.run == before, "Preview changes memory")
		require(not game.play_card(0, [], 0).ok and not game.run.battle.has("last_command"), "Invalid command changes memory")
		var result = game.play_card(0, [0], 0)
		require(result.ok, "Command failed")
		var memory = game.run.battle.last_command.duplicate(true)
		game.play_card(-1, [0], 0)
		require(game.run.battle.last_command == memory, "Rejected command replaces stored memory")
		require(memory.card == instance and memory.kind == definition.kind, "Identity or upgrade missing")
		require(memory.base.damage == int(definition.get("damage", 0)) + (3 if int(definition.get("damage", 0)) > 0 else 0), "Incorrect Rewrite base")
		require(memory.resolved.damage == result.damage, "Resolved damage mismatch")
		var restored = Game.new(directory)
		require(restored.load_saved() and restored.run.battle.last_command == memory, "Memory not preserved by save/load")
		require(game._valid_last_command(memory), "Valid memory rejected")
		var broken = memory.duplicate(true)
		broken.base.damage = "bad"
		require(not game._valid_last_command(broken), "Malformed memory accepted")
		game.end_turn()
		require(game.run.battle.last_command == memory, "End turn clears memory")
		ui.menu = false
		ui._clear_selection()
		ui._render()
		for unused in range(5): await process_frame
		var panel = ui.page.find_child("LastCommand", true, false)
		require(panel != null and panel.text.contains(str(definition.name)), "Combat memory panel missing")
		require(panel.position.y + panel.size.y <= 174, "Memory panel overlaps combat controls")
		require(panel.tooltip_text.contains("Base before organs") and panel.tooltip_text.contains("rounded down"), "Rewrite explanation missing")
		panel.pressed.emit()
		for unused in range(5): await process_frame
		require(ui.overlay != null, "Keyboard inspection unavailable")
		ui._close_overlay()
		game.run.battle.erase("last_command")
		game.save()
		require(restored.load_saved(), "Old saves without command snapshots rejected")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	print("LAST COMMAND: ", failures, " failures")
	quit(1 if failures else 0)
