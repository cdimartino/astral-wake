extends SceneTree
## All-screen typography audit; optionally capture native frames to ASTRAL_UI_AUDIT_DIR.
const Main = preload("res://scripts/main.gd")
var ui
var checks := 0
var failures := 0
var output := OS.get_environment("ASTRAL_UI_AUDIT_DIR")

func _initialize() -> void:
 OS.set_environment("ASTRAL_SKIP_INTRO", "1")
 OS.set_environment("ASTRAL_SAVE_DIR", OS.get_environment("TMPDIR") + "astral-type-%d" % Time.get_ticks_usec())
 check.call_deferred()

func require(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)

func settle() -> void:
 for i in range(6): await process_frame

func luminance(color: Color) -> float:
 var linear := color.srgb_to_linear()
 return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722

func contrast(a: Color, b: Color) -> float:
 return (maxf(luminance(a), luminance(b)) + 0.05) / (minf(luminance(a), luminance(b)) + 0.05)

func inspect(screen: String) -> void:
 await settle()
 var owner: Control = ui.overlay if is_instance_valid(ui.overlay) else ui.page
 if is_instance_valid(ui.overlay):
  for card in ui.hand_buttons:
   require(ui.overlay.z_index > card.z_index, "Raised cards obscure modal text")
 for label in owner.find_children("*", "Label", true, false):
  if label.text.is_empty() or not label.is_visible_in_tree(): continue
  var size: int = label.get_theme_font_size("font_size")
  require(size >= 14, screen + ": undersized text: " + label.text)
  if size < 32:
   require(label.get_theme_font("font") != ui.heading_font, screen + ": display font on small text: " + label.text)
  if label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and label.tooltip_text.is_empty():
   require(label.get_visible_line_count() == label.get_line_count(), screen + ": silently hidden lines: " + label.text)
 if not output.is_empty() and DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  var path := output.path_join("%d-%s.png" % [root.size.x, screen])
  require(root.get_texture().get_image().save_png(path) == OK, "Failed to capture " + path)
 print("LEGIBILITY_SCREEN ", root.size, " ", screen)

func fixture() -> void:
 ui.game.new_run(2101, "hollow_choir")
 ui.game.run.route_regions = [5, 4, 0]
 ui.menu = false
 ui.choosing_character = false
 ui._clear_selection()
 ui.game.profile.settings.reduced_motion = true

func check() -> void:
 if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
 ui = Main.new()
 root.add_child(ui)
 await settle()
 # Conservative text contrast: translucent reading plate over pure white.
 var plate := Color.WHITE.blend(Color(0.025, 0.05, 0.08, 0.94))
 for color in [Main.CREAM, Main.MUTED, Main.TEAL, Main.GOLD, Main.CORAL]:
  require(contrast(color, plate) >= 4.5, "Text fails 4.5:1 over the brightest reading-plate background")
 require(contrast(ui.theme.get_color("font_disabled_color", "Button"), Color("122030")) >= 4.5, "Disabled controls are unreadable")
 require(Main.PLAYER_COMBAT_RECT.size.y >= 260, "Ship portrait has shrunk below its restored size")
 for viewport_size in [Vector2i(1440, 900), Vector2i(1100, 720)]:
  root.size = viewport_size
  fixture()
  ui.menu = true
  ui._render()
  await inspect("title")
  ui.choosing_character = true
  ui._render()
  await inspect("ships")
  ui._character_info("hollow_choir")
  await inspect("ship-details")
  ui._close_overlay()
  ui.menu = false
  ui.choosing_character = false
  ui._render()
  await inspect("map")
  ui.game.choose_node(ui.game.run.map[0][0].id)
  ui._render()
  ui._select_card(0)
  ui._select_organ(0)
  await inspect("combat")
  for i in range(4): ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
  ui._render()
  await inspect("combat-crowded")
  for method in ["_open_help", "_open_settings", "_open_deck", "_open_history", "_open_unlocks", "_open_menu"]:
   if method == "_open_history": ui.game.profile.history = [{"seed":1111,"won":true,"region":2,"turns":12,"battles":3,"seconds":125}]
   ui.call(method)
   await inspect(method.trim_prefix("_open_"))
   ui._close_overlay()
  for screen in ["reward", "event", "shop", "recovery", "modify", "transition", "victory", "defeat"]:
   ui._clear_selection()
   ui.game.run.mode = screen
   if screen == "reward": ui.game.run.reward = {"choices":[{"kind":"card","id":"unbroken_song"},{"kind":"card","id":"whole_horizon"},{"kind":"card","id":"afterimage"},{"kind":"powerup","id":ui.game.catalog.powerups[0].id}],"boss":false}
   if screen == "event": ui.game.run.event_id = ui.game.catalog.events[0].id
   if screen == "shop": ui.game._make_shop()
   if screen == "modify": ui.game.run.modify_kind = "upgrade"
   ui._render()
   await inspect(screen)
 print("UI_LEGIBILITY ", checks, " checks, ", failures, " failures")
 ui.ambience.stop()
 ui.audio.stop()
 OS.delay_msec(200)
 ui.queue_free()
 await settle()
 quit(1 if failures else 0)
