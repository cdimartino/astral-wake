extends SceneTree
const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/evolution_fixtures.gd")
const Session = preload("res://tools/manual_session.gd")
const Selections = preload("res://scripts/known_selections.gd")
const Policy = preload("res://tests/playthrough.gd")
var checks=0
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("astral-evolutions-%d" % Time.get_ticks_usec())

func require(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _initialize() -> void: run_tests.call_deferred()

func game_at(suffix: String):
	var game=Fixtures.FixtureGame.new(directory.path_join(suffix))
	Fixtures.setup(game)
	return game

func workshop(game, shop: bool = false) -> void:
	game.run.mode="modify"
	game.run.modify_kind="upgrade"
	game.run.modify_return="shop" if shop else "recovery"
	if shop:
		game.run.shop={"items":[{"kind":"upgrade","id":"","cost":35,"sold":false}]}
		game.run.modify_shop_index=0
		game.run.salvage=50

func combat(game) -> void:
	game.run.mode="map"
	game.choose_node(game.run.map[0][0].id)
	var source=game.run.deck[0].duplicate(true)
	game.run.battle.hand=[source]
	game.run.battle.draw=game.run.deck.slice(1).duplicate(true)
	game.run.battle.discard=[]
	game.run.battle.enemies=[game._make_enemy("cinder_mite")]
	game.run.battle.enemies[0].hp=100
	game.run.battle.enemies[0].max_hp=100
	game.run.battle.command_points=1

func write_raw(game, state: Dictionary, name: String = "save.json") -> void:
	var file=FileAccess.open(game.store.directory.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"profile":game.profile,"run":state}))
	file.close()

func run_tests() -> void:
	var game=game_at("atomic")
	var uid=game.run.deck[0].uid
	workshop(game,true)
	var before=Session.snapshot(game.run)
	require(not game.modify_card(0).ok and Session.snapshot(game.run)==before,"One-argument API never defaults an authored branch or charges")
	for branch in ["", "legacy", "unknown"]:
		require(not game.evolve_card(uid,branch).ok and Session.snapshot(game.run)==before,"Invalid explicit branch is atomic: "+branch)
	require(not game.evolve_card(uid+0.5,"impact").ok,"Fractional UID is rejected")
	require(game.cancel_modify().ok and game.run.salvage==50 and not game.run.shop.items[0].sold,"Cancel costs nothing")
	require(not game.cancel_modify().ok and game.run.salvage==50,"Repeated cancellation is safe")
	workshop(game,true)
	game.run.salvage=34
	before=Session.snapshot(game.run)
	require(not game.evolve_card(uid,"flow").ok and Session.snapshot(game.run)==before,"Insufficient payment is atomic")
	game.run.salvage=50
	require(game.evolve_card(uid,"flow").ok and game.run.salvage==15 and game.run.shop.items[0].sold,"Explicit branch pays once")
	require(not game.evolve_card(uid,"impact").ok and game.run.salvage==15,"Repeated confirm cannot repay")
	workshop(game)
	require(not game.evolve_card(uid,"impact").ok and game.run.deck[0].evolution=="flow","Branches are mutually exclusive")
	require(game.effective_card(game.run.deck[0]).damage==10 and game.effective_card(game.run.deck[0]).draw==1,"Authored stats replace, never receive legacy +3")
	require(game.card_text(game.run.deck[0])=="Deal 10 damage. Draw 1 command.","Full text is the chosen branch")
	var detached=game.effective_card(game.run.deck[0])
	detached.damage=900
	require(not detached.has("evolutions") and game.effective_card(game.run.deck[0]).damage==10,"Detached, non-recursive effective definition")
	for branch in ["impact","flow"]:
		var trial=game_at(branch)
		require(trial.evolve_card(trial.run.deck[0].uid,branch).ok,"Recovery accepts explicit branch")
		combat(trial)
		var state=Session.snapshot(trial.run)
		trial._cards.needle.evolutions[0 if branch=="impact" else 1].stats.cost=2
		require(not trial.preview_card(0,[0],0).ok and Session.snapshot(trial.run)==state,"Authored CP replacement controls affordability without payment")
		trial._cards.needle.evolutions[0 if branch=="impact" else 1].stats.erase("cost")
		var preview=trial.preview_card(0,[0],0)
		require(preview.ok and state==Session.snapshot(trial.run),"Branch preview is pure at 1 CP")
		require(trial.play_card(0,[0],0)==preview and trial.run.battle.command_points==0,"Selected cost and preview match resolution")
		var amount=13 if branch=="impact" else 10
		require(trial.run.battle.last_command.base=={"damage":amount,"heal":0,"disrupt":0},"Plain payload is exact, without double upgrade")
		require(trial.run.battle.last_command.card.evolution==branch,"Last command preserves identity")
		require(trial.run.battle.hand.size()==(1 if branch=="flow" else 0),"Draw specialization uses existing draw primitive")
		require(trial._valid_run(trial.run),"Authored combat state validates")
		trial.save()
		var restored=Fixtures.FixtureGame.new(trial.store.directory)
		require(Session.snapshot(restored.run)==Session.snapshot(trial.run),"Branch and last command survive actual reload")
		var corrupt=trial.run.duplicate(true)
		corrupt.battle.last_command.card.evolution="flow" if branch=="impact" else "impact"
		require(not trial._valid_run(corrupt),"Last command mismatch rejected")
	validation(game)
	for branch in ["restore","cool"]:
		var repair=game_at("repair-"+branch)
		repair.run.deck[0].id="hull_stitch"
		require(repair.evolve_card(repair.run.deck[0].uid,branch).ok,"Repair fixture explicit branch")
		combat(repair)
		repair.run.hull=30
		repair.run.battle.strain=[1,1,1,1,1,1]
		var preview=repair.preview_card(0,[3],0)
		require(preview.ok and repair.play_card(0,[3],0)==preview,"Repair/cooling specialization preview matches actual at 1 CP")
		require(repair.run.battle.last_command.base.heal==(9 if branch=="restore" else 5),"Repair specialization preserves printed healing")
		require(repair.run.battle.strain[0]==(1 if branch=="restore" else 0),"Cooling specialization uses existing vent, not ward or new effects")
	migration()
	pending_migration()
	var production=Game.new(directory.path_join("production"))
	production.new_run("A1B2C3","palimpsest")
	workshop(production)
	require(not production.evolve_card(production.run.deck[0].uid,"").ok,"UID API requires an explicit identity even for legacy cards")
	require(production.modify_card(0).ok and production.run.deck[0].evolution=="legacy","Unbranched production keeps old one-argument behavior")
	var policy=Policy.new()
	policy.game=game_at("policy")
	# Isolate card ranking while checking scored and caller-supplied branch plans.
	for i in range(1,policy.game.run.deck.size()): policy.game.run.deck[i].level=1
	require(policy.plan_modify_branches()[policy.game.run.deck[0].uid]=="impact","Policy explicitly scores the fixture branches")
	require(policy.modify({policy.game.run.deck[0].uid:"flow"}).ok,"Policy fixture accepts an explicit branch mapping")
	policy.free()
	print("EVOLUTIONS_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func validation(game) -> void:
	var definition=game.card("needle")
	require(Game.Evolutions.valid_definition(definition),"Fixture schema accepted")
	for field in ["id","uid","art","evolutions","selections","engine","ward","refund","script"]:
		var bad=definition.duplicate(true)
		bad.evolutions[0].stats[field]=1
		require(not Game.Evolutions.valid_definition(bad),"Override allowlist rejects "+field)
	for identity in ["legacy", "flow", "", "BAD-ID"]:
		var bad=definition.duplicate(true)
		bad.evolutions[0].id=identity
		require(not Game.Evolutions.valid_definition(bad),"Reserved, duplicate and invalid branch identities rejected")
	var fraction=definition.duplicate(true)
	fraction.evolutions[0].stats.damage=13.5
	require(not Game.Evolutions.valid_definition(fraction),"Fractional authored stats rejected before integer restore")
	for instance in [{"id":"needle","uid":1,"level":1},{"id":"needle","uid":1,"level":0,"evolution":"impact"},{"id":"needle","uid":1,"level":1.5,"evolution":"impact"},{"id":"needle","uid":1,"level":1,"evolution":"cool"}]:
		require(not game._valid_instance(instance),"Current raw missing/foreign/mismatched evolution rejected")
	# All five zones use exactly the same identity validator, including installed.
	combat(game)
	for zone in Game.COMBAT_ZONES:
		var state=game.run.duplicate(true)
		var source=state.battle.hand.pop_front()
		state.battle[zone].append(source)
		if zone=="installed":
			source.id="fixture_evolving_install"
			state.deck[0].id=source.id
			state.battle.installed_sources=[{"source_uid":source.uid,"identity":"fixture_evolving_install"}]
		require(game._valid_run(state),"Valid branch in "+zone)
		write_raw(game,state)
		var restored=Fixtures.FixtureGame.new(game.store.directory)
		require(Session.snapshot(restored.run)==Session.snapshot(state),"Actual envelope reload preserves branch in "+zone)
		state.battle[zone][0].evolution="impact"
		require(not game._valid_run(state),"Zone/deck identity mismatch rejected in "+zone)
	game.save()
	var valid=game.run.duplicate(true)
	write_raw(game,valid,"save.backup.json")
	for mutation in ["fraction", "missing", "foreign", "level", "zone"]:
		var bad=valid.duplicate(true)
		match mutation:
			"fraction": bad.deck[0].level=0.5
			"missing": bad.deck[0].erase("evolution")
			"foreign": bad.deck[0].evolution="cool"
			"level": bad.deck[0].level=0
			"zone": bad.battle.hand[0].evolution="impact"
		write_raw(game,bad)
		var recovered=Fixtures.FixtureGame.new(game.store.directory)
		require(Session.snapshot(recovered.run)==Session.snapshot(valid) and recovered.save_error.contains("backup"),"Corrupted primary recovers validated backup without raw repair: "+mutation)
	var bad_backup=valid.duplicate(true)
	bad_backup.deck[0].evolution="unknown"
	write_raw(game,bad_backup,"save.backup.json")
	require(Fixtures.FixtureGame.new(game.store.directory).run.is_empty(),"Corrupt backup is rejected too; never silently reassign a branch")

func migration() -> void:
	var authored=game_at("old-authored")
	authored.run.schema_revision=4
	authored.run.deck[0].level=1
	require(authored._migrate_evolutions(authored.run) and authored.run.deck[0].evolution=="legacy", "Authoring branches never reassigns an old level-1 card to a sibling")
	require(authored.run.deck[1].level==0 and authored.evolution_choices(authored.run.deck[1]).size()==2,"Old level-0 cards stay eligible for authored choices")
	var game=Game.new(directory.path_join("migration"))
	game.new_run("A1B2C3")
	game.run.deck[0].level=1
	combat(game)
	game.play_card(0,[0],0)
	var old=game.run.duplicate(true)
	old.schema_revision=4
	var payload=old.battle.last_command.duplicate(true)
	write_raw(game,old)
	var restored=Game.new(game.store.directory)
	require(not restored.run.is_empty(),"Migration reload must succeed")
	if restored.run.is_empty(): return
	require(restored.run.schema_revision==5 and restored.run.deck[0].evolution=="legacy","Revision 4 missing level-1 identity migrates to reserved legacy")
	require(restored.run.battle.last_command.card.evolution=="legacy" and restored.run.battle.last_command.base==payload.base and restored.run.battle.last_command.resolved==payload.resolved,"Migration preserves recorded payloads")
	for zone in Game.COMBAT_ZONES:
		var state=old.duplicate(true)
		var source=state.battle.discard.pop_front()
		state.battle[zone].append(source)
		require(game._migrate_evolutions(state) and state.battle[zone].any(func(item): return item.get("evolution","")=="legacy"),"Migration covers "+zone)

func pending_migration() -> void:
	var game=Game.new(directory.path_join("pending"))
	preload("res://tests/selection_fixtures.gd").setup(game,"fixture_scrape")
	game.run.deck[0].level=1
	game.run.battle.hand[0].level=1
	require(game.begin_selection(game.run.deck[0].uid,[0],0,game.run.battle.enemies[0].duplicate(true)).ok,"Old pending fixture begins")
	var old=game.run.duplicate(true)
	old.schema_revision=4
	old.pending_selection.guard=Selections.guard(game,old,old.pending_selection)
	var damaged=old.duplicate(true)
	damaged.pending_selection.guard="wrong"
	require(not game._migrate_evolutions(damaged),"Old pending guard validated before migration")
	for corruption in ["definition","uid"]:
		damaged=old.duplicate(true)
		if corruption=="definition": damaged.pending_selection.definition.draw=99
		else: damaged.battle.hand[0].erase("uid")
		damaged.pending_selection.guard=Selections.guard(game,damaged,damaged.pending_selection)
		require(not game._migrate_evolutions(damaged),"Malformed old pending data rejected before refresh: "+corruption)
	require(game._migrate_evolutions(old) and game._valid_pending(old),"Pending effective definition and guard refresh after identity migration")
	old.pending_selection.definition.draw=99
	old.pending_selection.guard=Selections.guard(game,old,old.pending_selection)
	require(not game._valid_pending(old),"Even a refreshed guard cannot authorize a mismatched effective definition")
