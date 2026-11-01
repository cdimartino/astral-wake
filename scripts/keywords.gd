extends RefCounted
## Shared rules vocabulary. Membership comes from effect fields, never prose matching.
const DEFINITIONS := {
	"Command points":"The cost to play a command. Refill to 3 each turn; routing does not add command-point cost.",
	"Disruption":"Each point lowers that enemy's attack by 1 this enemy phase. Disruption and redirection together prevent at most half an attack. Some actions are interrupted at their displayed disruption threshold.",
	"Vent":"Cools every organ by this amount before route strain is added. It does not let a route enter an organ already at capacity.",
	"Draw":"Move cards from the draw pile into your hand, up to 10 cards. An empty draw pile reshuffles the discard pile when needed.",
	"Retain":"Stays in hand through end-turn discard and occupies the ten-card hand cap. Intrinsic Retain repeats; a temporary UID mark expires after one upcoming discard or when played. Draw five subject to room.",
	"Exhaust":"The played card leaves circulation before drawing and cannot reshuffle this combat. It remains in the expedition deck and returns next combat.",
	"Install":"Leaves circulation before drawing; same identity or name cannot stack. Typed engines show source-linked rules and counters. Novel ordered routes use all commands this turn; Exhaust engines grant flat ward 3 once per turn when another card exhausts. New stacks never buff the earning command. Cooling and retaliation engines grant no attack stacks. Untyped installs remain dormant; the card returns next combat.",
	"Cooling ward":"Once per player turn, the first later command meeting the printed actual-cooling threshold grants flat ward. Sum actual vent and post-route removals, not attempted cooling or net change. Own installation and automatic end-turn cooling never trigger it.",
	"Novel route":"Exact ordered route unused by any committed command this player turn, including utility and Install. Reversing a route is different. Living Atlas gains apply only to later attacks, capped per source for this combat.",
	"Entry strain":"Check routed organs at command entry, before vent or route strain. Exactly 2 qualifies once, not once per organ. An organ already at capacity still makes the route illegal.",
	"Route cooling":"With exactly three routed organs, cool the first by 1 after route strain. Counts actual removed strain; never authorizes an initially saturated route.",
	"Redirect retaliation":"Once per enemy phase, the first positive resolved redirect deals the printed extra hit to that same recipient after the attack. Armor absorbing the redirect still consumes the latch; armor/exposed apply separately to the extra hit. Dead recipient: no retarget. Player lethal: no passive payout. No copying or organ/powerup amplification.",
	"Trace":"Palimpsest resource, capped at 6. Card gains happen before routing; organs gain or spend it in route order. Resets each battle.",
	"Rewrite":"Copies half the previous command's upgraded base damage, repair and disruption, rounded down—not organ, resource or powerup bonuses. The organ spends 2 Trace; Rewrite cards spend all Trace and add their printed bonus if any was spent.",
	"Resonance":"Choir resource, capped at 3. Changing kind after a previous command gains 1; repeating a kind resets it to 0 before card and organ gains. Resets each battle.",
	"Concert":"Spend all Resonance to add 2 damage and 1 repair per point spent, before routing.",
	"Redirect":"Redirect up to 3 damage from the chosen enemy's next attack into another living foe this phase. Does not stack or work against a lone foe. Combined disruption and redirection prevent at most half an attack.",
	"Ward":"Absorbs incoming hull damage during the enemy phase. Printed ward is flat, additive, not copied or multiplied by organs. Unused ward expires at the end of that phase.",
	"Strain":"Each routed organ gains 1 strain. At capacity it cannot accept a route. Turn end cools organs; Vent cools before route strain. Upgraded pure utility cards spare the first routed organ.",
	"Link":"Restore severed connections, then connect the first and last organs of this route for the battle. The route must still be legal before the command is played.",
	"Split damage":"Also hit every other living enemy for half the command's damage, rounded down before bonuses and individual defenses. Primary damage is not divided between targets."
}

static func for_card(definition: Dictionary) -> Array[String]:
	var result: Array[String] = ["Command points"]
	for field in ["disrupt", "ward", "vent", "draw", "trace", "rewrite", "resonance", "concert", "link", "retain", "exhaust", "install"]:
		if definition.get(field, 0): result.append("Disruption" if field == "disrupt" else field.capitalize())
	result.append("Strain")
	if definition.has("conditional_ward") and not "Ward" in result: result.append("Ward")
	if definition.get("conditional_damage",{}).get("type","")=="novel_route" or definition.get("engine",{}).get("type","")=="novel_route": result.append("Novel route")
	if definition.get("conditional_damage",{}).get("type","")=="route_strain_two": result.append("Entry strain")
	if definition.has("route_cooling"): result.append("Route cooling")
	if definition.get("engine",{}).get("type","")=="cooling_ward": result.append("Cooling ward")
	if definition.get("engine",{}).get("type","")=="redirect_retaliation": result.append("Redirect retaliation")
	return result

static func for_organ(id: String) -> Array[String]:
	var mapping := {"fork":["Split damage"], "hush":["Disruption"], "prism":["Redirect"], "scribe":["Trace"], "splice":["Trace","Split damage"], "recall":["Trace"], "palimend":["Trace"], "redact":["Trace","Disruption"], "rewrite":["Trace","Rewrite"], "conductor":["Resonance"], "chorus":["Resonance","Split damage"], "crescendo":["Resonance"], "rest":["Resonance"], "dissonance":["Resonance","Disruption"], "cadence":["Resonance","Ward"]}
	var result: Array[String] = []
	result.assign(mapping.get(id, []))
	result.append("Strain")
	return result

static func describe(names: Array[String], rich: bool = false) -> String:
	var lines: Array[String] = []
	for name in names:
		lines.append(("[b]%s[/b]" % name if rich else name) + ": " + str(DEFINITIONS[name]))
	return "\n\n".join(lines)
