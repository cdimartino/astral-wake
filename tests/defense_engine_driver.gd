extends "res://tools/manual_replay.gd"
func _create_session():
	return preload("res://tests/defense_engine_fixtures.gd").FixtureSession.new()
