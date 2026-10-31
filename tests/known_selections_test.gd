extends SceneTree
const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/selection_fixtures.gd")
const Session = preload("res://tools/manual_session.gd")
var checks=0
var failures=0
var base: String

func _initialize() -> void: call_deferred("test_all")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func fresh(id: String = "fixture_pair", modern: bool = true):
	var game=Fixtures.FixtureGame.new(base.path_join("game-%d"%checks))
	Fixtures.setup(game,id,modern)
	checks+=1
	return game
func begin(game, route: Array = [0]) -> Dictionary:
	return game.begin_selection(game.run.battle.hand[0].uid,route,0,game.run.battle.enemies[0].duplicate(true))
func unchanged(game, action: Callable, label: String) -> void:
	var before=Session.snapshot(game.run)
	var result: Dictionary=action.call()
	check(not result.ok,label+" rejected")
	check(Session.snapshot(game.run)==before,label+" no mutation")
func command(session, op: String, extra: Dictionary = {}) -> Dictionary:
	var value={"op":op,"expect":session.guard()}
	value.merge(extra)
	return session.apply(value)

func test_all() -> void:
	base=OS.get_environment("TMPDIR").path_join("known-selections-%d"%Time.get_ticks_usec())
	if not base.is_absolute_path(): base=OS.get_user_data_dir().path_join("known-selections-%d"%Time.get_ticks_usec())
	for modern in [true,false]:
		var game=fresh("fixture_pair",modern)
		var initial=Session.snapshot(game.run)
		var source=game.run.battle.hand[0].uid
		var exhaust=game.run.battle.hand[1].uid
		var retain=game.run.battle.hand[2].uid
		var retrieve=game.run.battle.discard[0].uid
		check(begin(game).ok,"begin pending")
		check(game.run.battle==initial.battle,"begin has no applied effects")
		unchanged(game,func(): return game.play_card(0,[0],0),"play blocked")
		unchanged(game,func(): return game.end_turn(),"turn blocked")
		unchanged(game,func(): return game.retain_card(retain),"direct retain blocked")
		unchanged(game,func(): return game.new_run("ABC123"),"replacement blocked")
		unchanged(game,func(): return game.abandon(),"abandon blocked")
		unchanged(game,func(): return game.select_uid(source),"source choice blocked")
		unchanged(game,func(): return game.select_uid(1.5),"fractional choice blocked")
		unchanged(game,func(): return game.select_uid(null),"required none blocked")
		unchanged(game,func(): return game.confirm_selection(),"incomplete confirm blocked")
		check(game.select_uid(exhaust).ok,"choose exhaust")
		check(game.select_uid(retain).ok,"choose retain")
		check(game.select_uid(retrieve).ok,"choose retrieve")
		var before=Session.snapshot(game.run)
		var preview=game.preview_selection()
		check(preview.ok and game.preview_selection()==preview,"selected preview repeatable")
		check(Session.snapshot(game.run)==before,"selected preview pure")
		check(game._valid_run(JSON.parse_string(JSON.stringify(game.run))),"raw JSON pending valid")
		game.save()
		var loaded=Fixtures.FixtureGame.new(game.store.directory)
		check(Session.snapshot(loaded.run)==before,"pending save resume exact")
		var result=loaded.confirm_selection()
		var visible=result.duplicate(true)
		for cue in visible.presentation:
			if cue.kind=="draw_card":
				cue.erase("card")
				cue.hidden=true
		check(visible==preview,"confirm equals chosen preview except hidden draw identities")
		check(preview.presentation.filter(func(e): return e.kind=="draw_card").all(func(e): return not e.has("card") and e.hidden),"selection preview never reveals drawn identity")
		check(loaded.run.battle.exhausted[0].uid==exhaust,"chosen exhaust enters dedicated zone")
		check(retain in loaded.run.battle.temporary_retain,"chosen retain marked")
		check(Game.Selections.index(loaded.run.battle.hand,retrieve)>=0,"chosen discard returns")
		check(result.presentation.any(func(e): return e.kind=="retrieve_card"),"distinct retrieval event")
		check(loaded._valid_run(loaded.run),"committed zones conserve UIDs")
		check(game.cancel_selection().ok,"cancel complete selection")
		check(Session.snapshot(game.run)==initial,"cancel gameplay and RNG unchanged")
		check(begin(game).ok and game.cancel_selection().ok,"begin cancel repeat")
		check(Session.snapshot(game.run)==initial,"no free reveal on cancellation")
	# Temporary marks clear on selected exhaust; hand choice never includes drawn UIDs.
	var game=fresh("fixture_scrape")
	var marked=game.run.battle.hand[1].uid
	game.retain_card(marked)
	check(begin(game).ok,"marked exhaust begin")
	check(not game.run.battle.draw[0].uid in game.selection_view().eligible,"draw is ineligible")
	check(game.select_uid(marked).ok and game.confirm_selection().ok,"marked exhaust commit")
	check(not marked in game.run.battle.temporary_retain,"exhaust clears temporary retain")
	# Failed source validation never grants a free exhaust, vent or retain.
	for reason in ["cp","route","target"]:
		game=fresh("fixture_scrape")
		match reason:
			"cp": game.run.battle.command_points=0
			"route": game.run.battle.strain[0]=3
			"target": game.run.battle.enemies[0].hp=0
		unchanged(game,func(): return game.play_card(0,[0],0,[game.run.battle.hand[1].uid]),"failed source "+reason)
	game=fresh("fixture_binding")
	var held=game.run.battle.hand[1].uid
	check(begin(game).ok and game.select_uid(held).ok and game.confirm_selection().ok,"selected retain commit")
	check(game.end_turn().ok and Game.Selections.index(game.run.battle.hand,held)>=0,"selected retain survives next discard")
	check(game.run.battle.temporary_retain.is_empty(),"selected retain duration expires at boundary")
	check(game._valid_run(game.run),"retain boundary conserves UIDs")
	game=fresh("fixture_pair")
	check(begin(game).ok,"ordered begin")
	var used=game.run.battle.hand[1].uid
	check(game.select_uid(used).ok and not used in game.selection_view().eligible,"ordered exhaust removed from retain eligibility")
	unchanged(game,func(): return game.select_uid(used),"duplicate choice")
	game.cancel_selection()
	game=fresh("fixture_pair")
	game.run.battle.draw.append_array(game.run.battle.hand.slice(2))
	game.run.battle.hand=game.run.battle.hand.slice(0,2)
	unchanged(game,func(): return begin(game),"no hand choice can complete later required retain")
	# Dedicated zones cannot be retrieved even when discard has no candidates.
	game=fresh("fixture_reprise")
	game.run.battle.exhausted.append_array(game.run.battle.discard)
	game.run.battle.discard=[]
	unchanged(game,func(): return begin(game),"exhausted is not discard")
	# Empty required versus optional and effective kind filters.
	game=fresh("fixture_attack")
	game.run.battle.draw.append_array(game.run.battle.discard)
	game.run.battle.discard=[]
	unchanged(game,func(): return begin(game),"empty required discard")
	game=fresh("fixture_repair")
	game.run.battle.draw.append_array(game.run.battle.discard)
	game.run.battle.discard=[]
	check(begin(game).ok and game.selection_view().eligible==[null],"empty optional explicitly none")
	check(game.select_uid(null).ok and game.confirm_selection().ok,"authored none commits")
	game=fresh("fixture_repair")
	game.run.battle.discard[0].id="hull_stitch"
	for instance in game.run.deck:
		if instance.uid==game.run.battle.discard[0].uid: instance.id="hull_stitch"
	check(begin(game).ok and game.selection_view().eligible==[game.run.battle.discard[0].uid,null],"repair filter positive and optional none")
	check(game.select_uid(game.run.battle.discard[0].uid).ok and game.confirm_selection().ok,"filtered repair return commits")
	game=fresh("fixture_attack")
	game.run.battle.discard[0].id="hull_stitch"
	for instance in game.run.deck:
		if instance.uid==game.run.battle.discard[0].uid: instance.id="hull_stitch"
	unchanged(game,func(): return begin(game),"attack filter excludes repair")
	# Full ten-card hand plus an additional owned discard. Source vacates one slot.
	game=fresh("fixture_reprise")
	game.run.battle.hand=game.run.deck.duplicate(true)
	game.run.battle.draw=[]
	var extra=game._instance(game.run,"needle")
	game.run.deck.append(extra)
	game.run.battle.discard=[extra.duplicate(true)]
	var rng=game.run.rng_streams.duplicate(true)
	check(begin(game).ok,"hand ten can retrieve into source slot")
	check(game.select_uid(extra.uid).ok and game.confirm_selection().ok,"hand ten retrieval succeeds")
	check(game.run.battle.hand.size()==10 and Game.Selections.index(game.run.battle.hand,extra.uid)>=0,"retrieved UID kept at cap")
	check(game.run.rng_streams==rng,"cap suppresses draw and shuffle")
	check(game._valid_run(game.run),"cap conservation")
	# Two retrievals cannot overflow the single source-vacated slot.
	game=fresh("fixture_reprise")
	game._cards.fixture_reprise.selections=[{"kind":"return_discard"},{"kind":"return_discard"}]
	game.run.battle.hand=game.run.deck.duplicate(true)
	game.run.battle.draw=[]
	game.run.battle.discard=[]
	for unused in range(2):
		var item=game._instance(game.run,"needle")
		game.run.deck.append(item)
		game.run.battle.discard.append(item.duplicate(true))
	unchanged(game,func(): return begin(game),"multiple retrieval overflow rejects preflight")
	# Stale source/route/target/CP and raw metadata reject without clearing pending.
	for field in ["route","target","cost","source"]:
		game=fresh("fixture_binding")
		check(begin(game).ok,"stale begin")
		check(game.select_uid(game.run.battle.hand[1].uid).ok,"stale chosen")
		match field:
			"route": game.run.battle.strain[0]=3
			"target": game.run.battle.enemies[0].hp-=1
			"cost": game.run.battle.command_points=0
			"source": game.run.battle.hand[0].level=1
		unchanged(game,func(): return game.confirm_selection(),"stale "+field)
		check(game.cancel_selection().ok,"stale cancellable")
	game=fresh("fixture_binding")
	check(begin(game).ok,"raw validation begin")
	for change in ["uid","route","legal_route_change","choice","legal_choice_prefix","extra","definition","guard","target"]:
		var raw=JSON.parse_string(JSON.stringify(game.run))
		match change:
			"uid": raw.pending_selection.source_uid+=0.25
			"route": raw.pending_selection.route[0]=0.5
			"legal_route_change": raw.pending_selection.route=[1]
			"choice": raw.pending_selection.choices=[2.5]
			"legal_choice_prefix": raw.pending_selection.choices=[raw.battle.hand[1].uid]
			"extra": raw.pending_selection.extra=1
			"definition": raw.pending_selection.definition.cost=1.5
			"guard": raw.pending_selection.guard="stale"
			"target": raw.pending_selection.target_guard.hp+=0.5
		check(not game._valid_run(raw),"raw malformed pending "+change)
	check(game.cancel_selection().ok,"raw fixture cancel")
	# Real malformed primary falls back to an exact pending backup.
	check(begin(game).ok,"backup pending begin")
	var pending=game.run.duplicate(true)
	var envelope={"version":1,"profile":game.profile,"run":pending}
	var backup=FileAccess.open(game.store.directory.path_join("save.backup.json"),FileAccess.WRITE)
	backup.store_string(JSON.stringify(envelope))
	backup.close()
	envelope.run=pending.duplicate(true)
	envelope.run.pending_selection.route[0]=0.5
	var primary=FileAccess.open(game.store.directory.path_join("save.json"),FileAccess.WRITE)
	primary.store_string(JSON.stringify(envelope))
	primary.close()
	var recovered=Fixtures.FixtureGame.new(game.store.directory)
	check(recovered.run==pending and recovered.save_error.contains("backup"),"raw malformed pending recovers exact backup")
	check(game.cancel_selection().ok,"backup fixture cancel")
	var old=game.run.duplicate(true)
	old.schema_revision=2
	old.erase("pending_selection")
	game.store.write(game.profile,old)
	var migrated=Fixtures.FixtureGame.new(game.store.directory)
	check(migrated.run.schema_revision==3 and migrated.run.pending_selection=={},"explicit zones migration")
	# Selected repair does not revive a lethal repeated-route mark.
	game=fresh("fixture_binding")
	game.run.hull=1
	game.run.battle.mark=2
	game.run.battle.last_route=[0]
	check(begin(game).ok and game.select_uid(game.run.battle.hand[1].uid).ok,"lethal route chosen")
	check(game.confirm_selection().ok and game.run.mode=="defeat" and game.run.hull==0,"death precedence preserved")
	# Real Palimpsest pool and route: selected preview includes Trace, without
	# applying or revealing source draws before confirmation.
	game=fresh("fixture_binding")
	var trace_card=game.card("first_draft").duplicate(true)
	trace_card.merge({"id":"fixture_trace","name":"Fixture Trace Hold","selections":[{"kind":"retain_hand"}],"trace":2,"draw":1,"cost":1},true)
	game._cards.fixture_trace=trace_card
	game.new_run("A1B2C3","palimpsest")
	game.choose_node(game.run.map[0][0].id)
	game.run.battle.hand=game.run.deck.slice(0,5).duplicate(true)
	game.run.battle.draw=game.run.deck.slice(5).duplicate(true)
	game.run.battle.discard=[]
	Fixtures.Zones.identify(game,0,"fixture_trace")
	check(begin(game).ok and game.select_uid(game.run.battle.hand[1].uid).ok,"Trace fixture selection")
	var trace_before=Session.snapshot(game.run)
	var trace_preview=game.preview_selection()
	check(trace_preview.ok and trace_preview.trace==4 and Session.snapshot(game.run)==trace_before,"chosen Trace preview pure and includes source plus route")
	check(game.confirm_selection().trace==trace_preview.trace and game._valid_run(game.run),"Trace confirm agrees and remains valid")
	test_manual()
	await test_ui()
	print("KNOWN_SELECTIONS_TEST %d checks, %d failures"%[checks,failures])
	if "--demo" in OS.get_cmdline_user_args() and failures==0:
		var ui=load("res://main.tscn").instantiate()
		root.add_child(ui)
		ui.game=Fixtures.FixtureGame.new(base.path_join("demo"))
		Fixtures.setup(ui.game)
		ui.menu=false
		ui._render()
		return
	quit(1 if failures else 0)

func find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.begins_with(prefix): return child
		var found=find_button(child,prefix)
		if found!=null: return found
	return null

func test_ui() -> void:
	var ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.game=fresh("fixture_binding")
	ui.menu=false
	ui._render()
	for window in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=window
		ui._select_card(0)
		ui._select_organ(0)
		var open=find_button(ui.page,"Choose cards")
		check(open!=null and not open.disabled,"UI exposes chooser action")
		ui._confirm()
		for unused in range(4): await process_frame
		check(is_instance_valid(ui.overlay) and ui.game.selection_pending(),"chooser modal opens")
		check(ui.page.focus_behavior_recursive==Control.FOCUS_BEHAVIOR_DISABLED,"underlying focus restricted")
		check(ui.overlay.is_ancestor_of(root.gui_get_focus_owner()),"keyboard focus inside chooser")
		var first=find_button(ui.overlay,"UID ")
		check(first!=null and first.get_global_rect().end.x<=ui.get_viewport_rect().size.x,"choice fits viewport width")
		first.pressed.emit()
		for unused in range(4): await process_frame
		var confirm=find_button(ui.overlay,"Confirm · spend 1 CP")
		check(confirm!=null and not confirm.disabled,"explicit CP commitment button")
		check(root.gui_get_focus_owner()==confirm,"complete choice focuses confirm")
		var before=ui.game.run.battle.duplicate(true)
		var escape=InputEventKey.new()
		escape.pressed=true
		escape.keycode=KEY_ESCAPE
		ui._input(escape)
		check(not ui.game.selection_pending() and ui.game.run.battle==before,"Escape cancels without battle mutation")
		ui._select_card(0)
		ui._select_organ(0)
		ui._confirm()
		ui.game.select_uid(ui.game.run.battle.hand[1].uid)
		ui.game.save()
		ui.game=Fixtures.FixtureGame.new(ui.game.store.directory)
		ui._clear_selection()
		ui._render()
		for unused in range(3): await process_frame
		check(find_button(ui.overlay,"Confirm · spend 1 CP")!=null,"resume UI restores full chooser")
		ui._cancel_choice()
	ui.audio.stop()
	ui.ambience.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(4): await process_frame

func test_manual() -> void:
	var session=Fixtures.FixtureSession.new()
	check(session.start(base.path_join("manual"),"A1B2C3","cartographer",0).ok,"manual fixture start")
	var g=session.game
	var args={"uid":g.run.battle.hand[0].uid,"route":[0],"target":{"slot":0,"id":g.run.battle.enemies[0].id}}
	check(command(session,"begin_selection",args).ok,"manual begin")
	check(not command(session,"end_turn").ok,"manual blocked error recorded")
	check(not command(session,"select_uid",{"choice_uid":2.5}).ok,"manual fractional error recorded")
	check(command(session,"cancel_selection").ok,"manual cancel")
	check(command(session,"begin_selection",args).ok,"manual reopen")
	check(command(session,"select_uid",{"choice_uid":g.run.battle.hand[1].uid}).ok,"manual exhaust")
	check(command(session,"select_uid",{"choice_uid":g.run.battle.hand[2].uid}).ok,"manual retain")
	check(command(session,"select_uid",{"choice_uid":g.run.battle.discard[0].uid}).ok,"manual retrieve")
	var trace=session.journal.duplicate(true)
	check(command(session,"selection_preview").ok and session.journal==trace,"manual preview not journaled")
	var path=base.path_join("trace.json")
	check(session.write(path).ok,"write pending journal")
	var resumed=Fixtures.FixtureSession.new()
	check(resumed.resume(base.path_join("manual"),path).ok,"resume pending guarded manual context")
	check(command(resumed,"confirm_selection").ok,"manual confirm")
	check(resumed.write(path).ok,"write confirmed journal")
	var replay=Fixtures.FixtureSession.new()
	var result=replay.replay(path,base.path_join("replay"))
	check(result.ok,"manual exact replay "+str(result.get("error","")))
