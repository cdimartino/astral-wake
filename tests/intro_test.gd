extends SceneTree
## Run the actual movie, sampler and title together. With --skip, hand off
## while a note is playing. Optional ASTRAL_INTRO_TAKE saves the mixer capture.
const Main = preload("res://scripts/main.gd")
var completed := 0
var failures := 0
var pcm := PackedByteArray()

func check(value: bool, why: String) -> void:
	if not value:
		failures += 1
		push_error(why)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO", "1")
	OS.set_environment("ASTRAL_SAVE_DIR", OS.get_temp_dir().path_join("hull-intro-%d" % Time.get_ticks_usec()))
	var ui = Main.new()
	root.add_child(ui)
	check(ui.hull_audio.score_id.is_empty(), "Direct launch does not start the legacy title score")
	check(ui.title_audio.active and ui.title_audio._player.playing, "Direct launch plays the approved title breath")
	check(ui.title_audio._player.bus == "Music", "Title breath obeys Music settings")
	check(ui.title_audio._player.stream.loop_begin == ui.title_audio.INTRO_FRAMES and ui.title_audio._player.stream.loop_end == ui.title_audio.LOOP_END, "Only the breath tail loops, never the opening gesture")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 24
	AudioServer.add_bus_effect(0, capture)
	ui._start_opening()
	var film = ui.opening_film
	film.finished.connect(func(): completed += 1)
	var skip := "--skip" in OS.get_cmdline_user_args()
	var start := Time.get_ticks_msec()
	check(film.video.volume == 0.0, "No embedded audio doubles the opening")
	while completed == 0 and Time.get_ticks_msec() - start < 16500:
		await process_frame
		if skip and is_instance_valid(film) and Time.get_ticks_msec() - start >= 1100 and not film.ending:
			film.skip()
			film.skip()
	var elapsed := Time.get_ticks_msec() - start
	check(completed == 1 and elapsed < (3500 if skip else 16000), "Film reaches title exactly once")
	check(ui.hull_audio.score_id.is_empty(), "No legacy score doubles the approved title audio")
	check(ui.title_audio.active and ui.title_audio._player.playing, "Opening hands off to the continuing title breath")
	var starts := 0
	for event in ui.hull_audio.trace:
		if event.cue == "score_keel_tap": starts += 1
	check(starts == 0, "Rendered opening replaces the legacy synthesized contact")
	await create_timer(2.2).timeout
	ui._render()
	ui._request_new()
	check(ui.hull_audio.score_id.is_empty(), "Ship selection does not restart legacy menu ambience")
	check(ui.title_audio.active and ui.title_audio._player.playing, "Ship selection retains the approved breath")
	check(ui.title_audio._player.get_playback_position() >= ui.title_audio.INTRO_FRAMES / ui.title_audio.RATE - 0.1, "Title settles into the breath tail after full playback or skip")
	var frames := capture.get_buffer(capture.get_frames_available())
	check(frames.size() > AudioServer.get_mix_rate() * 2, "Real audio mixer produced opening and menu")
	var peak := 0.0
	var idle := 0.0
	for i in frames.size():
		var v := maxf(absf(frames[i].x), absf(frames[i].y))
		peak = maxf(peak, v)
		if i >= frames.size() - AudioServer.get_mix_rate() * .5: idle = maxf(idle, v)
	check(peak > .001 and idle > .0001, "Opening and continuing title breath are audible")
	var path := OS.get_environment("ASTRAL_INTRO_TAKE")
	if not path.is_empty():
		pcm.resize(frames.size() * 4)
		for i in frames.size():
			pcm.encode_s16(i*4, roundi(clampf(frames[i].x, -1, 1)*32767))
			pcm.encode_s16(i*4+2, roundi(clampf(frames[i].y, -1, 1)*32767))
		var take := AudioStreamWAV.new()
		take.format = AudioStreamWAV.FORMAT_16_BITS
		take.mix_rate = AudioServer.get_mix_rate()
		take.stereo = true
		take.data = pcm
		check(take.save_to_wav(path) == OK, "Save preview capture")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	ui.queue_free()
	await create_timer(.3).timeout
	print("INTRO AUDIO skip=", skip, " elapsed_ms=", elapsed, " peak=", peak, " idle_peak=", idle, " failures=", failures)
	quit(1 if failures else 0)
