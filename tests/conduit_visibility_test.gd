extends SceneTree

const Circuit = preload("res://scripts/organ_circuit.gd")
const Anatomy = preload("res://scripts/ship_anatomy.gd")
var failures := 0

func covered(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.grow(1).has_point(point): return true
	return false

func _initialize() -> void:
	var circuit = Circuit.new()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	for organic in [false, true]:
		circuit.organic = organic
		var rects: Array[Rect2] = []
		for position in Anatomy.POSITIONS if organic else Circuit.POSITIONS:
			rects.append(Rect2(position, Anatomy.NODE_SIZE if organic else Circuit.NODE_SIZE))
		if organic: rects.append(Anatomy.INSPECTOR_RECT)
		for ship in catalog.characters:
			for edge in ship.edges:
				var path = circuit._path(int(edge[0]), int(edge[1]))
				if path.size() < 2:
					failures += 1
					push_error("Missing conduit: %s %s" % [ship.id, edge])
					continue
				var exposed := 0.0
				for i in range(1, path.size()):
					if not covered(path[i - 1].lerp(path[i], 0.5), rects):
						exposed += path[i - 1].distance_to(path[i])
				if exposed < 8 or covered(path[path.size() / 2], rects):
					failures += 1
					push_error("Obscured conduit/cut marker: %s %s anatomy=%s exposed=%s" % [ship.id, edge, organic, exposed])
		# Link commands can graft any pair; their anatomy paths must also avoid
		# captions and preserve their shape when selected in reverse order.
		if organic:
			for a in range(6):
				for b in range(a + 1, 6):
					var path = circuit._path(a, b)
					var reverse = circuit._path(b, a).duplicate()
					reverse.reverse()
					if path.size() < 2 or path != reverse: failures += 1
					for point in path:
						if covered(point, rects) or point.y > 284:
							failures += 1
							push_error("Grafted conduit crosses a tile: %d-%d" % [a, b])
							break
	print("CONDUIT VISIBILITY: ", failures, " failures")
	circuit.free()
	quit(1 if failures else 0)
