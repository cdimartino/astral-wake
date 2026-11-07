extends "res://tools/manual_session.gd"
## Labelled recovery counterfactual only. Production cards, no catalog overrides.
func start(directory: String, seed_value, ship: String, unlocks: int) -> Dictionary:
	var result=super(directory,seed_value,ship,unlocks)
	if not result.ok: return result
	game.run.mode="recovery"
	game.recover("upgrade")
	journal.initial=snapshot(game.run)
	return inspect()

static func environment() -> Dictionary:
	var result=preload("res://tools/manual_session.gd").environment()
	for path in ["tests/production_evolution_session.gd","tests/production_evolution_driver.gd"]:
		result.sources[path]=FileAccess.get_sha256("res://"+path)
	return result
