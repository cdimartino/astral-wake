extends SceneTree
const Game = preload("res://scripts/game.gd")
const Main = preload("res://scripts/main.gd")
const Fixtures = preload("res://tests/card_zone_fixtures.gd")
const Session = preload("res://tools/manual_session.gd")
var failures := 0
var checks := 0
var directory := OS.get_environment("TMPDIR").path_join("astral-zones-%d" % Time.get_ticks_usec())

func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _initialize() -> void:
	check.call_deferred()

func count_events(result: Dictionary, kind: String) -> int:
	return result.presentation.filter(func(event): return event.kind==kind).size()

func checked_play(game) -> Dictionary:
	var before=Session.snapshot(game.run)
	var preview=game.preview_card(0,[0],0)
	require(game.preview_card(0,[0],0)==preview and Session.snapshot(game.run)==before,"Repeated preview is pure including RNG/zones")
	var result=game.play_card(0,[0],0)
	require(result==preview,"Committed result equals preview")
	return result

func write_save(game, state: Dictionary, backup: bool = false) -> void:
	var file=FileAccess.open(directory.path_join("save.backup.json" if backup else "save.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":state}))
	file.close()

func check() -> void:
	var game=Game.new(directory)
	Fixtures.register(game)
	# Exact circulation and self-draw boundary, using only authored test entries.
	for behavior in ["exhaust","install"]:
		Fixtures.battle(game)
		Fixtures.identify(game,0,"fixture_"+behavior)
		var uid=game.run.deck[0].uid
		game.run.battle.hand=[game.run.deck[0].duplicate(true)]
		game.run.battle.draw=[]
		game.run.battle.discard=game.run.deck.slice(1).duplicate(true)
		var result=checked_play(game)
		var zone="exhausted" if behavior=="exhaust" else "installed"
		require(result.ok and game.run.battle[zone][0].uid==uid,"Played card moves to "+zone)
		require(result.cost==int(game.effective_card(game.run.battle[zone][0]).cost) and game.run.battle.command_points==3-result.cost,"Dedicated behavior preserves ordinary CP cost")
		require(not game.run.battle.hand.any(func(instance): return instance.uid==uid),"Dedicated-zone card cannot self-redraw")
		require(count_events(result,"zone_card")==1 and count_events(result,"discard_card")==0,"Zone movement is not ordinary discard")
		require(game._valid_run(game.run),"Five-zone UID conservation")
		for other in game.COMBAT_ZONES:
			if other==zone: continue
			var broken=game.run.duplicate(true)
			broken.battle[other].append(broken.battle[zone][0].duplicate(true))
			require(not game._valid_run(broken),"Reject duplicated UID across "+other+" / "+zone)
		var broken=game.run.duplicate(true)
		broken.battle[zone][0].level=1
		require(not game._valid_run(broken),"Zone identity level must match deck")
		broken=game.run.duplicate(true)
		broken.battle[zone][0].id="needle"
		require(not game._valid_run(broken),"Zone identity id must match deck")
		game.save()
		var saved=Session.snapshot(game.run)
		var resumed=Game.new(directory)
		Fixtures.register(resumed)
		require(resumed.load_saved() and Session.snapshot(resumed.run)==saved,"Resume exact zones, source identity and RNG")
		game._start_battle(game.run.map[0][0])
		require(game.run.battle.exhausted.is_empty() and game.run.battle.installed.is_empty() and game.run.battle.installed_sources.is_empty(),"Combat resets dedicated zones and source records")
		require(game._valid_run(game.run),"Next combat restores all expedition UIDs, including previously removed circulation")
	# Duplicate identity and same-name rejection, before any mutation.
	for duplicate in ["fixture_install","fixture_alias","fixture_namesake"]:
		Fixtures.battle(game)
		Fixtures.identify(game,0,"fixture_install")
		Fixtures.identify(game,1,duplicate)
		checked_play(game)
		var before=game.run.duplicate(true)
		var cp=int(game.run.battle.command_points)
		require(not game.play_card(0,[1],0).ok and game.run==before,"Duplicate Install is atomic: "+duplicate)
		require(not game.preview_card(0,[1],0).ok and game.run==before,"Duplicate preview is atomic")
		require(int(game.run.battle.command_points)==cp,"Install uses ordinary cost without refund")
	# Stable retained order, normal five draw subject to ten-card cap.
	for retained_count in [2,6,10]:
		Fixtures.battle(game)
		game.run.battle.hand=game.run.deck.slice(0,maxi(5,retained_count)).duplicate(true)
		game.run.battle.draw=game.run.deck.slice(maxi(5,retained_count)).duplicate(true)
		var expected=[]
		for i in range(retained_count):
			Fixtures.identify(game,i,"fixture_retain")
			expected.append(game.run.deck[i].uid)
		var rng=game.run.rng_streams.duplicate(true)
		var result=game.end_turn()
		require(game.run.battle.hand.size()==mini(10,retained_count+5),"Retained hand cap and draw five")
		require(game.run.battle.hand.slice(0,retained_count).map(func(instance): return instance.uid)==expected,"Retained order is stable")
		require(count_events(result,"discard_card")==maxi(0,5-retained_count),"Only ordinary cards emit discard events")
		require(count_events(result,"draw_card")==mini(5,10-retained_count),"Only actual draws emit events")
		if retained_count==10: require(game.run.rng_streams==rng and count_events(result,"shuffle")==0,"Full retained hand does not shuffle or consume RNG")
		require(game._valid_run(game.run),"Retained state conserves UIDs")
	# Temporary retain survives exactly one discard, including intrinsic overlap.
	Fixtures.battle(game)
	var uid=int(game.run.battle.hand[0].uid)
	Fixtures.identify(game,1,"fixture_retain")
	game.retain_card(uid)
	game.retain_card(int(game.run.battle.hand[1].uid))
	var before=game.run.duplicate(true)
	require(not game.retain_card(99999).ok and game.run==before,"Invalid UID retain changes nothing")
	game.save()
	var resumed=Game.new(directory)
	Fixtures.register(resumed)
	require(resumed.load_saved() and resumed.run.battle.temporary_retain==game.run.battle.temporary_retain,"Temporary retain survives resume")
	game.end_turn()
	require(game.run.battle.hand[0].uid==uid and game.run.battle.temporary_retain.is_empty(),"Temporary mark expires at first boundary even with intrinsic retain")
	var result=game.end_turn()
	require(result.presentation.any(func(event): return event.kind=="discard_card" and event.card.uid==uid),"Temporary retained card discards next turn")
	Fixtures.battle(game)
	Fixtures.identify(game,0,"graft_wire")
	uid=int(game.run.deck[0].uid)
	game.run.battle.hand=[game.run.deck[0].duplicate(true)]
	game.run.battle.draw=[]
	game.run.battle.discard=[]
	game.run.battle.exhausted=game.run.deck.slice(1).duplicate(true)
	game.retain_card(uid)
	checked_play(game)
	require(game.run.battle.hand[0].uid==uid and game.run.battle.temporary_retain.is_empty(),"Playing consumes mark before forced same-UID self-redraw")
	# Real envelope-v1 files: legacy migration preserves RNG and is idempotent.
	for modern in [false,true]:
		Fixtures.battle(game,modern)
		var current=game.run.duplicate(true)
		current.reward_generation=0 # Expected permanent legacy policy, no RNG change.
		current.content_pool_revision=0
		var legacy=current.duplicate(true)
		legacy.erase("schema_revision")
		legacy.erase("reward_generation")
		legacy.erase("content_pool_revision")
		legacy.erase("rare_offer_misses")
		legacy.erase("pending_selection")
		for key in ["exhausted","installed","installed_sources","temporary_retain","engine_counters","engine_routes"]: legacy.battle.erase(key)
		write_save(game,legacy)
		resumed=Game.new(directory)
		require(resumed.run==current,"Legacy migration preserves all state including legacy/modern RNG")
		write_save(game,legacy,true)
		var damaged_legacy=legacy.duplicate(true)
		damaged_legacy.battle.hand[0].uid=1.5
		write_save(game,damaged_legacy)
		resumed=Game.new(directory)
		require(resumed.run==current and resumed.save_error.contains("backup"),"Corrupt legacy primary falls back to migrated legacy backup")
		resumed.save()
		require(Game.new(directory).run==current,"Migration is idempotent after write/resume")
		write_save(game,current,true)
		for field in ["exhausted","installed","installed_sources","temporary_retain","command_points"]:
			var broken=current.duplicate(true)
			broken.battle.erase(field)
			write_save(game,broken)
			resumed=Game.new(directory)
			require(resumed.run==current and resumed.save_error.contains("backup"),"Missing current-schema "+field+" recovers backup, never migrates")
		for corruption in ["fractional_uid","fractional_retain","unknown_retain","duplicate_retain","revision","missing_revision"]:
			var broken=current.duplicate(true)
			match corruption:
				"fractional_uid": broken.battle.hand[0].uid=1.5
				"fractional_retain": broken.battle.temporary_retain=[1.5]
				"unknown_retain": broken.battle.temporary_retain=[9999]
				"duplicate_retain": broken.battle.temporary_retain=[broken.battle.hand[0].uid,broken.battle.hand[0].uid]
				"revision": broken.schema_revision=99
				"missing_revision": broken.erase("schema_revision")
			write_save(game,broken)
			resumed=Game.new(directory)
			require(resumed.run==current and resumed.save_error.contains("backup"),"Reject before integer restore: "+corruption)
	# Source-link corruption and dead-combat draw exclusion.
	Fixtures.showcase(game)
	var installed_state=game.run.duplicate(true)
	for corruption in ["source_uid","identity","extra"]:
		var broken=installed_state.duplicate(true)
		if corruption=="source_uid": broken.battle.installed_sources[0].source_uid=1.5
		if corruption=="identity": broken.battle.installed_sources[0].identity="wrong"
		if corruption=="extra": broken.battle.installed_sources[0].arbitrary_script="no"
		require(not game._valid_run(broken),"Reject malformed Install source "+corruption)
	game.run.hull=1
	game.run.battle.enemies[0].intent={"kind":"attack","amount":999,"label":"Fixture lethal"}
	result=game.end_turn()
	require(game.run.mode=="defeat" and count_events(result,"draw_card")==0,"No draw after combat ends")
	# Headless node inspection, not graphical/legibility evidence.
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	OS.set_environment("ASTRAL_SAVE_DIR",directory.path_join("ui"))
	var ui=Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	Fixtures.showcase(ui.game)
	ui.menu=false
	ui._render()
	for unused in range(5): await process_frame
	for zone in ["draw","discard","exhausted","installed"]:
		var button=ui.page.find_child(zone.capitalize()+"Pile",true,false)
		require(button!=null and button.text.ends_with(str(ui.game.run.battle[zone].size())),"UI zone count "+zone)
		require(button.pressed.get_connections().size()>0,"UI inspection connected "+zone)
		button.pressed.emit()
		for unused in range(2): await process_frame
		var labels=[]
		collect_text(ui,labels)
		require(labels.any(func(text): return str(text).contains(zone.capitalize()+" pile")),"Inspection names correct zone "+zone)
		if zone=="installed":
			require(labels.any(func(text): return str(text).contains("Dormant identity: fixture_engine")),"Installed inspection shows source identity")
			var cue=ui.game._simulate_card(ui.game.run.duplicate(true),0,[2],0)
			# The showcase's held card is ordinary/intrinsic; no fake production behavior.
			require(cue.ok,"Fixture retains normal routing and costs")
		ui._close_overlay()
		ui._render()
		for unused in range(2): await process_frame
	require(ui.hand_buttons[0].find_child("RetainMarker",true,false).text=="[R] EVERY TURN" and ui.hand_buttons[1].find_child("RetainMarker",true,false).text=="[R1] NEXT DISCARD","Distinct intrinsic and one-discard markers visible")
	for index in [0,1]:
		require(ui.hand_buttons[index].explanation.contains("[b]Retain[/b]") and ui.hand_buttons[index].explanation.contains("temporary UID mark"),"Existing rich keyword tooltip explains intrinsic and temporary Retain")
	var intrinsic_text="Retained every end turn until played."
	var temporary_text="Retained through next discard only; expires when played."
	for index in [0,1]:
		var exact=intrinsic_text if index==0 else temporary_text
		require(ui.hand_buttons[index].tooltip_text.contains(exact) and ui.hand_buttons[index].explanation.begins_with(exact),"Card-specific hover and focus duration precedes general glossary")
	await check_retain_readability(ui)
	var retention_initial=ui.game.run.duplicate(true)
	ui.game.retain_card(int(ui.game.run.battle.hand[0].uid))
	ui._render()
	require(ui.hand_buttons[0].find_child("RetainMarker",true,false).text=="[R] EVERY TURN","Intrinsic marker wins when temporary Retain overlaps")
	var overlap_text="Temporary retain also expires at the next discard or when played; intrinsic Retain remains."
	require(ui.hand_buttons[0].explanation.begins_with(intrinsic_text) and ui.hand_buttons[0].explanation.contains(overlap_text) and ui.hand_buttons[0].tooltip_text.contains(overlap_text),"Overlap hover/focus explains expiry without removing intrinsic Retain")
	await check_retain_readability(ui)
	var retained_resume=Game.new(ui.game.store.directory)
	Fixtures.register(retained_resume)
	require(retained_resume.load_saved(),"Resume retention duration fixture")
	ui.game.run=retained_resume.run
	ui._render()
	require(ui.hand_buttons[0].explanation.contains("intrinsic Retain remains") and ui.hand_buttons[1].explanation.begins_with(temporary_text),"Save/resume preserves overlap and one-discard duration text")
	ui.game.end_turn()
	ui._render()
	require(ui.hand_buttons[0].find_child("RetainMarker",true,false).text=="[R] EVERY TURN" and not ui.hand_buttons[0].explanation.contains("Temporary retain also"),"Boundary removes temporary overlap text but retains intrinsic marker")
	require(ui.hand_buttons[1].find_child("RetainMarker",true,false)==null and not ui.hand_buttons[1].tooltip_text.contains(temporary_text),"One-discard marker and specific temporary text expire after boundary")
	retained_resume=Game.new(ui.game.store.directory)
	Fixtures.register(retained_resume)
	require(retained_resume.load_saved(),"Resume expired retention fixture")
	ui.game.run=retained_resume.run
	ui._render()
	require(ui.hand_buttons[0].find_child("RetainMarker",true,false).text=="[R] EVERY TURN" and ui.hand_buttons[1].find_child("RetainMarker",true,false)==null,"Resume cannot resurrect expired one-discard marker")
	await check_retain_readability(ui)
	ui.game.run=retention_initial
	ui._render()
	ui._open_deck()
	for unused in range(3): await process_frame
	var inspected=[]
	collect_text(ui,inspected)
	require(inspected.has(intrinsic_text) and inspected.has(temporary_text),"Owned-copy inspection distinguishes exact intrinsic and temporary duration")
	ui._close_overlay()
	for unused in range(3): await process_frame
	var played_temporary=ui.game.run.battle.hand[1].duplicate(true)
	require(ui.game.play_card(1,[2],0).ok and ui._retain_marker(played_temporary).is_empty() and ui._retain_detail(played_temporary).is_empty(),"Playing consumes temporary UI duration even if that UID redraws")
	ui.game.run=retention_initial.duplicate(true)
	ui._render()
	for id in ["fixture_exhaust","fixture_install"]:
		require(ui._card_tip({"id":id,"level":0}).contains("returns next combat"),"Existing keyword glossary explains dedicated zone behavior")
	var showcase=ui.game.run.duplicate(true)
	for behavior in ["exhaust","install"]:
		Fixtures.battle(ui.game)
		Fixtures.identify(ui.game,0,"fixture_"+behavior)
		var prior=ui.game.run.duplicate(true)
		var played=ui.game.play_card(0,[0],0)
		var cues=ui._feedback_plan(prior,played,"card",[0],0,prior.battle.hand[0])
		require(cues.filter(func(cue): return cue.kind=="zone_card").size()==1 and not cues.any(func(cue): return cue.kind=="discard_card"),"Existing presentation distinguishes dedicated movement: "+behavior)
	ui.game.run=showcase
	ui.game.save()
	ui._render()
	var detached=ui.hand_buttons[0]
	detached.get_parent().remove_child(detached)
	detached._show_focus_tip()
	require(not is_instance_valid(detached.focus_tip),"Deferred keyword focus on a detached zone/retain card creates no tooltip")
	detached.free()
	ui._render()
	print("CARD ZONES: ",checks," checks, ",failures," failures (headless node assertions, not graphical evidence)")
	if OS.get_cmdline_user_args().has("--demo"):
		print("TEST FIXTURE DEMO ONLY: inspect four piles, [R] EVERY TURN and [R1] NEXT DISCARD. Close window to exit.")
		return
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	quit(1 if failures else 0)

func collect_text(node: Node, values: Array) -> void:
	if node is Label or node is Button: values.append(node.text)
	for child in node.get_children(): collect_text(child,values)

func check_retain_readability(ui) -> void:
	# Font/rectangle checks only, not a claim of native visual review.
	for window in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=window
		ui._render()
		for unused in range(5): await process_frame
		for index in [0,1]:
			for hover in [-1,index]:
				ui.hover_card=hover
				ui._arrange_hand()
				for unused in range(3): await process_frame
				var button=ui.hand_buttons[index]
				var marker=button.find_child("RetainMarker",true,false)
				if marker==null: continue
				var font=marker.get_theme_font("font")
				var size=int(marker.get_theme_font_size("font_size"))
				require(font.get_string_size(marker.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=marker.size.x,"Duration marker fits without truncation at "+str(window))
				require(font.get_height(size)<=marker.size.y and button.get_global_rect().encloses(marker.get_global_rect()),"Duration marker fits card height/bounds")
				var title=button.get_meta("title_label")
				require(not title.text.begins_with("[R"),"Duration marker does not consume card title width")
				require(title.get_line_count()<=2 and button.get_global_rect().encloses(title.get_global_rect()),"Retained card name fits without truncation at "+str(window))
