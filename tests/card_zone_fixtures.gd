extends RefCounted
## Test-only catalog entries. Never loaded by the game or reward pools.

static func register(game) -> void:
	for spec in [
		{"id":"fixture_retain","name":"Fixture Hold","retain":true},
		{"id":"fixture_exhaust","name":"Fixture Burn","exhaust":true,"draw":1},
		{"id":"fixture_install","name":"Fixture Engine","install":"fixture_engine","draw":1},
		{"id":"fixture_alias","name":"Fixture Alias","install":"fixture_engine","draw":1},
		{"id":"fixture_namesake","name":"Fixture Engine","install":"fixture_other","draw":1},
	]:
		var definition=game.card("graft_wire").duplicate(true)
		definition.merge(spec,true)
		definition.description="Test fixture only. No passive activation."
		game._cards[definition.id]=definition

static func battle(game, modern: bool = true) -> void:
	game.new_run("A1B2C3" if modern else 2026)
	game.choose_node(game.run.map[0][0].id)
	game.run.battle.enemies=[game._make_enemy("cinder_mite")]
	game.run.battle.enemies[0].hp=5000
	game.run.battle.enemies[0].max_hp=5000
	game.run.battle.enemies[0].intent={"kind":"attack","amount":0,"label":"Fixture idle"}
	game.run.battle.hand=game.run.deck.slice(0,5).duplicate(true)
	game.run.battle.draw=game.run.deck.slice(5).duplicate(true)
	game.run.battle.discard=[]

static func identify(game, index: int, id: String) -> void:
	var uid=game.run.deck[index].uid
	game.run.deck[index].id=id
	for zone in game.COMBAT_ZONES:
		for instance in game.run.battle[zone]:
			if instance.uid==uid: instance.id=id

static func showcase(game) -> void:
	register(game)
	battle(game)
	identify(game,0,"fixture_install")
	game.play_card(0,[0],0)
	identify(game,1,"fixture_exhaust")
	game.play_card(0,[1],0)
	identify(game,2,"fixture_retain")
	game.retain_card(int(game.run.battle.hand[1].uid))
