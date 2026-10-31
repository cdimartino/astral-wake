extends SceneTree
const Main = preload("res://scripts/main.gd")
var failures := 0

func require(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-card-effects-%d" % Time.get_ticks_usec())
	check.call_deferred()

func check() -> void:
	var ui = Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	ui.game.new_run(2026)
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.menu = false
	var phrases = {"damage":"Deal %d damage", "heal":"Restore %d hull", "vent":"Cool every organ by %d", "disrupt":"Apply %d disruption"}
	for definition in ui.game.catalog.cards:
		for level in [0, 1]:
			var instance = {"id":definition.id,"uid":1,"level":level}
			var effective = ui.game.effective_card(instance)
			var text = ui.game.card_text(instance)
			for field in phrases:
				if int(definition.get(field, 0)) > 0:
					require(text.contains(phrases[field] % int(effective[field])), "Stale card text: " + definition.id)
			require(int(effective.get("draw", 0)) == int(definition.get("draw", 0)), "Draw gained an unintended upgrade")
			ui.game.run.battle.hand = [instance]
			ui._clear_selection()
			ui._render()
			for variant in range(4):
				var lifted := variant % 2 == 1
				root.size = Vector2i(1440, 900) if variant < 2 else Vector2i(1100, 720)
				ui.hover_card = 0 if lifted else -1
				ui._arrange_hand()
				for unused in range(3): await process_frame
				var button = ui.hand_buttons[0]
				var effects = button.find_child("CardEffects", true, false)
				for token in effects.get_children():
					require(button.get_global_rect().grow(1).encloses(token.get_global_rect()), "Clipped effect: %s level=%d lifted=%s" % [definition.id, level, lifted])
				if definition.id == "carbon_breath":
					var labels = effects.find_children("*", "Label", true, false)
					require(labels.any(func(label): return label.text == "Vent %d" % (1 + level)), "Carbon Breath vent invisible")
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	print("CARD EFFECTS: ", failures, " failures")
	quit(1 if failures else 0)
