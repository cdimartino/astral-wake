extends SceneTree
## Isolated production callback/committed-resolution audio evidence, not a
## recorded ordinary expedition. Headless Master-bus capture avoids unrelated
## renderer/shader initialization; apply only the unchanged Master fader to PCM.
const Main = preload("res://scripts/main.gd")
var ui
var elapsed := 0.0
var events: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var cursor := 0
var folder := OS.get_environment("ASTRAL_CAPTURE_OUT")
var mode := OS.get_environment("ASTRAL_CAPTURE_MODE")
var capture := AudioEffectCapture.new()
var samples := PackedVector2Array()
var capture_index := -1
var master_db := 0.0

func _initialize() -> void:
	assert(not folder.is_empty() and not OS.get_environment("ASTRAL_SAVE_DIR").is_empty())
	_run.call_deferred()

func _process(delta: float) -> bool:
	elapsed += delta
	if capture_index >= 0:
		var available := capture.get_frames_available()
		if available: samples.append_array(capture.get_buffer(available))
	if is_instance_valid(ui):
		while cursor < ui.hull_audio.trace.size():
			var entry: Dictionary = ui.hull_audio.trace[cursor].duplicate(true)
			entry["capture_seconds"] = elapsed
			entry["captured_audio_seconds"] = float(samples.size()) / AudioServer.get_mix_rate()
			trace.append(entry)
			cursor += 1
	return false

func _run() -> void:
	root.size = Vector2i(64,64)
	ui = Main.new()
	root.add_child(ui)
	ui.hide()
	await process_frame
	assert(ui.game.new_run("DTHQAA","cartographer").get("ok",false))
	ui.game.choose_node(ui.game.run.map[0][0].id)
	ui.menu = false
	ui.game.profile.settings.volume = 0.7 if mode == "defeats" else 0.5
	ui.game.profile.settings.music_volume = 0.22 if mode == "defeats" else 1.0
	ui.game.profile.settings.combat_volume = 1.0
	ui.game.profile.settings.reduced_motion = false
	ui._apply_settings()
	ui._render()
	master_db = AudioServer.get_bus_volume_db(0)
	capture.buffer_length = 2.0
	capture_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	if mode == "defeats":
		var enemies: Array = []
		for definition in ui.game.catalog.enemies:
			if definition.role != "regular": continue
			var enemy: Dictionary = ui.game._make_enemy(str(definition.id))
			enemy.hp = 5
			enemies.append(enemy)
			if enemies.size() == 2: break
		ui.game.run.battle.enemies = enemies
		ui.game.run.battle.hand = [{"id":"needle","level":0,"uid":91001},{"id":"needle","level":0,"uid":91002}]
		ui._render()
		await create_timer(3.5).timeout
		await _kill("ordinary committed defeat")
		assert(ui.game.run.mode == "combat")
		await create_timer(3.3).timeout
		await _kill("committed encounter clear")
		assert(ui.game.run.mode == "reward")
		await create_timer(4.5).timeout
	else:
		await create_timer(0.3).timeout
		ui.hull_audio.stop_all()
		await _at(1.833333)
		_callback({"kind":"shield"},false,"ward")
		await _at(3.333333)
		_callback({"kind":"enemy_shot","style":"kinetic","hp_delta":-16},true,"enemy kinetic launch")
		await _at(3.633333)
		_callback({"kind":"enemy_shot","style":"kinetic","hp_delta":-16},false,"enemy kinetic strike")
		await _at(5.066667)
		_callback({"kind":"enemy_shot","style":"sonic","hp_delta":-9},true,"enemy sonic launch")
		await _at(5.366667)
		_callback({"kind":"enemy_shot","style":"sonic","hp_delta":-9},false,"enemy sonic strike")
		await _at(7.2)
		_callback({"kind":"shot","style":"kinetic","hp_delta":-16},true,"unchanged player kinetic launch")
		await _at(7.5)
		_callback({"kind":"shot","style":"kinetic","hp_delta":-16},false,"unchanged player kinetic hit")
		await _at(8.6)
	var counts := {}
	for entry in trace:
		if entry.has("preview_event"):
			counts[entry.preview_event] = int(counts.get(entry.preview_event,0)) + 1
	if mode == "defeats":
		assert(counts.get("kill",0) == 2 and counts.get("clear",0) == 1)
	else:
		for key in ["ward","enemy_kinetic_launch","enemy_kinetic_hit","enemy_sonic_launch","enemy_sonic_hit"]:
			assert(counts.get(key,0) == 1, "Exactly one replacement, no original duplicate")
	var file := FileAccess.open(folder.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"events":events,"trace":trace,"counts":counts,
		"game_mode":ui.game.run.mode,"seconds":elapsed,
		"audio_rate":AudioServer.get_mix_rate(),"audio_frames":samples.size(),"master_db":master_db,
		"classification":"Actual current Main callbacks; defeats use staged low HP with genuine committed cards; enemy attack sampler explicitly invokes presentation callbacks, not an AI-play claim"}, "  "))
	file.close()
	assert(ui.enemy_defeat_audio.combat_preview.last_error.is_empty())
	assert(capture.get_discarded_frames() == 0)
	assert(is_equal_approx(AudioServer.get_bus_volume_db(0),master_db))
	var data := PackedByteArray()
	data.resize(samples.size()*4)
	var master_gain := db_to_linear(master_db)
	for i in range(samples.size()):
		var frame := samples[i]*master_gain
		assert(absf(frame.x)<1.0 and absf(frame.y)<1.0)
		data.encode_s16(i*4,roundi(frame.x*32767))
		data.encode_s16(i*4+2,roundi(frame.y*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = true
	wav.data = data
	assert(wav.save_to_wav(folder.path_join("take.wav")) == OK)
	AudioServer.remove_bus_effect(0,capture_index)
	capture_index = -1
	ui.hull_audio.stop_all()
	ui.queue_free()
	await create_timer(0.6).timeout
	print("PASS production capture ",mode," counts=",counts," seconds=",elapsed)
	quit(0)

func _at(seconds: float) -> void:
	while elapsed < seconds: await process_frame

func _callback(cue: Dictionary, launch: bool, label: String) -> void:
	events.append({"label":label,"seconds":elapsed,"captured_audio_seconds":float(samples.size())/AudioServer.get_mix_rate()})
	ui._combat_sound(cue,launch)

func _kill(label: String) -> void:
	ui.selected_card = 0
	ui.route.clear()
	ui.route.append(0)
	ui.target = 0
	ui._render()
	await create_timer(1.0).timeout
	var at := elapsed
	ui._perform(func(): return ui.game.play_card(0,[0],0),"command")
	assert(ui.presentation_busy())
	assert(ui.last_feedback.any(func(cue):return cue.kind == "defeat"))
	events.append({"label":label,"seconds":at,"cues":ui.last_feedback.duplicate(true)})
	await create_timer(ui.presentation_duration + 0.25).timeout
	assert(not ui.presentation_busy())
