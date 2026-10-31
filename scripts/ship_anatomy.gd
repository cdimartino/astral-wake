extends Control
## A translucent opened hull, with specimens nested inside its membrane.
const ORIGIN := Vector2(60, 220)
const NODE_SIZE := Vector2(190, 96)
const GRAPH_SIZE := Vector2(680, 286)
const POSITIONS := [Vector2(270, 0), Vector2(480, 40), Vector2(475, 167), Vector2(270, 185), Vector2(65, 157), Vector2(25, 25)]
var tint := Color("bcb5ff")

static func center(index: int) -> Vector2:
	return ORIGIN + POSITIONS[index] + Vector2(43, 48)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var membrane := PackedVector2Array()
	var rim := PackedVector2Array()
	for i in range(97):
		var angle := i * TAU / 96
		var radius := 1.0 + 0.035 * sin(angle * 5) + 0.02 * cos(angle * 9)
		membrane.append(Vector2(378, 184) + Vector2(cos(angle) * 348, sin(angle) * 142) * radius)
		rim.append(Vector2(378, 184) + Vector2(cos(angle) * 365, sin(angle) * 151) * radius)
	draw_colored_polygon(membrane, Color(0.015, 0.035, 0.055, 0.38))
	draw_polyline(rim, Color(tint, 0.10), 9, true)
	draw_polyline(rim, Color(tint, 0.48), 1.5, true)
	draw_polyline(membrane, Color(tint, 0.3), 2, true)
	# Short mineral ribs make the opened hull feel grown rather than framed.
	for i in range(30):
		var angle := i * TAU / 30
		var root := Vector2(378, 184) + Vector2(cos(angle) * 359, sin(angle) * 149)
		var tip := Vector2(378, 184) + Vector2(cos(angle + 0.025) * 332, sin(angle + 0.025) * 132)
		draw_line(root, tip, Color(tint, 0.30), 2, true)
		draw_circle(root, 2, Color("cbbd99"))
