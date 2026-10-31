extends SceneTree
const Main=preload("res://scripts/main.gd")
const Game=preload("res://scripts/game.gd")
var failures=0
var checks=0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+message)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	_run.call_deferred()

func settle() -> void:
	for ignored in range(6): await process_frame

func _run() -> void:
	var ui=Main.new()
	ui.game=Game.new("user://tactics-ui-"+str(Time.get_ticks_usec()))
	root.add_child(ui)
	await settle()
	for size in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=size
		for count in [1,5]:
			ui.game.new_run(424242)
			ui.game.choose_node(ui.game.run.map[0][0].id)
			ui.game.run.battle.enemies.clear()
			for ignored in range(count): ui.game.run.battle.enemies.append(ui.game._make_enemy("witness_array"))
			ui.menu=false
			ui._render()
			await settle()
			var badge=ui.page.find_child("EnemyIntent%d"%(count-1),true,false)
			check(badge.explanation.contains("Cross-examination") and badge.explanation.contains("Repeats:"),"badge teaches the enemy identity and repeating cycle")
			badge.grab_focus()
			await settle()
			var tip=badge.focus_tip
			check(is_instance_valid(tip),"keyboard reveals the counter")
			if is_instance_valid(tip):
				var rect=tip.get_global_rect()
				check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=ui.get_viewport_rect().size.x and rect.end.y<=ui.get_viewport_rect().size.y,"long boss counter fits inside the viewport")
			ui.game.run.battle.enemies[count-1].disrupt=5
			ui._render()
			await settle()
			badge=ui.page.find_child("EnemyIntent%d"%(count-1),true,false)
			check(badge.explanation.contains("INTERRUPTED"),"badge confirms that an action has been canceled")
	ui.queue_free()
	await settle()
	print("ENEMY TACTICS UI: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
