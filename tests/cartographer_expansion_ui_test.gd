extends SceneTree
const IDS=preload("res://tests/cartographer_expansion_test.gd").IDS
var failures=0
func require(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	check.call_deferred()
func check() -> void:
	var ui=preload("res://scripts/main.gd").new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	ui.game.new_run("0093CG")
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.menu=false
	for size in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=size
		for id in IDS:
			var variants=[{"id":id,"level":0,"uid":1}]
			for branch in ui.game.card(id).evolutions: variants.append({"id":id,"level":1,"evolution":branch.id,"uid":1})
			for instance in variants:
				ui.game.run.battle.hand=[instance]
				ui._clear_selection()
				ui._render()
				for unused in range(2): await process_frame
				var art=ui._card_art(instance,80)
				require(art.texture!=null,"Existing licensed atlas fallback: "+id)
				var shared_id=ui.game.catalog.cards[int(ui.game.card(id).art)].id
				var shared=ui._card_art({"id":shared_id,"level":0},80)
				require(art.texture==shared.texture,"Honest explicit shared original atlas slot: "+id)
				shared.free()
				art.free()
				var definition=ui.game.effective_card(instance)
				var tip=ui._card_tip(instance)
				require(tip.contains(definition.description),"Authoritative full branch rules accessible "+definition.name)
				require(not ui.game.card_text(instance).is_empty(),"Nonempty card rules")
	ui.audio.stop()
	ui.ambience.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	print("EXPANSION_UI 27 definitions at both sizes; ",failures," failures (node checks, NOT human visual acceptance)")
	quit(1 if failures else 0)
