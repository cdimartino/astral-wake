extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "AudioSmoke")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	var player := AudioStreamPlayer.new()
	player.bus = "AudioSmoke"
	root.add_child(player)
	var mix_rate := AudioServer.get_mix_rate()
	for region in range(6):
		var stream: AudioStreamWAV = load("res://audio/region_%d.wav" % region)
		check(stream != null, "Imported region %d exists" % region)
		if stream == null:
			continue
		var length := stream.get_length()
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "Soundtrack imports retain uncompressed PCM")
		check(absf(length - 48.0) < .01, "Decoded region %d is 48 seconds" % region)
		stream.loop_begin = 0
		# Godot interpolates the last valid frame; N would interpolate into padding.
		stream.loop_end = roundi(length * stream.mix_rate) - 1
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		check(stream.loop_end == 1058399, "Loop endpoint counts decoded sample frames")
		player.stream = stream
		capture.clear_buffer()
		# The capture contains the actual imported decoder crossing end -> beginning.
		player.play(length - .6)
		# Hosted runners can mix slower than wall time. Wait for actual samples,
		# retaining a bounded timeout so a stalled mixer still fails the test.
		var deadline := Time.get_ticks_msec() + 10000
		while capture.get_frames_available() < mix_rate * 1.1 and Time.get_ticks_msec() < deadline:
			await create_timer(.02).timeout
		check(player.playing, "Region %d continues after wrapping" % region)
		var frames := capture.get_buffer(capture.get_frames_available())
		check(frames.size() > mix_rate * .9, "Audio mixer produced a full seam capture")
		if frames.size() <= mix_rate * .9:
			player.stop()
			continue
		var minimum_rms := 1.0
		var maximum_step := 0.0
		var maximum_index := 0
		var window := roundi(mix_rate * .02)
		# Ignore startup/stop latency; retained middle includes the seam at ~0.6 sec.
		for start in range(roundi(mix_rate * .15), frames.size() - roundi(mix_rate * .1) - window, window):
			var energy := Vector2.ZERO
			for index in range(start, start + window):
				energy += frames[index] * frames[index]
				var step := maxf(absf(frames[index].x - frames[index - 1].x), absf(frames[index].y - frames[index - 1].y))
				if step > maximum_step:
					maximum_step = step
					maximum_index = index
			minimum_rms = minf(minimum_rms, minf(sqrt(energy.x / window), sqrt(energy.y / window)))
		check(minimum_rms > .025, "Region %d has no quiet gap in any 20ms seam window" % region)
		check(maximum_step < .06, "Region %d has no waveform click at wrap" % region)
		print("REGION %d: format=%d length=%.4f loop=%d..%d captured=%d min20msRMS=%.5f maxStep=%.5f at=%.4f before=%s after=%s" % [region, stream.format, length, stream.loop_begin, stream.loop_end, frames.size(), minimum_rms, maximum_step, float(maximum_index) / mix_rate, frames[maximum_index - 1], frames[maximum_index]])
		player.stop()
		await create_timer(.1).timeout
	var combat_files := DirAccess.get_files_at("res://audio")
	var combat_count := 0
	for filename in combat_files:
		if not filename.begins_with("combat_") or not filename.ends_with(".wav"): continue
		combat_count += 1
		var stream: AudioStreamWAV = load("res://audio/" + filename)
		check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Combat cues import as one-shots")
		player.stream = stream
		capture.clear_buffer()
		player.play()
		await create_timer(stream.get_length() + .12).timeout
		var deadline := Time.get_ticks_msec() + 5000
		while player.playing and Time.get_ticks_msec() < deadline:
			await create_timer(.02).timeout
		var frames := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > .02 and peak < .99, filename + " must decode audibly without clipping")
		check(not player.playing, filename + " must end without looping")
	check(combat_count == 21, "All 21 combat cues were mixed")
	print("AUDIO SMOKE: %d failures" % failures)
	quit(1 if failures else 0)
