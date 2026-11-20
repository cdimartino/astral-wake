extends RefCounted
## Commands run only on the private sandbox Game. The caller commits or rolls back
## the entire edit after validating the result with the normal save validator.
static func edit(game, command: String, a: PackedStringArray, events: Array = []) -> String:
	var run: Dictionary = game.run
	var b: Dictionary = run.get("battle", {})
	match command:
		"run start":
			var result: Dictionary = game.new_run(a[1], a[0])
			return "Started %s · %s" % [a[0], game.run.seed] if result.ok else "Error: " + result.error
		"region jump":
			var tier := int(a[1]) if a.size() == 2 else int(run.region)
			var area := 0
			while game.catalog.regions[area].id != a[0]: area += 1
			var other: int = run.route_regions.find(area)
			if other >= 0: run.route_regions[other] = run.route_regions[tier]
			run.route_regions[tier] = area
			run.region = tier
			run.layer = -1
			run.current_node = ""
			run.visited = []
			run.mode = "map"
			run.battle = {}
			run.reward = {}
			run.shop = {}
			run.event_id = ""
			run.map = game._generate_map(run)
			return "Chart: %s · tier %d" % [game.region().name, tier]
		"node jump":
			for layer in run.map:
				for node in layer:
					if node.id != a[0]: continue
					run.current_node = node.id
					run.layer = node.layer
					if not node.id in run.visited: run.visited.append(node.id)
					match node.type:
						"battle", "elite", "boss": game._start_battle(node)
						"event":
							run.mode = "event"
							run.event_id = node.event_id
						"shop": game._make_shop()
						"recovery": run.mode = "recovery"
					return "Arrived: %s · %s" % [node.id, run.mode]
		"room open":
			if a.size() == 2 and a[0] != "event": return "Error: Only an event room accepts an event ID."
			match a[0]:
				"shop": game._make_shop()
				"recovery": run.mode = "recovery"
				"event":
					run.mode = "event"
					run.event_id = a[1] if a.size() == 2 else game.catalog.events[0].id
				"reward":
					if run.mode != "combat":
						var foe: Dictionary = game.catalog.enemies.filter(func(e): return int(e.region) == int(run.route_regions[int(run.region)]) and e.role == "regular")[0]
						game._start_battle({"type":"battle","enemy_ids":[foe.id]})
					run.battle.enemies.clear()
					game._finish_battle()
			return "Opened " + run.mode
		"encounter battle", "encounter elite", "encounter boss":
			game._start_battle({"type":command.get_slice(" ", 1),"enemy_ids":[a[0]]})
			return "Encounter: %s · %s" % [a[0], run.battle.kind]
		"player set":
			var key := a[0]
			var n := int(a[1])
			var limit: int = {"hull":run.max_hull,"salvage":99999,"ward":999,"command_points":3,"trace":6,"resonance":3}[key]
			if n > limit or (key == "hull" and n == 0):
				return "Error: %s range: %d..%d." % [key, 1 if key == "hull" else 0, limit]
			if key in ["hull","salvage"]: run[key] = n
			else: b[key] = n
			return "%s = %d" % [key, n]
		"organ strain":
			if int(a[1]) > int(b.capacity): return "Error: Strain exceeds capacity %d." % b.capacity
			b.strain[int(a[0])] = int(a[1])
			return "Organ %s strain = %s" % [a[0], a[1]]
		"organ link":
			var first := int(a[0])
			var second := int(a[1])
			if first == second: return "Error: Choose two distinct organs."
			var linked: bool = game._edge_exists(b.edges, first, second)
			var cut: bool = game._edge_exists(b.severed, first, second)
			match a[2]:
				"connect":
					if linked: return "Error: Conduit already exists; mend a severed conduit."
					b.edges.append([first, second])
				"cut":
					if not linked or cut: return "Error: Select an intact conduit."
					b.severed.append([first, second])
				"mend":
					if not cut: return "Error: Select a severed conduit."
					b.severed.erase([first, second])
					b.severed.erase([second, first])
			return "%s: %d–%d" % [a[2], first, second]
		"card add":
			if run.deck.size() >= 200: return "Error: The deck already has 200 cards."
			var zone := a[1] if a.size() > 1 else "draw"
			if run.mode != "combat" and a.size() > 1: return "Error: Combat piles exist only in combat."
			if run.mode == "combat" and zone == "hand" and b.hand.size() >= 10: return "Error: Hand is full."
			var card: Dictionary = game._instance(run, a[0])
			run.deck.append(card)
			if run.mode == "combat": b[zone].append(card.duplicate(true))
			return "Added %s · UID %d" % [a[0], card.uid]
		"card remove", "card move":
			var uid := int(a[0])
			var index: int = game.Selections.index(run.deck, uid)
			if index < 0: return "Error: Unknown deck UID."
			var removing := command == "card remove"
			if removing and run.deck.size() <= 5: return "Error: Keep at least five cards."
			if run.mode == "combat":
				if game.Selections.index(b.installed, uid) >= 0: return "Error: Installed sources stay in place until the battle ends."
				if removing and b.get("last_command", {}).get("card", {}).get("uid") == uid: return "Error: This card is the remembered command."
				for zone in game.COMBAT_ZONES:
					var i: int = game.Selections.index(b[zone], uid)
					if i < 0: continue
					if not removing:
						if zone == a[1]: return "Error: Card is already in that pile."
						if a[1] == "hand" and b.hand.size() >= 10: return "Error: Hand is full."
						b[a[1]].append(b[zone][i])
					b[zone].remove_at(i)
					b.temporary_retain.erase(uid)
					break
			if removing: run.deck.remove_at(index)
			return "Removed UID %d" % uid if removing else "Moved UID %d to %s" % [uid, a[1]]
		"card draw":
			var before: int = b.hand.size()
			game._draw(run, int(a[0]), events)
			return "Drew %d; %d cards in hand." % [b.hand.size() - before, b.hand.size()]
		"powerup give", "powerup remove":
			if command == "powerup give":
				if a[0] in run.powerups: return "Error: Already owned."
				game._grant_powerup(a[0])
			else:
				if not a[0] in run.powerups: return "Error: Powerup not owned."
				run.powerups.erase(a[0])
			return "%s: %s" % [command, a[0]]
		"foe spawn":
			if b.enemies.size() >= 8: return "Error: Eight foes already present."
			var foe: Dictionary = game._make_enemy(a[0])
			foe.intent = game._intent_for(a[0], b.turn)
			b.enemies.append(foe)
			return "Spawned %s at %d" % [a[0], b.enemies.size() - 1]
		"foe remove":
			var foe = b.enemies.pop_at(int(a[0]))
			game._check_battle_end()
			return "Removed " + foe.name
		"damage", "heal", "status":
			var player := a[0] == "player"
			var amount := int(a[-1])
			if amount > 9999: return "Error: Amount must be 0..9999."
			var actor: Dictionary = run if player else b.enemies[int(a[0])]
			if command == "status":
				if player: b[a[1]] = amount
				else: actor[a[1]] = amount
				return "%s %s = %d" % [a[0], a[1], amount]
			if command == "damage":
				if player:
					var hit: Dictionary = game._hurt(run, amount)
					amount = hit.damage
					events.append({"kind":"enemy_attack","source_index":0,"amount":amount,"absorbed":hit.absorbed})
					if hit.restored > 0: events.append({"kind":"heal","amount":hit.restored,"source":"emergency"})
				else:
					amount = game._damage_enemy(run, int(a[0]), amount)
					events.append({"kind":"damage","target_index":int(a[0]),"amount":amount})
				game._clean_enemies(run, events)
				game._check_battle_end()
			else:
				var hp := "hull" if player else "hp"
				amount = mini(int(actor["max_" + hp]) - int(actor[hp]), amount)
				actor[hp] += amount
				events.append({"kind":"heal" if player else "enemy_heal","target_index":-1 if player else int(a[0]),"amount":amount})
			return "%s %s: %d" % [command, a[0], amount]
		"resolve":
			if a[0] == "battle":
				if run.mode != "combat": return "Error: An encounter win requires combat."
				b.enemies.clear()
				game._check_battle_end()
			else:
				if a[0] == "defeat": run.hull = 0
				game._finish_run(a[0] == "victory")
			return "Resolved: " + run.mode
	return "Error: Unknown game edit."
