extends "res://tools/manual_replay.gd"
func _create_session():
	return preload("res://tests/evolution_fixtures.gd").FixtureSession.new()
