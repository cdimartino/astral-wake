extends SceneTree
## Compare against df3e6c5, not a candidate-generated expected result.
const Game=preload("res://scripts/game.gd")
var rows=[]
func _initialize() -> void:
	for seed_value in [424242,"0093CG"]:
		for ship in ["cartographer","palimpsest","hollow_choir"]:
			for generation in [0,1]:
				var game=Game.new(OS.get_environment("ASTRAL_SAVE_DIR").path_join("oracle-%s-%s-%d"%[seed_value,ship,generation]))
				game.new_run(seed_value,ship)
				if game.run.has("content_pool_revision"): game.run.content_pool_revision=0
				game.run.reward_generation=generation
				game.choose_node(game.run.map[0][0].id)
				var offers=[]
				for i in range(8):
					game.run.battle.kind="battle" if i%2==0 else "elite"
					game._finish_battle()
					game._make_shop()
					offers.append({"reward":game.run.reward.duplicate(true),"shop":game.run.shop.duplicate(true),"streams":game.run.get("rng_streams",{}).duplicate(true),"rng_state":game.run.get("rng_state",""),"pity":game.run.rare_offer_misses})
				rows.append({"seed":seed_value,"ship":ship,"generation":generation,"pool":game._available_cards(),"offers":offers})
	var path=OS.get_environment("ASTRAL_ORACLE_OUTPUT")
	if not path.is_empty():
		var file=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(rows,"  ",true)+"\n")
	else:
		var expected=preload("res://tools/manual_session.gd").restore_numbers(JSON.parse_string(FileAccess.get_file_as_string("res://tests/content_pool_legacy_oracle.json")))
		if JSON.stringify(rows,"",true)!=JSON.stringify(expected,"",true):
			push_error("Pre-expansion pool0 future offers/shop prices/RNG diverged")
			quit(1)
			return
	print("CONTENT_POOL_ORACLE 12 histories / 96 reward+shop cycles match df3e6c5 (both RNGs, both reward generations, every ship)")
	quit()
