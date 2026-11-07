extends "res://tools/manual_replay.gd"
func _create_session():
	return preload("res://tests/production_evolution_session.gd").new()
