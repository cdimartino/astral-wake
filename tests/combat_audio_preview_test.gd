extends SceneTree
const Main = preload("res://scripts/main.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(not OS.get_environment("ASTRAL_SAVE_DIR").is_empty(), "Fresh isolated save required")
	var ui := Main.new()
	root.add_child(ui)
	ui.hull_audio.stop_all()
	ui.hull_audio.set_process(false)
	var bank: Dictionary = ui.hull_audio.bank.duplicate(true)
	for item in [["kinetic",16,0.30,0.76],["sonic",9,0.30,0.91]]:
		var cue := {"kind":"enemy_shot","style":item[0],"hp_delta":-int(item[1])}
		for launch in [true,false]:
			ui.combat_sound_times.clear()
			var count: int = ui.hull_audio.trace.size()
			ui._combat_sound(cue,launch)
			assert(ui.hull_audio.trace.size() == count + 1, "Exactly one production callback event")
			var voice: AudioStreamPlayer = ui.hull_audio.voices.back()
			assert(voice.get_meta("preview_event") == "enemy_" + str(item[0]) + ("_launch" if launch else "_hit"))
			assert(is_equal_approx(voice.volume_db, 6.0205999133))
			assert(is_equal_approx(voice.pitch_scale, 1.0), "Do not repitch the already authored gesture")
			assert(is_equal_approx(voice.stream.get_length(), float(item[2 if launch else 3])))
			ui._combat_sound(cue,launch)
			assert(ui.hull_audio.trace.size() == count + 1, "Split/duplicate callback is still throttled")
	ui.combat_sound_times.clear()
	var count: int = ui.hull_audio.trace.size()
	ui._combat_sound({"kind":"shield"})
	assert(ui.hull_audio.trace.size() == count + 1)
	assert(ui.hull_audio.voices.back().get_meta("preview_event") == "ward")
	assert(is_equal_approx(ui.hull_audio.voices.back().stream.get_length(),0.73))
	ui.combat_sound_times.clear()
	ui._combat_sound({"kind":"shot","style":"kinetic","hp_delta":-16},true)
	assert(not ui.hull_audio.voices.back().has_meta("preview_event"), "Original player attack remains")
	assert(ui.hull_audio.voices.back().get_meta("cue") == "combat_kinetic_launch")
	ui.combat_sound_times.clear()
	ui.hull_audio.muted["combat_shield"] = true
	count = ui.hull_audio.trace.size()
	ui._combat_sound({"kind":"shield"})
	assert(ui.hull_audio.trace.size() == count, "Mute cannot fall through to original")
	ui.hull_audio.muted.clear()
	ui.enemy_defeat_audio.combat_preview.set_enabled(false)
	ui.combat_sound_times.clear()
	ui._combat_sound({"kind":"enemy_shot","style":"kinetic","hp_delta":-16},true)
	assert(not ui.hull_audio.voices.back().has_meta("preview_event"), "Preview-off retains original path")
	assert(ui.hull_audio.bank == bank)
	ui.hull_audio.stop_all()
	ui.queue_free()
	await create_timer(0.6).timeout
	print("PASS actual Main._combat_sound routing: enemy kinetic/sonic launch+hit/ward, calibrated levels/durations, no original duplication, player path preserved, mute and preview-off")
	quit(0)
