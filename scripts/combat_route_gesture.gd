extends RefCounted
## Pointer-only staging state. Main remains the sole route validator and player.
signal pickup(card_uid: int)
signal route_changed(route: Array[int])
signal armed(card_uid: int, route: Array[int])
signal cancelled
signal rejected(socket: int, reason: String)

const DRAG_THRESHOLD := 12.0
var pressed_uid := -1
var pressed_index := -1
var origin := Vector2.ZERO
var dragging := false
var route: Array[int] = []
var last_socket := -1

func begin(card_index: int, card_uid: int, pointer: Vector2) -> void:
	pressed_index = card_index
	pressed_uid = card_uid
	origin = pointer
	dragging = false
	route.clear()
	last_socket = -1

func update_pointer(pointer: Vector2, socket: int, route_validator: Callable) -> bool:
	if pressed_uid < 0:
		return false
	if not dragging and origin.distance_to(pointer) >= DRAG_THRESHOLD:
		dragging = true
		pickup.emit(pressed_uid)
	if not dragging or socket < 0 or socket == last_socket:
		return dragging
	last_socket = socket
	if not route.is_empty() and socket == route.back():
		return dragging
	if route.size() > 0 and socket == route[route.size() - 1]:
		return dragging
	if route.has(socket):
		var prior := route.find(socket)
		if prior == route.size() - 2:
			route.resize(prior + 1)
			route_changed.emit(route.duplicate())
		return dragging
	if route.size() >= 3:
		rejected.emit(socket, "A route can contain at most three organs.")
		return dragging
	var candidate := route.duplicate()
	candidate.append(socket)
	var error := str(route_validator.call(candidate))
	if error.is_empty():
		route = candidate
		route_changed.emit(route.duplicate())
	else:
		rejected.emit(socket, error)
	return dragging

func finish() -> Dictionary:
	var result := {"dragged":dragging,"card_uid":pressed_uid,"card_index":pressed_index,"route":route.duplicate()}
	if dragging:
		armed.emit(pressed_uid, route.duplicate())
	pressed_uid = -1
	pressed_index = -1
	dragging = false
	last_socket = -1
	return result

func cancel() -> void:
	var was_active := pressed_uid >= 0
	pressed_uid = -1
	pressed_index = -1
	dragging = false
	route.clear()
	last_socket = -1
	if was_active:
		cancelled.emit()
