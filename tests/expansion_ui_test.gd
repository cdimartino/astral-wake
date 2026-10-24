extends SceneTree
var ui
var checks := 0
var failures := 0
func require(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)
func _initialize() -> void:
 OS.set_environment("ASTRAL_SKIP_INTRO","1")
 OS.set_environment("ASTRAL_SAVE_DIR","/tmp/astral-expansion-ui-%d" % Time.get_ticks_usec())
 check.call_deferred()
func settle() -> void:
 for i in range(5): await process_frame
func on_stage(control: Control) -> bool:
 return root.get_visible_rect().grow(0.1).encloses(control.get_global_rect())
func check() -> void:
 ui=load("res://scripts/main.gd").new()
 root.add_child(ui)
 await settle()
 require(ui.opening_film==null,"Headless tests should suppress intro")
 require(ui.game.catalog.characters.size()==3,"Ship selection needs all three definitions")
 require(ui.map_icons.size()==6,"Each destination kind needs an original vector icon")
 for viewport_size in [Vector2i(1440,900),Vector2i(1100,720)]:
  root.size=viewport_size
  await settle()
  ui.game.new_run(2101)
  var original=JSON.stringify(ui.game.run)
  ui._request_new()
  await settle()
  require(JSON.stringify(ui.game.run)==original,"Opening selection replaced active mission")
  var selection_text=[]
  for label in ui.page.find_children("*","Label",true,false):selection_text.append(label.text)
  require(selection_text.has("Select your ship"),"Ship selection lacks its simple prompt")
  for character in ui.game.catalog.characters:
   require(not selection_text.has(character.description),"Ship selection still displays mechanics paragraphs")
  for button in ui.page.find_children("*","Button",true,false):require(on_stage(button),"Ship selection control outside stage")
  for i in range(3):
   var choice=ui.page.find_child("CharacterChoice%d"%i,true,false)
   require(choice!=null and on_stage(choice),"Ship choice missing or outside stage")
   var portraits=choice.find_children("*","TextureRect",true,false)
   require(portraits.size()==1 and portraits[0].size.y>=400,"Freed space is not used for larger portraits")
   require(ui.page.find_child("CharacterDetails%d"%i,true,false).text=="Details","Optional ship information missing")
   choice.pressed.emit()
   await settle()
   require(ui.selected_character==ui.game.catalog.characters[i].id,"Selection chose wrong ship")
   require(JSON.stringify(ui.game.run)==original,"Ship inspection mutated active mission")
   ui._character_info(ui.selected_character)
   await settle()
   var titles=0
   for label in ui.overlay.find_children("*","Label",true,false):
    if label.get_meta("card_title",false):
     titles+=1
     require(label.get_visible_line_count()==label.get_line_count() and label.get_line_count()<=2,"Starter title is truncated")
   require(titles==10,"Starting deck inspector is incomplete")
   ui._close_overlay()
  ui._begin_character_run()
  await settle()
  require(ui.overlay!=null and JSON.stringify(ui.game.run)==original,"Replacing mission lacks confirmation")
  ui._close_overlay()
  for character in ui.game.catalog.characters:
   ui.selected_character=character.id
   ui._new_run()
   await settle()
   require(ui.game.run.character==character.id and not ui.menu and not ui.choosing_character,"Start did not use selected character")
   require(ui.game.choose_node(ui.game.run.map[0][0].id).ok,"Opening battle failed")
   ui._render()
   await settle()
   var image=ui.page.find_child("PlayerShip",true,false)
   require(image!=null and on_stage(image),"Player ship absent")
   var expected=ui.player_hd if character.id=="cartographer" else ui.expansion_characters.get(character.id)
   require(image.texture==expected,"Character uses another ship's artwork")
   var resource=ui.page.find_child("CharacterResource",true,false)
   if character.id=="cartographer":require(resource==null,"Cartographer displays another character's resource")
   else:
    require(resource!=null and on_stage(resource) and resource.get_visible_line_count()>0,"Character resource HUD absent")
    var kind="trace" if character.id=="palimpsest" else "resonance"
    require(resource.text.begins_with(kind.to_upper()+" 0 /"),"Character resource HUD shows wrong value")
    var before=ui.game.run.duplicate(true)
    var cues=ui._feedback_plan(before,{"presentation":[{"kind":kind,"before":0,"after":2,"amount":2}]},"command",[],0,{})
    require(cues.size()==1 and cues[0].label==kind.to_upper()+" 0 → 2","Resource changes lack visible actual-value feedback")
    ui._select_card(0)
    ui._select_organ(0)
    ui._confirm()
    while ui.presentation_busy():await process_frame
    await settle()
    require(ui.game.run.battle[kind]>0,"Actual starting command did not generate its character resource")
    resource=ui.page.find_child("CharacterResource",true,false)
    require(resource.text.begins_with(kind.to_upper()+" %d /"%ui.game.run.battle[kind]),"Committed command did not update its resource HUD")
   for button in ui.page.find_children("*","Button",true,false):require(on_stage(button),"Combat control outside stage: "+str(button.name))
   var organs=ui.page.find_children("Organ*","Button",true,false)
   require(organs.size()==6,"Character circuit must show six organs")
   for i in range(organs.size()):
    var font=organs[i].get_theme_font("font")
    for line in organs[i].text.split("\n"):
     require(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=organs[i].size.x-12,"Organ text overflows: "+line)
    for j in range(i+1,organs.size()):require(not organs[i].get_global_rect().intersects(organs[j].get_global_rect()),"Character organ buttons overlap")
   require(ui.page.find_children("*","ScrollContainer",true,false).is_empty(),"Combat must stay scroll-free")
  for index in range(ui.game.catalog.regions.size()):
   ui.game.new_run(2102)
   ui.game.run.route_regions=[index,(index+1)%6,(index+2)%6]
   ui._render()
   await settle()
   require(ui._area_index()==index,"Geography confused mission depth with area registry")
   require(ui.music_region==index and ui.ambience.stream==ui.tracks[index],"Wrong soundtrack for selected area")
   var region_id=str(ui.game.catalog.regions[index].id)
   var expected=ui.expansion_regions.get(region_id,ui.region_textures[index])
   require(ui.background.texture==expected,"Wrong background for area")
   var scroll=ui.page.find_child("StarChartScroll",true,false)
   var chart=ui.page.find_child("ExpeditionChart",true,false)
   require(scroll!=null and on_stage(scroll),"Map scroll surface absent")
   require(root.gui_get_focus_owner().get_meta("reachable_destination",false),"Map does not focus a reachable next choice")
   var nodes=chart.find_children("Destination*","Button",true,false)
   var last=nodes[-1]
   var before=JSON.stringify(ui.game.run)
   last.pressed.emit()
   await settle()
   require(JSON.stringify(ui.game.run)==before,"Inspecting unreachable destination traveled")
   last.grab_focus()
   await settle()
   require(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()),"Keyboard failed to reveal boss")
   ui.game.run.layer=9
   ui._render()
   await settle()
   scroll=ui.page.find_child("StarChartScroll",true,false)
   require(scroll.scroll_vertical>=1400,"Map did not return to mission progress")
 print("EXPANSION_UI ",checks," checks, ",failures," failures")
 ui.ambience.stop()
 ui.audio.stop()
 OS.delay_msec(200)
 ui.queue_free()
 await settle()
 quit(1 if failures else 0)
