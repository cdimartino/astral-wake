extends RefCounted
## Short function readouts accompany the full, authoritative organ tooltip.
const READOUTS := {
	"lens": ["+3", "damage if attacking", "f39789"],
	"fork": ["½ → ALL", "split to other foes", "f39789"],
	"echo": ["×1.5", "damage + healing", "bcb5ff"],
	"mend": ["+1 HULL", "add healing", "7be0ca"],
	"hush": ["+2", "disruption", "8bd5ec"],
	"prism": ["↗ 3 MAX", "redirect · needs foe", "bcb5ff"],
	"scribe": ["+2 TRACE", "store memory", "e7c381"],
	"splice": ["½ → ALL", "2 trace; else +2 dmg", "e7c381"],
	"recall": ["+2 / TRACE", "damage · spend all", "f39789"],
	"palimend": ["+2 HULL", "spend 1 trace", "7be0ca"],
	"redact": ["+3 / +1", "disrupt · 1 / 0 trace", "8bd5ec"],
	"rewrite": ["½ MEMORY", "spend 2 trace", "e7c381"],
	"conductor": ["+1 RES", "first / different kind", "bcb5ff"],
	"chorus": ["½ → ALL", "2 res; else +1 dmg", "bcb5ff"],
	"crescendo": ["+2 / RES", "damage + healing\nspend all", "f39789"],
	"rest": ["+1 HP / RES", "repair / utility only", "7be0ca"],
	"dissonance": ["1 + RES", "disruption", "8bd5ec"],
	"cadence": ["3 WARD", "spend 2 res · cap 3", "bcb5ff"],
}
