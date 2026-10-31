extends Button

var explanation := ""
var focus_tip: Control

func _ready() -> void:
	focus_entered.connect(_show_focus_tip)
	focus_exited.connect(_hide_focus_tip)

func _make_custom_tooltip(_text: String) -> Object:
	return _rich_tip()

func _rich_tip() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1828")
	style.border_color = Color("7be0ca")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 440
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_color_override("default_color", Color("edf2ee"))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = explanation
	panel.add_child(text)
	return panel

func _show_focus_tip() -> void:
	_hide_focus_tip()
	focus_tip = _rich_tip()
	add_child(focus_tip)
	focus_tip.position = Vector2(size.x - 342, size.y + 8 if global_position.y < 240 else -220)
	focus_tip.z_index = 100
	_place_focus_tip.call_deferred()

func _place_focus_tip() -> void:
	if not is_instance_valid(focus_tip): return
	var bounds=get_viewport_rect().size
	focus_tip.global_position=Vector2(clampf(global_position.x+size.x-focus_tip.size.x,8,maxf(8,bounds.x-focus_tip.size.x-8)),clampf(global_position.y+size.y+8,8,maxf(8,bounds.y-focus_tip.size.y-8)))

func _hide_focus_tip() -> void:
	if is_instance_valid(focus_tip): focus_tip.queue_free()
