extends SceneTree
const Game=preload("res://scripts/game.gd")
var checks=0
var failures=0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+message)

func fixture():
	var game=Game.new(OS.get_environment("ASTRAL_SAVE_DIR")+"/balance-"+str(Time.get_ticks_usec()) if not OS.get_environment("ASTRAL_SAVE_DIR").is_empty() else "user://balance-"+str(Time.get_ticks_usec()))
	game.new_run(424242)
	game.choose_node(game.run.map[0][0].id)
	return game

func _initialize() -> void:
	var game=fixture()
	for area in range(3):
		game.run.region=area
		for definition in game.catalog.enemies:
			for turn in range(1,definition.pattern.size()+1):
				var intent=game._intent_for(definition.id,turn)
				if intent.kind!="attack": continue
				var later=game._intent_for(definition.id,turn+definition.pattern.size()*4)
				check(later.amount>intent.amount,"prolonged fights escalate in every area")
				check(later.label.ends_with("%d damage"%later.amount),"escalation is visible in the intent")
	game.run.region=0
	game.run.hull=12
	game.run.battle.enemies=[game._make_enemy("lantern_eel")]
	game.run.battle.enemies[0].hp=999
	game.run.battle.enemies[0].max_hp=999
	game.run.battle.enemies[0].intent={"kind":"attack","amount":18,"label":"Test strike"}
	game.run.battle.hand[0].id="white_noise"
	var before=game.run.duplicate(true)
	var preview=game.preview_card(0,[4],0)
	check(preview.attack_reduction==9,"dedicated disruption can halve a heavy attack")
	check(game.run==before,"defensive preview does not mutate combat")
	game.play_card(0,[4],0)
	game.end_turn()
	check(game.run.hull==3 and game.run.mode=="combat","timely defense survives an otherwise lethal phase")
	game.run=before.duplicate(true)
	game.run.battle.hand[0].id="needle"
	game.play_card(0,[0],0)
	game.end_turn()
	check(game.run.mode=="defeat","choosing damage instead can lose the encounter")
	game=fixture()
	game.run.battle.kind="elite"
	game._finish_battle()
	var powers=[]
	for choice in game.run.reward.choices:
		if choice.kind=="powerup": powers.append(choice.id)
	check(powers.size()==2 and powers[0]!=powers[1],"elite offers distinct powerup alternatives")
	game.choose_reward(game.run.reward.choices.size()-1)
	check(game.run.powerups.size()==1 and game.run.mode=="map","only the chosen bonus is granted")
	game._make_shop()
	powers.clear()
	for item in game.run.shop.items:
		if item.kind=="powerup": powers.append(item.id)
	check(game.run.shop.items.size()==6 and powers.size()==2,"shop presents two powerups within its six slots")
	check(not game.run.powerups[0] in powers,"owned powerups are excluded from the shop")
	game.run.powerups.clear()
	for definition in game.catalog.powerups:
		if int(definition.unlock)==0: game.run.powerups.append(definition.id)
	game._make_shop()
	check(game.run.shop.items.size()==4,"exhausted powerup pool leaves a usable shop")
	game.run.battle.kind="boss"
	game._finish_battle()
	check(game.run.reward.choices.size()==2,"exhausted powerup pool still offers boss cards")
	print("BALANCE CHECKS: %d, failures: %d"%[checks,failures])
	quit(1 if failures else 0)
