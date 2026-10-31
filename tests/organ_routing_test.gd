extends SceneTree
const Main = preload("res://scripts/main.gd")
var ui
var checks := 0
var failures := 0

func _initialize() -> void:
 OS.set_environment("ASTRAL_SKIP_INTRO", "1")
 OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-organs-%d" % Time.get_ticks_usec())
 check.call_deferred()

func require(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)

func settle() -> void:
 for i in range(5): await process_frame

func check() -> void:
 ui = Main.new()
 root.add_child(ui)
 await settle()
 var specimens := []
 for viewport_size in [Vector2i(1440, 900), Vector2i(1100, 720)]:
  root.size = viewport_size
  for character in ui.game.catalog.characters:
   ui.game.new_run(2101, character.id)
   ui.game.choose_node(ui.game.run.map[0][0].id)
   ui.menu = false
   ui._clear_selection()
   ui.game.profile.settings.reduced_motion = true
   ui._render()
   ui._select_card(0)
   await settle()
   var console = ui.page.find_child("LivingCircuit", true, false)
   require(ui.page.find_child("AnatomyInspector", true, false).z_index > ui.page.find_child("OrganNetwork", true, false).z_index, "Neural conduits obscure the anatomy readout")
   for i in range(6):
    var organ = ui.page.find_child("Organ%d" % i, true, false)
    var specimen = organ.find_child("OrganSpecimen", true, false)
    require(specimen != null and specimen.texture != null, "Missing anatomical specimen")
    if viewport_size.x == 1440:
     require(not specimens.has(specimen.texture.resource_path), "Organs must have distinct artwork")
     specimens.append(specimen.texture.resource_path)
    require(console.get_global_rect().grow(1).encloses(organ.get_global_rect()), "Organ outside ship console")
    require(organ.get_meta("route_available"), "Any unsaturated organ should be a legal starting point")
    var local_center = (organ.get_global_rect().get_center() - ui.page.global_position) / ui.page.scale
    var feedback_center = local_center + (Vector2(-52, 0) if ui.anatomy_view else Vector2.ZERO)
    require(feedback_center.distance_to(ui._organ_center(i)) < 0.1, "Combat feedback misses the organ specimen")
    for label in organ.find_children("*", "Label", true, false):
     require(organ.get_global_rect().grow(1).encloses(label.get_global_rect()), "Organ readout outside its specimen tile")
     require(label.get_line_count() <= (2 if label.name == "OrganCondition" else 1), "Organ readout exceeds its allotted lines: " + label.text)
     require(label.get_visible_line_count() == label.get_line_count(), "Organ readout hides text: " + label.text)
   ui._select_organ(0)
   await settle()
   require(ui.page.find_child("Organ0", true, false).get_meta("route_step") == 1, "First route step lacks order")
   var circuit = ui.page.find_child("NeuralConduits", true, false)
   require(not circuit.is_processing(), "Reduced motion still animates the neural circuit")
   # Availability follows authored topology, not the rectangular visual arrangement.
   for i in range(1, 6):
    var connected = ui.game._edge_exists(ui.game.run.battle.edges, 0, i)
    require(ui.page.find_child("Organ%d" % i, true, false).get_meta("route_available") == connected, "Legal next step differs from the real network")
   ui.game.run.battle.severed = [[0, 1]]
   ui._render()
   await settle()
   require(not ui.page.find_child("Organ1", true, false).get_meta("route_available"), "Severed edge is offered as available")
   ui._select_organ(1)
   require(ui.route == [0], "Keyboard routing crossed a severed link")
   ui.game.run.battle.severed.clear()
   ui.game.run.battle.strain[1] = ui.game.run.battle.capacity
   ui._select_organ(1)
   require(ui.route == [0], "Keyboard routing entered a saturated organ")
   ui.game.run.battle.strain[1] = 0
   ui._select_organ(1)
   require(ui.route == [0, 1], "Restored connection did not accept a step")
   ui._select_organ(1)
   require(ui.route == [0], "Clicking a selected step did not undo it")
   ui.game.profile.settings.reduced_motion = false
   ui._sync_motion()
   circuit = ui.page.find_child("NeuralConduits", true, false)
   require(circuit.is_processing(), "Motion setting did not resume neural signals")
 # A newly grafted connection must also be routable and displayed.
 ui.game.new_run(2101)
 ui.game.choose_node(ui.game.run.map[0][0].id)
 ui._clear_selection()
 ui._select_card(0)
 ui._select_organ(0)
 ui._select_organ(2)
 require(ui.route == [0], "Unconnected organ was accepted")
 ui.game.run.battle.edges.append([0, 2])
 ui._render()
 require(ui.page.find_child("Organ2", true, false).get_meta("route_available"), "Newly grafted link is absent from availability")
 ui._select_organ(2)
 require(ui.route == [0, 2], "Newly grafted link was rejected")
 var before = ui.game.run.duplicate(true)
 ui.page.find_child("AnatomyViewToggle", true, false).pressed.emit()
 await settle()
 require(not ui.anatomy_view and ui.route == [0, 2] and ui.game.run == before, "Comparing layouts changes the battle or selected route")
 var toggle = ui.page.find_child("AnatomyViewToggle", true, false)
 for i in range(6):
  var organ = ui.page.find_child("Organ%d" % i, true, false)
  require(not toggle.get_global_rect().intersects(organ.get_global_rect()), "View switch covers a console organ")
 ui.page.find_child("AnatomyViewToggle", true, false).pressed.emit()
 await settle()
 require(ui.anatomy_view and ui.route == [0, 2], "Returning to anatomy loses the route")
 print("ORGAN_ROUTING ", checks, " checks, ", failures, " failures")
 ui.ambience.stop()
 ui.audio.stop()
 OS.delay_msec(200)
 ui.queue_free()
 await settle()
 quit(1 if failures else 0)
