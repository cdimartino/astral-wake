extends Control
## Organic socket artwork; interaction belongs to the transparent parent button.
var tint := Color("7be0ca")
var selected := false
var available := false
var strain := 0
var projected := 0
var capacity := 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := Vector2(43, 48)
	var boundary := PackedVector2Array()
	for i in range(65):
		var a := i * TAU / 64
		var r := 40 + 3 * sin(a * 3 + 0.4) + 2 * cos(a * 5)
		boundary.append(center + Vector2(cos(a) * r, sin(a) * r * 1.08))
	draw_colored_polygon(boundary, Color("081a24"))
	draw_polyline(boundary, Color(tint, 0.12), 10, true)
	draw_polyline(boundary, Color(tint, 0.9 if selected or available else 0.45), 2 if selected else 1, true)
	for i in range(capacity):
		var angle := PI * 0.15 + i * PI * 0.7 / maxi(1, capacity)
		var end := angle + PI * 0.7 / maxi(1, capacity) - 0.08
		var color := Color("f39789") if strain >= capacity else tint if i < strain else Color("405563")
		if i >= mini(strain, projected) and i < maxi(strain, projected): color = Color("e7c381")
		draw_arc(center, 43, angle, end, 12, color, 3, true)
