extends SceneTree
## SCRIPTED TEST DECKS, NOT drafted expeditions or human playtests.
const Game=preload("res://scripts/game.gd")
const Session=preload("res://tools/manual_session.gd")
const PACKAGES={
	"survey":["living_atlas","survey_spike","cross_current","needle","hull_stitch","survey_spike","cold_breath","quiet_pulse","needle","hull_stitch"],
	"thermal":["phase_radiator","thermal_lance","heat_sink","needle","hull_stitch","thermal_lance","heat_sink","quiet_pulse","needle","hull_stitch"],
	"interception":["interception_loom","refracted_fang","parry_filament","needle","hull_stitch","refracted_fang","parry_filament","cold_breath","needle","hull_stitch"],
	"hybrid":["survey_spike","thermal_lance","heat_sink","refracted_fang","parry_filament","cross_current","needle","cold_breath","hull_stitch","hull_stitch"]
}
func _initialize() -> void:
	var rows=[]
	var policy=load("res://tests/playthrough.gd").new()
	for package in PACKAGES:
		for no_rare in ([false,true] if package!="hybrid" else [true]):
			for opponent in ["group","boss"]:
				for power in ["none","hermit_knot","pilgrim_spine"]:
					var game=Game.new(OS.get_environment("ASTRAL_SAVE_DIR").path_join("packages-%d"%Time.get_ticks_usec()))
					game.new_run("0093CG")
					game.run.deck=[]
					for id in PACKAGES[package]:
						if no_rare and game.card(id).rarity==2: id="needle"
						game.run.deck.append(game._instance(game.run,id))
					if power!="none": game.run.powerups=[power]
					game._start_battle({"type":"boss" if opponent=="boss" else "battle","enemy_ids":["unhatched_sun"] if opponent=="boss" else ["cinder_mite","cinder_mite"]})
					# Fixed opening, explicitly scripted: preserve actual owned UIDs.
					game.run.battle.hand=game.run.deck.slice(0,5).duplicate(true)
					game.run.battle.draw=game.run.deck.slice(5).duplicate(true)
					policy.game=game
					policy.policy="tactical"
					policy.prepare_routes()
					var commands=[]
					# Authored setup decision, NOT a claim the greedy policy drafts or
					# discovers this engine. Pay ordinary CP and route strain.
					if not no_rare and package!="hybrid":
						var setup=game.run.battle.hand[0].duplicate(true)
						var result=game.play_card(0,[4],0)
						assert(result.ok and game.run.battle.command_points==1)
						commands.append({"id":setup.id,"uid":setup.uid,"turn":1,"route":[4],"damage":result.damage,"cooling":0,"flat_ward":0,"decision":"scripted engine setup: costs 2 of 3 CP"})
					var steps=0
					while game.run.mode=="combat" and steps<300:
						var plan=policy.plan_combat_action()
						if plan.get("end_turn",false): game.end_turn()
						else:
							var instance=game.run.battle.hand[plan.hand]
							var result=game.play_card(plan.hand,plan.route,plan.target)
							assert(result.ok)
							commands.append({"id":instance.id,"uid":instance.uid,"turn":game.run.battle.turn,"route":plan.route,"damage":result.damage,"cooling":result.get("command_cooling",0),"flat_ward":result.get("flat_ward_applied",0),"events":result.get("events",[])})
						assert(game._valid_run(game.run))
						steps+=1
					assert(game.run.mode!="combat","Evidence must finish, not silently truncate")
					rows.append({"package":package,"without_rare":no_rare,"opponent":opponent,"powerup":power,"mode":game.run.mode,"hull":game.run.hull,"turns":game.run.battle.turn,"commands":commands,"log":game.run.log})
	var report={"label":"SCRIPTED production-card test decks; NOT drafted expeditions or human decisions","content_pool_revision":1,"reward_generation":1,"policy":"cartographer-content1-setup-v1","environment":Session.environment(),"cases":rows}
	for path in ["tests/playthrough.gd","tests/cartographer_package_evidence.gd","scripts/main.gd","scripts/keywords.gd"]:
		report.environment.sources[path]=FileAccess.get_sha256("res://"+path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  ",true)+"\n")
	print("PACKAGE_EVIDENCE ",rows.size()," completed scripted encounters (all packages group/boss, hybrids, missing rare, short/long-route relic comparisons)")
	policy.free()
	quit()
