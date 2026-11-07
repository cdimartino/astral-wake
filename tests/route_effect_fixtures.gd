extends RefCounted
## Actual #16 printed prototypes, test-only: never added to catalog/rewards.
const Zones = preload("res://tests/card_zone_fixtures.gd")

static func register(game) -> void:
	for spec in [
		{"id":"fixture_survey_spike","name":"Survey Spike","kind":"attack","damage":8,"conditional_damage":{"type":"novel_route","amount":5},"description":"Deal 8 damage. An ordered route unused by any command this turn adds 5 before organs."},
		{"id":"fixture_cross_current","name":"Cross Current","kind":"attack","damage":7,"route_cooling":{"type":"three_first","amount":1},"description":"Deal 7 damage. After exactly three organs, cool the first by 1 after route strain."},
		{"id":"fixture_heat_sink","name":"Heat Sink","vent":1,"ward":5,"description":"Cool every organ by 1. Gain 5 flat ward."},
		{"id":"fixture_thermal_lance","name":"Thermal Lance","kind":"attack","damage":9,"conditional_damage":{"type":"route_strain_two","amount":6},"description":"Deal 9 damage. If any routed organ had exactly 2 strain at command entry, add 6 before organs (once)."},
		{"id":"fixture_parry_filament","name":"Parry Filament","disrupt":3,"ward":5,"description":"Apply 3 disruption. Gain 5 flat ward."},
		{"id":"fixture_refracted_fang","name":"Refracted Fang","kind":"attack","damage":9,"conditional_ward":{"type":"prism_other_foe","amount":4},"description":"Deal 9 damage. Gain 4 flat ward if the route contains Prism and another foe lived at command entry."},
	]:
		var definition=game.card("graft_wire").duplicate(true)
		# The base template supplies presentation defaults, not unrelated branches.
		definition.erase("evolutions")
		definition.merge({"kind":"utility","draw":0,"vent":0,"damage":0,"heal":0,"disrupt":0,"link":false,"cost":1},true)
		definition.merge(spec,true)
		definition.rarity=1 if definition.id in ["fixture_cross_current","fixture_thermal_lance","fixture_refracted_fang"] else 0
		definition.roles=game.Distribution.mechanical_roles(definition)
		definition.primary_role=definition.roles[0]
		game._cards[definition.id]=definition

static func battle(game, id: String = "fixture_heat_sink") -> void:
	Zones.battle(game)
	Zones.identify(game,0,id)
	game.run.battle.capacity=3

static func demo(game) -> void:
	register(game)
	battle(game)
	for i in range(5):
		Zones.identify(game,i,["fixture_heat_sink","fixture_thermal_lance","fixture_survey_spike","fixture_cross_current","fixture_refracted_fang"][i])
	Zones.identify(game,5,"fixture_parry_filament")
	game.run.battle.strain=[2,1,0,0,0,0]
	game.run.battle.enemies=[game._make_enemy("cinder_mite"),game._make_enemy("cinder_mite")]
	game.run.battle.ward=8
