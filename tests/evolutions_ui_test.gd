extends SceneTree
const Fixtures = preload("res://tests/evolution_fixtures.gd")
const Session = preload("res://tools/manual_session.gd")
var failures=0
var checks=0

func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _initialize() -> void:
	OS.set_environment("ASTRAL_SAVE_DIR",OS.get_environment("TMPDIR").path_join("astral-evolution-ui-%d" % Time.get_ticks_usec()))
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	run_test.call_deferred()

func all_text(node: Node) -> String:
	var result=""
	if node is Label or node is RichTextLabel or node is Button: result+=node.text+"\n"
	for child in node.get_children(): result+=all_text(child)
	return result

func button(node: Node, prefix: String):
	if node is Button and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found=button(child,prefix)
		if found!=null: return found
	return null

func run_test() -> void:
	var ui=preload("res://scripts/main.gd").new()
	root.add_child(ui)
	Fixtures.setup(ui.game)
	ui.menu=false
	ui._render()
	var before=Session.snapshot(ui.game.run)
	ui._choose_modification(0)
	var text=all_text(ui.overlay)
	require(text.contains("BEFORE") and text.contains("Deal 10 damage.") and text.contains("AFTER") and text.contains("Deal 13 damage.") and text.contains("Draw 1 command."),"Chooser displays full before/after and both specializations")
	require(text.contains("Impact") and text.contains("Flow") and text.contains("no salvage cost"),"Branch names and recovery price readable")
	button(ui.overlay,"Cancel ·").pressed.emit()
	require(ui.overlay==null and Session.snapshot(ui.game.run)==before,"Chooser cancellation returns to deck without charging or state mutation")
	ui.game.run.modify_return="shop"
	ui.game.run.modify_shop_index=0
	ui.game.run.shop={"items":[{"kind":"upgrade","id":"","cost":35,"sold":false}]}
	ui.game.run.salvage=50
	ui._choose_modification(0)
	require(all_text(ui.overlay).contains("35 salvage"),"Shop chooser displays exact charge")
	button(ui.overlay,"Confirm Fixture Needle · Flow").pressed.emit()
	require(ui.game.run.deck[0].evolution=="flow" and ui.game.run.salvage==15,"Native confirmation selects exact branch and pays once")
	var source=ui.game.run.deck[0]
	require(ui._card_tip(source).contains("[flow]") and ui._card_tip(source).contains("Draw 1 command."),"Hover exposes identity and actual effective text")
	ui._open_deck()
	require(all_text(ui.overlay).contains("Fixture Needle · Flow"),"Deck shows actual evolved name")
	ui._close_overlay()
	for player in ui.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	ui.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("EVOLUTIONS_UI_TEST ",checks," checks, ",failures," failures (node assertions, not graphical evidence)")
	quit(1 if failures else 0)
