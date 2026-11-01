extends SceneTree
## Run against base revision 7382d3d, not the candidate, to regenerate the oracle.
const Game = preload("res://scripts/game.gd")
func _initialize() -> void:
	if Game.RUN_SCHEMA != 5 or OS.get_environment("ASTRAL_LEGACY_OUTPUT").is_empty() or OS.get_environment("ASTRAL_SAVE_DIR").is_empty():
		push_error("Oracle generation requires the schema-5 base project plus explicit scratch save/output paths; never regenerate from the candidate.")
		quit(1)
		return
	var result: Array = []
	for seed_value in ["A1B2C3", 424242]:
		for ship in ["cartographer", "palimpsest", "hollow_choir"]:
			var game = Game.new(OS.get_environment("ASTRAL_SAVE_DIR").path_join(str(result.size())))
			game.new_run(seed_value, ship)
			game.choose_node(game.run.map[0][0].id)
			game.run.battle.kind="battle"
			game._finish_battle()
			var reward: Dictionary = game.run.duplicate(true)
			# Shop follows the pending reward without combat RNG consumption.
			game.run.powerups.append("old_favour")
			game._make_shop()
			var shop: Dictionary = game.run.duplicate(true)
			game.run.battle.kind="elite"
			game._finish_battle()
			result.append({"seed":seed_value,"ship":ship,"profile":game.profile,"reward":reward,"shop":shop,"next_reward":game.run.reward.duplicate(true),"next_streams":game.run.get("rng_streams",{}).duplicate(true),"next_legacy":game.run.get("rng_state","")})
	var file=FileAccess.open(OS.get_environment("ASTRAL_LEGACY_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ",true)+"\n")
	quit()
