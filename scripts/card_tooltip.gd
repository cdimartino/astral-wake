extends Button

var explanation := ""
var focus_tip: Control

func _ready() -> void:
	focus_entered.connect(_show_focus_tip)
	focus_exited.connect(_hide_focus_tip)
	tree_exiting.connect(_hide_focus_tip)

func _make_custom_tooltip(_text: String) -> Object:
	_hide_focus_tip()
	return _rich_tip()

func _rich_tip() -> Control:
	var panel := PanelContainer.new()
	panel.set_meta("card_keyword_tip", true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1828")
	style.border_color = Color("7be0ca")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 416
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_color_override("default_color", Color("edf2ee"))
	text.text = explanation
	scroll.add_child(text)
	var height := get_theme_font("font").get_multiline_string_size(text.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, 408, 17).y + 12
	scroll.custom_minimum_size = Vector2(440, minf(height, minf(540, get_viewport_rect().size.y - 64)))
	return panel

func _show_focus_tip() -> void:
	_hide_focus_tip()
	focus_tip = _rich_tip()
	# The hand clips its own card face. A viewport sibling keeps definitions
	# outside that clip and above raised cards without hiding the hand.
	get_tree().root.add_child(focus_tip)
	focus_tip.z_index = 200
	_place_focus_tip.call_deferred()

func _place_focus_tip() -> void:
	if not is_instance_valid(focus_tip): return
	var bounds := get_viewport_rect().size
	var rect := get_global_rect()
	var x := rect.end.x + 12
	if x + focus_tip.size.x > bounds.x - 8: x = rect.position.x - focus_tip.size.x - 12
	var y := rect.end.y - focus_tip.size.y
	focus_tip.position = Vector2(clampf(x, 8, maxf(8, bounds.x - focus_tip.size.x - 8)), clampf(y, 8, maxf(8, bounds.y - focus_tip.size.y - 8)))

func _hide_focus_tip() -> void:
	if is_instance_valid(focus_tip):
		focus_tip.get_parent().remove_child(focus_tip)
		focus_tip.queue_free()
	focus_tip = null
