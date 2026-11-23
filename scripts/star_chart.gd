extends Control
class_name StarChart
## Standalone, public-information-only voyage chart.
##
## Travel is deliberately two-phase: activate Travel to emit travel_requested,
## then call apply_committed_travel only after the game controller confirms the
## jump. This view never changes game state and never guesses whether a request
## succeeded.

signal focus_node(node_id: String)
signal travel_requested(node_id: String)
signal travel_committed(from_node_id: String, to_node_id: String)
signal travel_presentation_finished(node_id: String)

const ChartStopView = preload("res://scripts/chart_stop_view.gd")
const DisplayFont = preload("res://art/fonts/AstralWake-Display.ttf")
const PlayerShipTexture = preload("res://art/ships_hd/player.png")

const INK := Color("#d5edf3")
const MUTED := Color("#829eae")
const CYAN := Color("#78e6d0")

var _nodes: Array[Dictionary] = []
var _positions: Dictionary = {}
var _buttons: Dictionary = {}
var _current_id := ""
var _region_label := "Uncharted"
var _focused_id := ""
var _traveling := false
var _travel_epoch := 0
var _arrival_id := ""
var _travel_tween: Tween
var _travel_request_pending := false
var reduced_motion := false
var _star_phase := 0.0
var _ambient_time := 0.0
var _heading := 0.0
var _panel: PanelContainer
var _panel_title: Label
var _panel_copy: Label
var _travel_button: Button
var _close_button: Button
var _recenter_button: Button
var _skip_button: Button
var _beacon_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_signal_panel()
	resized.connect(_rebuild)
	resized.connect(_layout_chrome)
	set_process(true)

func _process(delta: float) -> void:
	if not reduced_motion:
		_ambient_time += delta
		if not _traveling:
			queue_redraw()

## Accepts ChartStopView.project(run)'s layered public projection.
func configure(public_graph: Variant, current_node_id: String, region_label: String) -> void:
	_nodes.clear()
	var layers: Variant = public_graph.get("layers", []) if public_graph is Dictionary else []
	if layers is Array:
		for layer_index in range(layers.size()):
			if not layers[layer_index] is Array: continue
			for item in layers[layer_index]:
				if not item is Dictionary or not item.has("id"): continue
				_nodes.append({
					"id": str(item.get("id", "")),
					"layer": int(item.get("layer", layer_index)),
					"column": int(item.get("column", 0)),
					"type": str(item.get("type", "unknown")),
					"edges": _string_array(item.get("edges", [])),
					"reachable": bool(item.get("reachable", false)),
					"visited": bool(item.get("visited", false)),
					"label": str(item.get("label", "")),
					"description": str(item.get("description", "")),
				})
	_current_id = current_node_id
	_region_label = region_label
	_focused_id = current_node_id
	_traveling = false
	_travel_request_pending = false
	_travel_epoch += 1
	_arrival_id = ""
	_star_phase = 0.0
	if is_instance_valid(_travel_tween) and _travel_tween.is_running():
		_travel_tween.kill()
	_travel_tween = null
	_rebuild()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	set_process(not enabled)
	if enabled and _traveling:
		skip_travel()
	queue_redraw()

## Call only after the owning controller has successfully committed travel.
## Repeating the same arrival is harmless and cannot trigger another jump.
func apply_committed_travel(from_id: String, to_id: String) -> void:
	if to_id == _current_id or _traveling:
		return
	if from_id != _current_id:
		return
	var target: Dictionary = _node_by_id(to_id)
	if target.is_empty() or not bool(target.get("reachable", false)):
		return
	_travel_request_pending = false
	_traveling = true
	_skip_button.visible = not reduced_motion
	_arrival_id = to_id
	var course: Vector2 = _positions.get(to_id, _departure_position()) - _departure_position()
	if not course.is_zero_approx():
		_heading = course.angle() + PI * 0.5
	travel_committed.emit(from_id, to_id)
	_travel_epoch += 1
	var epoch := _travel_epoch
	_travel_button.disabled = true
	if reduced_motion:
		_finish_travel(epoch, to_id)
	else:
		_travel_tween = create_tween()
		_travel_tween.tween_method(func(value: float) -> void:
			_star_phase = value
			queue_redraw()
		, 0.0, 1.0, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_travel_tween.tween_callback(_finish_travel.bind(epoch, to_id))

func skip_travel() -> void:
	if _traveling:
		_travel_epoch += 1
		if is_instance_valid(_travel_tween):
			_travel_tween.kill()
		_finish_travel(_travel_epoch, _arrival_id)

func recenter() -> void:
	_focused_id = _current_id
	_panel.visible = true
	_update_panel()
	focus_node.emit(_current_id)
	queue_redraw()

func is_inspection_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible

## Main owns Escape priority and can call this when the chart is idle.
func close_inspection() -> void:
	_panel.visible = false
	_focused_id = ""
	queue_redraw()

func _finish_travel(epoch: int, to_id: String) -> void:
	if not _traveling or epoch != _travel_epoch or not is_inside_tree():
		return
	_traveling = false
	_skip_button.visible = false
	_star_phase = 0.0
	_current_id = to_id
	_focused_id = to_id
	_arrival_id = ""
	_rebuild()
	travel_presentation_finished.emit(to_id)

func _build_signal_panel() -> void:
	_beacon_layer = Control.new()
	_beacon_layer.name = "BeaconLayer"
	_beacon_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_beacon_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_beacon_layer)
	_panel = PanelContainer.new()
	_panel.name = "SignalReadout"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.custom_minimum_size = Vector2(292, 118)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	box.add_child(heading)
	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 18)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_panel_title)
	_close_button = Button.new()
	_close_button.text = "× Close"
	_close_button.custom_minimum_size = Vector2(72, 34)
	_close_button.set_meta("mcp_control", "close_inspection")
	_close_button.pressed.connect(close_inspection)
	heading.add_child(_close_button)
	_panel_copy = Label.new()
	_panel_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_copy.add_theme_color_override("font_color", MUTED)
	box.add_child(_panel_copy)
	_travel_button = Button.new()
	_travel_button.text = "Travel to signal"
	_travel_button.pressed.connect(_request_travel)
	_travel_button.set_meta("mcp_control", "choose_node")
	_travel_button.set_meta("node_id", "")
	_travel_button.set_meta("reachable", false)
	_travel_button.set_meta("visited", false)
	box.add_child(_travel_button)
	add_child(_panel)
	_recenter_button = Button.new()
	_recenter_button.text = "⌖  Recenter on ship"
	_recenter_button.position = Vector2(28, 84)
	_recenter_button.custom_minimum_size = Vector2(190, 42)
	_recenter_button.pressed.connect(recenter)
	add_child(_recenter_button)
	_skip_button = Button.new()
	_skip_button.text = "Skip travel"
	_skip_button.position = Vector2(28, 136)
	_skip_button.custom_minimum_size = Vector2(190, 42)
	_skip_button.pressed.connect(skip_travel)
	_skip_button.visible = false
	add_child(_skip_button)

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in _beacon_layer.get_children():
		_beacon_layer.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_positions.clear()
	var by_id := {}
	for node in _nodes:
		by_id[node.id] = node
	var ordered := _nodes.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.layer == b.layer: return a.column < b.column
		return a.layer < b.layer
	)
	var max_layer := 1
	for node in ordered: max_layer = maxi(max_layer, int(node.layer))
	var margin_x := 76.0 if size.x < 1200 else 92.0
	var chart_top := 142.0
	var chart_bottom := size.y - 190.0
	for node in ordered:
		var peers: Array = []
		for other in ordered:
			if other.layer == node.layer: peers.append(other)
		var peer_index := peers.find(node)
		var x := margin_x + (size.x - margin_x * 2.0) * float(node.layer) / float(max_layer)
		var centered_peer := float(peer_index) - float(peers.size() - 1) * 0.5
		var y := (chart_top + chart_bottom) * 0.5 + centered_peer * minf(82.0, (chart_bottom - chart_top) / maxf(1.0, float(peers.size())))
		var degree: int = int(node.edges.size())
		for other in _nodes:
			if str(node.id) in other.edges: degree += 1
		var public_phase := float((int(node.layer) * 31 + int(node.column) * 17 + degree * 13) % 7) - 3.0
		x += public_phase * 4.0
		y += sin(float(node.layer) * 0.72 + float(node.column) * 1.37 + float(degree) * 0.55) * 16.0
		_positions[node.id] = Vector2(clampf(x, 48, size.x - 48), clampf(y, chart_top, chart_bottom))
	for node in ordered:
		var beacon := Button.new()
		beacon.name = "Beacon_" + str(node.id).validate_node_name()
		beacon.custom_minimum_size = Vector2(52, 48)
		beacon.focus_mode = Control.FOCUS_ALL
		beacon.flat = true
		beacon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		beacon.text = _beacon_glyph(node)
		beacon.add_theme_font_size_override("font_size", 12)
		beacon.add_theme_color_override("font_color", _beacon_tint(node))
		beacon.add_theme_color_override("font_hover_color", Color("#fff0c7"))
		beacon.add_theme_color_override("font_focus_color", Color("#fff0c7"))
		beacon.tooltip_text = "%s — %s" % [_stop_label(node), _stop_description(node)]
		beacon.set_meta("mcp_control", "inspect_node")
		beacon.set_meta("node_id", node.id)
		beacon.set_meta("reachable", node.reachable)
		beacon.set_meta("visited", node.visited)
		beacon.accessibility_description = "%s, %s%s" % [
			_stop_label(node), _stop_description(node),
			", reachable" if node.reachable else (", visited" if node.visited else ", distant"),
		]
		beacon.position = _positions[node.id] - beacon.custom_minimum_size * 0.5
		beacon.pressed.connect(_on_beacon_pressed.bind(str(node.id)))
		beacon.focus_entered.connect(_on_beacon_focused.bind(str(node.id)))
		beacon.mouse_entered.connect(_on_beacon_focused.bind(str(node.id)))
		_beacon_layer.add_child(beacon)
		_buttons[node.id] = beacon
	_update_panel()
	_layout_chrome()
	queue_redraw()

func _layout_chrome() -> void:
	if not is_instance_valid(_panel):
		return
	var minimum := _panel.get_combined_minimum_size()
	_panel.size = minimum
	_panel.position = Vector2(28, maxf(76.0, size.y - minimum.y - 22.0))

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("#06111d"))
	# Broad translucent haze layers add depth without implying encounters.
	var haze_center := Vector2(size.x * 0.56, size.y * 0.48)
	draw_set_transform(haze_center, -0.14, Vector2(1.45, 0.48))
	for ring in range(12, 0, -1):
		draw_circle(Vector2.ZERO, 30.0 + ring * 24.0, Color("#246875", 0.004 + float(12 - ring) * 0.0018))
	draw_set_transform(haze_center + Vector2(-size.x * 0.25, size.y * 0.12), 0.18, Vector2(1.2, 0.4))
	for ring in range(10, 0, -1):
		draw_circle(Vector2.ZERO, 26.0 + ring * 23.0, Color("#65513f", 0.003 + float(10 - ring) * 0.0012))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(128):
		var depth := 0.12 + float(i % 5) * 0.06
		var x := fposmod(i * 137.51 + 47.0 - _star_phase * size.x * depth, maxf(size.x, 1.0))
		var y := fposmod(i * 93.71 + 19.0 + _star_phase * size.y * depth * 0.12, maxf(size.y, 1.0))
		var radius := 1.35 if i % 11 == 0 else (0.8 if i % 4 == 0 else 0.5)
		var shimmer := sin(_ambient_time * (0.7 + float(i % 5) * 0.18) + float(i) * 2.17) * 0.035
		var alpha := (0.34 if i % 11 == 0 else 0.18 if i % 3 == 0 else 0.1) + shimmer
		draw_circle(Vector2(x, y), radius, Color(0.69, 0.84, 0.89, clampf(alpha, 0.04, 0.4)))
	draw_string(ThemeDB.fallback_font, Vector2(30, 38), _region_label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9bbbc8"))
	draw_string(DisplayFont, Vector2(30, 72), "PLOT A COURSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, INK)
	var by_id := {}
	for node in _nodes: by_id[node.id] = node
	# Draw each undirected route once. Public geometry only.
	var drawn := {}
	for node in _nodes:
		for neighbor_id in node.edges:
			if not _positions.has(neighbor_id): continue
			var key := str(node.id) + "|" + str(neighbor_id)
			var reverse := str(neighbor_id) + "|" + str(node.id)
			if drawn.has(key) or drawn.has(reverse): continue
			drawn[key] = true
			var other: Dictionary = by_id.get(neighbor_id, {})
			var origin: Vector2 = _positions[node.id]
			var destination: Vector2 = _positions[neighbor_id]
			var visited_lane: bool = bool(node.visited) and bool(other.get("visited", false))
			var reachable_lane: bool = node.id == _current_id and bool(other.get("reachable", false))
			var alpha := 0.68 if visited_lane else (0.8 if reachable_lane else 0.19)
			var tint := CYAN if reachable_lane else Color("#a3c0cb")
			draw_line(origin, destination, Color(tint, alpha), 3.2 if reachable_lane else 1.4, true)
			if visited_lane:
				draw_line(origin, destination, Color("#d2f4ed", 0.22), 1.0, true)
	if _current_id.is_empty():
		var home := _departure_position()
		for node in _nodes:
			if node.layer == 0 and node.reachable and _positions.has(node.id):
				draw_line(home, _positions[node.id], Color(CYAN, 0.62), 2.4, true)
	# The ship is the current marker; visited stops remain a subdued wake.
	var ship := _ship_position()
	if _traveling:
		ship = _departure_position().lerp(_positions.get(_arrival_id, ship), _star_phase)
	if not reduced_motion:
		draw_arc(ship, 26 + (sin(Time.get_ticks_msec() / 460.0) + 1.0) * 2.0, 0, TAU, 48, Color(CYAN, 0.56), 1.5, true)
	if _traveling:
		draw_line(_departure_position(), _positions.get(_arrival_id, ship), Color(CYAN, 0.48), 3.0, true)
		draw_line(_departure_position(), ship, Color(CYAN, 0.65), 5.0, true)
	draw_set_transform(ship, _heading, Vector2.ONE)
	draw_texture_rect(PlayerShipTexture, Rect2(Vector2(-34, -28), Vector2(68, 56)), false, Color("#ddfff7"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _traveling and not reduced_motion:
		draw_rect(rect, Color("#c6f9f2", 0.12 * sin(_star_phase * PI)))

func _beacon_glyph(node: Dictionary) -> String:
	if node.id == _current_id: return ""
	if node.visited: return "✦\nPAST"
	match str(node.type):
		"recovery": return "✚"
		"shop": return "◇"
		"event": return "✧"
		"battle": return "●"
		"elite": return "⬡"
		"boss": return "✹"
	return "✦"

func _beacon_tint(node: Dictionary) -> Color:
	if node.reachable: return CYAN
	if node.visited: return Color("#b7c4c5")
	match str(node.type):
		"recovery": return Color("#92e1c1")
		"shop": return Color("#e8c989")
		"event": return Color("#c5a9ea")
		"battle": return Color("#df9b92")
		"elite", "boss": return Color("#e8a879")
	return INK

func _on_beacon_pressed(node_id: String) -> void:
	_on_beacon_focused(node_id)

func _on_beacon_focused(node_id: String) -> void:
	if _focused_id == node_id:
		_panel.visible = true
		return
	_focused_id = node_id
	_panel.visible = true
	_update_panel()
	queue_redraw()
	focus_node.emit(node_id)

func _update_panel() -> void:
	if not is_instance_valid(_panel): return
	var node := _node_by_id(_focused_id)
	if node.is_empty():
		_panel_title.text = "Signal readout"
		_panel_copy.text = "Choose a beacon to inspect its public signal."
		_travel_button.disabled = true
		call_deferred("_layout_chrome")
		return
	_panel_title.text = _stop_label(node)
	var public_description := _stop_description(node)
	_panel_copy.text = "%s · %s" % [_region_label, public_description.get_slice("·", 1).strip_edges()]
	_travel_button.disabled = node.id == _current_id or not node.reachable or _traveling or _travel_request_pending
	_travel_button.text = "Travel to signal"
	_travel_button.set_meta("node_id", node.id)
	_travel_button.set_meta("reachable", node.reachable)
	_travel_button.set_meta("visited", node.visited)
	_travel_button.accessibility_description = "Travel to %s, %s" % [
		_stop_label(node), _stop_description(node),
	]
	call_deferred("_layout_chrome")

func _request_travel() -> void:
	var node := _node_by_id(_focused_id)
	if node.is_empty() or not node.reachable or node.id == _current_id or _traveling or _travel_request_pending:
		return
	_travel_request_pending = true
	_travel_button.disabled = true
	travel_requested.emit(str(node.id))

func reject_travel_request() -> void:
	_travel_request_pending = false
	_update_panel()

func _ship_position() -> Vector2:
	return _positions.get(_current_id, Vector2(54.0, size.y * 0.5))

func _departure_position() -> Vector2:
	return _positions.get(_current_id, Vector2(54.0, size.y * 0.5))

func _node_by_id(node_id: String) -> Dictionary:
	for node in _nodes:
		if node.id == node_id: return node
	return {}

func _stop_label(node: Dictionary) -> String:
	return ChartStopView.stop_label(node)

func _stop_description(node: Dictionary) -> String:
	return ChartStopView.stop_description(node)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value: result.append(str(entry))
	return result
