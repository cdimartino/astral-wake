extends SceneTree
# Presentation fixture only; this is not a measured expedition or a player save.
const Main = preload("res://scripts/main.gd")
const Game = preload("res://scripts/game.gd")
var ui
func _initialize() -> void:
 OS.set_environment("ASTRAL_SKIP_INTRO","1")
 call_deferred("showcase")
func wait(seconds: float) -> void:
 await create_timer(seconds).timeout
func fixture(count: int) -> void:
 ui.game.new_run(98213 + count)
 ui.game.choose_node(ui.game.run.map[0][0].id)
 ui.game.run.hull=45
 ui.game.run.tutorial_step=4
 ui.game.run.battle.ward=4
 ui.game.run.battle.enemies.clear()
 for i in range(count):
  ui.game.run.battle.enemies.append(ui.game._make_enemy(ui.game.catalog.enemies[i].id))
 ui.game.run.battle.strain=[1,1,1,1,1,1]
 hand(["needle","hull_stitch","quiet_pulse","cold_breath"])
 ui.menu=false
 ui._render()
 var caption=ui._screen_text("PRESENTATION SHOWCASE  ·  ISOLATED DEMO FIXTURE",Rect2(45,134,1350,28),18,Color("e7c381"))
 caption.name="DemoCaption"
func hand(ids: Array) -> void:
 ui.game.run.battle.hand.clear()
 for id in ids:
  ui.game.run.battle.hand.append({"id":id,"uid":int(ui.game.run.next_uid),"level":0})
  ui.game.run.next_uid+=1
func play(id: String, organs: Array, enemy_index: int=0) -> void:
 var index=-1
 for i in range(ui.game.run.battle.hand.size()):
  if ui.game.run.battle.hand[i].id==id:
   index=i
   break
 assert(index>=0,"Showcase command missing: "+id)
 ui._select_card(index)
 ui._select_target(enemy_index)
 var chosen=organs
 var preview=ui.game.preview_card(index,chosen,enemy_index)
 if not preview.ok:
  for organ in range(6):
   var alternative=ui.game.preview_card(index,[organ],enemy_index)
   if alternative.ok:
    chosen=[organ]
    preview=alternative
    break
 assert(preview.ok,"Showcase route invalid: "+str(preview.error))
 for organ in chosen:ui._select_organ(organ)
 ui._confirm()
 print("SHOWCASE actual command: ",id," route=",chosen," effects=",ui.last_feedback.size())
func showcase() -> void:
 ui=Main.new()
 ui.game=Game.new("/tmp/astral-wake-presentation-showcase")
 root.add_child(ui)
 root.size=Vector2i(1440,900)
 await process_frame
 fixture(5)
 await wait(3.0)
 play("needle",[0,1,2])
 await wait(3.5)
 play("hull_stitch",[3])
 await wait(3.5)
 play("quiet_pulse",[4],1)
 await wait(3.5)
 ui._end_turn()
 await wait(4.0)
 hand(["cold_breath","needle","hull_stitch"])
 ui._render()
 play("cold_breath",[5])
 await wait(3.5)
 play("needle",[0,1,2])
 await wait(3.5)
 ui._end_turn()
 await wait(4.0)
 fixture(3)
 await wait(3.0)
 play("needle",[1,4,5])
 await wait(3.5)
 play("hull_stitch",[3])
 await wait(3.0)
 ui._end_turn()
 await wait(4.0)
 print("SHOWCASE_COMPLETE: actual damage, repair, disruption, cooling and enemy-phase actions; fixture, not full run")
 await wait(2.0)
 ui.ambience.stop()
 ui.audio.stop()
 await wait(0.15)
 ui.queue_free()
 await process_frame
 quit()
