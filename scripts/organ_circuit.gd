extends Control
## Anatomical conduits follow the battle's real edges, never a decorative graph.

const NODE_SIZE := Vector2(220, 100)
const ORIGIN := Vector2(326, 202)
const GRAPH_SIZE := Vector2(456, 328)
const POSITIONS := [Vector2(0, 0), Vector2(236, 0), Vector2(236, 114), Vector2(236, 228), Vector2(0, 228), Vector2(0, 114)]
var edges: Array = []
var severed: Array = []
var route: Array = []
var available: Array[int] = []
var hovered := -1
var organic := false
var reduced_motion := false
var tint := Color("7be0ca")
var phase := 0.0
var _anatomy_paths := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not reduced_motion)

func _process(delta: float) -> void:
	phase = fmod(phase + delta * 0.5, 1.0)
	queue_redraw()

static func center(index: int) -> Vector2:
	return ORIGIN + POSITIONS[index] + NODE_SIZE * 0.5

func _has_edge(list: Array, a: int, b: int) -> bool:
	for edge in list:
		if (int(edge[0]) == a and int(edge[1]) == b) or (int(edge[1]) == a and int(edge[0]) == b): return true
	return false

func _path(a: int, b: int) -> PackedVector2Array:
	if organic:
		return _anatomy_path(a, b)
	var start: Vector2 = POSITIONS[a] + NODE_SIZE * 0.5
	var end: Vector2 = POSITIONS[b] + NODE_SIZE * 0.5
	var curve := Curve2D.new()
	if is_equal_approx(start.x, end.x):
		var sign_y := signf(end.y - start.y)
		if absf(end.y - start.y) > 120:
			# Long grafts travel outside the specimens, clear of all text.
			var side := -1.0 if start.x < 200 else 1.0
			start.x += side * NODE_SIZE.x * 0.5
			end.x += side * NODE_SIZE.x * 0.5
			curve.add_point(start, Vector2.ZERO, Vector2(side * 16, 0))
			curve.add_point(end, Vector2(side * 16, 0), Vector2.ZERO)
		else:
			start.y += sign_y * NODE_SIZE.y * 0.5
			end.y -= sign_y * NODE_SIZE.y * 0.5
			curve.add_point(start, Vector2.ZERO, Vector2(-5, sign_y * 6))
			curve.add_point(end, Vector2(5, -sign_y * 6), Vector2.ZERO)
	else:
		var sign_x := signf(end.x - start.x)
		start.x += sign_x * NODE_SIZE.x * 0.5
		end.x -= sign_x * NODE_SIZE.x * 0.5
		# Offset diagonal ports so adjacent nerves can be traced individually.
		var offset_y := signf(end.y - start.y) * 26
		start.y += offset_y
		end.y -= offset_y
		curve.add_point(start, Vector2.ZERO, Vector2(sign_x * 12, 0))
		curve.add_point(end, Vector2(-sign_x * 12, 0), Vector2.ZERO)
	return curve.get_baked_points()

func _clear_segment(a: Vector2, b: Vector2, obstacles: Array[Rect2]) -> bool:
	for rect in obstacles:
		if rect.has_point(a.lerp(b, 0.5)): return false
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null: return false
	return true

func _anatomy_path(a: int, b: int) -> PackedVector2Array:
	var key := Vector2i(a, b)
	if _anatomy_paths.has(key): return _anatomy_paths[key]
	var anatomy = preload("res://scripts/ship_anatomy.gd")
	var obstacles: Array[Rect2] = []
	var vertices: Array[Vector2] = []
	# Ports surround the whole tile, including its opaque caption, not just
	# the specimen. Route around other tiles and the central inspector too.
	for position in anatomy.POSITIONS:
		var rect := Rect2(position, anatomy.NODE_SIZE)
		obstacles.append(rect.grow(1))
		var center := rect.get_center()
		vertices.append_array([Vector2(center.x, rect.position.y - 3), Vector2(rect.end.x + 3, center.y), Vector2(center.x, rect.end.y + 3), Vector2(rect.position.x - 3, center.y)])
	obstacles.append(anatomy.INSPECTOR_RECT.grow(1))
	for obstacle in obstacles:
		var rect := obstacle.grow(2)
		vertices.append_array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[int] = []
	for i in range(vertices.size()):
		distances.append(0.0 if i / 4 == a and i < 24 else INF)
		previous.append(-1)
	var end := -1
	for unused in range(vertices.size()):
		var current := -1
		for i in range(vertices.size()):
			if not visited.has(i) and (current < 0 or distances[i] < distances[current]): current = i
		if current < 0 or is_inf(distances[current]): break
		if current < 24 and current / 4 == b:
			end = current
			break
		visited.append(current)
		for i in range(vertices.size()):
			var distance := distances[current] + vertices[current].distance_to(vertices[i])
			if distance < distances[i] and _clear_segment(vertices[current], vertices[i], obstacles):
				distances[i] = distance
				previous[i] = current
	var points: Array[Vector2] = []
	while end >= 0:
		points.push_front(vertices[end])
		end = previous[end]
	var curve := Curve2D.new()
	for point in points: curve.add_point(point)
	var path := curve.get_baked_points()
	_anatomy_paths[key] = path
	var reverse := path.duplicate()
	reverse.reverse()
	_anatomy_paths[Vector2i(b, a)] = reverse
	return path

func _cable(path: PackedVector2Array, color: Color, active: bool, broken: bool = false) -> void:
	if path.size() < 2: return
	draw_polyline(path, Color("050e18"), 10, true)
	draw_polyline(path, Color(color, 0.15), 8, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	var traveled := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		traveled += a.distance_to(b)
		if broken and traveled / maxf(1, length) > 0.38 and traveled / maxf(1, length) < 0.62: continue
		draw_line(a, b, color, 2.5 if active else 1.4, true)
		if i % 2 == 0:
			var normal := (b - a).normalized().orthogonal() * 3.5
			draw_line(b - normal, b + normal, Color(color, 0.5), 1, true)
	if broken:
		var middle := path[path.size() / 2]
		draw_line(middle - Vector2(4, 5), middle + Vector2(4, 5), color, 2, true)
		draw_line(middle - Vector2(-4, 5), middle + Vector2(-4, 5), color, 2, true)
	elif active:
		var step := clampi(int((0.5 if reduced_motion else phase) * (path.size() - 1)), 1, path.size() - 1)
		var direction := (path[step] - path[step - 1]).normalized()
		var head := path[step]
		draw_circle(head, 5, Color(color, 0.2))
		draw_polyline(PackedVector2Array([head - direction * 6 + direction.orthogonal() * 4, head, head - direction * 6 - direction.orthogonal() * 4]), Color("f8e4ad"), 2, true)
	for point in [path[0], path[-1]]:
		draw_circle(point, 4, Color("101f2c"))
		draw_arc(point, 4, 0, TAU, 12, color, 1, true)

func _draw() -> void:
	# The dorsal nerve joins the full-size vessel to its adjacent specimens.
	var root := Curve2D.new()
	root.add_point(Vector2(-80, 106), Vector2.ZERO, Vector2(50, 0))
	root.add_point(Vector2(0, 164), Vector2(-45, 0), Vector2.ZERO)
	if not organic: _cable(root.get_baked_points(), tint.darkened(0.35), false)
	for selected_pass in [false, true]:
		for edge in edges:
			var a := int(edge[0])
			var b := int(edge[1])
			var selected := false
			for j in range(route.size() - 1):
				if _has_edge([edge], int(route[j]), int(route[j + 1])):
					selected = true
					a = int(route[j])
					b = int(route[j + 1])
			if selected != selected_pass: continue
			var broken := _has_edge(severed, a, b)
			var next: bool = not route.is_empty() and ((a == route[-1] and available.has(b)) or (b == route[-1] and available.has(a)))
			var highlighted: bool = a == hovered or b == hovered or next
			_cable(_path(a, b), Color("f39789") if broken else Color("e7c381") if selected else tint if highlighted else tint.darkened(0.45), selected, broken)
