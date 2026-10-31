extends "res://tools/manual_replay.gd"
## Test-only driver. Same guarded JSON protocol, never loaded in production.
func _create_session():
	return preload("res://tests/selection_fixtures.gd").FixtureSession.new()
