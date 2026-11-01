extends SceneTree
const Main = preload("res://scripts/main.gd")
const Fixtures = preload("res://tests/route_effect_fixtures.gd")
var failures=0
var directory=OS.get_environment("TMPDIR").path_join("route-effects-ui-%d"%Time.get_ticks_usec())
func require(value: bool, message: String) -> void:
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	OS.set_environment("ASTRAL_SKIP_INTRO","1")
	OS.set_environment("ASTRAL_SAVE_DIR",directory)
	check.call_deferred()
func check() -> void:
	var ui=Main.new()
	root.add_child(ui)
	for unused in range(5): await process_frame
	Fixtures.demo(ui.game)
	ui.menu=false
	ui.selected_card=0
	ui.route.assign([4])
	var result=ui.game.preview_card(0,[4],0)
	require(result.flat_ward_requested==5 and result.flat_ward_applied==5 and result.command_cooling==2,"Heat Sink preview ward and actual cooling")
	for size in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size=size
		ui._render()
		for unused in range(5): await process_frame
		var label=ui.page.find_child("RoutePreviewSummary",true,false)
		require(label.text.contains("Ward 5/5 · Cool 2") and label.get_line_count()==1,"Visible compact requested/applied ward and cooling")
		var stats=ui._printed_stats(ui.game.run.battle.hand[0],true)
		require(stats.get_children().any(func(child): return child is Label and child.text=="Ward 5"),"Printed ward stat")
		stats.free()
	var played=ui.game.play_card(0,[4],0)
	require(played==result and ui.game.run.battle.ward==13,"Native fixture commit agrees with preview; 8+5=13")
	ui._clear_selection()
	ui._render()
	Fixtures.demo(ui.game)
	ui.selected_card=1
	ui.route.assign([0])
	var thermal=ui.game.preview_card(1,[0],0)
	require(thermal.conditional_damage==6 and ui._command_preview_summary(thermal).contains("Bonus +6"),"Native conditional bonus is explicit, not only aggregate damage")
	ui._render()
	for unused in range(5): await process_frame
	ui.ambience.stop()
	ui.audio.stop()
	OS.delay_msec(200)
	ui.queue_free()
	for unused in range(5): await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Route effects UI: %d failures"%failures)
	quit(1 if failures else 0)
