extends RefCounted

const MAX_RANK = 11
const MODIFIER_REVISION = 1
const DELTAS = ["Current rules, unchanged.", "Area 3 attacks gain +1 damage.", "Area 2 attacks gain +1 damage.", "Area 3 attacks gain +1 from turn 5.", "Area 2 attacks gain +1 from turn 5.", "Area 3 attacks gain +1 from turn 9.", "Area 2 attacks gain +1 from turn 9.", "Area 3's turn-5 bonus starts on turn 3.", "Area 2's turn-5 bonus starts on turn 3.", "Area 3 elite and guardian attacks gain +1.", "Area 2 elite and guardian attacks gain +1.", "Area 3 guardian attacks gain +1."]

static func valid_rank(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= 0 and value <= MAX_RANK

static func valid_identity(value: Dictionary) -> bool:
	if not value.has("ascension_rank") and not value.has("modifier_revision"): return true
	return value.has("ascension_rank") and value.has("modifier_revision") and valid_rank(value.ascension_rank) and (value.modifier_revision is int or value.modifier_revision is float) and value.modifier_revision == MODIFIER_REVISION

static func attack_bonus(rank: int, area: int, turn: int, kind: String) -> int:
	if area == 0 or rank == 0: return 0
	var late = area == 2
	var bonus = 0
	if rank >= (1 if late else 2): bonus += 1
	if rank >= (3 if late else 4) and turn >= (3 if rank >= (7 if late else 8) else 5): bonus += 1
	if rank >= (5 if late else 6) and turn >= 9: bonus += 1
	if rank >= (9 if late else 10) and kind in ["elite", "boss"]: bonus += 1
	if rank >= 11 and late and kind == "boss": bonus += 1
	return bonus
