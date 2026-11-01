extends RefCounted
## Frozen a382575 outcome fingerprints; includes full state, RNG, piles and legacy results.
const Session = preload("res://tools/manual_session.gd")
const ORIGINAL_IDS = ["needle", "hull_stitch", "cold_breath", "quiet_pulse", "graft_wire", "sun_splinter", "mercy_circuit", "black_suture", "spare_heartbeat", "frost_seam", "red_interval", "wake_lance", "glass_murmur", "thread_cannon", "mute_bell", "cold_psalm", "salvage_hymn", "votive_shard", "mirror_cut", "open_channel", "scar_bridge", "winter_needle", "hollow_chorus", "seam_of_light", "pilgrim_signal", "long_hem", "blue_refrain", "last_match", "white_noise", "star_chart", "ember_abacus", "kindly_static", "afterimage", "deep_winter", "whole_horizon", "unbroken_song", "margin_knife", "pale_patch", "carbon_breath", "first_draft", "ghost_line", "revision_spike", "vellum_shield", "cut_sentence", "borrowed_dawn", "ink_well", "overwrite", "scar_note", "lost_paragraph", "double_exposure", "final_revision", "memory_lattice", "blank_page", "second_history", "choral_bolt", "warm_refrain", "silent_measure", "call_and_response", "tuning_fork", "bright_canon", "breath_between", "dissonant_edge", "shared_pulse", "counterpoint", "crescendo", "hushed_chord", "orbital_round", "harmonic_bridge", "grand_concert", "resonant_shell", "rest_note", "unison"]

static func capture(game) -> Dictionary:
	assert(ORIGINAL_IDS.size()==72)
	for id in ORIGINAL_IDS: assert(not game.card(id).is_empty())
	var outcomes = {}
	for ship in ["cartographer", "palimpsest", "hollow_choir"]:
		game.new_run("A1B2C3", ship)
		game.run.content_pool_revision=0
		game.choose_node(game.run.map[0][0].id)
		var initial = Session.snapshot(game.run)
		initial.hull = 30
		initial.powerups = ["amber_sight", "soft_copper"]
		initial.battle.enemies = [game._make_enemy("cinder_mite"), game._make_enemy("cinder_mite")]
		for foe in initial.battle.enemies:
			foe.hp = 5000
			foe.max_hp = 5000
		initial.battle.trace = 3
		initial.battle.resonance = 2
		initial.battle.last_command_kind = "repair"
		initial.battle.last_payload = {"damage":9, "heal":5, "disrupt":3}
		initial.battle.strain = [1, 1, 1, 1, 1, 1]
		var results = []
		for id in ORIGINAL_IDS:
			var definition=game.card(id)
			if definition.get("character", "cartographer") != ship: continue
			for level in [0, 1]:
				for route in [[0], [0, 1], [0, 1, 2]]:
					var state = initial.duplicate(true)
					state.battle.hand[0].id = definition.id
					state.battle.hand[0].level = level
					var result = game._simulate_card(state, 0, route, 0)
					assert(result.ok)
					# PR28 adds only these presentation records. Keep the original hashes
					# and every state/RNG field; card_piles_test checks the new records.
					result.presentation = result.presentation.filter(func(event): return event.kind not in ["discard_card", "draw_card", "shuffle"])
					# Explicitly additive dormant bookkeeping only; never omit RNG/gameplay.
					assert(result.next.reward_generation==1 and result.next.rare_offer_misses==0)
					result.next.erase("reward_generation")
					result.next.erase("rare_offer_misses")
					result.next.erase("schema_revision")
					assert(result.next.content_pool_revision==0)
					result.next.erase("content_pool_revision")
					assert(result.next.pending_selection.is_empty())
					result.next.erase("pending_selection")
					assert(result.next.battle.engine_routes==[route])
					result.next.battle.erase("engine_routes")
					for field in ["exhausted", "installed", "installed_sources", "temporary_retain", "engine_counters"]:
						assert(result.next.battle[field].is_empty())
						result.next.battle.erase(field)
					results.append(result)
		outcomes[ship] = {"cases":results.size(), "sha256":Session.digest(results)}
	return outcomes
