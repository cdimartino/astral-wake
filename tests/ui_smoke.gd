extends SceneTree
var ui
var checks=0
var failures=0
var failure_messages={}
func require(condition,message="Check failed"):
 if not condition:
  failures+=1
  if not failure_messages.has(message):
   failure_messages[message]=true
   push_error(message)
func _initialize():
 OS.set_environment("ASTRAL_SKIP_INTRO","1")
 call_deferred("check")
func settle():
 for i in range(5):await process_frame
func full_title(title):
 require(title.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING,"Card title still permits ellipsis: "+title.text)
 require(title.get_line_count()>0 and title.get_line_count()<=2,"Card title exceeds its two-line header: "+title.text)
 require(title.get_visible_line_count()==title.get_line_count(),"Card title hides a shaped line: "+title.text)
 var font=title.get_theme_font("font")
 var font_size=title.get_theme_font_size("font_size")
 for word in title.text.split(" ",false):
  require(font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=title.size.x+0.1,"Card title word exceeds actual width: "+title.text)
func bounds(label):
 var visible=root.get_visible_rect()
 var physical_visible=Rect2(Vector2.ZERO,root.size)
 require(ui.background.get_global_rect().grow(0.1).encloses(visible),"Background leaves part of logical viewport uncovered")
 require((root.get_final_transform()*ui.background.get_global_rect()).grow(0.1).encloses(root.get_final_transform()*visible),"Background fails canvas stretch")
 var buttons=ui.page.find_children("*","Button",true,false)
 for button in buttons:
  var rect=button.get_global_rect()
  if button.get_meta("map_node",false):
   var chart=ui.page.find_child("ExpeditionChart",true,false)
   require(chart.get_global_rect().encloses(rect),"Map destination outside scrollable chart")
   checks+=1
   continue
  require(visible.grow(0.1).encloses(rect),label+" outside logical viewport: "+button.name+" "+str(rect)+" root "+str(visible))
  var physical_rect=root.get_final_transform()*rect
  require(physical_visible.grow(0.1).encloses(physical_rect),label+" outside physical window: "+button.name+" "+str(physical_rect)+" window "+str(physical_visible))
  checks+=1
 for scroll in ui.page.find_children("*","ScrollContainer",true,false):
  require(scroll.name=="StarChartScroll" and not ui.menu and ui.game.run.get("mode","")=="map","Scrolling outside overmap")
  require(scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"Overmap scrolls horizontally")
 for title in ui.page.find_children("*","Label",true,false):
  if title.get_meta("card_title",false):full_title(title)
 var organs=[]
 for button in buttons:
  if button.name.begins_with("Organ"):organs.append(button)
 for i in range(organs.size()):
  for j in range(i+1,organs.size()):
   require(not organs[i].get_global_rect().intersects(organs[j].get_global_rect()),"Organ buttons overlap "+str(organs[i].name)+str(organs[i].get_global_rect())+" / "+str(organs[j].name)+str(organs[j].get_global_rect()))
 for card in ui.hand_buttons:
  var title=card.get_meta("title_label")
  full_title(title)
  require(card.get_global_rect().grow(0.1).encloses(title.get_global_rect()),"Card title outside frame: "+title.text)
  var desc=card.get_meta("description_label")
  require(card.get_global_rect().grow(0.1).encloses(desc.get_global_rect()),"Card description outside card "+str(card.name)+" "+str(desc.get_global_rect())+" card "+str(card.get_global_rect()))
  if card.position.y<672:
   for button in buttons:
    if button.text in ["Confirm [Space]","Undo","Cancel","End turn [E]"]:
     require(not card.get_global_rect().intersects(button.get_global_rect()),"Raised card covers route action")
 require(ui.page.find_child("CardInspection",true,false)==null,"Side inspection overlay should not exist")
 if ui.game.run.get("mode","")=="combat" and not ui.menu:
  var count=ui.game.run.battle.enemies.size()
  require(ui.enemy_art.size()==count and ui.enemy_hulls.size()==count,"Enemy art/bar count does not match living enemies")
  require(ui.player_hull!=null and ui.player_hull.value==ui.game.run.hull and ui.player_hull.max_value==ui.game.run.max_hull,"Player hull bar inaccurate")
  var targets=[]
  for i in range(count):
   var enemy=ui.game.run.battle.enemies[i]
   var target=ui.page.find_child("EnemyTarget%d"%i,true,false)
   for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
    var style=target.get_theme_stylebox(state)
    require(style is StyleBoxFlat and style.bg_color.a==0 and style.border_color.a==0 and style.border_width_left==0 and style.border_width_right==0 and style.border_width_top==0 and style.border_width_bottom==0,"Enemy target box visible in state "+state)
   var image=ui.page.find_child("EnemyArt%d"%i,true,false)
   var bar=ui.page.find_child("EnemyHullBar%d"%i,true,false)
   var intent=ui.page.find_child("EnemyIntent%d"%i,true,false)
   var name=ui.page.find_child("EnemyName%d"%i,true,false)
   var hull_text=ui.page.find_child("EnemyHullText%d"%i,true,false)
   require(name.get_theme_font("font")==ui.title_font,"Enemy name must use the readable semibold title font")
   full_title(name)
   require(image.get_global_rect().end.y<=name.get_global_rect().position.y+0.1,"Enemy name is not below its artwork")
   require(name.get_global_rect().end.y<=hull_text.get_global_rect().position.y+0.1,"Enemy hull value is not below its name")
   require(hull_text.get_global_rect().end.y<=bar.get_global_rect().position.y+0.1,"Enemy hull bar is not below its hull value")
   require(image!=null and image.texture!=null and image.is_visible_in_tree() and image.size.x>40 and image.size.y>40,"Enemy art is absent or hidden behind target tabs")
   require(bar!=null and bar.value==enemy.hp and bar.max_value==enemy.max_hp and bar.size.y>=8,"Enemy hull bar inaccurate")
   require(intent is Button and not intent.explanation.is_empty() and intent.get_child_count()>=2,"Enemy intent icon, amount or rich explanation absent")
   for control in [image,name,hull_text,bar,intent]:require(target.get_global_rect().grow(0.1).encloses(control.get_global_rect()),"Enemy presentation outside its target")
   for other in targets:require(not target.get_global_rect().intersects(other.get_global_rect()),"Enemy targets overlap")
   targets.append(target)
 var hints=ui.page.find_child("ShortcutHints",true,false)
 if hints!=null:
  for card in ui.hand_buttons:
   require(not card.get_global_rect().intersects(hints.get_global_rect()),"Hand covers shortcut text "+str(card.get_global_rect())+" hints "+str(hints.get_global_rect()))
   for control in buttons:
    if control.name.begins_with("Organ") or control.text in ["Confirm [Space]","Undo","Cancel","End turn [E]"]:
     require(not card.get_global_rect().intersects(control.get_global_rect()),"Card covers gameplay control")
   require(card.size.is_equal_approx(Vector2(160,210)) or card.size.is_equal_approx(Vector2(200,250)),"Card not using requested hover sizes "+str(card.size)+" "+str(card.name))
   var description=card.get_meta("description_label")
   require(description.size.y>5 and description.get_visible_line_count()>0,"Card effect text collapsed")
 if label not in ["upgraded card hover","card titles resting","card titles hovering"]:print("GEOMETRY ",label," buttons=",buttons.size()," physical=",root.size," logical=",root.get_visible_rect().size)
func check():
 ui=load("res://scripts/main.gd").new()
 root.add_child(ui)
 await settle()
 require(ui.ship_atlas!=null,"Ship art missing")
 require(ui.theme.default_font.get_font_name().contains("Avenir"),"Body typography fell back from intended installed family")
 if ResourceLoader.exists("res://art/fonts/AstralWake-Display.ttf"):
  require(ui.heading_font.resource_path=="res://art/fonts/AstralWake-Display.ttf","Original display typography is not selected")
 else:require(ui.heading_font.get_font_name().contains("DIN"),"Heading typography fell back from intended installed family")
 print("FONTS body=",ui.theme.default_font.get_font_name()," heading=",ui.heading_font.get_font_name())
 require(ui.card_atlas!=null or ui.hd_card_regions.size()==36,"Original card art missing")
 if ResourceLoader.exists("res://art/ships_hd/player.png"):
  var player=ui._art(0,300)
  require(player.texture==ui.player_hd and player.texture.get_width()>=1024,"Player does not use native HD art")
  player.free()
 var art_regions=[]
 for definition in ui.game.catalog.cards:
  var image=ui._card_art({"id":definition.id,"level":0},105)
  var region=image.texture.region
  require(image.texture.filter_clip,"Atlas filtering can bleed adjacent illustrations")
  var identity=str(image.texture.atlas.resource_path)+str(region)
  if definition.get("introduced_revision",0)==0:
   require(not art_regions.has(identity),"Duplicate original card illustration crop")
  require(Rect2(0,0,image.texture.atlas.get_width(),image.texture.atlas.get_height()).encloses(region),"Card illustration crop outside atlas")
  if definition.get("introduced_revision",0)==0: art_regions.append(identity)
  image.free()
 require(art_regions.size()==72,"All original 72 illustration identities remain unique; expansion shared art is NOT distinct art acceptance")

 for pair in [["res://art/ships_hd/manifest.json","ships",ui.hd_ship_regions,700],["res://art/cards_hd/manifest.json","cards",ui.hd_card_regions,600]]:
  if FileAccess.file_exists(pair[0]):
   var declared=JSON.parse_string(FileAccess.get_file_as_string(pair[0]))[pair[1]]
   require(pair[2].size()==declared.size(),"Declared HD art did not load: "+pair[0])
   for region in pair[2].values():
    require(minf(region.region.size.x,region.region.size.y)>=pair[3],"HD crop lacks native source resolution")
    require(region.filter_clip,"HD crop may bleed neighboring art")
   print("HD_ART ",pair[1],"=",pair[2].size()," declared=",declared.size())
 require(ui.expansion_characters.size()==2,"Expansion ship art incomplete")
 require(ui.expansion_regions.size()==3,"Expansion region art incomplete")
 for definition in ui.game.catalog.cards:
  if definition.get("character","cartographer")!="cartographer":
   require(ui.expansion_cards.has(definition.id),"Missing original expansion command artwork: "+str(definition.id))
 for definition in ui.game.catalog.enemies:
  if int(definition.art)>=20:
   require(ui.expansion_enemies.has(definition.id),"Missing original expansion enemy artwork: "+str(definition.id))
 for texture in ui.expansion_cards.values():require(minf(texture.region.size.x,texture.region.size.y)>=600,"Expansion command artwork lacks native detail")
 for texture in ui.expansion_enemies.values():require(minf(texture.region.size.x,texture.region.size.y)>=700,"Expansion enemy artwork lacks native detail")
 require(ui.tracks.size()==ui.game.catalog.regions.size(),"Region music missing")
 for track in ui.tracks.values():
  require(track.loop_end==maxi(0,roundi(track.get_length()*track.mix_rate)-1),"Loop length uses compressed bytes")
  require(absf(track.loop_end/float(track.mix_rate)-track.get_length())<=1.01/track.mix_rate,"Loop truncates soundtrack")
  print("MUSIC_LOOP format=",track.format," length=",track.get_length()," loop_end=",track.loop_end)
 var player_id=ui.ambience.get_instance_id()
 await create_timer(0.15).timeout
 var playback=ui.ambience.get_playback_position()
 ui._render()
 await settle()
 require(ui.ambience.get_instance_id()==player_id,"Rerender replaced music player")
 require(ui.ambience.get_playback_position()>=playback-0.03,"Rerender restarted soundtrack")
 for viewport_size in [Vector2i(1440,900),Vector2i(1100,720)]:
  root.size=viewport_size
  await settle()
  ui.menu=true
  ui._render()
  await settle()
  bounds("title")
  ui.game.new_run(1001)
  ui.menu=false
  ui._render()
  await settle()
  bounds("map")
  var chart=ui.page.find_child("ExpeditionChart",true,false)
  require(chart.get_global_rect().end.x<=root.get_visible_rect().end.x)
  var star_scroll=ui.page.find_child("StarChartScroll",true,false)
  for i in range(ui.game.run.map[0].size()):
   require(star_scroll.get_global_rect().encloses(ui.page.find_child("Destination%d"%i,true,false).get_global_rect()),"Opening choices not visible")
  var destinations=chart.find_children("Destination*","Button",true,false)
  require(destinations.size()==ui.game.run.map.reduce(func(total,layer):return total+layer.size(),0),"Map omits destinations")
  destinations[-1].grab_focus()
  await settle()
  require(star_scroll.get_global_rect().grow(1).encloses(destinations[-1].get_global_rect()),"Keyboard does not scroll to later destinations")
  star_scroll.scroll_vertical=0
  ui.game.choose_node(ui.game.run.map[0][0].id)
  ui._render()
  await settle()
  bounds("combat unselected")
  require(ui.page.find_child("CommandPoints",true,false)!=null,"Command point HUD missing")
  ui.game.run.battle.command_points=0
  ui._render()
  await settle()
  for card in ui.hand_buttons:require(card.disabled,"Unaffordable card enabled")
  ui.hand_buttons[0].emit_signal("mouse_entered")
  await settle()
  require(ui.hand_buttons[0].size.is_equal_approx(Vector2(200,250)),"Unaffordable card did not enlarge on hover")
  ui.hand_buttons[0].grab_focus()
  await settle()
  require(root.gui_get_focus_owner()==ui.hand_buttons[0],"Unaffordable keyboard inspection missing")
  require(ui.hand_buttons[0].find_next_valid_focus()==ui.hand_buttons[1],"Tab skips unaffordable cards")
  ui._select_card(0)
  require(ui.selected_card==-1 and ui.game.run.battle.command_points==0,"Unaffordable hotkey changed selection or points")
  ui.game.run.battle.command_points=3
  ui._render()
  await settle()
  ui._select_card(0)
  ui._select_organ(0)
  ui._select_organ(1)
  ui._select_organ(2)
  await settle()
  require(ui.game.preview_card(0,ui.route,0).ok)
  bounds("combat selected3")
  var before=ui.game.run.battle.hand.size()
  ui.route.clear()
  ui.route.append_array([0,2])
  ui._confirm()
  await settle()
  require(ui.game.run.battle.hand.size()==before)
  ui._clear_selection()
  while ui.game.run.battle.hand.size()<10:ui.game.run.battle.hand.append(ui.game.run.deck[0].duplicate())
  for i in range(4):ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
  ui._render()
  await settle()
  bounds("combat ten cards five enemies")
  var full_enemies=ui.game.run.battle.enemies.duplicate(true)
  for enemy_count in [2,3,4]:
   ui.game.run.battle.enemies=full_enemies.slice(0,enemy_count)
   ui._render()
   await settle()
   bounds("combat %d simultaneous enemies"%enemy_count)
  ui.game.run.battle.enemies=full_enemies
  ui._render()
  await settle()
  for i in range(10):
   ui.hover_card=i
   ui._arrange_hand()
   await settle()
   bounds("hand hover%d"%i)
  for level in [0,1]:
   for offset in range(0,ui.game.catalog.cards.size(),5):
    ui.game.run.battle.hand.clear()
    for i in range(offset,mini(offset+5,ui.game.catalog.cards.size())):
     ui.game.run.battle.hand.append({"id":ui.game.catalog.cards[i].id,"uid":i+100,"level":level})
    ui._render()
    await settle()
    bounds("card titles resting")
    for i in range(ui.hand_buttons.size()):
     ui.hover_card=i
     ui._arrange_hand()
     await settle()
     bounds("card titles hovering")
  for offset in range(0,ui.game.catalog.enemies.size(),5):
   ui.game.run.battle.enemies.clear()
   for i in range(offset,mini(offset+5,ui.game.catalog.enemies.size())):
    ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
   ui._render()
   await settle()
   bounds("full enemy names")
  ui.game.profile.settings.reduced_motion=true
  ui._sync_motion()
  for image in ui.page.find_children("*","TextureRect",true,false):
   if image.has_meta("idle_tween"):
    require(not image.get_meta("idle_tween").is_running(),"Reduced motion left idle tween running")
  ui.game.profile.settings.reduced_motion=false
  ui._sync_motion()
  for screen in ["reward","event","shop","recovery","modify","transition","victory","defeat"]:
   ui._clear_selection()
   ui.game.run.mode=screen
   if screen=="reward":ui.game.run.reward={"choices":[{"kind":"card","id":"unbroken_song"},{"kind":"card","id":"whole_horizon"},{"kind":"card","id":"afterimage"},{"kind":"powerup","id":ui.game.catalog.powerups[0].id}],"boss":false}
   if screen=="event":ui.game.run.event_id=ui.game.catalog.events[0].id
   if screen=="shop":ui.game._make_shop()
   if screen=="modify":
    ui.game.run.modify_kind="upgrade"
    ui.game.run.deck.clear()
    for card in ui.game.catalog.cards:ui.game.run.deck.append({"id":card.id,"uid":ui.game.run.deck.size()+1,"level":1})
    ui.modify_page=5
   ui._render()
   await settle()
   bounds(screen)
  for mode in ["reward","shop","modify"]:
   var batch=4 if mode=="reward" else 6
   for offset in range(0,ui.game.catalog.cards.size(),batch):
    ui.game.run.mode=mode
    if mode=="reward":
     ui.game.run.reward={"choices":[],"boss":false}
     for i in range(offset,mini(offset+batch,ui.game.catalog.cards.size())):ui.game.run.reward.choices.append({"kind":"card","id":ui.game.catalog.cards[i].id})
    elif mode=="shop":
     ui.game.run.shop={"items":[]}
     for i in range(offset,mini(offset+batch,ui.game.catalog.cards.size())):ui.game.run.shop.items.append({"kind":"card","id":ui.game.catalog.cards[i].id,"cost":35,"sold":false})
    else:
     ui.game.run.modify_kind="upgrade"
     ui.modify_page=offset/6
    ui._render()
    await settle()
    bounds("all-card "+mode+" titles")
  for level in [0,1]:
   ui.game.run.deck.clear()
   for card in ui.game.catalog.cards:ui.game.run.deck.append({"id":card.id,"uid":ui.game.run.deck.size()+1,"level":level})
   ui._open_deck()
   await settle()
   for title in ui.overlay.find_children("*","Label",true,false):
    if title.get_meta("card_title",false):full_title(title)
   ui._close_overlay()
  for method in ["_open_help","_open_settings","_open_deck","_open_history","_open_unlocks","_open_menu"]:
   ui.call(method)
   await settle()
   require(ui.page.focus_behavior_recursive==Control.FOCUS_BEHAVIOR_DISABLED)
   var focused=root.gui_get_focus_owner()
   for i in range(30):
    focused=focused.find_next_valid_focus()
    require(ui.overlay.is_ancestor_of(focused),"Focus escaped modal")
   ui._close_overlay()
  ui.game.profile.history=[{"seed":1111,"won":true,"region":2,"turns":12,"battles":3,"seconds":125},{"seed":2222,"won":false,"region":0,"turns":1,"battles":0,"seconds":20}]
  ui._open_history()
  await settle()
  var found=[]
  for label in ui.overlay.find_children("*","Label",true,false):
   if "Seed " in label.text:found.append(label.text)
  require(found==["Victory  ·  Seed 1111","Defeat  ·  Seed 2222"])
  ui._close_overlay()
 print("UI_FAILURE_COUNT ",failures)
 print("UI_GEOMETRY_PASS " if failures==0 else "UI_GEOMETRY_FAIL ",checks," button bounds, all screens, both sizes, overmap-only vertical scrolling, small cards+actual hover enlargement, no text/controls covered, disabled hover+keyboard inspection, command points, atlas crops, modal focus, history, invalid route")
 ui.ambience.stop()
 ui.audio.stop()
 OS.delay_msec(200)
 ui.queue_free()
 await settle()
 quit(0 if failures==0 else 1)
