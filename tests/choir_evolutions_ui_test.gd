extends "res://tests/evolutions_ui_test.gd"

func run_test() -> void:
	var ui=preload("res://scripts/main.gd").new()
	root.add_child(ui)
	ui.game.new_run("0093CG","hollow_choir")
	ui.game.run.mode="recovery"
	ui.menu=false
	ui._render()
	require(all_text(ui.page).contains("permanent branch"),"Choir recovery explains explicit choice")
	ui.game.recover("upgrade")
	ui._render()
	var before=Session.snapshot(ui.game.run)
	var seen=[]
	for i in range(ui.game.run.deck.size()):
		var instance=ui.game.run.deck[i]
		if instance.id in seen: continue
		seen.append(instance.id)
		ui._choose_modification(i)
		var text=all_text(ui.overlay)
		require(text.contains("BEFORE") and text.contains("AFTER") and text.contains("CP"),"Native before/after CP: "+instance.id)
		for branch in ui.game.card(instance.id).evolutions:
			require(text.contains(branch.name) and text.contains(branch.description),"Full production names/effect prose: "+branch.id)
		button(ui.overlay,"Cancel ·").pressed.emit()
		require(ui.overlay==null and Session.snapshot(ui.game.run)==before,"Starter cancellation leaves identical state")
	ui._choose_modification(0)
	button(ui.overlay,"Confirm Gathering Chorus").pressed.emit()
	require(ui.game.run.deck[0].evolution=="gathering_chorus","Native explicit production confirm by UID")
	require(ui._card_tip(ui.game.run.deck[0]).contains("Gain 1 Resonance") and ui._card_tip(ui.game.run.deck[0]).contains("[gathering_chorus]"),"Hover shows effective resource and identity")
	ui._open_deck()
	require(all_text(ui.overlay).contains("Gathering Chorus"),"Deck shows production branch name")
	ui._close_overlay()
	# Labelled nonstarter setup for the existing first-free primitive and paid cost pair.
	ui.game.run.deck[1].id="counterpoint"
	ui.game.run.mode="recovery"
	ui.game.recover("upgrade")
	ui._choose_modification(1)
	var text=all_text(ui.overlay)
	require(text.contains("First routed organ gains no strain.") and text.contains("Gain 2 Resonance"),"Counterpoint exposes first-free versus generation")
	button(ui.overlay,"Cancel ·").pressed.emit()
	ui.game.run.deck[1].id="resonant_shell"
	ui.game.run.modify_return="shop"
	ui.game.run.modify_shop_index=0
	ui.game.run.shop={"items":[{"kind":"upgrade","id":"","cost":35,"sold":false}]}
	ui.game.run.salvage=50
	ui._choose_modification(1)
	text=all_text(ui.overlay)
	require(text.contains("2 CP") and text.contains("1 CP") and text.contains("35 salvage"),"Actual Shell CP tradeoff and exact service price")
	button(ui.overlay,"Confirm Light Shell").pressed.emit()
	require(ui.game.run.deck[1].evolution=="light_shell" and ui.game.run.salvage==15,"Native paid discount-branch confirmation")
	for player in ui.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	ui.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("CHOIR_EVOLUTIONS_UI_TEST ",checks," checks, ",failures," failures (node assertions, not graphical evidence)")
	quit(1 if failures else 0)
