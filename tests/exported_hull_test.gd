extends SceneTree
## Load the exported PCK with the pinned engine's --main-pack and --script,
## outside the source project (release templates omit --script). Supply a
## fresh ASTRAL_SAVE_DIR and a copy of the runtime bank in
## <save>/hull_audio/banks/listening/. No original project WAVs are loaded.
var errors := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save := OS.get_environment("ASTRAL_SAVE_DIR")
	if save.is_empty() or FileAccess.file_exists("res://tests/exported_hull_test.gd"):
		push_error("Use the exported pack and an isolated save directory")
		quit(1)
		return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var hull = scene.hull_audio
	check(hull.options("scores").has("region_2") and hull.score_id.is_empty(), "Packaged bank loads without starting menu music")
	scene._enter_admin()
	var admin = scene.hull_admin
	check(admin.active and is_instance_valid(scene.hull_desk), "Exported build opens the real Sound Desk")
	var bank_name: String = admin.execute("audio bank listening")
	check(bank_name == "Bank active: listening", "External PCM bank switch in exported app: " + bank_name)
	hull.set_score("region_2")
	await create_timer(.35).timeout
	var cursor: float = hull.score_time
	var versions: Array = hull.bank.cues.combat_shield.variants
	admin.execute("audio bind combat_shield " + str(versions[1]))
	admin.execute("audio audition combat_shield")
	check(hull.trace.back().patch == versions[1] and hull.score_time >= cursor, "Live patch swap leaves timeline in place")
	var indicator := scene.hull_desk.find_child("PlayingIndicator", true, false) as Label
	# process_frame is emitted before the desk's _process; allow one complete
	# draw/update cycle before observing the visible indicator.
	for i in 3: await process_frame
	check(indicator != null and indicator.text.contains("combat_shield"), "Packaged desk highlights the auditioned shield")
	var bad: String = admin.execute("audio bank not-present")
	check(bad != "Bank active: not-present" and hull.bank_path.contains("listening"), "A bad pack leaves the playing bank intact")
	var stored: String = admin.execute("audio preset save export-test")
	check(stored.contains("export-test"), "Saved named preset in an exported build")
	admin.execute("audio bank factory")
	check(hull.bank_path.begins_with("res://") and hull.score_time >= cursor, "Return to imported assets without restarting")
	scene._leave_admin()
	check(not admin.active, "Original session restored")
	hull.stop_all()
	scene.queue_free()
	await process_frame
	await create_timer(.4).timeout
	print("EXPORTED SOUND WORKSHOP: %d failures" % errors)
	quit(1 if errors else 0)
