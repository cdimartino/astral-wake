extends SceneTree
const Main = preload("res://scripts/main.gd")
const Game = preload("res://scripts/game.gd")
var ui
var failures := 0
var checks := 0
func _initialize() -> void:
 OS.set_environment("ASTRAL_SKIP_INTRO","1")
 call_deferred("check")
func require(condition: bool, message: String) -> void:
 checks+=1
 if not condition:
  failures+=1
  push_error(message)
func settle() -> void:
 for i in range(5): await process_frame
func capture(name: String) -> void:
 var output=OS.get_environment("ASTRAL_PRESENTATION_CAPTURE")
 if output.is_empty() or DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(output)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func finish() -> void:
 var started=Time.get_ticks_msec()
 while ui.presentation_busy():
  if Time.get_ticks_msec()-started>10000:
   require(false,"Presentation never finished")
   ui._render()
   break
  await process_frame
 await settle()
func fixture(count: int, card_id: String, reduced: bool=false) -> void:
 ui.game.new_run(7163)
 ui.game.choose_node(ui.game.run.map[0][0].id)
 ui.game.run.hull=40
 ui.game.run.tutorial_step=4
 ui.game.profile.settings.reduced_motion=reduced
 ui.game.run.battle.enemies.clear()
 for i in range(count):ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
 ui.game.run.battle.hand=[{"id":card_id,"uid":900,"level":0}]
 ui.game.run.battle.strain=[0,0,0,0,0,0]
 ui.menu=false
 ui._render()
func play(organs: Array, enemy: int=0) -> Dictionary:
 ui._select_card(0)
 ui._select_target(enemy)
 for organ in organs:ui._select_organ(organ)
 var expected=ui.game.preview_card(ui.selected_card,ui.route,ui.target)
 require(expected.ok,"Presentation fixture route should be legal")
 ui._confirm()
 return expected
func cues(kind: String) -> Array:
 return ui.last_feedback.filter(func(cue):return cue.kind==kind)
func check() -> void:
 ui=Main.new()
 ui.game=Game.new("/tmp/astral-wake-presentation-test")
 root.add_child(ui)
 root.size=Vector2i(1440,900)
 await settle()
 # Duplicate enemy definitions make index-shift mistakes observable.
 require(ui.combat_voices.size()==12 and ui.sounds.has("combat_beam_launch") and ui.sounds.has("combat_repair"),"Combat sound bank and overlapping voices must load")
 ui._combat_sound({"kind":"shot","style":"plasma"},true)
 ui._combat_sound({"kind":"shield"})
 require(ui.combat_voices.filter(func(voice):return voice.playing).size()==2,"Support sounds must not cut off attack launches")
 var voices_before=ui.combat_voice_cursor
 ui._combat_sound({"kind":"shield"})
 require(ui.combat_voice_cursor==voices_before,"Simultaneous identical cues must not multiply volume")
 for voice in ui.combat_voices:voice.stop()
 ui.combat_sound_times.clear()
 fixture(5,"needle")
 ui.game.run.battle.enemies[0].intent={"kind":"sever","amount":2,"label":"Cut two links"}
 ui.game.run.battle.enemies[1].intent={"kind":"attack","amount":12,"label":"Strike"}
 ui.game.run.battle.enemies[1].disrupt=3
 ui._render()
 await settle()
 var badge=ui.page.find_child("EnemyIntent0",true,false)
 require(badge is Button and badge.explanation.contains("2 open connection"),"Multi-link sever must have an accurate rich icon explanation")
 var attack_badge=ui.page.find_child("EnemyIntent1",true,false)
 require(attack_badge.explanation.contains("9 incoming damage") and attack_badge.explanation.contains("Ward absorbs"),"Attack badge must distinguish defense preview from shared ward")
 badge.grab_focus()
 await settle()
 require(is_instance_valid(badge.focus_tip),"Keyboard focus must reveal rich intent details")
 await capture("intent-details")
 var rich_tip=badge._make_custom_tooltip("")
 require(rich_tip.get_child(0) is RichTextLabel and rich_tip.get_child(0).bbcode_enabled,"Hover explanation must render rich text")
 rich_tip.free()
 var styles=[]
 for id in ["needle","sun_splinter","winter_needle","choral_bolt","margin_knife"]:
  var style=ui._attack_style(ui.game.card(id))
  require(not styles.has(style),"Attack families need distinct visual signatures")
  styles.append(style)
 for style in styles:
  var effect=Main.SpaceCanvas.new()
  effect.stars=false
  effect.effect_kind="shot"
  effect.effect_style=style
  effect.effect_from=Vector2(410,350)
  effect.effect_to=Vector2(1100,350)
  effect.effect_color=ui._style_color(style)
  ui._at(effect,Rect2(0,0,1440,900))
  for progress in [0.25,0.75]:
   effect.effect_progress=progress
   await settle()
  await capture("impact-"+style)
  effect.queue_free()
 fixture(2,"needle")
 ui.game.run.battle.enemies[1]=ui.game._make_enemy(ui.game.run.battle.enemies[0].id)
 ui.game.run.battle.enemies[0].hp=5
 ui._render()
 await settle()
 var peer_hp=ui.game.run.battle.enemies[1].hp
 var expected=play([0])
 var first_actor=ui.enemy_art[0]
 var second_actor=ui.enemy_art[1]
 require(ui.presentation_busy(),"Resolution should hold the preaction scene")
 require(ui.game.run.battle.enemies.size()==1 and ui.enemy_art.size()==2,"Removed actor was not retained through its hit")
 require(cues("beam").size()==1 and cues("beam")[0].hp_delta==-5,"Damage cue must use actual capped damage")
 require(ui.enemy_hulls[0].value==5,"HP changed before projectile impact")
 require(ui.combat_voices.any(func(voice):return voice.playing and voice.stream==ui.sounds.combat_beam_launch),"Lens launch must use its beam sound")
 await create_timer(0.18).timeout
 require(ui.enemy_hulls[0].value==5,"Damage number/bar appeared at launch")
 await create_timer(0.22).timeout
 require(ui.enemy_hulls[0].value==0 and ui.enemy_hulls[1].value==peer_hp,"Impact changed the wrong duplicate enemy")
 require(ui.combat_voices.any(func(voice):return voice.playing and voice.stream==ui.sounds.combat_beam_hit),"Impact sound must arrive with the visible hit")
 require(first_actor.modulate.a<1 and second_actor.self_modulate==Color.WHITE,"Removed-target flash/fade affected its shifted peer")
 var damage_label=ui.page.find_child("DamagePoints",true,false)
 require(damage_label!=null and damage_label.get_theme_font_size("font_size")>=36 and damage_label.get_theme_constant("outline_size")>=4,"Damage points need a large outlined font")
 await create_timer(1.4).timeout
 require(is_instance_valid(damage_label) and ui.presentation_busy(),"Damage points disappear before a readable two-second lifetime")
 await finish()
 require(ui.enemy_art.size()==1 and ui.enemy_hulls[0].value==peer_hp,"Resolved enemy layout did not update")
 # The final blow is visible before reward presentation.
 fixture(1,"needle")
 ui.game.run.battle.enemies[0].hp=5
 ui._render()
 await settle()
 play([0])
 require(ui.game.run.mode=="reward" and ui.page.find_child("EnemyArt0",true,false)!=null,"Rewards replaced the final kill before effects")
 await finish()
 require(ui.page.find_child("EnemyArt0",true,false)==null,"Reward scene did not appear after final hit")
 fixture(2,"hull_stitch")
 await settle()
 expected=play([3])
 require(cues("repair").size()==1 and cues("repair")[0].hp_delta==expected.heal,"Repair particles do not match actual hull gain")
 await finish()
 require(ui.player_hull.value==ui.game.run.hull,"Player hull bar failed to resolve repair")
 fixture(3,"needle")
 await settle()
 expected=play([1,4,5])
 require(cues("shot").size()==3,"Fork should visibly hit every actual damaged enemy")
 require(cues("disrupt").size()==1 and cues("shield").size()==1,"Hush/Prism effects should be distinct")
 await finish()
 var forecast=ui.game.enemy_attack_preview(0)
 require(ui._intent_text(ui.game.run.battle.enemies[0],0).contains("%d damage"%forecast.damage),"Intent differs from authoritative defense preview")
 fixture(2,"cold_breath")
 ui.game.run.battle.strain=[2,2,2,2,2,2]
 ui._render()
 await settle()
 expected=play([5])
 require(cues("vent").size()==6,"Cooling must visibly affect each actually cooled organ")
 require(cues("strain").size()==1,"Routing strain must remain separate from cooling")
 await finish()
 fixture(3,"needle")
 ui.game.run.battle.enemies[2].intent={"kind":"attack","amount":8,"label":"Test strike · 8 damage"}
 ui.game.run.battle.ward=4
 ui._render()
 await settle()
 ui._end_turn()
 var attacks=cues("enemy_shot")
 require(cues("phase").size()==1 and cues("ready").size()==1 and cues("charge").size()==3,"Round resolution needs a phase sweep, actor signals and command refill")
 require(attacks.size()==3,"Real enemy attacks should appear separately")
 require(attacks[0].delay<attacks[1].delay,"Enemy attacks are not visibly sequential")
 require(ui.player_hull.value==40,"Enemy impact changed hull before travel")
 await create_timer(0.38).timeout
 require(ui.player_hull.value<40 and ui.presentation_busy(),"First enemy impact did not update its hull bar during resolution")
 await create_timer(0.72).timeout
 var lanes=[]
 for label in ui.page.find_children("*","Label",true,false):
  if label.get_meta("damage_points",false):lanes.append(label.get_meta("feedback_lane"))
 require(lanes.size()==3 and lanes[0]!=lanes[1] and lanes[1]!=lanes[2] and lanes[0]!=lanes[2],"Repeated damage points must remain visible in separate lanes")
 await finish()
 require(ui.player_hull.value==ui.game.run.hull,"Enemy-phase hull bar does not match committed game state")
 fixture(2,"needle")
 ui.game.run.hull=1
 ui.game.run.powerups.append("buried_dawn")
 ui.game.run.battle.mark=5
 ui.game.run.battle.last_route=[0]
 ui._render()
 await settle()
 play([0])
 await create_timer(0.5).timeout
 require(ui.game.run.hull>0 and ui.player_hull.value==ui.game.run.hull,"Emergency repair not reflected during resolution")
 require(ui.player_art.modulate.a>0.9,"Emergency resurrection leaves player invisible")
 await finish()
 fixture(2,"hull_stitch",true)
 await settle()
 play([3])
 await settle()
 var animated=0
 for node in ui.page.get_children():
  if node.get_script()==Main.SpaceCanvas and not node.effect_kind.is_empty():animated+=1
 require(animated==0 and ui.last_feedback.size()>0,"Reduced motion must retain feedback without animated particles")
 await finish()
 ui.ambience.stop()
 ui.audio.stop()
 # Fixed-FPS scene time can outrun the real audio mixer during teardown.
 OS.delay_msec(200)
 await create_timer(0.15).timeout
 ui.queue_free()
 await settle()
 print("COMBAT_PRESENTATION_TESTS ",checks," checks ",failures," failures")
 quit(0 if failures==0 else 1)
