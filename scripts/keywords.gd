extends RefCounted
## Shared rules vocabulary. Membership comes from effect fields, never prose matching.
const DEFINITIONS := {
	"Command points":"The cost to play a command. Refill to 3 each turn; routing does not add command-point cost.",
	"Disruption":"Each point lowers that enemy's attack by 1 this enemy phase. Disruption and redirection together prevent at most half an attack. Some actions are interrupted at their displayed disruption threshold.",
	"Vent":"Cools every organ by this amount before route strain is added. It does not let a route enter an organ already at capacity.",
	"Draw":"Move cards from the draw pile into your hand, up to 10 cards. An empty draw pile reshuffles the discard pile when needed.",
	"Retain":"Stays in hand through end-turn discard and occupies the ten-card hand cap. Intrinsic Retain repeats; a temporary UID mark expires after one upcoming discard or when played. Draw five subject to room.",
	"Exhaust":"The played card leaves circulation before drawing and cannot reshuffle this combat. It remains in the expedition deck and returns next combat.",
	"Install":"Dormant storage only: the played card leaves circulation before drawing, with a source-linked identity. Same identity or name cannot stack. Passive activation and triggers are deferred; the card returns next combat.",
	"Trace":"Palimpsest resource, capped at 6. Card gains happen before routing; organs gain or spend it in route order. Resets each battle.",
	"Rewrite":"Copies half the previous command's upgraded base damage, repair and disruption, rounded down—not organ, resource or powerup bonuses. The organ spends 2 Trace; Rewrite cards spend all Trace and add their printed bonus if any was spent.",
	"Resonance":"Choir resource, capped at 3. Changing kind after a previous command gains 1; repeating a kind resets it to 0 before card and organ gains. Resets each battle.",
	"Concert":"Spend all Resonance to add 2 damage and 1 repair per point spent, before routing.",
	"Redirect":"Redirect up to 3 damage from the chosen enemy's next attack into another living foe this phase. Does not stack or work against a lone foe. Combined disruption and redirection prevent at most half an attack.",
	"Ward":"Absorbs incoming hull damage during the enemy phase. Unused ward expires at the end of that phase.",
	"Strain":"Each routed organ gains 1 strain. At capacity it cannot accept a route. Turn end cools organs; Vent cools before route strain. Upgraded pure utility cards spare the first routed organ.",
	"Link":"Restore severed connections, then connect the first and last organs of this route for the battle. The route must still be legal before the command is played.",
	"Split damage":"Also hit every other living enemy for half the command's damage, rounded down before bonuses and individual defenses. Primary damage is not divided between targets."
}

static func for_card(definition: Dictionary) -> Array[String]:
	var result: Array[String] = ["Command points"]
	for field in ["disrupt", "vent", "draw", "trace", "rewrite", "resonance", "concert", "link", "retain", "exhaust", "install"]:
		if definition.get(field, 0): result.append("Disruption" if field == "disrupt" else field.capitalize())
	result.append("Strain")
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
