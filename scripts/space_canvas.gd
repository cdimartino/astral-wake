extends Control

var connections: Array = []
var connection_colors: Array[Color] = []
var map_paths := false
var points: Array = []
var active_route: Array = []
var severed: Array = []
var stars := true
var animate_stars := false
var phase := 0.0
var pulse_start := Vector2.ZERO
var pulse_end := Vector2.ZERO
var pulse_progress := 0.0:
	set(value):
		pulse_progress = value
		queue_redraw()
var icon_kind := ""
var effect_kind := ""
var effect_echo := false
var effect_from := Vector2.ZERO
var effect_to := Vector2.ZERO
var effect_color := Color("7be0ca")
var effect_route: Array[Vector2] = []
var effect_progress := 0.0:
	set(value):
		effect_progress = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(stars and animate_stars)

func _process(delta: float) -> void:
	phase += delta * 4.0
	queue_redraw()

func _draw() -> void:
	if not effect_kind.is_empty():
		_draw_effect()
		return
	if not icon_kind.is_empty():
		_draw_icon()
		return
	if stars:
		for i in range(95):
			var p := Vector2(fmod(i * 137.51 + 51.0 + phase, 1440.0) / 1440.0 * size.x, fmod(i * 93.71 + 25.0 + phase * 0.3, 900.0) / 900.0 * size.y)
			draw_circle(p, 1.2 if i % 7 == 0 else 0.65, Color(0.55, 0.72, 0.78, 0.36 if i % 3 == 0 else 0.17))
	for edge_index in range(connections.size()):
		var edge = connections[edge_index]
		if edge[0] >= points.size() or edge[1] >= points.size():
			continue
		var broken := false
		for cut in severed:
			if (cut[0] == edge[0] and cut[1] == edge[1]) or (cut[1] == edge[0] and cut[0] == edge[1]):
				broken = true
		var selected := false
		for j in range(active_route.size() - 1):
			if (active_route[j] == edge[0] and active_route[j + 1] == edge[1]) or (active_route[j + 1] == edge[0] and active_route[j] == edge[1]):
				selected = true
		var tint := Color("7be0ca") if selected else Color("30465a")
		if edge_index < connection_colors.size(): tint = connection_colors[edge_index]
		if map_paths:
			var curve := Curve2D.new()
			var start: Vector2 = points[edge[0]] + Vector2(0, 78)
			var end: Vector2 = points[edge[1]] - Vector2(0, 46)
			curve.add_point(start, Vector2.ZERO, Vector2(0, 28))
			curve.add_point(end, Vector2(0, -28), Vector2.ZERO)
			var path := curve.get_baked_points()
			draw_polyline(path, Color(tint, 0.12), 7, true)
			draw_polyline(path, tint, 2, true)
			continue
		if broken:
			draw_dashed_line(points[edge[0]], points[edge[1]], Color("cf786f"), 2.0, 7.0)
		else:
			draw_line(points[edge[0]], points[edge[1]], tint, 3.0 if selected else 1.4, true)
	if pulse_start != pulse_end:
		var head := pulse_start.lerp(pulse_end, pulse_progress)
		var tail := pulse_start.lerp(pulse_end, maxf(0.0, pulse_progress - 0.22))
		draw_line(tail, head, Color(0.48, 0.95, 0.83, 1.0 - pulse_progress * 0.4), 7.0, true)
		draw_circle(head, 10.0, Color(0.75, 1.0, 0.9, 0.9))

func _draw_icon() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 22.0, size.y / 22.0))
	var tint := Color("f39789") if icon_kind == "damage" else Color("7be0ca") if icon_kind == "heal" else Color("e7c381")
	match icon_kind:
		"damage":
			draw_colored_polygon(PackedVector2Array([Vector2(13, 1), Vector2(4, 12), Vector2(10, 12), Vector2(7, 21), Vector2(19, 8), Vector2(12, 8)]), tint)
		"heal":
			draw_rect(Rect2(8, 2, 6, 18), tint)
			draw_rect(Rect2(2, 8, 18, 6), tint)
		"disrupt":
			draw_arc(Vector2(11, 11), 8, -PI * 0.8, PI * 0.8, 18, tint, 2, true)
			draw_line(Vector2(3, 20), Vector2(19, 2), tint, 3, true)
		"strain":
			var hex := PackedVector2Array()
			for i in range(7):
				hex.append(Vector2(11, 11) + Vector2(cos(i * TAU / 6), sin(i * TAU / 6)) * 9)
			draw_polyline(hex, tint, 2, true)
			draw_circle(Vector2(11, 11), 3, tint)
		"cost":
			draw_colored_polygon(PackedVector2Array([Vector2(11, 1), Vector2(20, 11), Vector2(11, 21), Vector2(2, 11)]), tint)

func _draw_effect() -> void:
	var t := effect_progress
	var tint := effect_color
	tint.a = 1.0 - t * 0.75
	if effect_kind in ["shot", "beam", "enemy_shot"]:
		var travel := minf(1.0, t / 0.55)
		var head := effect_from.lerp(effect_to, travel)
		var tail := effect_from.lerp(effect_to, maxf(0.0, travel - 0.22))
		if effect_kind == "beam":
			draw_line(effect_from, head, Color(tint, tint.a * 0.25), 18, true)
			draw_line(effect_from, head, tint, 5, true)
			draw_line(effect_from, head, Color(1, 1, 0.9, tint.a), 2, true)
			if effect_echo: draw_line(effect_from + Vector2(0, 10), head + Vector2(0, 10), Color(tint, tint.a * 0.55), 3, true)
		else:
			draw_line(tail, head, Color(tint, tint.a * 0.3), 16, true)
			draw_line(tail, head, tint, 6 if effect_kind == "shot" else 9, true)
			draw_circle(head, 7 if effect_kind == "shot" else 11, tint)
		if t > 0.5:
			var impact := (t - 0.5) * 2
			for i in range(10):
				var direction := Vector2.from_angle(i * TAU / 10)
				draw_line(effect_to + direction * (6 + impact * 18), effect_to + direction * (20 + impact * 68), Color(effect_color, 1 - impact), 3, true)
			draw_arc(effect_to, 12 + impact * 55, 0, TAU, 40, Color(effect_color, 1 - impact), 3, true)
	elif effect_kind == "repair":
		draw_arc(effect_to, 22 + t * 90, 0, TAU, 64, tint, 4, true)
		for i in range(7):
			var angle := i * TAU / 7 + t
			var point := effect_to + Vector2.from_angle(angle) * (25 + t * 65) + Vector2(0, -t * 30)
			draw_line(point - Vector2(7, 0), point + Vector2(7, 0), tint, 3, true)
			draw_line(point - Vector2(0, 7), point + Vector2(0, 7), tint, 3, true)
	elif effect_kind in ["disrupt", "shield", "mark", "incubate"]:
		for i in range(3):
			var radius := 26 + i * 18 + t * 30
			var angle := t * TAU * (1 if i % 2 == 0 else -1)
			draw_arc(effect_to, radius, angle, angle + PI * 1.4, 30, tint, 3, true)
		for i in range(6):
			var a := i * TAU / 6 + t
			draw_line(effect_to + Vector2.from_angle(a) * 14, effect_to + Vector2.from_angle(a + 0.2) * (60 + t * 30), Color(tint, tint.a * 0.5), 2, true)
	elif effect_kind == "vent":
		for i in range(8):
			var direction := Vector2.from_angle(i * TAU / 8)
			var point := effect_to + direction * (15 + t * 65)
			draw_line(point - direction * 9, point + direction * 9, tint, 3, true)
			draw_circle(point, 3, tint)
	elif effect_kind == "strain":
		var ring := PackedVector2Array()
		for i in range(7): ring.append(effect_to + Vector2.from_angle(i * TAU / 6) * (28 + t * 28))
		draw_polyline(ring, tint, 4, true)
	elif effect_kind == "route":
		for i in range(effect_route.size() - 1):
			draw_line(effect_route[i], effect_route[i + 1], Color(effect_color, 0.8 * (1 - t)), 8, true)
		for point in effect_route: draw_arc(point, 20 + t * 30, 0, TAU, 24, tint, 3, true)
	elif effect_kind == "sever":
		if effect_route.size() == 2:
			draw_dashed_line(effect_route[0], effect_route[1], tint, 6, 9, true)
		draw_line(effect_to - Vector2(14, 14), effect_to + Vector2(14, 14), tint, 5, true)
		draw_line(effect_to - Vector2(-14, 14), effect_to + Vector2(-14, 14), tint, 5, true)
	elif effect_kind == "link":
		for i in range(3): draw_arc(effect_to, 25 + i * 20 + t * 60, t * 3 + i, t * 3 + i + PI, 32, tint, 3, true)
