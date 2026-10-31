extends Control
## A local, skippable film. It never changes expedition or profile state.
signal finished
var ending := false
var video: VideoStreamPlayer

func start(volume: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	video = VideoStreamPlayer.new()
	video.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	video.expand = true
	video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video.volume_db = linear_to_db(maxf(0.001, volume))
	add_child(video)
	if not ResourceLoader.exists("res://art/cinematic/opening.ogv"):
		skip.call_deferred()
		return
	video.stream = load("res://art/cinematic/opening.ogv")
	video.finished.connect(skip)
	var hint := Label.new()
	hint.text = "Press any key or click to skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -48
	hint.offset_bottom = -16
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("d6e8e7"))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	add_child(hint)
	video.play()
	# A decoder failure must not trap the player before the title screen.
	get_tree().create_timer(12.0).timeout.connect(skip)

func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		skip()

func skip() -> void:
	if ending: return
	ending = true
	var fade := create_tween().set_parallel()
	fade.tween_property(self, "modulate:a", 0.0, 0.7)
	if is_instance_valid(video): fade.tween_property(video, "volume_db", -60.0, 0.7)
	fade.chain().tween_callback(func():
		finished.emit()
		queue_free())
