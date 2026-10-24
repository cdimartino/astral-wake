extends SceneTree
## Render with Godot Movie Maker at 30 fps; no game state or saves are loaded.
var film: Control
var time := 0.0
var background: TextureRect
var ship: TextureRect
var title: Label
var veil: ColorRect
var stars: Array[ColorRect] = []
var lights: Array[ColorRect] = []

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1440, 900)
	film = Control.new()
	root.add_child(film)
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = TextureRect.new()
	background.texture = load("res://art/backgrounds_hd/region_2.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size = Vector2(1656, 1035)
	background.position = Vector2(-108, -68)
	background.modulate = Color(0.4, 0.55, 0.62)
	film.add_child(background)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87412
	for i in range(100):
		var star := ColorRect.new()
		star.position = Vector2(rng.randf_range(0,1440), rng.randf_range(0,900))
		star.size = Vector2.ONE * rng.randf_range(1,3)
		star.color = Color(0.6, 0.9, 1.0, rng.randf_range(0.15,0.7))
		film.add_child(star)
		stars.append(star)
	ship = TextureRect.new()
	ship.texture = load("res://art/ships_hd/player.png")
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ship.size = Vector2(720,720)
	ship.position = Vector2(360,50)
	film.add_child(ship)
	for i in range(6):
		var light := ColorRect.new()
		light.size = Vector2(3,3)
		light.color = Color("a3ffe4")
		film.add_child(light)
		lights.append(light)
	title = Label.new()
	title.text = "ASTRAL WAKE"
	title.add_theme_font_override("font", load("res://art/fonts/AstralWake-Display.ttf"))
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("e8e2cc"))
	title.add_theme_color_override("font_outline_color", Color("07131d"))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0,730)
	title.size = Vector2(1440,100)
	film.add_child(title)
	veil = ColorRect.new()
	veil.color = Color.BLACK
	veil.size = Vector2(1440,900)
	film.add_child(veil)
	var audio := AudioStreamPlayer.new()
	audio.stream = load("res://audio/opening.wav")
	film.add_child(audio)
	audio.play()

func _process(delta: float) -> bool:
	if not is_instance_valid(veil): return false
	time += delta
	var progress := clampf(time / 9.0,0,1)
	background.position.x = -108 + progress * 55
	ship.position = Vector2(380 - progress * 60, 60 - progress * 25)
	ship.modulate = Color(0.22,0.38,0.43).lerp(Color.WHITE, smoothstep(0.7,5.0,time))
	for i in range(stars.size()):
		stars[i].position.x = fposmod(stars[i].position.x - delta * (3 + i % 8),1440)
	for i in range(lights.size()):
		var angle := time * 0.7 + i * TAU / 6
		lights[i].position = Vector2(730,410) + Vector2(cos(angle)*145,sin(angle)*110)
		lights[i].modulate.a = sin(clampf((time-1.5)/6.0,0,1)*PI)*0.8
	title.modulate.a = smoothstep(5.0,6.8,time)
	veil.color.a = maxf(1.0-smoothstep(0.0,1.5,time),smoothstep(8.0,9.0,time))
	if time >= 9.0: quit()
	return false
