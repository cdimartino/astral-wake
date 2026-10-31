extends RefCounted
## Versioned, engine-independent gameplay RNG. Never use the presentation RNG here.
## Park–Miller with rejection sampling; all products fit signed 64-bit integers.
const VERSION := 1
const ALPHABET := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const SPACE := 2176782336 # 36^6; two low bits also encode the discovery pool.
const MODULUS := 2147483647
const STREAMS := ["world", "cards", "rewards", "shop", "events", "enemies"]

static func valid(code: String) -> bool:
	if code.length() != 6: return false
	for letter in code:
		if ALPHABET.find(letter) < 0: return false
	return true

static func canonical(code: String) -> String:
	return code.strip_edges().to_upper()

static func decode(code: String) -> int:
	var value := 0
	for letter in code: value = value * 36 + ALPHABET.find(letter)
	return value

static func encode(value: int) -> String:
	var code := ""
	for i in range(6):
		code = ALPHABET[value % 36] + code
		value = int(value / 36)
	return code

static func generate(pool_tier: int) -> String:
	# Entropy is used only to choose a new code, never after an expedition begins.
	var bytes := Crypto.new().generate_random_bytes(4)
	var value := int(bytes.decode_u32(0)) % SPACE
	return encode(value - value % 4 + clampi(pool_tier, 0, 3))

static func initialize(state: Dictionary, code: String) -> void:
	state.seed = code
	state.rng_version = VERSION
	state.rng_streams = {}
	state.pool_tier = decode(code) % 4
	var base := decode(code) % (MODULUS - 1) + 1
	for i in range(STREAMS.size()):
		state.rng_streams[STREAMS[i]] = (base + (i + 1) * 104729) % (MODULUS - 1) + 1

static func pick(state: Dictionary, count: int, stream: String) -> int:
	if count <= 1: return 0
	assert(stream in STREAMS and count < MODULUS)
	var limit := (MODULUS - 1) - (MODULUS - 1) % count
	var value := 0
	while true:
		var next := int(state.rng_streams[stream]) * 48271 % MODULUS
		state.rng_streams[stream] = next
		value = next - 1
		if value < limit: return value % count
	return 0

static func pick_legacy(state: Dictionary, count: int) -> int:
	# Exact compatibility with the original numeric-seed Godot PCG sequence.
	if count <= 1: return 0
	var random := RandomNumberGenerator.new()
	random.seed = int(state.seed)
	if state.has("rng_state"): random.state = int(state.rng_state)
	var result := random.randi_range(0, count - 1)
	state.rng_state = str(random.state)
	return result

static func valid_state(state: Dictionary) -> bool:
	if not state.get("seed") is String or not valid(state.seed): return false
	if state.get("rng_version") != VERSION or not state.get("seeded") is bool: return false
	if state.get("pool_tier") != decode(state.seed) % 4: return false
	if not state.get("rng_streams") is Dictionary or state.rng_streams.size() != STREAMS.size(): return false
	for stream in STREAMS:
		var value = state.rng_streams.get(stream)
		if not (value is int or value is float) or not is_finite(float(value)) or value != floor(value) or value < 1 or value >= MODULUS: return false
	return true
