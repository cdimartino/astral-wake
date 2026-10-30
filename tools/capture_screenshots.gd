extends SceneTree
## Render real seeded opening encounters; never reads or changes player saves.
const Main = preload("res://scripts/main.gd")
var ui
func _initialize() -> void:
 OS.set_environment("ASTRAL_SKIP_INTRO", "1")
 OS.set_environment("ASTRAL_SAVE_DIR", "/tmp/astral-docs-%d" % Time.get_ticks_usec())
 capture.call_deferred()
func settle() -> void:
 for frame in range(8): await process_frame
func shot(filename: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 var error = root.get_texture().get_image().save_png("res://docs/screenshots/" + filename + ".png")
 if error != OK:
  push_error("Screenshot failed: " + filename)
  quit(1)
 print("SCREENSHOT ", filename)
func expedition(ship: String, area: int) -> void:
 for seed_value in range(2026, 2126):
  ui.game.new_run(seed_value, ship)
  if int(ui.game.run.route_regions[0]) == area: break
 ui.menu = false
 ui.choosing_character = false
 ui.selected_card = -1
 ui.route.clear()
 ui.target = 0
 ui._render()
func capture() -> void:
 root.size = Vector2i(1440,900)
 root.gui_disable_input = true
 ui = Main.new()
 root.add_child(ui)
 await settle()
 ui.choosing_character = true
 ui.menu = false
 ui._render()
 await shot("ship-selection")
 expedition("cartographer", 5)
 await shot("overmap")
 for pair in [["cartographer", 0], ["palimpsest", 4], ["hollow_choir", 5]]:
  expedition(pair[0], pair[1])
  var result = ui.game.choose_node(ui.game.run.map[0][0].id)
  if not result.ok:
   push_error(result.error)
   quit(1)
   return
  ui._render()
  for index in range(ui.game.run.battle.hand.size()):
   var card = ui.game.card(ui.game.run.battle.hand[index].id)
   if int(card.get("damage", 0)) > 0:
    ui._select_card(index)
    ui._select_organ(0)
    if pair[0] == "cartographer":
     ui._select_organ(1)
     ui._select_organ(2)
    break
  await shot(pair[0] + "-combat")
 ui.ambience.stop()
 ui.queue_free()
 await process_frame
 quit(0)
