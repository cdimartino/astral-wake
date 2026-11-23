extends SceneTree

const View = preload("res://scripts/chart_stop_view.gd")
const Game = preload("res://scripts/game.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var labels := {"battle":"Hostile signal", "elite":"High-risk contact", "boss":"Guardian signal", "event":"Unknown signal", "shop":"Trading signal", "recovery":"Safe harbor"}
	for kind in labels:
		check(View.stop_label({"type":kind}) == labels[kind], "actual map type label: " + kind)
	var base := OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_cache_dir()
	var isolated := base.path_join("astral-chart-projection-" + Crypto.new().generate_random_bytes(16).hex_encode())
	if DirAccess.make_dir_recursive_absolute(isolated) != OK:
		push_error("Cannot create isolated chart test save directory")
		quit(1)
		return
	var game = Game.new(isolated)
	var started: Dictionary = game.new_run("CHART1")
	if not started.get("ok", false):
		push_error("Cannot initialize chart reachability fixture")
		quit(1)
		return
	check_reachability(game, "initial")
	# Every possible committed position, without resolving encounters or changing RNG.
	for layer in game.run.map:
		for node in layer:
			game.run.current_node = node.id
			game.run.layer = node.layer
			game.run.visited = [node.id]
			game.run.mode = "map"
			check_reachability(game, "post-node " + str(node.id))
	game.run.pending_selection = {"source_uid":1}
	check_reachability(game, "pending selection")
	game.run.pending_selection = {}
	game.run.mode = "combat"
	check_reachability(game, "combat arrived")
	var run := {"mode":"map", "layer":-1, "current_node":"", "visited":[], "seed":"secret", "rng":123, "map":[[
		{"id":"a", "layer":0, "column":0, "type":"battle", "edges":["b"], "enemies":["secret_enemy"], "event_id":"secret_event"}
	], [
		{"id":"b", "layer":1, "column":0, "type":"boss", "edges":[], "enemies":["secret_boss"]}
	]]}
	var original := run.duplicate(true)
	var first := View.project(run)
	var other := run.duplicate(true)
	other.seed = "other_secret"
	other.rng = 999
	other.map[0][0].enemies = ["other_enemy", "third_enemy"]
	other.map[0][0].event_id = "other_event"
	other.map[1][0].enemies = ["different_boss"]
	check(first == View.project(other), "hidden roster/event/RNG differences cannot alter public projection")
	check(run == original, "projection must not mutate saves")
	check(first.layers[0][0].reachable, "first layer reachable")
	check(not first.layers[1][0].reachable, "future layer not reachable")
	check(first.layers[0][0].label == "Hostile signal", "generic combat label")
	check(first.layers[1][0].label == "Guardian signal", "generic boss label")
	run.current_node = "a"
	run.layer = 0
	run.visited = ["a"]
	check(View.project(run).layers[1][0].reachable, "connected destination reachable")
	check(View.project(run).layers[0][0].visited, "visited public history")
	run.mode = "combat"
	check(not View.project(run).layers[1][0].reachable, "travel unavailable during encounter")
	first.layers[0][0].edges.append("mutated")
	check(run.map[0][0].edges == ["b"], "projection edges detached from save")
	print("Chart projection tests: ", failures, " failures")
	quit(1 if failures else 0)

func check_reachability(game, context: String) -> void:
	var projected := View.project(game.run)
	for layer_index in range(game.run.map.size()):
		for index in range(game.run.map[layer_index].size()):
			var node: Dictionary = game.run.map[layer_index][index]
			check(projected.layers[layer_index][index].reachable == game.reachable(node), context + " reachability " + str(node.id))
