extends "res://tools/manual_replay.gd"
## Fixture-only guarded adapter; not a production catalog or demo hook.
func _create_session():
	return preload("res://tests/install_engine_fixtures.gd").FixtureSession.new()
