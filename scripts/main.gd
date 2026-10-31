extends Control

const Game = preload("res://scripts/game.gd")
const SpaceCanvas = preload("res://scripts/space_canvas.gd")
const OrganCircuit = preload("res://scripts/organ_circuit.gd")
const OrganVisuals = preload("res://scripts/organ_visuals.gd")
const ShipAnatomy = preload("res://scripts/ship_anatomy.gd")
const OrganSocket = preload("res://scripts/organ_socket.gd")
const OpeningFilm = preload("res://scripts/intro_cinematic.gd")
const NAVY := Color("08131f")
const PANEL := Color("111f30")
const CREAM := Color("eee9d9")
const MUTED := Color("b5c6d2")
const TEAL := Color("7be0ca")
const CORAL := Color("f39789")
const GOLD := Color("e7c381")
const ORGAN_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
const ORGAN_LETTERS := ["Q", "W", "E", "R", "T", "Y"]
const PLAYER_COMBAT_RECT := Rect2(38, 177, 280, 270)

var game = Game.new()
var page: Control
var overlay: Control
var selected_card := -1
var anatomy_view := true
var anatomy_readout: Label
var route: Array[int] = []
var target := 0
var notice := ""
var menu := true
var choosing_character := false
var selected_character := "cartographer"
var expedition_seed := ""
var ship_atlas: Texture2D
var card_atlas: Texture2D
var player_hd: Texture2D
var hd_ship_regions: Dictionary = {}
var hd_card_regions: Dictionary = {}
var expansion_characters: Dictionary = {}
var expansion_regions: Dictionary = {}
var expansion_cards: Dictionary = {}
var expansion_enemies: Dictionary = {}
var map_icons: Dictionary = {}
var region_textures: Array = []
var background: TextureRect
var audio: AudioStreamPlayer
var combat_voices: Array[AudioStreamPlayer] = []
var combat_sound_times := {}
var combat_voice_cursor := 0
var ambience: AudioStreamPlayer
var sounds: Dictionary = {}
var focus_key := ""
var hand_buttons: Array[Button] = []
var hover_card := -1
var modify_page := 0
var map_detail: VBoxContainer
var tracks: Dictionary = {}
var music_region := -99
var heading_font: Font
var title_font: Font
var player_art: TextureRect
var enemy_art: Array[TextureRect] = []
var enemy_hulls: Array[ProgressBar] = []
var player_hull: ProgressBar
var feedback_serial := 0
var last_feedback: Array = []
var resolving := false
var presentation_duration := 0.0
var opening_film

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	var atlas_path := "res://art/ships_transparent.png" if ResourceLoader.exists("res://art/ships_transparent.png") else "res://art/ships.png"
	if ResourceLoader.exists(atlas_path):
		ship_atlas = load(atlas_path)
	if ResourceLoader.exists("res://art/cards.png"):
		card_atlas = load("res://art/cards.png")
	if ResourceLoader.exists("res://art/ships_hd/player.png"):
		player_hd = load("res://art/ships_hd/player.png")
	hd_ship_regions = _load_art_regions("res://art/ships_hd/manifest.json", "ships")
	hd_card_regions = _load_art_regions("res://art/cards_hd/manifest.json", "cards")
	expansion_characters = _load_art_regions("res://art/expansion/manifest.json", "characters")
	expansion_regions = _load_art_regions("res://art/expansion/manifest.json", "regions")
	expansion_cards = _load_art_regions("res://art/expansion/manifest.json", "cards")
	expansion_enemies = _load_art_regions("res://art/expansion/manifest.json", "enemies")
	for kind in ["battle", "elite", "boss", "event", "shop", "recovery"]:
		var icon_path := "res://art/map_icons/%s.svg" % kind
		if ResourceLoader.exists(icon_path): map_icons[kind] = load(icon_path)
	for i in range(game.catalog.regions.size()):
		var path := "res://art/backgrounds_hd/region_%d.png" % i
		if not ResourceLoader.exists(path): path = "res://art/region_%d.png" % i
		region_textures.append(load(path) if ResourceLoader.exists(path) else null)
	_audio_setup()
	game.load_saved()
	_apply_settings()
	resized.connect(_layout_stage)
	_render()
	if DisplayServer.get_name() != "headless" and OS.get_environment("ASTRAL_SKIP_INTRO") != "1" and not game.profile.get("settings", {}).get("reduced_motion", false):
		opening_film = OpeningFilm.new()
		add_child(opening_film)
		ambience.stop()
		opening_film.finished.connect(func():
			opening_film = null
			ambience.play())
		opening_film.start(1.0)

func _build_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 17
	var readable := SystemFont.new()
	readable.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue", "sans-serif"])
	readable.font_weight = 500
	t.default_font = readable
	var strong := SystemFont.new()
	strong.font_names = readable.font_names
	strong.font_weight = 600
	title_font = strong
	var display := SystemFont.new()
	display.font_names = PackedStringArray(["DIN Condensed", "Avenir Next Condensed", "Avenir Next", "sans-serif"])
	display.font_weight = 700
	heading_font = display
	if ResourceLoader.exists("res://art/fonts/AstralWake-Display.ttf"):
		var original: Font = load("res://art/fonts/AstralWake-Display.ttf")
		if original != null:
			heading_font = original
			heading_font.fallbacks.append(display)
	for font_path in ["res://art/body.ttf", "res://art/Inter-Regular.ttf", "res://art/fonts/body.ttf"]:
		if ResourceLoader.exists(font_path):
			t.default_font = load(font_path)
			break
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", TEAL)
	t.set_color("font_disabled_color", "Button", Color("9aabba"))
	t.set_font("font", "Button", title_font)
	t.set_color("font_color", "CheckBox", CREAM)
	t.set_color("font_color", "RichTextLabel", CREAM)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 14)
	t.set_stylebox("normal", "Button", _style(Color("172a3d"), Color("344a5e"), 10, 12))
	t.set_stylebox("hover", "Button", _style(Color("20394c"), TEAL, 10, 12))
	t.set_stylebox("pressed", "Button", _style(Color("203f48"), TEAL, 10, 12))
	t.set_stylebox("disabled", "Button", _style(Color("122030"), Color("233444"), 10, 12))
	t.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD, 10, 3, 2))
	t.set_stylebox("panel", "PanelContainer", _style(PANEL, Color("2c3e51"), 14, 18))
	t.set_stylebox("background", "ProgressBar", _style(Color("233246"), Color.TRANSPARENT, 5, 0))
	t.set_stylebox("fill", "ProgressBar", _style(TEAL, Color.TRANSPARENT, 5, 0))
	t.set_stylebox("panel", "TooltipPanel", _style(Color("1d3040"), TEAL, 8, 14))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 18)
	theme = t

func _style(fill: Color, stroke: Color, radius: int, padding: int, border: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = stroke
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func _label(text: String, font_size: int = 17, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	# Display lettering is for large headings, never small readouts or body copy.
	if heading_font != null and font_size >= 32:
		label.add_theme_font_override("font", heading_font)
	label.add_theme_color_override("font_color", color)
	return label

func _text(text: String, font_size: int = 17, color: Color = MUTED) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Finite line caps prevent wrapped labels collapsing inside Godot containers.
	label.max_lines_visible = 32
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable, tip: String = "", accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("focus_key", text)
	button.pressed.connect(func():
		_tick()
		callback.call()
	)
	if accent:
		button.add_theme_stylebox_override("normal", _style(Color("254840"), TEAL, 10, 12))
		button.add_theme_color_override("font_color", TEAL)
	return button

func _column(parent: Node, expand: bool = true) -> VBoxContainer:
	var box := VBoxContainer.new()
	if expand:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _row(parent: Node, expand: bool = true) -> HBoxContainer:
	var box := HBoxContainer.new()
	if expand:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return _column(panel)

func _spacer(parent: Node) -> void:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)

func _art(slot: int, height: float, width: float = 0) -> TextureRect:
	var image := TextureRect.new()
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size = Vector2(width, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot == 0 and expansion_characters.has(str(game.run.get("character", "cartographer"))):
		image.texture = expansion_characters[str(game.run.get("character", "cartographer"))]
		return image
	if slot == 0 and player_hd != null:
		image.texture = player_hd
		return image
	if hd_ship_regions.has(str(slot)):
		image.texture = hd_ship_regions[str(slot)]
		return image
	if ship_atlas:
		var texture := AtlasTexture.new()
		texture.filter_clip = true
		texture.atlas = ship_atlas
		slot = clampi(slot, 0, 19)
		var cell := Vector2(ship_atlas.get_width() / 5.0, ship_atlas.get_height() / 4.0)
		texture.region = Rect2(Vector2(slot % 5, floori(slot / 5.0)) * cell, cell)
		image.texture = texture
	return image

func _render() -> void:
	resolving = false
	feedback_serial += 1
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focus_key = str(focused.get_meta("focus_key", ""))
	for child in get_children():
		if child != audio and child != ambience:
			remove_child(child)
			child.queue_free()
	overlay = null
	hand_buttons.clear()
	enemy_art.clear()
	enemy_hulls.clear()
	player_art = null
	player_hull = null
	hover_card = -1
	var fill := ColorRect.new()
	fill.color = NAVY
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	background = TextureRect.new()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var region_index := _area_index()
	var area_id := str(game.region().get("id", "")) if not game.run.is_empty() else str(game.catalog.regions[0].id)
	if expansion_regions.has(area_id): background.texture = expansion_regions[area_id]
	elif region_index < region_textures.size(): background.texture = region_textures[region_index]
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.07, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var stars := SpaceCanvas.new()
	stars.animate_stars = not game.profile.get("settings", {}).get("reduced_motion", false)
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stars)
	page = Control.new()
	page.name = "GameStage"
	page.size = Vector2(1440, 900)
	add_child(page)
	_layout_stage()
	_header()
	if choosing_character:
		_character_selection()
	elif menu or game.run.is_empty():
		_title()
	else:
		match str(game.run.get("mode", "map")):
			"map": _map()
			"combat": _combat()
			"reward": _rewards()
			"event": _event()
			"shop": _shop()
			"recovery": _recovery()
			"modify": _modify()
			"transition": _transition()
			"victory", "defeat": _ending()
	if not notice.is_empty() or not game.save_error.is_empty():
		var message: String = "Save warning: " + game.save_error if not game.save_error.is_empty() else notice
		var banner := _screen_text(message, Rect2(46, 80, 1348, 50), 19, CORAL)
		banner.z_index = 80
		banner.add_theme_stylebox_override("normal", _style(Color(0.03, 0.06, 0.10, 0.95), CORAL, 8, 10))
	_soundtrack()
	_focus_first.call_deferred()

func _focus_first() -> void:
	if not is_instance_valid(page) or is_instance_valid(overlay):
		return
	var buttons := page.find_children("*", "Button", true, false)
	if not menu and game.run.get("mode", "") == "map":
		for button in buttons:
			if button.get_meta("reachable_destination", false):
				button.grab_focus()
				return
	for button in buttons:
		if not button.disabled and button.is_visible_in_tree() and str(button.get_meta("focus_key", "")) == focus_key:
			button.grab_focus()
			return
	for button in buttons:
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return

func _header() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.025, 0.045, 0.08, 0.80)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(bar, Rect2(0, 0, 1440, 78))
	_screen_text("A / W", Rect2(38, 22, 94, 40), 30, TEAL)
	_screen_text("ASTRAL WAKE", Rect2(138, 27, 260, 32), 21, CREAM)
	if not menu and not game.run.is_empty():
		var header_hull := _screen_text("HULL  %d / %d" % [game.run.hull, game.run.max_hull], Rect2(550, 28, 220, 30), 20, CORAL if game.run.hull < 30 else TEAL)
		header_hull.name = "HeaderHull"
		_screen_text("SALVAGE  %d" % game.run.salvage, Rect2(790, 28, 200, 30), 20, GOLD)
		_at(_button("Deck · %d" % game.run.deck.size(), _open_deck, "Inspect commands and powerups."), Rect2(1044, 17, 150, 46))
	_at(_button("?", _open_help, "How to play and keyboard controls."), Rect2(1208, 17, 54, 46))
	_at(_button("Settings" if menu else "Menu", func(): _open_settings() if menu else _open_menu()), Rect2(1276, 17, 126, 46))

func _title() -> void:
	_float_art(0, Rect2(630, 145, 720, 600))
	_reading_plate(Rect2(60, 182, 650, 376))
	_screen_text("A STRANGE FRONTIER AWAITS", Rect2(80, 197, 550, 30), 20, TEAL)
	_screen_text("Astral Wake", Rect2(73, 240, 650, 115), 78, CREAM)
	_screen_text("You are a ship.\nLearn what you can become.", Rect2(82, 365, 490, 100), 31, CREAM)
	_screen_text("Route living commands through six organs.\nCross three impossible regions.", Rect2(82, 475, 500, 82), 22, MUTED)
	var y := 579.0
	if game.run_exists():
		_at(_button("Continue expedition  →", func():
			menu = false
			_clear_selection()
			_render(), "Resume your exact saved encounter.", true), Rect2(82, y, 420, 56))
		y += 70
	_at(_button("New expedition", _request_new, "Begin a voyage; replacing a saved expedition requires confirmation.", not game.run_exists()), Rect2(82, y, 420, 56))
	_at(_button("Run history", _open_history), Rect2(82, y + 72, 202, 48))
	_at(_button("Discoveries", _open_unlocks), Rect2(298, y + 72, 204, 48))
	_reading_plate(Rect2(906, 741, 450, 108))
	_screen_text(str(game.character().name).to_upper(), Rect2(922, 753, 420, 32), 24, TEAL)
	_screen_text("A nervous system built for the unknown.", Rect2(922, 790, 420, 50), 20, CREAM)

func _request_new() -> void:
	expedition_seed = ""
	choosing_character = true
	menu = true
	selected_character = str(game.run.get("character", selected_character))
	_clear_selection()
	_render()

func _begin_character_run() -> void:
	if not expedition_seed.is_empty() and not Game.SeedEngine.valid(Game.SeedEngine.canonical(expedition_seed)):
		notice = "Use exactly 6 letters or digits (A–Z, 0–9), or leave the seed blank."
		_render()
		return
	if game.run_exists() or (game.run.is_empty() and not game.save_error.is_empty()):
		var body := _modal("Replace this expedition?")
		body.add_child(_text("Begin a new voyage aboard %s. The active expedition will be replaced and its current progress cannot be resumed." % str(game.character(selected_character).name), 19, CREAM))
		var row := _row(body)
		row.add_child(_button("Keep expedition", _close_overlay))
		row.add_child(_button("Replace and begin", _new_run, "Replace the saved expedition.", true))
	else:
		_new_run()

func _new_run() -> void:
	choosing_character = false
	menu = false
	_perform(func(): return game.new_run(expedition_seed, selected_character))

func _character_selection() -> void:
	_reading_plate(Rect2(44, 118, 1352, 84))
	_screen_text("Select your ship", Rect2(60, 130, 1320, 66), 43, CREAM)
	_screen_text("Seed (optional)", Rect2(600, 137, 180, 29), 18, CREAM)
	var seed_input := LineEdit.new()
	seed_input.name = "ExpeditionSeed"
	seed_input.placeholder_text = "e.g. A1B2C3"
	seed_input.text = expedition_seed
	seed_input.max_length = 6
	seed_input.add_theme_font_size_override("font_size", 20)
	seed_input.tooltip_text = "Blank: normal expedition. Enter 6 letters/digits: reproducible practice, with no durable progression or unlocks. Use the same ship and game version to retry tactics."
	seed_input.text_changed.connect(func(value: String): expedition_seed = value)
	_at(seed_input, Rect2(786, 132, 190, 40))
	_screen_text("Entered seed = practice · no progression or unlocks", Rect2(600, 176, 760, 26), 16, GOLD)
	var characters: Array = game.catalog.get("characters", [])
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		var id := str(character.id)
		var selected := id == selected_character
		var x := 50.0 + i * 456
		var pick := _button("", func():
			selected_character = id
			_render(), "Select " + str(character.name), selected)
		pick.name = "CharacterChoice%d" % i
		pick.set_meta("focus_key", "character_" + id)
		pick.add_theme_stylebox_override("normal", _style(Color(0.025, 0.07, 0.11, 0.35), TEAL if selected else Color("41576b"), 18, 0, 2 if selected else 1))
		_at(pick, Rect2(x, 225, 420, 530))
		var image := _character_image(id, 410)
		_at(image, Rect2(20, 18, 380, 410), pick)
		var name_label := _screen_text(("› " if selected else "") + str(character.name), Rect2(20, 450, 380, 52), 30, TEAL if selected else CREAM, pick)
		name_label.add_theme_stylebox_override("normal", _style(Color("0b1926"), Color.TRANSPARENT, 8, 0))
		name_label.max_lines_visible = 2
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var details := _button("Details", func(): _character_info(id), "Inspect this ship’s systems and starting deck.")
		details.name = "CharacterDetails%d" % i
		_at(details, Rect2(x + 110, 771, 200, 44))
	_at(_button("Back", func():
		choosing_character = false
		menu = true
		_render()), Rect2(60, 832, 220, 48))
	_at(_button("Begin →", _begin_character_run, "Begin aboard the selected ship.", true), Rect2(1030, 826, 350, 54))

func _character_info(id: String) -> void:
	var character: Dictionary = game.character(id)
	var body := _modal(str(character.name) + " · systems")
	body.add_child(_text(str(character.description), 21, CREAM))
	body.add_child(_text("Hull %d · Organ capacity %d · Turn cooling %d" % [int(character.max_hull), int(character.capacity), int(character.cooling)], 19, GOLD))
	body.add_child(_label("SIX LIVING ORGANS", 17, TEAL))
	for organ in character.organs:
		body.add_child(_text(str(organ.name) + " — " + str(organ.description), 18, CREAM))
	body.add_child(_label("STARTING COMMANDS", 17, GOLD))
	var instances: Array = []
	for card_id in character.starting_deck: instances.append({"id":card_id, "level":0})
	_deck_grid(body, false, instances)

func _section(kicker: String, title: String, description: String = "") -> void:
	_reading_plate(Rect2(44, 98, 1352, 174))
	_screen_text(kicker.to_upper(), Rect2(64, 112, 1312, 28), 18, TEAL)
	_screen_text(title, Rect2(60, 147, 1320, 66), 43, CREAM)
	if not description.is_empty():
		_screen_text(description, Rect2(64, 216, 1300, 58), 21, MUTED)

func _map() -> void:
	var region: Dictionary = game.region()
	_reading_plate(Rect2(44, 94, 1352, 88))
	_screen_text("REGION %d / 3  ·  %s" % [int(game.run.region) + 1, str(region.get("name", "Frontier")).to_upper()], Rect2(58, 103, 1100, 38), 27, CREAM)
	_screen_text("Chart a course through the stars. Lit destinations are within reach.", Rect2(62, 149, 1250, 30), 20, TEAL)
	var scroll := ScrollContainer.new()
	scroll.name = "StarChartScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_at(scroll, Rect2(48, 198, 912, 638))
	var chart := Control.new()
	chart.name = "ExpeditionChart"
	chart.custom_minimum_size = Vector2(870, 12 * 170 + 50)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(chart)
	var paths := SpaceCanvas.new()
	paths.stars = false
	paths.map_paths = true
	_at(paths, Rect2(0, 0, 870, chart.custom_minimum_size.y), chart)
	var locations: Array = []
	for layer in game.run.map:
		for node in layer: locations.append(node)
	for node in locations:
		var layer: Array = game.run.map[int(node.layer)]
		var index := layer.find(node)
		paths.points.append(Vector2(65 + (index + 0.5) * 740.0 / layer.size(), 80 + int(node.layer) * 170))
	for i in range(locations.size()):
		var node: Dictionary = locations[i]
		for edge_id in node.edges:
			for j in range(locations.size()):
				if locations[j].id == edge_id:
					paths.connections.append([i, j])
					var visited_edge: bool = game.run.visited.has(node.id) and game.run.visited.has(edge_id)
					var next_edge: bool = node.id == game.run.current_node
					paths.connection_colors.append(TEAL if visited_edge or next_edge else Color("36536c"))
		var accessible: bool = game.reachable(node)
		var visited: bool = game.run.visited.has(node.id)
		var tint: Color = GOLD if accessible else TEAL if visited else Color("6f8ca5")
		var button := _button("", func():
			if game.reachable(node): _perform(func(): return game.choose_node(str(node.id)))
			else: _map_details(node), _node_name(node))
		button.name = "Destination%d" % i
		button.set_meta("map_node", true)
		button.set_meta("reachable_destination", accessible)
		button.set_meta("focus_key", "destination_" + str(node.id))
		button.add_theme_stylebox_override("normal", _style(Color(0.025, 0.07, 0.12, 0.45), tint, 42, 0, 2 if accessible else 1))
		button.add_theme_stylebox_override("hover", _style(Color(0.06, 0.15, 0.22, 0.75), GOLD, 42, 0, 2))
		button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 42, 0, 3))
		button.add_theme_stylebox_override("pressed", _style(Color(0.08, 0.2, 0.26, 0.85), TEAL, 42, 0, 2))
		button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
		_at(button, Rect2(paths.points[i] - Vector2(44, 44), Vector2(88, 88)), chart)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = map_icons.get(str(node.type))
		_at(icon, Rect2(4, 4, 80, 80), button)
		var type_label := _screen_text(("✓ " if visited else "") + str(node.type).to_upper(), Rect2(-24, 94, 136, 26), 16, tint, button)
		type_label.add_theme_stylebox_override("normal", _style(Color("08131f"), Color.TRANSPARENT, 6, 0))
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_color_override("font_outline_color", NAVY)
		type_label.add_theme_constant_override("outline_size", 3)
		button.mouse_entered.connect(func(): _map_details(node))
		button.focus_entered.connect(func():
			_map_details(node)
			scroll.ensure_control_visible.call_deferred(button))
	for depth in range(12):
		_reading_plate(Rect2(2, depth * 170 + 64, 50, 34), chart)
		_screen_text("%02d" % (depth + 1), Rect2(6, depth * 170 + 66, 44, 30), 22, TEAL if depth == game.run.layer else MUTED, chart)
	paths.queue_redraw()
	_scroll_map_to_progress(scroll, int(game.run.layer))
	map_detail = _surface(Rect2(1000, 198, 378, 638))
	var selected: Dictionary = game.run.map[0][0]
	for node in locations:
		if game.reachable(node):
			selected = node
			break
	_map_details(selected)
	_reading_plate(Rect2(44, 847, 1352, 40))
	_screen_text("12 destinations deep · Scroll to inspect the frontier · Seed %s" % str(game.run.seed), Rect2(58, 855, 1320, 28), 17, MUTED)

func _scroll_map_to_progress(scroll: ScrollContainer, layer: int) -> void:
	# Wait for container sorting to establish its scroll range.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll): scroll.scroll_vertical = maxi(0, layer * 170 - 100)

func _node_name(node: Dictionary) -> String:
	if node.type in ["battle", "elite", "boss"]:
		var names: Array[String] = []
		for id in node.get("enemy_ids", []):
			names.append(str(game.enemy(id).get("name", id)))
		return " + ".join(names)
	if node.type == "event":
		for item in game.catalog.get("events", []):
			if item.id == node.get("event_id", ""):
				return str(item.name)
	return {"shop": "Salvage exchange", "recovery": "A quiet orbit"}.get(str(node.type), "Unknown signal")

func _combat() -> void:
	var battle: Dictionary = game.run.battle
	target = clampi(target, 0, maxi(0, battle.enemies.size() - 1))
	_reading_plate(Rect2(34, 86, 1370, 82))
	_screen_text(str(game.region().get("name", "Frontier")), Rect2(45, 95, 365, 32), 22, CREAM)
	var points := int(battle.get("command_points", 3))
	var maximum := int(battle.get("max_command_points", 3))
	var points_label := _screen_text("COMMAND POINTS  %d / %d" % [points, maximum], Rect2(430, 95, 345, 32), 20, GOLD if points > 0 else CORAL)
	points_label.name = "CommandPoints"
	_screen_text("TURN %d   WARD %d   DRAW %d   DISCARD %d" % [battle.turn, battle.ward, battle.draw.size(), battle.discard.size()], Rect2(800, 96, 600, 32), 18, TEAL)
	if points == 0:
		_screen_text("NO POINTS LEFT · End turn [E] to refill. Cards remain inspectable.", Rect2(45, 133, 740, 32), 17, CORAL)
	elif int(game.run.get("tutorial_step", 0)) < 4:
		_screen_text("Choose a card → route connected organs [Q W E R T Y] → Space", Rect2(45, 133, 740, 32), 17, GOLD)
	_last_command()
	var anatomy := Panel.new()
	anatomy.name = "LivingCircuit"
	anatomy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anatomy.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT if anatomy_view else Color(0.025, 0.055, 0.085, 0.91), Color.TRANSPARENT if anatomy_view else Color("385762"), 22, 0))
	_at(anatomy, Rect2(34, 176, 756, 357))
	if anatomy_view:
		_ship_cutaway(battle)
	else:
		_ship_console(battle)
	var switch_view := _button("Console view" if anatomy_view else "Anatomy view", func():
		anatomy_view = not anatomy_view
		_render(), "Compare the embedded-organ sample with the ship console.")
	switch_view.name = "AnatomyViewToggle"
	switch_view.custom_minimum_size.y = 26
	switch_view.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "focus"]:
		switch_view.add_theme_stylebox_override(state, _style(PANEL, TEAL if state != "normal" else MUTED, 10, 0))
	_at(switch_view, Rect2(646, 174, 138, 26))
	var count: int = battle.enemies.size()
	var locations := _enemy_layout(count)
	for i in range(count):
		_enemy_target(i, battle.enemies[i], locations[i], count)
	_preview()
	_reading_plate(Rect2(40, 607, 1360, 22))
	var hints := _screen_text("1–5 select   Q W E R T Y route   Space confirm   E end turn (Shift+E while routing)   Esc cancel", Rect2(50, 605, 1340, 23), 16, CREAM)
	hints.name = "ShortcutHints"
	_hand()

func _last_command_tip() -> String:
	var battle: Dictionary = game.run.battle
	var memory: Dictionary = battle.get("last_command", {})
	var base: Dictionary = memory.get("base", battle.get("last_payload", {}))
	var tip := "Previous command: none yet." if memory.is_empty() else game.card_text(memory.card)
	if memory.is_empty() and not base.is_empty(): tip = "Previous card identity was not stored in this older save."
	if not base.is_empty():
		tip += "\nBase before organs and powerups: Damage %d · Repair %d · Disruption %d." % [int(base.get("damage", 0)), int(base.get("heal", 0)), int(base.get("disrupt", 0))]
		tip += "\nRewrite adds half these base values, rounded down: Damage %d · Repair %d · Disruption %d (costs 2 Trace)." % [int(base.get("damage", 0)) / 2, int(base.get("heal", 0)) / 2, int(base.get("disrupt", 0)) / 2]
		tip += "\nBase includes the card's upgrade, but excludes organ, resource and powerup bonuses."
	if not memory.is_empty():
		tip += "\nResolved: %d total damage · %d hull repaired · %d disruption applied." % [memory.resolved.damage, memory.resolved.heal, memory.resolved.disrupt]
		tip += "\nKind: %s. The Choir compares this kind with the next command." % str(memory.kind).capitalize()
	return tip

func _last_command() -> void:
	var battle: Dictionary = game.run.battle
	var memory: Dictionary = battle.get("last_command", {})
	var text := "LAST COMMAND · None yet"
	if not memory.is_empty():
		var instance: Dictionary = memory.card
		text = "LAST COMMAND · %s%s · %s\nDealt %d · Repaired %d · Disruption %d" % [game.effective_card(instance).name, " +" if int(instance.level) > 0 else "", str(memory.kind).capitalize(), memory.resolved.damage, memory.resolved.heal, memory.resolved.disrupt]
	elif not battle.get("last_payload", {}).is_empty() or not str(battle.get("last_command_kind", "")).is_empty():
		text = "LAST COMMAND · Older save · Inspect stored memory"
	var inspect := _button(text, func():
		var body := _modal("Last command")
		if not memory.is_empty():
			var face := PanelContainer.new()
			face.custom_minimum_size = Vector2(260, 350)
			body.add_child(face)
			_card_face(face, memory.card, true, true)
		body.add_child(_text(_last_command_tip(), 17, CREAM)), _last_command_tip())
	inspect.name = "LastCommand"
	inspect.custom_minimum_size.y = 36
	inspect.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed"]:
		inspect.add_theme_stylebox_override(state, _style(Color("10202d"), TEAL if state != "normal" else Color("344a5e"), 8, 1))
	_at(inspect, Rect2(800, 129, 590, 36))

func _ship_cutaway(battle: Dictionary) -> void:
	player_art = _art(0, 344)
	player_art.name = "PlayerShip"
	player_art.stretch_mode = TextureRect.STRETCH_SCALE
	player_art.modulate = Color.WHITE
	_at(player_art, Rect2(38, 184, 744, 344))
	var hull := ShipAnatomy.new()
	var ship_id := str(game.run.get("character", "cartographer"))
	hull.tint = Color("bcb5ff") if ship_id == "hollow_choir" else GOLD if ship_id == "palimpsest" else TEAL
	_at(hull, Rect2(34, 176, 756, 357))
	_reading_plate(Rect2(42, 177, 590, 31))
	_screen_text(str(game.character().name) + " / living anatomy", Rect2(48, 180, 590, 29), 20, CREAM)
	var resource := "%d / 3 ROUTED\nFollow the lit organs" % route.size() if selected_card >= 0 else "LIVING CIRCUIT\nChoose a card to begin"
	var inspector := Panel.new()
	inspector.name = "AnatomyInspector"
	inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector.z_index = 2
	inspector.add_theme_stylebox_override("panel", _style(Color("081722"), Color.TRANSPARENT, 20, 0))
	_at(inspector, Rect2(ShipAnatomy.ORIGIN + ShipAnatomy.INSPECTOR_RECT.position, ShipAnatomy.INSPECTOR_RECT.size))
	anatomy_readout = _screen_text(resource, Rect2(10, 4, 190, 62), 14, TEAL, inspector)
	_reading_plate(Rect2(42, 505, 742, 28))
	var label := _screen_text("HULL %d / %d" % [game.run.hull, game.run.max_hull], Rect2(48, 509, 150, 23), 16, CREAM)
	label.name = "PlayerHullText"
	player_hull = _hull_bar(game.run.hull, game.run.max_hull, TEAL)
	player_hull.name = "PlayerHullBar"
	_at(player_hull, Rect2(208, 516, 140, 8))
	var footer := _screen_text(_character_resource_text(battle).replace("\n", " · ") if ship_id != "cartographer" else "Hover an organ to inspect its function", Rect2(380, 509, 400, 23), 14, TEAL)
	if ship_id != "cartographer": footer.name = "CharacterResource"
	var graph := Control.new()
	graph.name = "OrganNetwork"
	_at(graph, Rect2(ShipAnatomy.ORIGIN, ShipAnatomy.GRAPH_SIZE))
	_organ_graph(graph, battle)

func _ship_console(battle: Dictionary) -> void:
	if str(game.run.get("character", "cartographer")) != "cartographer":
		var resource_label := _screen_text(_character_resource_text(battle), Rect2(48, 488, 266, 43), 14, TEAL)
		resource_label.name = "CharacterResource"
	else:
		_screen_text("Living circuit · 6 organs\nFilled cells show strain", Rect2(48, 488, 266, 43), 14, MUTED)
	player_art = _float_art(0, PLAYER_COMBAT_RECT)
	player_art.name = "PlayerShip"
	_screen_text(str(game.character().name), Rect2(48, 438, 266, 29), 22, TEAL)
	var player_hull_label := _screen_text("HULL %d / %d" % [game.run.hull, game.run.max_hull], Rect2(48, 466, 146, 23), 16, CREAM)
	player_hull_label.name = "PlayerHullText"
	player_hull = _hull_bar(game.run.hull, game.run.max_hull, TEAL)
	player_hull.name = "PlayerHullBar"
	_at(player_hull, Rect2(200, 473, 110, 8))
	var guidance := "Choose a card → wake the circuit"
	if selected_card >= 0:
		guidance = "Start anywhere · lit organs are available" if route.is_empty() else "%d / 3 routed · follow the lit connections" % route.size()
		if route.size() == 3: guidance = "Route complete · confirm below [Space]"
	_screen_text(guidance, Rect2(48, 178, 590, 24), 16, GOLD if selected_card >= 0 else MUTED)
	var graph := Control.new()
	graph.name = "OrganNetwork"
	_at(graph, Rect2(OrganCircuit.ORIGIN, OrganCircuit.GRAPH_SIZE))
	_organ_graph(graph, battle)

func _organ_graph(parent: Node, battle: Dictionary) -> void:
	var graph: Control = parent
	var lines := OrganCircuit.new()
	lines.name = "NeuralConduits"
	lines.edges = battle.edges
	lines.severed = battle.get("severed", [])
	lines.route = route
	lines.organic = anatomy_view
	lines.reduced_motion = game.profile.get("settings", {}).get("reduced_motion", false)
	var ship_id := str(game.run.get("character", "cartographer"))
	lines.tint = Color("bcb5ff") if ship_id == "hollow_choir" else GOLD if ship_id == "palimpsest" else TEAL
	_at(lines, Rect2(Vector2.ZERO, ShipAnatomy.GRAPH_SIZE if anatomy_view else OrganCircuit.GRAPH_SIZE), graph)
	var forecast: Array = []
	var step_forecast := {}
	if selected_card >= 0:
		var preview: Dictionary = game.preview_card(selected_card, route, target)
		if preview.get("ok", false):
			forecast = preview.get("strain", [])
		for step in preview.get("route_steps", []): step_forecast[int(step.organ)] = step
	for i in range(6):
		var organ: Dictionary = game.organ(i)
		var strain: int = battle.strain[i]
		var selected := route.has(i)
		var candidate := route.duplicate()
		candidate.append(i)
		var reason: String = game._validate_route(game.run, candidate)
		var available := selected_card >= 0 and not selected and reason.is_empty()
		if available: lines.available.append(i)
		var saturated := strain >= int(battle.capacity)
		var readout: Array = OrganVisuals.READOUTS[str(organ.id)]
		var accent := Color(str(readout[2]))
		var tip: String = str(organ.name) + " [" + ORGAN_LETTERS[i] + "]\n" + str(organ.description)
		var step: Dictionary = step_forecast.get(i, {})
		var effect_status := str(step.get("status", "unselected"))
		if not step.is_empty():
			tip += "\nPreview: %s · %s\nTrace %d → %d · Resonance %d → %d" % [effect_status.capitalize(), step.reason, step.trace_before, step.trace_after, step.resonance_before, step.resonance_after]
			tip += "\nDamage %d → %d · Repair %d → %d · Disruption %d → %d" % [step.payload_before[0], step.payload_after[0], step.payload_before[1], step.payload_after[1], step.payload_before[2], step.payload_after[2]]
		tip += "\nStrain %d / %d. Filled segments are current strain; gold outlines show the preview." % [strain, battle.capacity]
		tip += "\n" + ("Click to undo this organ and later steps." if selected else "Available next organ." if available else reason if selected_card >= 0 else "Choose a card to begin routing.")
		var button := _button("", func(): _select_organ(i), tip)
		button.name = "Organ%d" % i
		button.set_meta("focus_key", "organ%d" % i)
		button.set_meta("route_available", available)
		button.set_meta("route_step", route.find(i) + 1)
		button.set_meta("effect_status", effect_status)
		button.mouse_entered.connect(func():
			lines.hovered = i
			_anatomy_inspect(i)
			lines.queue_redraw())
		button.mouse_exited.connect(func():
			lines.hovered = -1
			_anatomy_inspect(-1)
			lines.queue_redraw())
		button.focus_entered.connect(func():
			lines.hovered = i
			_anatomy_inspect(i)
			lines.queue_redraw())
		button.focus_exited.connect(func():
			lines.hovered = -1
			_anatomy_inspect(-1)
			lines.queue_redraw())
		var border := GOLD if selected else CORAL if saturated else TEAL if available else Color("425565")
		if selected and not step.is_empty(): border = TEAL if effect_status == "active" else GOLD if effect_status == "fallback" else CORAL
		button.add_theme_stylebox_override("normal", _style(Color("21332f") if selected else Color("11232c"), border, 14, 0, 2 if selected or available else 1))
		button.add_theme_stylebox_override("hover", _style(Color("203642"), GOLD, 14, 0, 2))
		button.add_theme_stylebox_override("pressed", _style(Color("284039"), GOLD, 14, 0, 2))
		_at(button, Rect2(ShipAnatomy.POSITIONS[i] if anatomy_view else OrganCircuit.POSITIONS[i], ShipAnatomy.NODE_SIZE if anatomy_view else OrganCircuit.NODE_SIZE), graph)
		if anatomy_view:
			_anatomy_organ(button, i, organ, readout, border, strain, int(forecast[i]) if forecast.size() == 6 else strain, selected, available)
			if not step.is_empty():
				var effect_label: Label = button.find_child("OrganEffect", true, false)
				effect_label.text = effect_status.to_upper()
				effect_label.add_theme_color_override("font_color", border)
			continue
		var art := TextureRect.new()
		art.name = "OrganSpecimen"
		art.texture = load("res://art/organs/%s.svg" % organ.id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.modulate = Color.WHITE if selected or available or selected_card < 0 else Color("8a98a6")
		_at(art, Rect2(0, 16, 80, 82), button)
		var key := _screen_text(ORGAN_LETTERS[i], Rect2(193, 6, 21, 21), 14, GOLD if selected else MUTED, button)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_stylebox_override("normal", _style(Color("08131f"), border, 5, 0))
		var title := _screen_text(str(organ.name).trim_prefix("The "), Rect2(84, 5, 109, 24), 16, CREAM, button)
		title.name = "OrganName"
		_screen_text(str(readout[0]), Rect2(82, 27, 134, 23), 16, accent, button)
		var condition := _screen_text(effect_status.capitalize() if not step.is_empty() else str(readout[1]), Rect2(82, 48, 134, 35), 14, border if not step.is_empty() else MUTED, button)
		condition.name = "OrganCondition"
		condition.max_lines_visible = 2
		if selected:
			var order := _screen_text(str(route.find(i) + 1), Rect2(6, 5, 24, 24), 16, NAVY, button)
			order.name = "RouteOrder"
			order.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			order.add_theme_stylebox_override("normal", _style(GOLD, CREAM, 12, 0))
		elif saturated:
			_screen_text("FULL", Rect2(5, 5, 40, 20), 14, CORAL, button)
		var projected: int = int(forecast[i]) if forecast.size() == 6 else strain
		var segment_width := minf(15, 68.0 / maxf(1, battle.capacity) - 3)
		for pip in range(int(battle.capacity)):
			var segment := Panel.new()
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fill := CORAL if saturated else accent if pip < strain else Color("223643")
			var stroke := GOLD if projected != strain and pip < maxi(strain, projected) and pip >= mini(strain, projected) else Color("4a6370")
			segment.add_theme_stylebox_override("panel", _style(fill, stroke, 2, 0))
			_at(segment, Rect2(83 + pip * (segment_width + 3), 88, segment_width, 7), button)
		var value := "%d/%d" % [strain, battle.capacity]
		if forecast.size() == 6 and int(forecast[i]) != strain:
			value = "%d→%d/%d" % [strain, projected, battle.capacity]
		var strain_label := _screen_text(value, Rect2(151, 81, 65, 19), 14, GOLD if projected != strain else CORAL if saturated else MUTED, button)
		strain_label.name = "StrainReadout"
		strain_label.add_theme_font_override("font", theme.default_font)
	lines.queue_redraw()

func _anatomy_organ(button: Button, index: int, organ: Dictionary, readout: Array, border: Color, strain: int, projected: int, selected: bool, available: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 40, 0, 1))
	var socket := OrganSocket.new()
	socket.tint = border
	socket.selected = selected
	socket.available = available
	socket.strain = strain
	socket.projected = projected
	socket.capacity = int(game.run.battle.capacity)
	_at(socket, Rect2(0, 0, 86, 96), button)
	var art := TextureRect.new()
	art.name = "OrganSpecimen"
	art.texture = load("res://art/organs/%s.svg" % organ.id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(art, Rect2(8, 9, 70, 78), button)
	var caption := Panel.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel", _style(Color(0.02, 0.05, 0.075, 0.96), Color.TRANSPARENT, 17, 0))
	_at(caption, Rect2(78, 12, 112, 71), button)
	var name_label := _screen_text(str(organ.name).trim_prefix("The "), Rect2(84, 14, 106, 23), 16, CREAM, button)
	name_label.name = "OrganName"
	var effect_label := _screen_text(str(readout[0]), Rect2(84, 37, 106, 22), 14, Color(str(readout[2])), button)
	effect_label.name = "OrganEffect"
	var value := "%d/%d strain" % [strain, game.run.battle.capacity]
	if strain != projected: value = "%d→%d/%d" % [strain, projected, game.run.battle.capacity]
	var strain_label := _screen_text(value, Rect2(84, 60, 106, 21), 14, GOLD if strain != projected else MUTED, button)
	strain_label.name = "StrainReadout"
	var key := _screen_text(ORGAN_LETTERS[index], Rect2(5, 6, 22, 22), 14, border, button)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_stylebox_override("normal", _style(NAVY, border, 11, 0))
	if selected:
		var order := _screen_text(str(route.find(index) + 1), Rect2(58, 3, 24, 24), 16, NAVY, button)
		order.name = "RouteOrder"
		order.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		order.add_theme_stylebox_override("normal", _style(GOLD, CREAM, 12, 0))
	elif strain >= int(game.run.battle.capacity):
		_screen_text("FULL", Rect2(25, 75, 42, 21), 14, CORAL, button)

func _anatomy_inspect(index: int) -> void:
	if not anatomy_view or not is_instance_valid(anatomy_readout): return
	if index < 0:
		anatomy_readout.text = "%d / 3 ROUTED\nFollow the lit organs" % route.size() if selected_card >= 0 else "LIVING CIRCUIT\nChoose a card to begin"
	else:
		var organ: Dictionary = game.organ(index)
		var readout: Array = OrganVisuals.READOUTS[str(organ.id)]
		anatomy_readout.text = str(organ.name) + "\n" + str(readout[1])

func _intent_text(enemy: Dictionary, enemy_index: int = -1) -> String:
	if enemy.id == "_egg":
		return "Hatches in %d enemy phase(s)" % maxi(1, int(enemy.get("egg_timer", 2)))
	var intent: Dictionary = enemy.get("intent", {})
	var label := str(intent.get("label", str(intent.get("kind", "Unknown")).capitalize()))
	if intent.get("kind", "") == "attack":
		if enemy_index < 0: enemy_index = game.run.battle.enemies.find(enemy)
		var forecast: Dictionary = game.enemy_attack_preview(enemy_index)
		label = label.get_slice(" · ", 0) + " · %d damage" % int(forecast.damage)
		if int(forecast.redirected) > 0: label += " (%d redirected)" % int(forecast.redirected)
	return label

func _preview() -> void:
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", _style(Color(0.025, 0.07, 0.11, 0.92), Color("577b83"), 12, 0))
	_at(strip, Rect2(40, 536, 1360, 72))
	var valid := false
	var heading := "SELECT A COMMAND · TRACE A ROUTE"
	var summary := "Lit organs connect. Filled cells show strain; gold outlines preview the change."
	var full_summary := summary
	if selected_card >= 0 and selected_card < game.run.battle.hand.size():
		var instance: Dictionary = game.run.battle.hand[selected_card]
		var names: Array[String] = []
		for index in route:
			names.append(str(game.organ(index).name))
		heading = str(game.effective_card(instance).name) + "  /  " + (" → ".join(names) if not names.is_empty() else "Choose an organ")
		var result: Dictionary = game.preview_card(selected_card, route, target)
		valid = result.get("ok", false)
		full_summary = str(result.get("summary", "")) if valid else str(result.get("error", "Choose a legal route."))
		full_summary += _resource_flow_text(result)
		summary = "Damage %d · Hull %+d · Disrupt %d · Command points %d → %d" % [int(result.get("damage", 0)), int(result.get("heal", 0)), int(result.get("disrupt", 0)), int(game.run.battle.get("command_points", 3)), int(result.get("command_points", game.run.battle.get("command_points", 3)))] if valid else full_summary
	_screen_text(heading, Rect2(58, 545, 700, 26), 19, TEAL)
	var detail := _screen_text(summary.replace("\n", " · "), Rect2(58, 575, 700, 27), 17, CREAM if selected_card < 0 or valid else CORAL)
	detail.max_lines_visible = 1
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.tooltip_text = full_summary
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	var confirm := _button("Confirm [Space]", _confirm, full_summary, true)
	confirm.disabled = not valid
	_at(confirm, Rect2(790, 549, 184, 50))
	_at(_button("Undo", func():
		if not route.is_empty(): route.pop_back()
		_render(), "Remove the last organ."), Rect2(984, 549, 90, 50))
	_at(_button("Cancel", func():
		_clear_selection()
		_render(), "Clear command and route. [Esc]"), Rect2(1084, 549, 100, 50))
	_at(_button("End turn [E]", _end_turn, "Enemies act, organs cool and a new hand arrives. Shift+E while routing."), Rect2(1194, 549, 190, 50))

func _select_card(index: int) -> void:
	if presentation_busy(): return
	var card: Dictionary = game.effective_card(game.run.battle.hand[index])
	var cost := int(card.get("cost", 1))
	var remaining := int(game.run.battle.get("command_points", 3))
	if cost > remaining:
		notice = "This command costs %d command points; %d remain. End turn to refill to %d." % [cost, remaining, int(game.run.battle.get("max_command_points", 3))]
		_render()
		return
	selected_card = index
	route.clear()
	notice = ""
	_render()

func _select_organ(index: int) -> void:
	if presentation_busy(): return
	if selected_card < 0:
		notice = "Choose a command from your hand first."
	elif route.has(index):
		route.resize(route.find(index))
	elif route.size() >= 3:
		notice = "A route can contain at most three organs. Undo a step to change it."
	else:
		var candidate := route.duplicate()
		candidate.append(index)
		var error: String = game._validate_route(game.run, candidate)
		if error.is_empty():
			route.append(index)
			notice = ""
		else:
			notice = error
	_render()

func _select_target(index: int) -> void:
	if presentation_busy(): return
	target = index
	notice = ""
	_render()

func _confirm() -> void:
	if presentation_busy(): return
	if selected_card < 0:
		return
	var preview: Dictionary = game.preview_card(selected_card, route, target)
	if not preview.get("ok", false):
		notice = str(preview.get("error", "Choose a legal route."))
		_render()
		return
	_perform(func(): return game.play_card(selected_card, route, target), "command")

func _end_turn() -> void:
	if presentation_busy(): return
	_perform(func(): return game.end_turn(), "enemy_phase")

func _rewards() -> void:
	_section("ENCOUNTER COMPLETE", "A signal worth keeping.", "Salvage recovered. Choose one discovery, or keep your deck lean and skip.")
	var choices: Array = game.run.reward.get("choices", [])
	var width := (1312.0 - 24 * (choices.size() - 1)) / maxf(1, choices.size())
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var item: Dictionary = game.effective_card({"id":choice.id}) if choice.kind == "card" else game.powerup(choice.id)
		var box := _surface(Rect2(64 + i * (width + 24), 285, width, 500))
		box.add_theme_constant_override("separation", 10)
		box.add_child(_card_art({"id": choice.id, "level": 0}, 90 if choices.size() >= 4 else 130) if choice.kind == "card" else _art(int(item.get("art", 19)), 90 if choices.size() >= 4 else 130))
		if choice.kind == "card": box.add_child(_printed_stats({"id": choice.id, "level": 0}, true))
		var item_name := _card_title(str(item.get("name", "Discovery")), 24)
		item_name.max_lines_visible = 2
		box.add_child(item_name)
		var description := _text(game.card_text({"id": choice.id, "level": 0}) if choice.kind == "card" else str(item.get("description", "")), 18)
		description.max_lines_visible = 8
		box.add_child(description)
		box.add_child(_button("Take discovery", func(): _perform(func(): return game.choose_reward(i)), "Add this discovery to the expedition.", true))
	_at(_button("Skip reward →", func(): _perform(func(): return game.choose_reward(-1))), Rect2(1080, 814, 296, 52))

func _event() -> void:
	var event: Dictionary = {}
	for item in game.catalog.get("events", []):
		if item.id == game.run.event_id:
			event = item
	_section("ANOMALOUS TRANSMISSION", str(event.get("name", "A strange encounter")))
	_float_art(19, Rect2(80, 235, 560, 330))
	_reading_plate(Rect2(64, 539, 592, 246))
	_screen_text(str(event.get("text", "The frontier waits for a decision.")), Rect2(80, 550, 560, 225), 26, CREAM)
	var choices: Array = event.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var box := _surface(Rect2(720, 300 + i * 218, 650, 186))
		var detail := _text(str(choice.get("detail", "")), 23, GOLD)
		detail.max_lines_visible = 3
		box.add_child(detail)
		box.add_child(_button(str(choice.get("label", "Choose")), func(): _perform(func(): return game.event_choice(i)), str(choice.get("detail", "")), true))
	_at(_button("Leave the signal behind →", func(): _perform(func(): return game.leave_location())), Rect2(1000, 814, 376, 52))

func _shop() -> void:
	_section("SALVAGE EXCHANGE", "Useful things. Unlikely hands.", "Purchases last for this expedition. Upgrades and removals let you choose a command before paying.")
	var items: Array = game.run.shop.get("items", [])
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var data: Dictionary = {}
		if item.kind == "card": data = game.effective_card({"id":item.id})
		elif item.kind == "powerup": data = game.powerup(item.id)
		var box := _surface(Rect2(64 + (i % 3) * 448, 292 + floori(i / 3.0) * 250, 416, 240))
		box.add_theme_constant_override("separation", 4)
		box.add_child(_card_title(str(data.get("name", "Remove a command" if item.kind == "remove" else "Upgrade a command")), 24))
		var desc := game.card_text({"id": item.id, "level": 0}) if item.kind == "card" else str(data.get("description", "Choose one command from your deck."))
		if item.kind == "card": box.add_child(_printed_stats({"id": item.id, "level": 0}, true))
		var description := _text(desc, 19)
		description.max_lines_visible = 3
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.tooltip_text = desc
		description.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(description)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var sold: bool = item.get("sold", false)
		var button := _button("Sold" if sold else "Buy · %d salvage" % item.cost, func(): _perform(func(): return game.buy(i)), "Spend %d salvage." % item.cost, not sold and game.run.salvage >= item.cost)
		button.disabled = sold or game.run.salvage < item.cost
		box.add_child(button)
	_at(_button("Return to the chart →", func(): _perform(func(): return game.leave_location())), Rect2(1040, 814, 336, 52))

func _recovery() -> void:
	_section("A QUIET ORBIT", "Let the engines breathe.", "Take one moment of care before returning to the frontier.")
	_float_art(0, Rect2(130, 265, 440, 340))
	_float_art(19, Rect2(864, 260, 370, 340))
	_reading_plate(Rect2(74, 604, 602, 162))
	_reading_plate(Rect2(764, 604, 602, 162))
	_screen_text("Repair the hull", Rect2(90, 614, 570, 48), 34, TEAL)
	_screen_text("Restore 30 hull, up to your maximum.\nCurrent hull: %d / %d." % [game.run.hull, game.run.max_hull], Rect2(90, 674, 570, 82), 24, CREAM)
	_at(_button("Repair +30 hull", func(): _perform(func(): return game.recover("repair")), "Repair and return to the chart.", true), Rect2(90, 778, 570, 54))
	_screen_text("Refine a command", Rect2(780, 614, 570, 48), 34, GOLD)
	_screen_text("Damage +3. Repair +2. Vent and disrupt +1.\nChoose the exact command to evolve.", Rect2(780, 674, 570, 82), 24, CREAM)
	_at(_button("Choose an upgrade", func(): _perform(func(): return game.recover("upgrade")), "Inspect commands before choosing.", true), Rect2(780, 778, 570, 54))
	_at(_button("Leave without resting", func(): _perform(func(): return game.leave_location())), Rect2(550, 845, 340, 44))

func _modify() -> void:
	var remove: bool = game.run.get("modify_kind", "upgrade") == "remove"
	_section("DECK WORKSHOP", "Release a command." if remove else "Make a command your own.", "Choose the exact copy below. " + ("It will leave your deck." if remove else "Evolved commands gain stronger effects."))
	var pages := maxi(1, ceili(game.run.deck.size() / 6.0))
	modify_page = clampi(modify_page, 0, pages - 1)
	for slot in range(6):
		var i := modify_page * 6 + slot
		if i >= game.run.deck.size(): break
		var instance: Dictionary = game.run.deck[i]
		var card: Dictionary = game.effective_card(instance)
		var box := _surface(Rect2(64 + (slot % 3) * 448, 292 + floori(slot / 3.0) * 246, 416, 228))
		box.add_theme_constant_override("separation", 7)
		box.add_child(_card_title(str(card.name) + (" +" if instance.get("level", 0) > 0 else ""), 26))
		box.add_child(_printed_stats(instance, true))
		var description := _text(game.card_text(instance), 19)
		description.max_lines_visible = 2
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.tooltip_text = game.card_text(instance)
		description.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(description)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var button := _button("Remove" if remove else "Upgrade", func(): _perform(func(): return game.modify_card(i)), "Select this copy.", true)
		button.disabled = not remove and instance.get("level", 0) > 0
		box.add_child(button)
	_at(_button("Cancel selection", func(): _perform(func(): return game.cancel_modify())), Rect2(64, 814, 270, 52))
	var previous := _button("← Previous", func():
		modify_page -= 1
		_render())
	previous.disabled = modify_page == 0
	_at(previous, Rect2(865, 814, 180, 52))
	_screen_text("%d / %d" % [modify_page + 1, pages], Rect2(1060, 826, 100, 32), 21, CREAM)
	var next := _button("Next →", func():
		modify_page += 1
		_render())
	next.disabled = modify_page == pages - 1
	_at(next, Rect2(1176, 814, 200, 52))

func _transition() -> void:
	_section("REGION COMPLETE", "Beyond the familiar dark.", "The hull repairs by 25 as you cross. The next region is waiting.")
	_float_art(0, Rect2(100, 295, 560, 440))
	var regions: Array = game.catalog.get("regions", [])
	var next_stage: int = int(game.run.region) + 1
	var route_regions: Array = game.run.get("route_regions", [0, 1, 2])
	var next: int = int(route_regions[next_stage]) if next_stage < route_regions.size() else -1
	if next >= 0 and next < regions.size():
		_reading_plate(Rect2(738, 322, 640, 326))
		_screen_text(str(regions[next].name), Rect2(755, 340, 600, 120), 45, GOLD)
		_screen_text(str(regions[next].get("description", "")), Rect2(760, 480, 560, 150), 26, CREAM)
	_at(_button("Cross the threshold →", func(): _perform(func(): return game.continue_region()), "Repair 25 hull and enter the next region.", true), Rect2(760, 690, 570, 62))

func _ending() -> void:
	var won: bool = game.run.mode == "victory"
	_section("EXPEDITION CONCLUDED", "You taught the dark your name." if won else "Even stars leave echoes.")
	_float_art(0 if won else 19, Rect2(100, 260, 530, 450))
	_reading_plate(Rect2(159, 723, 472, 85))
	_screen_text("VICTORY" if won else "SHIP LOST", Rect2(175, 733, 440, 65), 42, TEAL if won else CORAL)
	_reading_plate(Rect2(758, 270, 610, 444))
	_screen_text("EXPEDITION RECORD", Rect2(780, 282, 560, 40), 20, GOLD)
	var record := _screen_text("Region %d / 3\nTurns taken  %d\nCommands aboard  %d\nPowerups installed  %d\nSalvage remaining  %d\nSeed  %s" % [game.run.region + 1, game.run.turns, game.run.deck.size(), game.run.powerups.size(), game.run.salvage, str(game.run.seed)], Rect2(780, 338, 560, 270), 27, CREAM)
	record.name = "ExpeditionRecord"
	_screen_text("Seeded practice · no durable progression or unlocks." if game.run.get("seeded", false) else "Discovery tier %d / 3. New possibilities; the same starting strength." % game.profile.get("unlocks", 0), Rect2(780, 622, 560, 75), 22, TEAL)
	if game.run.seed is String:
		_at(_button("Retry seed · " + str(game.run.seed), _retry_seed, "Restart with the same ship and seed. Practice runs do not grant progression."), Rect2(780, 812, 560, 52))
	_at(_button("New expedition", _request_new, "Begin again.", true), Rect2(780, 740, 270, 56))
	_at(_button("Return to title", func():
		menu = true
		_clear_selection()
		_render()), Rect2(1070, 740, 270, 56))

func _retry_seed() -> void:
	if not game.run.get("seed") is String: return
	expedition_seed = str(game.run.seed)
	selected_character = str(game.run.character)
	_clear_selection()
	_new_run()

func _perform(action: Callable, action_kind: String = "") -> void:
	if presentation_busy(): return
	var previous_mode := str(game.run.get("mode", ""))
	var before: Dictionary = game.run.duplicate(true) if previous_mode == "combat" else {}
	var played_route := route.duplicate()
	var played_target := target
	var played_card := {}
	if previous_mode == "combat" and selected_card >= 0 and selected_card < game.run.battle.hand.size():
		played_card = game.run.battle.hand[selected_card].duplicate()
	var result: Dictionary = action.call()
	if result.get("ok", false):
		var next_mode := str(game.run.get("mode", ""))
		if previous_mode != "combat" or next_mode != "combat":
			_sound("transition" if next_mode == "transition" else "reward" if next_mode in ["reward", "victory"] or previous_mode == "reward" else "play")
		notice = ""
		_clear_selection()
	else:
		notice = str(result.get("error", "This action is unavailable."))
	if result.get("ok", false) and previous_mode == "combat":
		_feedback(before, result, action_kind, played_route, played_target, played_card)
		if presentation_busy():
			for button in page.find_children("*", "Button", true, false): button.disabled = true
			var serial := feedback_serial
			var remaining := maxf(0.01, presentation_duration)
			get_tree().create_timer(remaining).timeout.connect(func():
				if serial == feedback_serial: _render())
			return
	_render()

func presentation_busy() -> bool:
	return resolving

func _clear_selection() -> void:
	selected_card = -1
	route.clear()
	target = 0

func _modal(title: String) -> VBoxContainer:
	_close_overlay()
	page.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	overlay = Control.new()
	# Hand cards and combat feedback use elevated canvas layers.
	overlay.z_index = 100
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.045, 0.91)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(minf(900, get_viewport_rect().size.x - 80), 0)
	center.add_child(frame)
	var stack := _column(frame)
	var heading := _row(stack)
	heading.add_child(_label(title, 29))
	_spacer(heading)
	var close := _button("Close  [Esc]", _close_overlay)
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(510, get_viewport_rect().size.y - 190))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var body := _column(scroll)
	close.grab_focus.call_deferred()
	return body

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null
	if is_instance_valid(page):
		page.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED

func _open_menu() -> void:
	var body := _modal("Expedition paused")
	body.add_child(_text("Your progress is saved after each action. Resume when you are ready.", 20, CREAM))
	body.add_child(_button("Resume expedition", _close_overlay, "Return to the current room.", true))
	body.add_child(_button("How to play", _open_help))
	body.add_child(_button("Settings", _open_settings))
	body.add_child(_button("Save and return to title", func():
		game.save()
		menu = true
		_clear_selection()
		_render()))
	body.add_child(_button("Abandon expedition…", func():
		var confirm := _modal("End this expedition?")
		confirm.add_child(_text("Abandoning records a defeat and ends the current voyage. You can still inspect its final deck.", 19, CREAM))
		confirm.add_child(_button("Keep sailing", _close_overlay, "Resume this expedition.", true))
		confirm.add_child(_button("Abandon and record defeat", func(): _perform(func(): return game.abandon())))))

func _open_settings() -> void:
	var body := _modal("Settings")
	var settings: Dictionary = game.profile.get("settings", {})
	body.add_child(_text("Make yourself at home in the dark.", 20, CREAM))
	var motion := CheckBox.new()
	motion.text = "Reduced motion"
	motion.button_pressed = settings.get("reduced_motion", false)
	motion.tooltip_text = "Remove screen fades. All gameplay information remains visible."
	body.add_child(motion)
	var full := CheckBox.new()
	full.text = "Fullscreen"
	full.button_pressed = settings.get("fullscreen", false)
	body.add_child(full)
	var volumes := {}
	for entry in [["volume", "Master", "All game audio."], ["music_volume", "Music & cinematic", "Regional music and the opening film."], ["combat_volume", "Combat effects", "Attacks, impacts, repairs, defenses and round cues."], ["interface_volume", "Interface", "Clicks, menu actions, rewards and region transitions."]]:
		var key := str(entry[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		body.add_child(row)
		var label := _label(str(entry[1]), 18)
		label.custom_minimum_size.x = 190
		row.add_child(label)
		var volume := HSlider.new()
		volume.name = "Volume_" + key
		volume.min_value = 0.0
		volume.max_value = 1.0
		volume.step = 0.05
		volume.value = settings.get(key, 0.5 if key == "volume" else 1.0)
		volume.custom_minimum_size = Vector2(250, 35)
		volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume.tooltip_text = str(entry[2]) + " Zero mutes this category."
		row.add_child(volume)
		var value_label := _label("%d%%" % roundi(volume.value * 100), 18)
		value_label.custom_minimum_size.x = 55
		row.add_child(value_label)
		volume.value_changed.connect(func(value): value_label.text = "%d%%" % roundi(value * 100))
		volumes[key] = volume
	var update := func(_value = null):
		var values := {"reduced_motion": motion.button_pressed, "fullscreen": full.button_pressed}
		for key in volumes: values[key] = volumes[key].value
		game.set_settings(values)
		_apply_settings()
	motion.toggled.connect(update)
	full.toggled.connect(update)
	for volume in volumes.values(): volume.value_changed.connect(update)
	body.add_child(_text("Settings save immediately on this Mac.", 16))

func _apply_settings() -> void:
	var settings: Dictionary = game.profile.get("settings", {})
	var volume := float(settings.get("volume", 0.5))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, volume)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	for category in ["Music", "Combat", "Interface"]:
		var bus := AudioServer.get_bus_index(category)
		if bus < 0: continue
		var level := float(settings.get(category.to_lower() + "_volume", 1.0))
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, level)))
		AudioServer.set_bus_mute(bus, level <= 0.0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)
	_sync_motion()

func _open_help() -> void:
	var body := _modal("The art of routing")
	body.add_child(_text(str(game.character().name) + " — " + str(game.character().description), 21, TEAL))
	body.add_child(_text("1. Choose a command.  2. Trace one to three connected organs.  3. Choose an enemy and confirm the preview.", 22, CREAM))
	body.add_child(_text("Commands resolve immediately and leave your hand. Each card costs 1 or 2 command points; you start each turn with 3. Every routed organ gains 1 strain. An organ at capacity cannot be used. You may play more cards, or End Turn: enemies act, each organ cools by 1, and you draw a new hand.", 18))
	for i in range(game.catalog.get("organs", []).size()):
		var organ: Dictionary = game.organ(i)
		body.add_child(_text("%s  [%s]  —  %s" % [organ.name, ORGAN_LETTERS[i], organ.description], 17, TEAL))
	body.add_child(_text("Vent cools all organs before route strain is applied. Link commands restore severed connections and connect the first and last organ in their route. Ward absorbs damage during the next enemy phase, then resets. Eggs hatch after two enemy phases. Read each enemy's forecast before committing.", 17))
	body.add_child(_text("Icons: bolt = damage; cross = hull repair; broken ring = disruption; hexagon = organ strain; diamond = command points. The gold badge is the card’s command point cost.", 17, CREAM))
	body.add_child(_label("KEYBOARD", 15, GOLD))
	body.add_child(_text("1–5  Select the first five hand cards\nQ W E R T Y  Add organs while a card is selected\nSpace  Confirm route\nE  End turn when no command is selected\nShift+E  End turn at any time\nEsc  Cancel a selection, close a panel or pause\nTab / Shift+Tab  Move focus · Enter  Activate a button\nLeft / Right  Change enemy target when routing\nCards overlap when your hand grows. Hover or focus a card to enlarge it and lift it above the hand. Full card effects remain in the tooltip.", 17, CREAM))
	body.add_child(_text("Hull and salvage persist across the voyage. Deck changes and powerups last for this expedition. Finish or abandon voyages to discover optional cards and powerups; starting stats stay the same.", 17))

func _open_deck() -> void:
	var body := _modal(str(game.character().name) + " · deck")
	if game.run.is_empty():
		body.add_child(_text("Begin an expedition to inspect your commands."))
		return
	body.add_child(_label("INSTALLED POWERUPS", 14, GOLD))
	if game.run.powerups.is_empty():
		body.add_child(_text("No powerups installed yet."))
	for id in game.run.powerups:
		var power: Dictionary = game.powerup(str(id))
		body.add_child(_text(str(power.get("name", id)) + " — " + str(power.get("description", "")), 16, TEAL))
	body.add_child(_label("%d COMMANDS" % game.run.deck.size(), 14, GOLD))
	_deck_grid(body, false)

func _deck_grid(parent: Node, selectable: bool, preview_instances: Array = []) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	var instances: Array = game.run.deck if preview_instances.is_empty() else preview_instances
	for i in range(instances.size()):
		var instance: Dictionary = instances[i]
		var card: Dictionary = game.effective_card(instance)
		var box := _panel(grid)
		box.custom_minimum_size.x = 240
		box.add_child(_card_title(str(card.name) + (" +" if instance.get("level", 0) > 0 else ""), 19))
		box.add_child(_printed_stats(instance, true))
		box.add_child(_text(game.card_text(instance), 17))
		if selectable:
			var button := _button("Remove" if game.run.modify_kind == "remove" else "Upgrade", func(): _perform(func(): return game.modify_card(i)), "Select this exact copy of the card.", true)
			button.disabled = game.run.modify_kind == "upgrade" and instance.get("level", 0) > 0
			box.add_child(button)

func _open_history() -> void:
	var body := _modal("Expedition history")
	var history: Array = game.profile.get("history", [])
	if history.is_empty():
		body.add_child(_text("No concluded expeditions yet. The first page is yours to write.", 22, CREAM))
	for record in history:
		var box := _panel(body)
		var outcome := "Victory" if record.get("won", false) else "Defeat"
		box.add_child(_label(outcome + "  ·  Seed " + str(record.get("seed", "—")), 22, TEAL if outcome.to_lower() == "victory" else CORAL))
		if record.get("seeded", false): box.add_child(_text("Seeded practice · no durable progression or unlocks", 17, GOLD))
		var seconds := int(record.get("seconds", 0))
		box.add_child(_text(str(game.character(str(record.get("character", "cartographer"))).name), 18, TEAL))
		box.add_child(_text("Region %d · %d turns · %d battles · %d:%02d elapsed" % [int(record.get("region", 0)) + 1, int(record.get("turns", 0)), int(record.get("battles", 0)), seconds / 60, seconds % 60], 17))

func _open_unlocks() -> void:
	var body := _modal("Discoveries")
	var tier := int(game.profile.get("unlocks", 0))
	body.add_child(_text("Discovery tier %d / 3. Ordinary expeditions reveal more possibilities; entered-seed practice does not grant progression. Your starting hull and strength stay the same." % tier, 20, CREAM))
	for kind in ["cards", "powerups"]:
		body.add_child(_label(kind.to_upper(), 14, GOLD))
		for item in game.catalog.get(kind, []):
			var required := int(item.get("unlock", 0))
			if required == 0:
				continue
			var unlocked := tier >= required
			var box := _panel(body)
			box.add_child(_label(("Discovered  ·  " if unlocked else "Tier %d  ·  " % required) + str(item.name), 20, TEAL if unlocked else MUTED))
			box.add_child(_text(str(item.get("description", "")), 16))

func _input(event: InputEvent) -> void:
	if is_instance_valid(opening_film): return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if presentation_busy():
		if event.keycode == KEY_ESCAPE:
			_render()
		else:
			get_viewport().set_input_as_handled()
			return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(overlay):
			_close_overlay()
		elif choosing_character:
			choosing_character = false
			_render()
		elif selected_card >= 0:
			_clear_selection()
			_render()
		elif not menu:
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	if menu or is_instance_valid(overlay) or game.run.get("mode", "") != "combat":
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var index: int = event.keycode - KEY_1
		if index < game.run.battle.hand.size():
			_select_card(index)
	elif event.keycode == KEY_E and (event.shift_pressed or selected_card < 0):
		_end_turn()
	elif event.keycode in ORGAN_KEYS and selected_card >= 0:
		_select_organ(ORGAN_KEYS.find(event.keycode))
	elif event.keycode == KEY_SPACE:
		_confirm()
	elif event.keycode in [KEY_LEFT, KEY_RIGHT] and selected_card >= 0:
		var living: Array[int] = []
		for i in range(game.run.battle.enemies.size()):
			if game.run.battle.enemies[i].hp > 0:
				living.append(i)
		if not living.is_empty():
			var current := living.find(target)
			var step := 1 if event.keycode == KEY_RIGHT else -1
			_select_target(living[posmod(current + step, living.size())])
	else:
		return
	get_viewport().set_input_as_handled()

func _audio_setup() -> void:
	for category in ["Music", "Combat", "Interface"]:
		if AudioServer.get_bus_index(category) >= 0: continue
		var index := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index, category)
		AudioServer.set_bus_send(index, "Master")
	audio = AudioStreamPlayer.new()
	audio.bus = "Interface"
	add_child(audio)
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Music"
	ambience.volume_db = -3
	add_child(ambience)
	for cue in ["click", "play", "impact", "reward", "transition"]:
		var path := "res://audio/%s.wav" % cue
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream != null:
				sounds[cue] = stream
	var combat_cues: Array[String] = ["repair", "shield", "disrupt", "vent", "sever", "link", "phase", "ready", "draw"]
	for family in ["kinetic", "plasma", "fracture", "sonic", "memory", "beam"]:
		combat_cues.append(family + "_launch")
		combat_cues.append(family + "_hit")
	for cue in combat_cues:
		var path := "res://audio/combat_%s.wav" % cue
		if ResourceLoader.exists(path): sounds["combat_" + cue] = load(path)
	# Independent voices preserve launch tails, split hits and defensive layers.
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Combat"
		audio.add_child(voice)
		combat_voices.append(voice)
	for index in range(game.catalog.regions.size()):
		var path := "res://audio/region_%d.wav" % index
		if ResourceLoader.exists(path):
			var stream: AudioStreamWAV = load(path)
			if stream != null:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_end = maxi(0, roundi(stream.get_length() * stream.mix_rate) - 1)
				tracks[index] = stream
	if tracks.is_empty() and ResourceLoader.exists("res://audio/ambient.wav"):
		var fallback: AudioStreamWAV = load("res://audio/ambient.wav")
		if fallback != null:
			fallback.loop_mode = AudioStreamWAV.LOOP_FORWARD
			fallback.loop_end = maxi(0, roundi(fallback.get_length() * fallback.mix_rate) - 1)
			tracks[0] = fallback

func _sound(cue: String) -> void:
	if is_instance_valid(audio) and sounds.has(cue):
		audio.stream = sounds[cue]
		audio.play()

func _combat_sound(cue: Dictionary, launch: bool = false) -> void:
	var kind := str(cue.get("kind", ""))
	var sound := ""
	if kind in ["shot", "beam", "enemy_shot"]:
		var family := str(cue.get("style", "kinetic"))
		if kind == "beam" and family == "kinetic": family = "beam"
		sound = family + ("_launch" if launch else "_hit")
	elif not launch:
		sound = {"repair":"repair", "shield":"shield", "disrupt":"disrupt", "vent":"vent", "sever":"sever", "link":"link", "phase":"phase", "ready":"ready", "draw":"draw", "mark":"disrupt", "incubate":"link"}.get(kind, "")
	if sound.is_empty() or not sounds.has("combat_" + sound) or combat_voices.is_empty(): return
	var now := Time.get_ticks_msec()
	# Six cooling organs / simultaneous split targets should not multiply loudness.
	if now - int(combat_sound_times.get(sound, -1000)) < 65: return
	combat_sound_times[sound] = now
	var voice := combat_voices[combat_voice_cursor % combat_voices.size()]
	combat_voice_cursor += 1
	for available in combat_voices:
		if not available.playing:
			voice = available
			break
	voice.stream = sounds["combat_" + sound]
	var strength := clampf(absf(float(cue.get("hp_delta", 8))) / 20.0, 0, 1)
	voice.volume_db = -10.0 + strength * 3.0 if cue.has("hp_delta") else -13.0
	# Deterministic micro-variation never consumes the game's random seed.
	voice.pitch_scale = 1.0 + (posmod(feedback_serial + combat_voice_cursor * 3, 7) - 3) * 0.016
	if kind == "enemy_shot": voice.pitch_scale *= 0.88
	voice.play()

func _tick() -> void:
	_sound("click")


func _at(control: Control, rect: Rect2, parent: Node = null) -> Control:
	if parent == null: parent = page
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size
	if control is Label: control.set_deferred("size", rect.size)
	return control

func _screen_text(text: String, rect: Rect2, font_size: int = 20, color: Color = CREAM, parent: Node = null) -> Label:
	var label := _text(text, font_size, color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.04, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(label, rect, parent)
	return label

func _reading_plate(rect: Rect2, parent: Node = null) -> void:
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _style(Color(0.025, 0.05, 0.08, 0.94), Color.TRANSPARENT, 10, 0))
	_at(plate, rect, parent)

func _surface(rect: Rect2) -> VBoxContainer:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _style(Color(0.025, 0.06, 0.10, 0.96), Color("49606d"), 14, 0))
	_at(frame, rect)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_at(body, Rect2(Vector2(18, 18), rect.size - Vector2(36, 36)), frame)
	return body

func _layout_stage() -> void:
	if not is_instance_valid(page): return
	# Canvas coordinates stay logical when Godot stretches the window.
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1440.0, viewport_size.y / 900.0)
	page.scale = Vector2(factor, factor)
	page.position = (viewport_size - Vector2(1440, 900) * factor) * 0.5

func _float_art(slot: int, rect: Rect2) -> TextureRect:
	var image := _art(slot, rect.size.y)
	_at(image, rect)
	image.set_meta("idle_y", rect.position.y)
	if not game.profile.get("settings", {}).get("reduced_motion", false):
		_animate_art(image)
	return image

func _animate_art(image: TextureRect) -> void:
	var y := float(image.get_meta("idle_y"))
	var tween := image.create_tween().set_loops()
	image.set_meta("idle_tween", tween)
	tween.tween_property(image, "position:y", y - 7, 3.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(image, "position:y", y, 3.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _sync_motion() -> void:
	var reduced: bool = game.profile.get("settings", {}).get("reduced_motion", false)
	for child in get_children():
		if child.get_script() == SpaceCanvas:
			child.animate_stars = not reduced
			child.set_process(not reduced)
	if not is_instance_valid(page): return
	var circuit = page.find_child("NeuralConduits", true, false)
	if circuit != null:
		circuit.reduced_motion = reduced
		circuit.set_process(not reduced)
		circuit.queue_redraw()
	for image in page.find_children("*", "TextureRect", true, false):
		if not image.has_meta("idle_y"): continue
		var old_tween = image.get_meta("idle_tween") if image.has_meta("idle_tween") else null
		if old_tween != null and old_tween.is_valid(): old_tween.kill()
		if not reduced: _animate_art(image)

func _map_details(node: Dictionary) -> void:
	if not is_instance_valid(map_detail): return
	for child in map_detail.get_children():
		map_detail.remove_child(child)
		child.queue_free()
	var reachable: bool = game.reachable(node)
	map_detail.add_child(_label("DESTINATION %02d" % (int(node.layer) + 1), 18, GOLD))
	map_detail.add_child(_text(str(node.type).to_upper(), 31, TEAL if reachable else CREAM))
	var slot := 19
	if not node.get("enemy_ids", []).is_empty():
		slot = int(game.enemy(str(node.enemy_ids[0])).get("art", 19))
	map_detail.add_child(_enemy_image(str(node.enemy_ids[0]), 160) if not node.get("enemy_ids", []).is_empty() else _art(slot, 160))
	var name_label := _text(_node_name(node), 25, CREAM)
	name_label.max_lines_visible = 2
	name_label.tooltip_text = _node_name(node)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	map_detail.add_child(name_label)
	var detail := "Choose this connected destination to travel."
	if node.type == "recovery": detail = "Repair 30 hull or evolve a command."
	elif node.type == "shop": detail = "Spend salvage on commands, powerups or deck work."
	elif node.type == "event": detail = "A consequential choice awaits."
	elif node.type == "elite": detail = "A harder fight, with discoveries to recover."
	elif node.type == "boss": detail = "Defeat this guardian to cross the region."
	var detail_label := _text(detail, 20)
	detail_label.max_lines_visible = 3
	map_detail.add_child(detail_label)
	var button := _button("Travel here →" if reachable else "Follow a connected branch", func(): _perform(func(): return game.choose_node(str(node.id))), _node_name(node), true)
	button.disabled = not reachable
	map_detail.add_child(button)

func _hand() -> void:
	var hand: Array = game.run.battle.hand
	var points := int(game.run.battle.get("command_points", 3))
	for i in range(hand.size()):
		var instance: Dictionary = hand[i]
		var card: Dictionary = game.effective_card(instance)
		var cost := int(card.get("cost", 1))
		var affordable := cost <= points
		var tip := "%d command point%s. %d remaining.\n" % [cost, "s" if cost != 1 else "", points] + game.card_text(instance)
		if not affordable: tip += "\nEnd your turn to refill command points. Hover to inspect this card."
		var button := _button("", func(): _select_card(i), tip, selected_card == i)
		button.name = "Hand%d" % i
		button.set_meta("focus_key", "hand%d" % i)
		button.clip_contents = true
		button.disabled = not affordable
		var edge: Color = CORAL if card.get("kind", "") == "attack" else TEAL if card.get("kind", "") == "repair" else GOLD
		button.add_theme_stylebox_override("normal", _style(Color("10202d"), TEAL if selected_card == i else edge.darkened(0.25), 13, 0, 2))
		button.add_theme_stylebox_override("hover", _style(Color("172f3b"), GOLD, 13, 0, 2))
		button.add_theme_stylebox_override("disabled", _style(Color("17202a"), Color("62727e"), 13, 0, 2))
		_at(button, Rect2(0, 670, 160, 210))
		hand_buttons.append(button)
		var face := _card_face(button, instance, false, affordable)
		button.set_meta("title_label", face.title)
		button.set_meta("description_label", face.description)
		button.set_meta("card_art", face.art)
		button.mouse_entered.connect(func():
			hover_card = i
			_arrange_hand())
		button.mouse_exited.connect(func():
			if hover_card == i:
				hover_card = -1
				_arrange_hand())
		button.focus_entered.connect(func():
			hover_card = i
			_arrange_hand())
		button.focus_exited.connect(func():
			if hover_card == i:
				hover_card = -1
				_arrange_hand())
	_arrange_hand()

func _arrange_hand() -> void:
	var raised := hover_card if hover_card >= 0 else selected_card
	var step := minf(182, 1180.0 / maxf(1, hand_buttons.size() - 1))
	var left := (1440.0 - 160 - step * (hand_buttons.size() - 1)) * 0.5
	for i in range(hand_buttons.size()):
		var button: Button = hand_buttons[i]
		var lifted := i == raised
		button.position = Vector2(clampf(left + i * step - (20 if lifted else 0), 40, 1200 if lifted else 1240), 630 if lifted else 670)
		button.size = Vector2(200, 250) if lifted else Vector2(160, 210)
		button.z_index = 50 if lifted else i
		var title: Label = button.get_meta("title_label")
		var description: Label = button.get_meta("description_label")
		var art: TextureRect = button.get_meta("card_art")
		title.add_theme_font_size_override("font_size", 17 if lifted else 15)
		description.add_theme_font_size_override("font_size", 16)
		description.max_lines_visible = 3 if lifted else 2
		art.custom_minimum_size.y = 24

func _card_face(parent: Control, instance: Dictionary, expanded: bool, affordable: bool) -> Dictionary:
	var card: Dictionary = game.effective_card(instance)
	var text := game.card_text(instance)
	var long_text := text.length() > 95 or text.contains("\n")
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 3)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 6
	body.offset_right = -6
	body.offset_top = 6
	body.offset_bottom = -6
	parent.add_child(body)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 40
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 7)
	body.add_child(header)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(30, 30)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _style(GOLD if affordable else MUTED, Color("f8df9c"), 18, 0, 2))
	header.add_child(badge)
	var cost_label := _label(str(int(card.get("cost", 1))), 23, NAVY)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(cost_label)
	var title := _card_title(str(card.name) + (" +" if instance.get("level", 0) > 0 else ""), 16 if expanded else 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", title_font)
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	var art := _card_art(instance, 24)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(art)
	var description := _text(text, 16, CREAM)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.max_lines_visible = 3 if expanded else 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(description)
	var footer := _printed_stats(instance, false)
	footer.name = "CardEffects"
	footer.add_theme_constant_override("h_separation", 6)
	for token in footer.get_children():
		token.add_theme_constant_override("separation", 2)
		for item in token.get_children():
			if item is Label: item.add_theme_font_size_override("font_size", 15)
			else: item.custom_minimum_size = Vector2(16, 18)
	body.add_child(footer)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in footer.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return {"title": title, "description": description, "art": art}

func _soundtrack() -> void:
	var index := 0 if menu else _area_index()
	if music_region == index or tracks.is_empty(): return
	var stream = tracks.get(index, tracks.get(0))
	if stream == null: return
	music_region = index
	ambience.stream = stream
	ambience.play()

func _feedback(before: Dictionary, result: Dictionary, action_kind: String, played_route: Array, played_target: int, played_card: Dictionary) -> void:
	last_feedback = _feedback_plan(before, result, action_kind, played_route, played_target, played_card)
	if last_feedback.is_empty(): return
	var reduced: bool = game.profile.get("settings", {}).get("reduced_motion", false)
	feedback_serial += 1
	var serial := feedback_serial
	var duration := 0.0
	for cue in last_feedback:
		var points: bool = cue.has("hp_delta") and int(cue.hp_delta) != 0
		var travel := 0.28 if not reduced and str(cue.kind) in ["shot", "beam", "enemy_shot"] else 0.0
		duration = maxf(duration, float(cue.get("delay", 0)) + (travel + 2.02 if points else 0.65 if reduced else 0.9))
	presentation_duration = duration
	resolving = true
	for cue in last_feedback:
		var wait := float(cue.get("delay", 0))
		if wait <= 0:
			if reduced: _static_cue(cue)
			else: _play_cue(cue)
		else:
			get_tree().create_timer(wait).timeout.connect(func():
				if serial == feedback_serial and is_instance_valid(page):
					if reduced: _static_cue(cue)
					else: _play_cue(cue))

func _static_cue(cue: Dictionary) -> void:
	_combat_sound(cue, true)
	_apply_cue_impact(cue, false)
	if not str(cue.get("label", "")).is_empty():
		_cue_label(str(cue.label), cue.get("to", Vector2(720, 250)), cue.get("color", CREAM), false)

func _attack_style(card: Dictionary) -> String:
	if card.get("character", "") == "hollow_choir": return "sonic"
	if card.get("character", "") == "palimpsest": return "memory"
	var id := str(card.get("id", ""))
	if id in ["wake_lance", "thread_cannon", "long_hem"]: return "beam"
	if id in ["sun_splinter", "last_match", "ember_abacus", "whole_horizon"]: return "plasma"
	if id in ["glass_murmur", "votive_shard", "mirror_cut", "winter_needle"]: return "fracture"
	if int(card.get("disrupt", 0)) > 0: return "sonic"
	return "kinetic"

func _style_color(style: String) -> Color:
	return {"kinetic":CORAL, "plasma":Color("ffb65c"), "fracture":Color("98dfff"), "sonic":Color("cca7ff"), "memory":Color("a8c5ff"), "beam":GOLD}.get(style, CORAL)

func _feedback_plan(before: Dictionary, result: Dictionary, action_kind: String, played_route: Array, played_target: int, played_card: Dictionary) -> Array:
	var cues: Array = []
	var uses_lens := false
	var uses_echo := false
	for index in played_route:
		uses_lens = uses_lens or str(game.organ(int(index)).id) == "lens"
		uses_echo = uses_echo or str(game.organ(int(index)).id) == "echo"
	var battle: Dictionary = before.get("battle", {})
	var ship := Vector2(410, 350) if anatomy_view else PLAYER_COMBAT_RECT.get_center()
	var old_enemies: Array = battle.get("enemies", [])
	var locations := _enemy_layout(old_enemies.size())
	var records: Array = result.get("presentation", [])
	var enemy_phase := action_kind == "enemy_phase"
	var attack_style := _attack_style(game.effective_card(played_card)) if not played_card.is_empty() else "kinetic"
	var phase_tail := old_enemies.size() * 0.32 + 0.1 if enemy_phase else 0.0
	var command_impact := 0.3 if not enemy_phase and int(result.get("damage", 0)) > 0 else 0.0
	var cooling: Array = []
	var phase_source := 0
	var signaled_sources: Array[int] = []
	if enemy_phase:
		cues.append({"kind":"phase", "to":Vector2(1100, 190), "color":CORAL, "label":"ENEMY PHASE"})
		if game.run.get("mode", "") == "combat":
			cues.append({"kind":"ready", "to":ship + Vector2(0, 100), "color":TEAL, "label":"COMMAND POINTS REFILLED", "delay":phase_tail + 0.35})
	elif not played_card.is_empty():
		var definition: Dictionary = game.effective_card(played_card)
		if int(definition.get("draw", 0)) > 0:
			cues.append({"kind":"draw", "to":ship + Vector2(0, 80), "color":GOLD, "delay":command_impact})
	for event in records:
		var kind := str(event.get("kind", ""))
		if event.has("source_index"): phase_source = int(event.source_index)
		var source_index := int(event.get("source_index", -1))
		var index := int(event.get("target_index", 0))
		var point := _enemy_effect_point(locations[clampi(index, 0, locations.size() - 1)], old_enemies.size()) if not locations.is_empty() else Vector2(1120, 320)
		var origin := _enemy_effect_point(locations[clampi(source_index, 0, locations.size() - 1)], old_enemies.size()) if source_index >= 0 and not locations.is_empty() else ship
		var delay := source_index * 0.32 if source_index >= 0 else command_impact
		var amount := int(event.get("amount", 0))
		if enemy_phase and source_index >= 0 and not signaled_sources.has(source_index):
			signaled_sources.append(source_index)
			cues.append({"kind":"charge", "to":origin, "color":CORAL, "delay":delay})
		match kind:
			"damage":
				if amount > 0: cues.append({"kind":"beam" if uses_lens or source_index >= 0 else "shot", "from":origin, "to":point, "label":"−%d" % amount, "color":GOLD if source_index >= 0 or event.get("split", false) else CORAL, "target_index":index, "hp_delta":-amount, "delay":source_index * 0.32 if source_index >= 0 else 0.0, "echo":uses_echo})
				if amount > 0 and source_index < 0:
					cues[-1]["style"] = attack_style
					cues[-1]["color"] = _style_color(attack_style)
			"enemy_attack":
				var absorbed := int(event.get("absorbed", 0))
				var redirected := int(event.get("redirected", 0))
				if amount > 0:
					cues.append({"kind":"enemy_shot", "from":origin, "to":ship, "label":"HULL −%d" % amount, "color":CORAL, "delay":delay, "player":true, "hp_delta":-amount})
					var region := int(game.enemy(str(old_enemies[source_index].id)).get("region", 0)) if source_index >= 0 else 0
					var style := str(["plasma", "kinetic", "fracture", "sonic", "memory", "fracture"][clampi(region, 0, 5)])
					cues[-1]["style"] = style
					cues[-1]["color"] = _style_color(style)
					if absorbed > 0: cues.append({"kind":"shield", "to":ship, "color":TEAL, "delay":delay + 0.24, "player":true})
				elif absorbed > 0:
					cues.append({"kind":"shield", "to":ship, "label":"WARD ABSORBED %d" % absorbed, "color":TEAL, "delay":delay + 0.28, "player":true})
				elif redirected == 0:
					cues.append({"kind":"disrupt", "to":origin, "label":"ATTACK NULLIFIED", "color":Color("cca7ff"), "delay":delay})
			"hull_damage":
				if amount > 0: cues.append({"kind":"mark", "to":ship, "label":"REPEATED ROUTE −%d" % amount, "color":CORAL, "player":true, "hp_delta":-amount})
				elif int(event.get("absorbed", 0)) > 0: cues.append({"kind":"shield", "to":ship, "label":"WARD ABSORBED %d" % int(event.absorbed), "color":TEAL, "player":true})
			"heal", "player_heal":
				if amount <= 0: continue
				var emergency: bool = event.get("source", "") == "emergency"
				var heal_delay := phase_source * 0.32 + 0.3 if enemy_phase and emergency else phase_tail if enemy_phase else command_impact
				cues.append({"kind":"repair", "to":ship, "label":("REIGNITED +" if emergency else "REPAIR +") + str(amount), "color":GOLD if emergency else TEAL, "player":true, "hp_delta":amount, "delay":heal_delay})
			"enemy_heal":
				if amount > 0: cues.append({"kind":"repair", "to":point, "label":"REPAIR +%d" % amount, "color":TEAL, "target_index":index, "hp_delta":amount, "delay":delay})
			"interrupted":
				cues.append({"kind":"disrupt", "to":origin, "label":"INTERRUPTED", "color":TEAL, "delay":delay})
			"disrupt":
				if amount > 0: cues.append({"kind":"disrupt", "to":point, "label":"DISRUPT +%d" % amount, "color":Color("cca7ff"), "target_index":index, "delay":command_impact})
				if amount > 0: cues.append({"kind":"link", "to":ship, "color":Color("cca7ff"), "player":true, "delay":command_impact})
			"redirect":
				if amount > 0: cues.append({"kind":"shield", "to":point, "label":"REDIRECT +%d" % amount, "color":GOLD, "target_index":index, "delay":command_impact})
				if amount > 0: cues.append({"kind":"link", "to":ship, "color":GOLD, "player":true, "delay":command_impact})
			"cooling":
				cooling = event.get("amounts", [])
				for i in range(mini(6, cooling.size())):
					if int(cooling[i]) > 0: cues.append({"kind":"vent", "to":_organ_center(i), "label":"COOL −%d" % int(cooling[i]), "color":Color("98dfff"), "delay":phase_tail if enemy_phase else command_impact})
			"strain":
				var additions: Array = event.get("amounts", [])
				for i in range(mini(6, additions.size())):
					if int(additions[i]) > 0: cues.append({"kind":"strain", "from":origin, "to":_organ_center(i), "label":"STRAIN +%d" % int(additions[i]), "color":CORAL, "delay":delay})
			"sever":
				var edge: Array = event.get("edge", [])
				if edge.size() == 2: cues.append({"kind":"sever", "to":(_organ_center(int(edge[0])) + _organ_center(int(edge[1]))) * 0.5, "route":edge, "label":"LINK SEVERED", "color":CORAL, "delay":delay})
			"mark": cues.append({"kind":"mark", "to":ship, "label":"MARK: REPEAT COSTS %d" % amount, "color":GOLD, "delay":delay})
			"incubate": cues.append({"kind":"incubate", "to":origin, "label":"EGG · %d HULL" % amount, "color":GOLD, "delay":delay})
			"trace", "resonance":
				cues.append({"kind":"link", "to":Vector2(180, 492), "label":"%s %d → %d" % [kind.to_upper(), int(event.get("before", 0)), int(event.get("after", 0))], "color":TEAL if kind == "trace" else GOLD, "delay":command_impact})
			"ward":
				if amount > 0: cues.append({"kind":"shield", "to":ship, "label":"WARD +%d" % amount, "color":TEAL, "player":true, "delay":command_impact})
			"link": cues.append({"kind":"link", "to":ship, "label":"LINKS RESTORED", "color":TEAL, "player":true, "delay":command_impact})
	if not enemy_phase:
		var after: Array = result.get("strain", [])
		var previous: Array = battle.get("strain", [])
		for i in range(mini(6, mini(previous.size(), after.size()))):
			var cooled := int(cooling[i]) if i < cooling.size() else 0
			var increase := int(after[i]) - maxi(0, int(previous[i]) - cooled)
			if increase > 0: cues.append({"kind":"strain", "to":_organ_center(i), "label":"STRAIN +%d" % increase, "color":GOLD, "delay":command_impact + 0.15})
		if not played_route.is_empty(): cues.append({"kind":"route", "to":_organ_center(int(played_route[-1])), "route":played_route, "color":TEAL})
	return cues

func _play_cue(cue: Dictionary) -> void:
	if game.profile.get("settings", {}).get("reduced_motion", false):
		_static_cue(cue)
		return
	_combat_sound(cue, true)
	var effect := SpaceCanvas.new()
	effect.stars = false
	effect.effect_kind = str(cue.get("kind", "shot"))
	effect.effect_from = cue.get("from", cue.get("to", Vector2.ZERO))
	effect.effect_to = cue.get("to", Vector2.ZERO)
	effect.effect_color = cue.get("color", TEAL)
	effect.effect_echo = cue.get("echo", false)
	effect.effect_style = str(cue.get("style", "kinetic"))
	for index in cue.get("route", []): effect.effect_route.append(_organ_center(int(index)))
	effect.z_index = 40
	_at(effect, Rect2(0, 0, 1440, 900))
	var duration := 0.65 if effect.effect_kind in ["repair", "vent", "link"] else 0.5
	var tween := effect.create_tween()
	tween.tween_property(effect, "effect_progress", 1.0, duration)
	tween.tween_callback(effect.queue_free)
	var impact_delay := 0.28 if effect.effect_kind in ["shot", "beam", "enemy_shot"] else 0.0
	if impact_delay <= 0:
		_apply_cue_impact(cue, true)
	else:
		var serial := feedback_serial
		get_tree().create_timer(impact_delay).timeout.connect(func():
			if serial == feedback_serial: _apply_cue_impact(cue, true))

func _apply_cue_impact(cue: Dictionary, animated: bool) -> void:
	_combat_sound(cue)
	var color: Color = cue.get("color", TEAL)
	var kind := str(cue.get("kind", ""))
	var index := int(cue.get("target_index", -1))
	if not str(cue.get("label", "")).is_empty():
		var points: bool = cue.has("hp_delta") and int(cue.hp_delta) != 0
		_cue_label("%+d" % int(cue.hp_delta) if points else str(cue.label), cue.get("to", Vector2(720, 250)), color, animated, points)
	var bar: ProgressBar = player_hull if cue.get("player", false) else enemy_hulls[index] if index >= 0 and index < enemy_hulls.size() else null
	if is_instance_valid(bar) and cue.has("hp_delta"):
		bar.value = clampf(bar.value + int(cue.hp_delta), 0, bar.max_value)
		var label_name := "PlayerHullText" if cue.get("player", false) else "EnemyHullText%d" % index
		var label := page.find_child(label_name, true, false)
		if label != null: label.text = "%d / %d HULL" % [int(bar.value), int(bar.max_value)]
		if cue.get("player", false):
			var header := page.find_child("HeaderHull", true, false)
			if header != null:
				header.text = "HULL  %d / %d" % [int(bar.value), int(bar.max_value)]
				header.add_theme_color_override("font_color", CORAL if bar.value < 30 else TEAL)
	if not animated: return
	var image: TextureRect = player_art if cue.get("player", false) else enemy_art[index] if index >= 0 and index < enemy_art.size() else null
	if is_instance_valid(image):
		_impact_art(image, color, kind in ["shot", "beam", "enemy_shot"])
		if not cue.get("player", false) and is_instance_valid(bar) and bar.value <= 0:
			image.create_tween().tween_property(image, "modulate:a", 0.0, 0.35)

func _impact_art(image: TextureRect, color: Color, shake: bool) -> void:
	if not is_instance_valid(image): return
	var tint := Color(1.65, 1.4, 1.25, 1.0) if shake else color.lightened(0.4)
	var tween := image.create_tween()
	tween.tween_property(image, "self_modulate", tint, 0.035)
	tween.tween_interval(0.11)
	tween.tween_property(image, "self_modulate", Color.WHITE, 0.4)
	if shake:
		var original_x := image.position.x
		var movement := image.create_tween()
		movement.tween_property(image, "position:x", original_x + 14, 0.06)
		movement.tween_property(image, "position:x", original_x - 10, 0.08)
		movement.tween_property(image, "position:x", original_x, 0.16)

func _cue_label(text: String, point: Vector2, color: Color, animated: bool, prominent: bool = false) -> void:
	var position := Vector2(clampf(point.x - 85, 20, 1210), clampf(point.y - 25, 160, 480))
	var lane := 0
	if prominent:
		var occupied: Array[int] = []
		for previous in page.find_children("*", "Label", true, false):
			if previous.get_meta("damage_points", false) and Vector2(previous.get_meta("feedback_anchor", Vector2.ZERO)).distance_to(point) < 8:
				occupied.append(int(previous.get_meta("feedback_lane", 0)))
		while occupied.has(lane) and lane < 5: lane += 1
		var offsets := [Vector2(-55, -45), Vector2(55, -45), Vector2(-55, 15), Vector2(55, 15), Vector2(0, -105), Vector2(0, 75)]
		position = point + offsets[lane] - Vector2(90, 30)
		position.x = clampf(position.x, 20 if point.x < 800 else 800, 620 if point.x < 800 else 1240)
		position.y = clampf(position.y, 170, 470)
	else:
		for previous in page.find_children("*", "Label", true, false):
			if previous.has_meta("feedback_anchor") and not previous.get_meta("damage_points", false) and Vector2(previous.get_meta("feedback_anchor")).distance_to(point) < 8: previous.queue_free()
	var label := _screen_text(text, Rect2(position, Vector2(180, 60) if prominent else Vector2(210, 35)), 40 if prominent else 25, color.lightened(0.35) if prominent else color)
	label.set_meta("feedback_anchor", point)
	label.set_meta("feedback_lane", lane)
	label.set_meta("damage_points", prominent)
	label.name = "DamagePoints" if prominent else "CombatFeedback"
	label.add_theme_font_override("font", title_font)
	label.z_index = 70
	if prominent:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 1.0))
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_y", 3)
	var lifetime := 2.0 if prominent else 0.8
	if animated:
		var tween := label.create_tween().set_parallel()
		tween.tween_property(label, "position:y", position.y - (18 if prominent else 32), lifetime)
		tween.tween_property(label, "modulate:a", 0.0, 0.45 if prominent else lifetime).set_delay(1.55 if prominent else 0.0)
		tween.chain().tween_callback(label.queue_free)
	else:
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = lifetime
		label.add_child(timer)
		timer.timeout.connect(label.queue_free)
		timer.start()

func _organ_center(index: int) -> Vector2:
	return ShipAnatomy.center(index) if anatomy_view else OrganCircuit.center(index)

func _enemy_layout(count: int) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if count <= 3:
		var width := (590.0 - maxi(0, count - 1) * 12) / maxf(1, count)
		for i in range(count): rectangles.append(Rect2(810 + i * (width + 12), 174, width, 354))
	else:
		for i in range(count):
			var row := i / 3
			var row_count := mini(3, count - row * 3)
			var left := 810 + (590 - row_count * 190 - (row_count - 1) * 10) * 0.5
			rectangles.append(Rect2(left + (i % 3) * 200, 174 + row * 180, 190, 174))
	return rectangles

func _enemy_effect_point(rect: Rect2, count: int) -> Vector2:
	# Anchor hits to the artwork, above the name, hull bar and intent badge.
	return rect.position + (Vector2(61, 43) if count > 3 else Vector2(rect.size.x * 0.5, 101))

func _enemy_target(index: int, enemy: Dictionary, rect: Rect2, count: int) -> void:
	var definition: Dictionary = game.enemy(str(enemy.id))
	var selected := target == index
	var button := _button("", func(): _select_target(index), str(enemy.name) + "\n" + game.enemy_tactics_text(index), selected)
	button.name = "EnemyTarget%d" % index
	button.set_meta("focus_key", "enemy%d" % index)
	var transparent := _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, transparent)
	_at(button, rect)
	var small := count > 3
	_reading_plate(Rect2(0, 84 if small else 198, rect.size.x, 90 if small else 156), button)
	if small: _reading_plate(Rect2(116, 4, rect.size.x - 116, 82), button)
	var title := _screen_text(("› " if selected else "") + str(enemy.name), Rect2(8, 84 if small else 198, rect.size.x - 16, 46 if small else 56), 16 if small else 20, TEAL if selected else CREAM, button)
	title.name = "EnemyName%d" % index
	title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_entered.connect(func():
		title.text = "› " + str(enemy.name)
		title.add_theme_color_override("font_color", GOLD))
	button.focus_exited.connect(func():
		title.text = ("› " if selected else "") + str(enemy.name)
		title.add_theme_color_override("font_color", TEAL if selected else CREAM))
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var art_rect := Rect2(6, 4, 110, 78) if small else Rect2(10, 4, rect.size.x - 20, 194)
	var image := _enemy_image(str(enemy.id), art_rect.size.y)
	image.name = "EnemyArt%d" % index
	image.flip_h = true
	_at(image, art_rect, button)
	enemy_art.append(image)
	var hp := _hull_bar(enemy.hp, enemy.max_hp, CORAL)
	hp.name = "EnemyHullBar%d" % index
	_at(hp, Rect2(8, 160 if small else 284, rect.size.x - 16, 9), button)
	enemy_hulls.append(hp)
	var hull := _screen_text("%d / %d HULL" % [enemy.hp, enemy.max_hp], Rect2(8, 133 if small else 256, rect.size.x - 16, 22 if small else 24), 16 if small else 18, CREAM, button)
	hull.name = "EnemyHullText%d" % index
	hull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_badge(enemy, index, button, Rect2(120, 16, rect.size.x - 126, 54) if small else Rect2(10, 302, rect.size.x - 20, 42))

func _intent_badge(enemy: Dictionary, index: int, parent: Control, rect: Rect2) -> void:
	var kind := "incubate" if enemy.id == "_egg" else str(enemy.intent.kind)
	var amount := int(enemy.intent.get("amount", 0))
	var detail := ""
	var title := ""
	var color := CORAL
	match kind:
		"attack":
			var forecast: Dictionary = game.enemy_attack_preview(index)
			amount = int(forecast.damage)
			title = "Incoming attack"
			detail = "[b]%d incoming damage[/b] after disruption and redirection.\nRaw attack: %d · Disrupted: %d · Redirected: %d\n[color=#7be0ca]Ward absorbs remaining damage in enemy action order.[/color]" % [amount, int(forecast.raw), int(forecast.disrupted), int(forecast.redirected)]
		"strain":
			title = "Organ overload"
			detail = "Adds [b]up to 2 strain[/b] to each of the [b]%d most strained organs[/b], capped by capacity. Ties use organ order. Cooling follows the enemy phase." % mini(amount, 6)
		"sever":
			title = "Sever connections"
			detail = "Cuts [b]up to %d open connection(s)[/b]: your last route first, then circuit order. Bait cuts with a spare route. Link commands restore connections." % amount
		"rebuild":
			title = "Rebuild allies"
			color = TEAL
			detail = "Repairs [b]%d hull on every living enemy[/b], up to each enemy's maximum hull. Defeated enemies are not revived." % amount
		"mark":
			title = "Remember your route"
			color = GOLD
			detail = "Marks your circuit: repeating the [b]immediately previous route[/b] costs [b]%d hull[/b]. Change the route to avoid the penalty." % amount
		"incubate":
			color = GOLD
			title = "Incubate cocoon"
			amount = maxi(1, int(enemy.get("egg_timer", 2))) if enemy.id == "_egg" else 1
			detail = "Hatches into a [b]Newborn Flare[/b] in [b]%d enemy phase(s)[/b]. Destroy the cocoon before it hatches." % amount if enemy.id == "_egg" else "Creates [b]1 Ember Cocoon[/b] if fewer than five enemies remain. It hatches after [b]two enemy phases[/b]."
	var badge := preload("res://scripts/intent_badge.gd").new()
	if int(enemy.intent.get("interrupt",0))>0 and int(enemy.disrupt)>=int(enemy.intent.interrupt):
		amount = 0
		detail = "[color=#7be0ca][b]INTERRUPTED[/b]: enough disruption has been applied. This action will be skipped.[/color]\n" + detail
	badge.name = "EnemyIntent%d" % index
	badge.tooltip_text = game.enemy_tactics_text(index)
	badge.explanation = "[b][color=#e7c381]%s[/color][/b]\n%s\n\n%s\n\n[color=#b5c9d4]Acts when you end your turn.[/color]" % [title, detail, game.enemy_tactics_text(index).replace("[", "(").replace("]", ")")]
	badge.set_meta("focus_key", "intent%d" % index)
	badge.add_theme_stylebox_override("normal", _style(Color("152432"), color.darkened(0.35), 8, 0, 1))
	badge.add_theme_stylebox_override("hover", _style(Color("243747"), color, 8, 0, 2))
	badge.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 8, 0, 2))
	badge.pressed.connect(func(): _select_target(index))
	_at(badge, rect, parent)
	var icon := SpaceCanvas.new()
	icon.stars = false
	icon.icon_kind = kind
	_at(icon, Rect2(maxf(4, (rect.size.x - 58) / 2), (rect.size.y - 24) / 2, 24, 24), badge)
	var value := _screen_text(str(amount), Rect2(maxf(32, (rect.size.x - 58) / 2 + 32), (rect.size.y - 28) / 2, 40, 28), 22, color, badge)
	value.add_theme_font_override("font", title_font)

func _hull_bar(value: int, maximum: int, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, maximum)
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("07121d"), Color("526574"), 4, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 4, 0))
	return bar

func _compact_intent(enemy: Dictionary, enemy_index: int) -> String:
	if enemy.id == "_egg": return "Hatch\n%d phases" % maxi(1, int(enemy.get("egg_timer", 2)))
	var intent: Dictionary = enemy.get("intent", {})
	var amount := int(intent.get("amount", 0))
	match str(intent.get("kind", "")):
		"attack": return "Attack\n%d damage" % int(game.enemy_attack_preview(enemy_index).damage)
		"strain": return "Strain\n%d organs" % amount
		"sever": return "Sever\n1 link"
		"incubate": return "Create\n1 egg"
		"rebuild": return "Repair\n%d hull" % amount
		"mark": return "Mark\n%d hull" % amount
	return str(intent.get("label", "Unknown"))

func _card_art(instance: Dictionary, height: float) -> TextureRect:
	var definition: Dictionary = game.effective_card(instance)
	var slot := 0
	for i in range(game.catalog.cards.size()):
		if game.catalog.cards[i].id == instance.id:
			slot = i
			break
	var image := TextureRect.new()
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size.y = height
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expansion_cards.has(str(instance.id)):
		image.texture = expansion_cards[str(instance.id)]
		return image
	if hd_card_regions.has(str(slot)):
		image.texture = hd_card_regions[str(slot)]
		return image
	if card_atlas == null:
		image.free()
		return _art(int(definition.get("art", 19)), height)
	var texture := AtlasTexture.new()
	texture.filter_clip = true
	texture.atlas = card_atlas
	var column_width := card_atlas.get_width() / 6.0
	var row_bounds := [0, 202, 397, 595, 793, 991, 1254]
	slot = clampi(slot, 0, 35)
	var row := floori(slot / 6.0)
	texture.region = Rect2((slot % 6) * column_width + 1, row_bounds[row] + 1, column_width - 2, row_bounds[row + 1] - row_bounds[row] - 2)
	image.texture = texture
	return image

func _printed_stats(instance: Dictionary, include_cost: bool) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 2)
	var definition: Dictionary = game.effective_card(instance)
	if include_cost:
		_stat_token(row, "cost", "%d CP" % int(definition.get("cost", 1)), "Command points spent to play this card. Each turn refills to 3.")
	for kind in ["damage", "heal", "disrupt"]:
		var value := int(definition.get(kind, 0))
		if value <= 0: continue
		_stat_token(row, kind, str(value), {"damage":"Damage before organs and powerups.", "heal":"Hull repaired before organs and powerups.", "disrupt":"Reduce the chosen enemy's next attack."}[kind])
	for field in ["vent", "draw", "trace", "resonance"]:
		if int(definition.get(field, 0)) > 0:
			var label := _label("%s %s%d" % [field.capitalize(), "+" if field in ["trace", "resonance"] else "", int(definition[field])], 15, CREAM)
			row.add_child(label)
	for field in ["link", "rewrite", "concert"]:
		if definition.get(field, false): row.add_child(_label(field.capitalize(), 15, GOLD))
	_stat_token(row, "strain", "0 / +1" if definition.first_free else "+1", "Each routed organ gains 1 strain; vent cools first. Evolved pure utility commands spare the first organ.")
	return row

func _stat_token(parent: Node, kind: String, value: String, tip: String) -> void:
	var token := HBoxContainer.new()
	token.tooltip_text = tip
	token.mouse_filter = Control.MOUSE_FILTER_STOP
	token.add_theme_constant_override("separation", 3)
	parent.add_child(token)
	var icon := SpaceCanvas.new()
	icon.stars = false
	icon.icon_kind = kind
	icon.custom_minimum_size = Vector2(21, 22)
	icon.tooltip_text = tip
	token.add_child(icon)
	var label := _label(value, 17, CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.add_child(label)

func _load_art_regions(path: String, collection_key: String) -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(path): return result
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return result
	var entries = parsed.get(collection_key, {})
	if not entries is Dictionary: return result
	var sheets := {}
	for key in entries:
		var entry = entries[key]
		if not entry is Dictionary: continue
		var image_path := str(entry.get("path", ""))
		var coordinates = entry.get("rect", [])
		if not coordinates is Array: continue
		if not sheets.has(image_path):
			if not ResourceLoader.exists(image_path): continue
			sheets[image_path] = load(image_path)
		var sheet: Texture2D = sheets[image_path]
		if sheet == null: continue
		if coordinates.is_empty(): coordinates = [0, 0, sheet.get_width(), sheet.get_height()]
		if coordinates.size() != 4: continue
		var region := Rect2(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]), float(coordinates[3]))
		if region.size.x < 1 or region.size.y < 1 or not Rect2(Vector2.ZERO, sheet.get_size()).encloses(region): continue
		var texture := AtlasTexture.new()
		texture.filter_clip = true
		texture.atlas = sheet
		texture.region = region
		result[str(key)] = texture
	return result

func _card_title(text: String, font_size: int) -> Label:
	var label := _text(text, font_size, CREAM)
	label.add_theme_font_override("font", title_font)
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.set_meta("card_title", true)
	return label

func _area_index() -> int:
	if game.run.is_empty(): return 0
	var id := str(game.region().get("id", ""))
	for i in range(game.catalog.regions.size()):
		if str(game.catalog.regions[i].id) == id: return i
	return 0

func _character_image(id: String, height: float) -> TextureRect:
	var image := _art(0, height)
	if expansion_characters.has(id): image.texture = expansion_characters[id]
	elif id == "cartographer" and player_hd != null: image.texture = player_hd
	return image

func _character_resource_text(battle: Dictionary) -> String:
	var id := str(game.run.get("character", "cartographer"))
	var forecast: Dictionary = game.preview_card(selected_card, route, target) if selected_card >= 0 else {}
	var previewing := forecast.has("resource_preview")
	if id == "palimpsest":
		var payload: Dictionary = battle.get("last_payload", {})
		var value := "%d → %d" % [int(battle.get("trace", 0)), int(forecast.trace)] if previewing else str(int(battle.get("trace", 0)))
		if previewing: return "TRACE %s / 6 · PREVIEW" % value
		return "TRACE %s / 6%s\n%s" % [value, " · PREVIEW" if previewing else "", "Previous command in memory" if not payload.is_empty() else "Play a command to store memory"]
	if id == "hollow_choir":
		var value := "%d → %d" % [int(battle.get("resonance", 0)), int(forecast.resonance)] if previewing else str(int(battle.get("resonance", 0)))
		if previewing: return "RESONANCE %s / 3 · PREVIEW" % value
		return "RESONANCE %s / 3%s\nLast command: %s" % [value, " · PREVIEW" if previewing else "", (str(battle.get("last_command_kind", "")).capitalize() if not str(battle.get("last_command_kind", "")).is_empty() else "None")]
	return ""

func _resource_flow_text(result: Dictionary) -> String:
	if not result.has("resource_preview"): return ""
	var resource := "trace" if game.run.character == "palimpsest" else "resonance" if game.run.character == "hollow_choir" else ""
	if resource.is_empty(): return ""
	var values: Dictionary = result.resource_preview
	var text := "\n%s preview: card %d → %d" % [resource.capitalize(), int(values[resource + "_before"]), int(values["card_" + resource])]
	for step in result.get("route_steps", []):
		text += "\n%s: %d → %d · %s (%s)" % [game.organ(int(step.organ)).name, int(step[resource + "_before"]), int(step[resource + "_after"]), step.status, step.reason]
	return text

func _enemy_image(id: String, height: float) -> TextureRect:
	var image := _art(int(game.enemy(id).get("art", 19)), height)
	if expansion_enemies.has(id): image.texture = expansion_enemies[id]
	return image
