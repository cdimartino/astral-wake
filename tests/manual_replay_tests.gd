extends SceneTree
const Session = preload("res://tools/manual_session.gd")
const Game = preload("res://scripts/game.gd")
var checks = 0
var failures = 0
var directory = OS.get_environment("TMPDIR").path_join("astral-manual-%d" % Time.get_ticks_usec())

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func command(session, op: String, fields: Dictionary = {}) -> Dictionary:
	var value = fields.duplicate(true)
	value.op = op
	value.expect = session.guard()
	# Exercise the public JSON boundary, including its float representation of ints.
	return JSON.parse_string(JSON.stringify(value))

func play(session, uid: int, op = "play", slot = 0) -> Dictionary:
	return command(session, op, {"uid":uid, "route":[0], "target":{"slot":slot, "id":session.game.run.battle.enemies[slot].id}})

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var session = Session.new()
	var saves = directory.path_join("original/saves")
	require(session.start(saves, "A1B2C3", "cartographer", 3).ok, "Explicit practice session starts")
	require(session.game.run.pool_tier == Game.SeedEngine.decode("A1B2C3") % 4, "Practice discovery pool remains seed-encoded")
	var first_node = session.game.run.map[0][0].id
	require(session.apply(command(session, "choose_node", {"node":first_node})).ok, "Manual destination selection")
	var original_hand = session.game.run.battle.hand.duplicate(true)
	var stale = play(session, original_hand[1].uid)
	var before = session.game.run.duplicate(true)
	var trace = session.journal.duplicate(true)
	for i in range(5): require(session.apply(play(session, original_hand[0].uid, "preview")).ok, "Preview succeeds")
	require(session.game.run == before and session.journal == trace, "Preview leaves all state, RNG, trace and guard untouched")
	var invalid_preview = play(session, 999999, "preview")
	require(not session.apply(invalid_preview).ok and session.journal == trace, "Failed preview is also pure")
	require(session.apply(play(session, original_hand[0].uid)).ok, "First stable UID played")
	before = session.game.run.duplicate(true)
	require(not session.apply(stale).ok and session.game.run == before, "Queued selection rejected after hand shifts")
	require(session.journal.errors.size() == 1 and session.journal.entries.size() == 2, "Diagnostics separate from committed actions")
	var second = play(session, original_hand[1].uid)
	require(session.apply(second).ok, "Fresh guard plays original second UID, now at shifted index zero")
	var last = session.journal.entries.back()
	require(last.effective_card.id == original_hand[1].id and not session.game.run.battle.hand.any(func(item): return item.uid == original_hand[1].uid), "Intended card definition recorded and intended instance removed")
	before = session.game.run.duplicate(true)
	require(not session.apply(play(session, original_hand[0].uid)).ok and session.game.run == before, "Removed UID never falls back to hand index")
	var malformed = command(session, "play", {"uid":1, "route":[0.5], "target":{"slot":0,"id":session.game.run.battle.enemies[0].id}})
	require(not session.apply(malformed).ok, "Fractional route rejected without truncation")
	require(not session.apply(command(session, "end_turn", {"hand_index":0})).ok, "Index-based and unexpected fields rejected")
	require(session.apply(command(session, "end_turn")).ok, "Explicit turn end")
	var path = directory.path_join("original/trace.json")
	require(session.write(path).ok, "Journal persisted")
	var resumed = Session.new()
	require(resumed.resume(saves, path).ok and resumed.guard() == session.guard(), "Real save/load preserves guard and all RNG")
	require(not Session.new().start(saves, "ABC123", "cartographer", 0).ok, "Active run never silently restarted")
	var ending = command(session, "abandon")
	require(session.apply(ending).ok and resumed.apply(ending).ok, "Resumed and uninterrupted commands both succeed")
	require(Session.snapshot(session.game.run) == Session.snapshot(resumed.game.run), "Resume outcome matches uninterrupted execution")
	require(session.write(path).ok, "Final trace saved")
	var replayed = Session.new()
	require(replayed.replay(path, directory.path_join("replayed/saves")).ok, "Deterministic replay verifies successes, errors, guards, snapshots, definitions and RNG")
	require(replayed.journal == session.journal, "Full journal round trip")
	require(not Session.new().resume(directory.path_join("missing/saves"), path).ok, "Missing save is not restarted")
	var tampered = session.journal.duplicate(true)
	tampered.entries[0].after.hull -= 1
	var tampered_path = directory.path_join("tampered.json")
	write_json(tampered_path, tampered)
	require(not Session.new().replay(tampered_path, directory.path_join("diverged/saves")).ok, "Snapshot divergence rejected")
	tampered = session.journal.duplicate(true)
	tampered.environment.sources["data/catalog.json"] = "wrong"
	write_json(tampered_path, tampered)
	require(not Session.new().replay(tampered_path, directory.path_join("wrong-content/saves")).ok, "Content identity mismatch rejected")
	tampered = session.journal.duplicate(true)
	tampered.errors.append("malformed")
	write_json(tampered_path, tampered)
	require(not Session.new().resume(saves, tampered_path).ok, "Malformed trace rejected without a script exception")
	tampered = session.journal.duplicate(true)
	tampered.entries[0].sequence = 99
	write_json(tampered_path, tampered)
	require(not Session.new().resume(saves, tampered_path).ok, "Broken journal ordering rejected on resume")
	require(not Session.new().start(saves, "ABC123", "cartographer", 0).ok, "Completed save also never overwritten")
	var legacy = Session.new()
	require(legacy.start(directory.path_join("legacy/saves"), 777, "cartographer", 0).ok, "Legacy seed supported without translating to practice code")
	require(legacy.apply(command(legacy, "choose_node", {"node":legacy.game.run.map[0][0].id})).ok, "Legacy combat starts")
	var legacy_path = directory.path_join("legacy/trace.json")
	require(legacy.write(legacy_path).ok and Session.new().replay(legacy_path, directory.path_join("legacy-replay/saves")).ok, "Legacy string RNG state replays exactly")
	check_enemy_identity()
	check_noncombat()
	print("MANUAL_REPLAY_TESTS ", checks, " checks, ", failures, " failures; isolated saves: ", directory)
	quit(1 if failures else 0)

func write_json(path: String, value) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func check_enemy_identity() -> void:
	var session = Session.new()
	session.start(directory.path_join("enemy/saves"), "A1B2C3", "cartographer", 0)
	session.game.choose_node(session.game.run.map[0][0].id)
	var battle = session.game.run.battle
	battle.enemies.append(battle.enemies[0].duplicate(true))
	var uid = battle.hand[0].uid
	var queued = play(session, uid, "play", 1)
	var before = Session.snapshot(session.game.run)
	require(session.apply(play(session, uid, "preview", 1)).ok and Session.snapshot(session.game.run) == before, "Duplicate enemy types selectable only with explicit guarded slot")
	battle.enemies.remove_at(0)
	before = Session.snapshot(session.game.run)
	require(not session.apply(queued).ok and Session.snapshot(session.game.run) == before, "Enemy removal invalidates queued duplicate-type target")
	var bad = play(session, uid)
	bad.target.id = "different_type"
	require(not session.apply(bad).ok, "Fresh state cannot excuse incorrect enemy identity")
	var ambiguous = play(session, uid)
	ambiguous.target.erase("slot")
	require(not session.apply(ambiguous).ok, "Enemy type alone is ambiguous and rejected")

func check_noncombat() -> void:
	# Authored fixtures exercise the adapter's noncombat API, not a gameplay policy.
	var session = Session.new()
	session.start(directory.path_join("noncombat/saves"), "A1B2C3", "palimpsest", 0)
	var state = session.game.run
	state.mode = "recovery"
	require(session.apply(command(session, "recover", {"choice":"upgrade"})).ok, "Recovery opens evolution")
	var uid = state.deck[2].uid
	var before = Session.snapshot(state)
	require(not session.apply(command(session, "modify", {"uid":uid})).ok and Session.snapshot(state)==before, "Authored Palimpsest requires explicit branch without mutation")
	require(session.apply(command(session, "modify", {"uid":uid,"branch":"inscribed_margin"})).ok and state.deck[2].level == 1 and state.deck[2].evolution=="inscribed_margin", "Evolution uses stable deck UID and named branch")
	state.mode = "reward"
	state.reward = {"boss":false, "choices":[{"kind":"card", "id":"needle"}]}
	require(session.apply(command(session, "reward", {"choice":-1})).ok and state.mode == "map", "Explicit reward skip")
	session.game._make_shop()
	require(session.apply(command(session, "buy", {"choice":0})).ok, "Explicit shop choice")
	require(session.apply(command(session, "leave")).ok, "Explicit leave")
	state.mode = "transition"
	# Begin a new authored fixture chain after the direct state setup above.
	# Unlike the unmodified seed trace tested earlier, this is not a seed replay.
	session.journal.initial = Session.snapshot(state)
	session.journal.entries.clear()
	session.journal.errors.clear()
	require(session.apply(command(session, "continue_region")).ok and state.region == 1, "Explicit region transition preserves generated RNG")
	var path = directory.path_join("noncombat/trace.json")
	session.write(path)
	var resumed = Session.new()
	require(resumed.resume(session.game.store.directory, path).ok and resumed.guard() == session.guard(), "Noncombat save/resume preserves trace guard")
