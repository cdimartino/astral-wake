extends SceneTree

const Gesture = preload("res://scripts/combat_route_gesture.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var gesture := Gesture.new()
	var rejected: Array[String] = []
	gesture.rejected.connect(func(_socket: int, reason: String): rejected.append(reason))
	var valid_edges := [[0, 1], [1, 2], [2, 3]]
	var validator := func(candidate: Array) -> String:
		if candidate.size() > 1 and not valid_edges.has([candidate[-2], candidate[-1]]):
			return "Broken connection."
		return ""
	gesture.begin(3, 431, Vector2.ZERO)
	check(not gesture.update_pointer(Vector2(8, 0), -1, validator), "Small movement remains an ordinary click")
	gesture.update_pointer(Vector2(13, 0), 0, validator)
	gesture.update_pointer(Vector2(30, 0), 1, validator)
	gesture.update_pointer(Vector2(34, 0), 1, validator)
	gesture.update_pointer(Vector2(41, 0), 2, validator)
	check(gesture.route == [0, 1, 2], "Connected sockets form an ordered route without duplicates")
	gesture.update_pointer(Vector2(50, 0), 1, validator)
	check(gesture.route == [0, 1], "Re-entering the previous socket backtracks one step")
	gesture.update_pointer(Vector2(60, 0), 3, validator)
	check(gesture.route == [0, 1] and not rejected.is_empty(), "Invalid edge preserves the last legal route")
	var result := gesture.finish()
	check(result.dragged and result.card_uid == 431 and result.card_index == 3, "Release arms the exact card UID")
	gesture.begin(0, 432, Vector2.ZERO)
	gesture.update_pointer(Vector2(13, 0), 0, validator)
	gesture.update_pointer(Vector2(25, 0), 1, validator)
	gesture.update_pointer(Vector2(35, 0), 2, validator)
	gesture.update_pointer(Vector2(45, 0), 3, validator)
	check(gesture.route == [0, 1, 2], "Fourth step is rejected locally")
	gesture.cancel()
	check(gesture.pressed_uid == -1 and gesture.route.is_empty(), "Cancel clears gesture without committing")
	print("Combat route gesture: %d failures" % failures)
	quit(1 if failures else 0)
