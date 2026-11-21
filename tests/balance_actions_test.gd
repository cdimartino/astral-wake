extends SceneTree

# Controller-bound visible-control fixture; no gameplay rules or saves mutated.
class Fixture extends Node:
	var page := Control.new()
	var overlay = null
	var opening_film = null
	var game = {"run":{}, "profile":{}}
	var choosing_character := false
	var menu := false
	var selected_card := -1
	var route: Array = []
	var target := 0
	var selected_character := 0
	var modify_page := 0
	var anatomy_view := false
	var notice := ""
	var activated := -1
	func presentation_busy() -> bool: return false

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func options(state: Dictionary, action: String) -> Array:
	for entry in state.legal_actions:
		if entry.action == action: return entry.args.index.options
	return []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main := Fixture.new()
	root.add_child(main)
	main.add_child(main.page)
	var controller = load("res://scripts/mcp_controller.gd").new(main)
	for i in range(33):
		var button := Button.new()
		button.name = "Destination%d" % i
		button.text = "Visible chart node %d" % i
		button.set_meta("map_node", true)
		button.set_meta("focus_key", "destination_node-%d" % i)
		button.set_meta("reachable_destination", i in [4, 19])
		button.pressed.connect(func(): main.activated = i)
		main.page.add_child(button)
	var detail_travel := Button.new()
	detail_travel.text = "Travel here →"
	main.page.add_child(detail_travel)
	var state: Dictionary = controller.snapshot()
	check(options(state, "choose_node").size() == 2, "33 chart nodes advertise only two reachable travels")
	check(options(state, "choose_node")[1].node_id == "node-19", "travel exposes stable public node identity, not only binding index")
	check(options(state, "inspect_node").size() == 31, "other visible nodes remain separately inspectable")
	var response: Dictionary = controller.request("act", {"action":"choose_node", "args":{"index":1}, "expected_revision":state.revision})
	check(response.ok and main.activated == 19, "travel activates corresponding shared UI binding")
	for child in main.page.get_children():
		main.page.remove_child(child)
		child.free()
	for i in range(3):
		var button := Button.new()
		button.text = "Buy · 20 salvage"
		button.set_meta("purchase_name", ["Visible card", "Visible organ", "Repair service"][i])
		button.set_meta("purchase_price", 20)
		button.set_meta("purchase_slot", i)
		button.pressed.connect(func(): main.activated = i)
		main.page.add_child(button)
	state = controller.snapshot()
	var purchases := options(state, "buy")
	check(purchases.size() == 3 and purchases[2].name == "Repair service" and purchases[2].price == 20 and purchases[2].slot == 2, "purchases advertise visible names, prices and original slots")
	var old_revision: int = state.revision
	var sold: Button = main.page.get_child(0)
	sold.text = "Sold"
	sold.disabled = true
	state = controller.snapshot()
	purchases = options(state, "buy")
	check(purchases.size() == 2 and purchases[0].index == 1 and purchases[0].slot == 1, "sold slot does not reindex later purchase bindings")
	response = controller.request("act", {"action":"buy", "args":{"index":1}, "expected_revision":old_revision})
	check(not response.ok and response.error.code == "stale_revision", "sold-slot UI changes invalidate old revision")
	response = controller.request("act", {"action":"buy", "args":{"index":1}, "expected_revision":state.revision})
	check(response.ok and main.activated == 1, "fresh named purchase executes original UI callback")
	response = controller.request("act", {"action":"buy", "args":{"index":0}, "expected_revision":controller.snapshot().revision})
	check(not response.ok and response.error.code == "unavailable", "sold slot cannot be purchased")
	var preview: Dictionary = controller._public_preview({"ok":true, "ward_gained":7, "next":{"draw":["secret"]}, "presentation":["secret"], "events":["secret"], "summary":"secret", "seed":"secret", "draw":["secret"]})
	check(preview.get("ward_gained") == 7, "public preview preserves ward gained")
	check(preview.size() == 2 and preview.ok, "public preview excludes forbidden simulation and hidden fields")
	main.free()
	print("Balance actions fixture: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
