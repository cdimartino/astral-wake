extends Control
## Local-only console and sound tuning surface. This node is created only while
## the administrator opens the desk; it never owns game or audio state.

signal close_requested

var admin: Object
var hull: Object
var _query := ""
var _group := ""
var _cue := ""
var _history: Array[String] = []
var _history_index := 0
var _output: RichTextLabel
var _entry: LineEdit
var _catalog: ItemList
var _group_select: OptionButton
var _status: Label
var _mix_db := 0.0
var _mix_pitch := 1.0
var _mix_pan := 0.0
var _mix_variation := 1.0
var _solo := false
var _muted := false
var _ab := false
var _ab_stored := false
var _playing_badge: Label
var _cue_afterglow: Dictionary = {}
var _processed_trace: Dictionary = {}
var _catalog_cues: Array[String] = []
var _row_visual_state: Dictionary = {}
var _last_playing_signature := ""
const AFTERGLOW_MS := 250

const INK := Color("#dce7e6")
const MUTED := Color("#829697")
const PANEL := Color("#101c20")
const LINE := Color("#263b40")
const AQUA := Color("#8ee3d1")
const AMBER := Color("#efbd78")

func setup(admin_api: Object, hull_api: Object) -> void:
	admin = admin_api
	hull = hull_api
	_build()
	_refresh_catalog()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.045, 0.90)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var shell := PanelContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 36
	shell.offset_top = 28
	shell.offset_right = -36
	shell.offset_bottom = -28
	add_child(shell)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0b1418")
	sb.border_color = Color("#42615f")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	shell.add_theme_stylebox_override("panel", sb)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	shell.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "HULL / SOUND DESK"
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var eyebrow := Label.new()
	eyebrow.text = "   LOCAL ADMIN  ·  LIVE MIX"
	eyebrow.add_theme_color_override("font_color", AQUA)
	header.add_child(eyebrow)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "CLOSE  [Esc]"
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	var rule := HSeparator.new()
	root.add_child(rule)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var group_label := Label.new()
	group_label.text = "CUE LIBRARY"
	group_label.add_theme_color_override("font_color", MUTED)
	left.add_child(group_label)
	_group_select = OptionButton.new()
	_group_select.item_selected.connect(func(_i): _group = _group_select.get_item_text(_group_select.selected); _refresh_catalog())
	left.add_child(_group_select)
	var search := LineEdit.new()
	search.placeholder_text = "Filter cues…"
	search.text_changed.connect(func(s): _query = s.to_lower(); _refresh_catalog())
	left.add_child(search)
	_catalog = ItemList.new()
	_catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog.item_selected.connect(_select_cue)
	left.add_child(_catalog)
	_playing_badge = Label.new()
	_playing_badge.name = "PlayingIndicator"
	_playing_badge.text = "Playing · none"
	_playing_badge.add_theme_color_override("font_color", AQUA)
	_playing_badge.accessibility_name = "Playing indicator"
	left.add_child(_playing_badge)
	var audition := Button.new()
	audition.text = "▶   AUDITION SELECTED"
	audition.pressed.connect(_audition)
	left.add_child(audition)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var card := PanelContainer.new()
	right.add_child(card)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PANEL
	card_style.border_color = LINE
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(5)
	card.add_theme_stylebox_override("panel", card_style)
	var mix := VBoxContainer.new()
	mix.add_theme_constant_override("separation", 8)
	card.add_child(mix)
	var cue_title := Label.new()
	cue_title.name = "CueTitle"
	cue_title.text = "SELECT A CUE"
	cue_title.add_theme_color_override("font_color", AQUA)
	mix.add_child(cue_title)
	var controls := VBoxContainer.new()
	mix.add_child(controls)
	var patch_row := HBoxContainer.new()
	controls.add_child(patch_row)
	var patch_select := OptionButton.new()
	patch_select.name = "PatchSelect"
	patch_row.add_child(patch_select)
	var bind := Button.new()
	bind.text = "BIND PATCH"
	bind.pressed.connect(func():
		if _cue != "" and patch_select.selected > 0:
			_send("audio bind %s %s" % [_cue, patch_select.get_item_text(patch_select.selected)])
	)
	patch_row.add_child(bind)
	var variants := Button.new()
	variants.text = "VARIANTS"
	variants.pressed.connect(func():
		if _cue != "":
			_send("audio variants " + _cue)
	)
	patch_row.add_child(variants)
	var switch_group := Button.new()
	switch_group.text = "ALT GROUP"
	switch_group.pressed.connect(func():
		if _group != "" and _group != "All groups":
			_send("audio group %s alternate" % JSON.stringify(_group))
	)
	patch_row.add_child(switch_group)
	var mix_controls := HBoxContainer.new()
	controls.add_child(mix_controls)
	var solo := Button.new()
	solo.name = "SoloButton"
	solo.text = "SOLO"
	solo.toggle_mode = true
	solo.toggled.connect(func(on): _solo = on; _send("audio solo " + (_cue if on else "off")))
	mix_controls.add_child(solo)
	var mute := Button.new()
	mute.name = "MuteButton"
	mute.text = "MUTE"
	mute.toggle_mode = true
	mute.toggled.connect(func(on): _muted = on; _send("audio mute " + _cue))
	mix_controls.add_child(mute)
	var ab := Button.new()
	ab.name = "ABButton"
	ab.text = "A / B"
	ab.pressed.connect(func():
		if not _ab_stored:
			_send("audio ab store")
			_ab_stored = true
			ab.text = "STORE A"
		else:
			_send("audio ab swap")
			_ab = not _ab
			ab.text = "SHOW B" if not _ab else "SHOW A"
	)
	mix_controls.add_child(ab)
	var gain_label := Label.new()
	gain_label.text = "GAIN"
	gain_label.add_theme_color_override("font_color", MUTED)
	mix_controls.add_child(gain_label)
	var gain := HSlider.new()
	gain.name = "GainSlider"
	gain.min_value = -18
	gain.max_value = 6
	gain.value = 0
	gain.custom_minimum_size.x = 150
	gain.value_changed.connect(func(value): _mix_db = value; _send("audio mix %s gain_db %.1f" % [_cue, value]))
	mix_controls.add_child(gain)
	var parameter_row := HBoxContainer.new()
	mix.add_child(parameter_row)
	_add_mix_slider(parameter_row, "PITCH", "pitch", 0.5, 2.0, 1.0)
	_add_mix_slider(parameter_row, "PAN", "pan", -1.0, 1.0, 0.0)
	_add_mix_slider(parameter_row, "VARIATION", "variation", 0.0, 1.0, 1.0)
	var preset_row := HBoxContainer.new()
	mix.add_child(preset_row)
	var preset_name := LineEdit.new()
	preset_name.placeholder_text = "preset name"
	preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(preset_name)
	var save := Button.new()
	save.text = "SAVE PRESET"
	save.pressed.connect(func(): _send("audio preset save " + preset_name.text))
	preset_row.add_child(save)
	var load_btn := Button.new()
	load_btn.text = "LOAD"
	load_btn.pressed.connect(func(): _send("audio preset load " + preset_name.text))
	preset_row.add_child(load_btn)
	var reload := Button.new()
	reload.text = "RELOAD BANK"
	reload.pressed.connect(func(): _send("audio reload"))
	preset_row.add_child(reload)
	var stinger := CheckButton.new()
	stinger.name = "StingerToggle"
	stinger.text = "STINGERS"
	stinger.button_pressed = bool(_preset_state().get("stingers_enabled", true))
	stinger.toggled.connect(func(on): _send("audio stinger " + ("on" if on else "off")))
	mix_controls.add_child(stinger)
	_status = Label.new()
	_status.text = "Ready · changes apply to the live mix"
	_status.add_theme_color_override("font_color", MUTED)
	mix.add_child(_status)
	var track_row := HBoxContainer.new()
	mix.add_child(track_row)
	var track_label := Label.new()
	track_label.text = "SCORE TRACK"
	track_label.add_theme_color_override("font_color", MUTED)
	track_row.add_child(track_label)
	var track_select := OptionButton.new()
	track_select.name = "TrackSelect"
	track_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_row.add_child(track_select)
	var track_mute := CheckButton.new()
	track_mute.name = "TrackMute"
	track_mute.text = "MUTE TRACK"
	track_row.add_child(track_mute)
	var track_solo := CheckButton.new()
	track_solo.name = "TrackSolo"
	track_solo.text = "SOLO TRACK"
	track_row.add_child(track_solo)
	var track_names: Array[String] = []
	if hull != null:
		var bank_data = hull.get("bank")
		if bank_data is Dictionary:
			for score in bank_data.get("scores", {}).values():
				for event in score.get("events", []):
					var track := str(event.get("track", ""))
					if not track.is_empty() and not track_names.has(track):
						track_names.append(track)
			track_names.sort()
	for track in track_names:
		track_select.add_item(track)
	if track_select.item_count > 0:
		track_select.select(0)
	track_mute.toggled.connect(func(on):
		if track_select.item_count > 0:
			var track := track_select.get_item_text(track_select.selected)
			_send("audio mute " + JSON.stringify(track))
	)
	track_solo.toggled.connect(func(on):
		if track_select.item_count > 0:
			var track := track_select.get_item_text(track_select.selected)
			_send("audio solo " + (JSON.stringify(track) if on else "off"))
	)
	track_select.item_selected.connect(func(_index):
		var state := _preset_state()
		var muted_tracks: Dictionary = state.get("muted", {})
		track_mute.set_pressed_no_signal(bool(muted_tracks.get(track_select.get_item_text(track_select.selected), false)))
		var solo_track := str(state.get("solo", ""))
		track_solo.set_pressed_no_signal(solo_track == track_select.get_item_text(track_select.selected))
	)
	if track_select.item_count > 0:
		var state := _preset_state()
		var muted_tracks: Dictionary = state.get("muted", {})
		track_mute.set_pressed_no_signal(bool(muted_tracks.get(track_select.get_item_text(0), false)))
		track_solo.set_pressed_no_signal(str(state.get("solo", "")) == track_select.get_item_text(0))
	var trace_head := Label.new()
	trace_head.text = "RECENT TRACE  /  COMMAND OUTPUT"
	trace_head.add_theme_color_override("font_color", AMBER)
	right.add_child(trace_head)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.custom_minimum_size.y = 110
	_output.add_theme_stylebox_override("normal", _plain_box(PANEL))
	right.add_child(_output)
	var cmdrow := HBoxContainer.new()
	root.add_child(cmdrow)
	var prompt := Label.new()
	prompt.text = "›"
	prompt.add_theme_color_override("font_color", AQUA)
	cmdrow.add_child(prompt)
	_entry = LineEdit.new()
	_entry.placeholder_text = "Type a command — Tab completes, ↑ recalls history"
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.text_submitted.connect(_run_command)
	_entry.gui_input.connect(_entry_input)
	cmdrow.add_child(_entry)
	var run := Button.new()
	run.text = "RUN"
	run.pressed.connect(func(): _run_command(_entry.text))
	cmdrow.add_child(run)
	var copy := Button.new()
	copy.text = "COPY"
	copy.pressed.connect(func(): DisplayServer.clipboard_set(_output.get_parsed_text()); _status.text = "Output copied")
	cmdrow.add_child(copy)
	_entry.grab_focus()

func _plain_box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	return style

func _refresh_catalog() -> void:
	if _catalog == null:
		return
	_catalog.clear()
	_catalog_cues.clear()
	_row_visual_state.clear()
	if hull == null:
		return
	var groups: PackedStringArray = hull.options("groups")
	var previous_group := _group
	_group_select.clear()
	_group_select.add_item("All groups")
	for group in groups:
		_group_select.add_item(group)
	var group_index := 0
	for i in _group_select.item_count:
		if _group_select.get_item_text(i) == previous_group:
			group_index = i
			break
	_group_select.select(group_index)
	_group = _group_select.get_item_text(group_index)
	var cues: PackedStringArray = hull.options("cues")
	for cue in cues:
		if _query != "" and not cue.to_lower().contains(_query):
			continue
		if _group != "" and _group != "All groups":
			var bank_data = hull.get("bank")
			if bank_data is Dictionary and str(bank_data.get("cues", {}).get(cue, {}).get("group", "")) != _group:
				continue
		_catalog.add_item(cue)
		_catalog_cues.append(cue)
	_update_playing()

func _process(_delta: float) -> void:
	_update_playing()

func _update_playing() -> void:
	if _catalog == null or not is_instance_valid(_catalog):
		return
	if hull == null:
		return
	var now := Time.get_ticks_msec()
	var active := PackedStringArray()
	if hull.has_method("active_cues"):
		active = hull.call("active_cues")
	var trace_data = hull.get("trace")
	if trace_data is Array:
		for record in trace_data:
			if record is Dictionary:
				var at := int(record.get("at_ms", 0))
				var cue := str(record.get("cue", ""))
				var event_id := "%d|%s|%s" % [at, cue, str(record.get("patch", ""))]
				if not _processed_trace.has(event_id) and cue != "" and at + AFTERGLOW_MS >= now:
					_cue_afterglow[cue] = maxi(int(_cue_afterglow.get(cue, 0)), at + AFTERGLOW_MS)
				_processed_trace[event_id] = at + AFTERGLOW_MS
	for event_id in _processed_trace.keys():
		if int(_processed_trace[event_id]) < now:
			_processed_trace.erase(event_id)
	var visible_active := PackedStringArray()
	for cue in active:
		if not visible_active.has(cue):
			visible_active.append(cue)
	for cue in _cue_afterglow.keys():
		if int(_cue_afterglow[cue]) < now:
			_cue_afterglow.erase(cue)
		elif not visible_active.has(str(cue)):
			visible_active.append(str(cue))
	var signature := ",".join(visible_active)
	if _playing_badge != null and signature != _last_playing_signature:
		_playing_badge.text = "Playing · " + (", ".join(visible_active) if not visible_active.is_empty() else "none")
		_playing_badge.add_theme_color_override("font_color", AQUA if not visible_active.is_empty() else MUTED)
	_last_playing_signature = signature
	for i in _catalog.item_count:
		var cue := _catalog_cues[i]
		var is_playing := active.has(cue)
		var afterglow := _cue_afterglow.has(cue)
		var visual := ("active" if is_playing else "afterglow" if afterglow else "idle")
		if _row_visual_state.get(i, "") != visual:
			_row_visual_state[i] = visual
			_catalog.set_item_text(i, ("▶ " if is_playing else "· " if afterglow else "") + cue + ("  Playing" if is_playing else ""))
			_catalog.set_item_custom_bg_color(i, Color("#24564e") if is_playing else Color("#24342f") if afterglow else Color(0, 0, 0, 0))
			_catalog.set_item_custom_fg_color(i, AQUA if is_playing else INK)

func _select_cue(index: int) -> void:
	_cue = _catalog_cues[index]
	var snapshot := _preset_state()
	var overrides: Dictionary = snapshot.get("overrides", {})
	var cue_mix: Dictionary = overrides.get(_cue, {})
	var solo_button := find_child("SoloButton", true, false) as Button
	var mute_button := find_child("MuteButton", true, false) as Button
	_solo = str(snapshot.get("solo", "")) == _cue
	_muted = bool(snapshot.get("muted", {}).get(_cue, false))
	if solo_button: solo_button.set_pressed_no_signal(_solo)
	if mute_button: mute_button.set_pressed_no_signal(_muted)
	var patch_select := find_child("PatchSelect", true, false) as OptionButton
	if patch_select:
		patch_select.clear()
		patch_select.add_item("Default patch")
		var bound_patch := str(cue_mix.get("patch", ""))
		if hull != null:
			var bank_data = hull.get("bank")
			if bank_data is Dictionary:
				var cue_data: Dictionary = bank_data.get("cues", {}).get(_cue, {})
				for patch in cue_data.get("variants", []):
					patch_select.add_item(str(patch))
					if str(patch) == bound_patch:
						patch_select.select(patch_select.item_count - 1)
				var gain_slider := find_child("GainSlider", true, false) as HSlider
				if gain_slider:
					gain_slider.set_value_no_signal(float(cue_mix.get("gain_db", cue_data.get("gain_db", -6))))
				for name in ["PitchSlider", "PanSlider", "VariationSlider"]:
					var parameter_slider := find_child(name, true, false) as HSlider
					if parameter_slider:
						var key := str(name).trim_suffix("Slider").to_lower()
						parameter_slider.set_value_no_signal(float(cue_mix.get(key, 1.0 if key in ["pitch", "variation"] else 0.0)))
	var stinger_toggle := find_child("StingerToggle", true, false) as CheckButton
	if stinger_toggle:
		stinger_toggle.set_pressed_no_signal(bool(snapshot.get("stingers_enabled", true)))
	var label := find_child("CueTitle", true, false) as Label
	if label:
		label.text = _cue.to_upper()
	_status.text = "Selected · choose audition, solo, mute, or adjust gain"

func _audition() -> void:
	if _cue != "":
		_send("audio audition " + _cue)
		_send("audio trace")
		_send("audio voices")

func _send(line: String) -> void:
	if admin == null or line.strip_edges() == "":
		return
	if line.begins_with("audio preset load") or line == "audio reload":
		_cue_afterglow.clear()
	var result := str(admin.execute(line))
	_append("$ " + line + "\n" + result)

func _run_command(line: String) -> void:
	var clean := line.strip_edges()
	if clean == "":
		return
	_history.append(clean)
	_history_index = _history.size()
	_entry.clear()
	_send(clean)

func _append(text: String) -> void:
	if _output == null:
		return
	_output.add_text(text + "\n")
	_status.text = "Applied · " + Time.get_time_string_from_system()

func _entry_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_TAB:
		var suggestions: PackedStringArray = admin.complete(_entry.text) if admin != null else PackedStringArray()
		if not suggestions.is_empty():
			_entry.text = suggestions[0]
			_entry.caret_column = _entry.text.length()
		_entry.accept_event()
	elif event.keycode == KEY_UP and not _history.is_empty():
		_history_index = maxi(0, _history_index - 1)
		_entry.text = _history[_history_index]
		_entry.caret_column = _entry.text.length()
		_entry.accept_event()
	elif event.keycode == KEY_DOWN and _history_index < _history.size() - 1:
		_history_index += 1
		_entry.text = _history[_history_index]
		_entry.caret_column = _entry.text.length()
		_entry.accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_requested.emit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_send("audio trace")

func _add_mix_slider(parent: HBoxContainer, label: String, parameter: String, low: float, high: float, initial: float) -> void:
	var title := Label.new()
	title.text = label
	title.add_theme_color_override("font_color", MUTED)
	parent.add_child(title)
	var slider := HSlider.new()
	slider.name = {"pitch": "PitchSlider", "pan": "PanSlider", "variation": "VariationSlider"}[parameter]
	slider.min_value = low
	slider.max_value = high
	slider.value = initial
	slider.custom_minimum_size.x = 100
	slider.value_changed.connect(func(value): _send("audio mix %s %s %.2f" % [_cue, parameter, value]))
	parent.add_child(slider)

func _preset_state() -> Dictionary:
	if hull != null and hull.has_method("preset_snapshot"):
		var snapshot = hull.call("preset_snapshot")
		if snapshot is Dictionary:
			return snapshot
	return {"overrides": {}, "muted": {}, "solo": "", "stingers_enabled": true}
