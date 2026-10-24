extends SceneTree
const Intro = preload("res://scripts/intro_cinematic.gd")
var completed := 0
var started := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("10252c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var intro = Intro.new()
	root.add_child(intro)
	started = Time.get_ticks_msec()
	intro.finished.connect(func(): completed += 1)
	intro.start(0.3)
	if "--skip" in OS.get_cmdline_user_args():
		await create_timer(1.0).timeout
		intro.skip()
		intro.skip()
	else:
		await create_timer(4.0).timeout
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/astral-intro-midpoint.png")
	while is_instance_valid(intro): await process_frame
	assert(completed == 1, "Cinematic must finish exactly once")
	var elapsed := (Time.get_ticks_msec()-started)/1000.0
	assert(elapsed < 13.5, "Cinematic must always reach the title screen")
	if "--skip" in OS.get_cmdline_user_args(): assert(elapsed < 3.0, "Skip must finish promptly")
	print("INTRO_TEST_PASS elapsed=",elapsed," completed=",completed)
	quit()
