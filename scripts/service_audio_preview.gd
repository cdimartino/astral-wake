extends Node
## Cabin ambience is a loop with a one-time introduction. Only an explicit
## action plays feedback; re-rendering a service screen does not trigger it.
const CABIN := preload("res://audio/preview/services/cabin.wav")
const ACTIONS := {
	"click": preload("res://audio/preview/services/click.wav"),
	"ship_select": preload("res://audio/preview/services/ship_select.wav"),
	"reward": preload("res://audio/preview/services/reward.wav"),
	"shop_buy": preload("res://audio/preview/services/shop_buy.wav"),
	"recovery": preload("res://audio/preview/services/recovery.wav"),
	"transition": preload("res://audio/preview/services/transition.wav"),
}
const ALIASES := {"ui": "click", "repair": "recovery", "map_jump": "transition"}
const ATTACK := 0.12
const RELEASE := 0.36

var active := false
var _hull: Node
var _bed: AudioStreamPlayer
var _actions: Dictionary[String, AudioStreamPlayer] = {}
var _level := 0.0

func setup(hull_audio: Node) -> void:
	_hull = hull_audio
	if _bed != null or not is_instance_valid(_hull): return
	_bed = _player("Cabin", CABIN, "Music")
	_bed.volume_db = -80.0
	for kind: String in ACTIONS:
		var player := _player(kind, ACTIONS[kind], "Interface")
		player.max_polyphony = 2
		_actions[kind] = player
	set_process(false)

func _player(label: String, stream: AudioStreamWAV, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.stream = stream
	player.bus = bus
	# PCM is authored pre-master: 0 dB here + default Master 0.5 = audition.
	add_child(player)
	return player

func enter() -> void:
	if active or not is_instance_valid(_hull) or _bed == null: return
	active = true
	if not _bed.playing: _bed.play()
	set_process(true)

func leave() -> void:
	if not active: return
	active = false
	set_process(true)

func action(kind: String) -> void:
	if not is_instance_valid(_hull): return
	var player: AudioStreamPlayer = _actions.get(ALIASES.get(kind, kind))
	if player != null: player.play()

func _process(delta: float) -> void:
	if _bed == null: return
	_level = move_toward(_level, 1.0 if active else 0.0, delta / (ATTACK if active else RELEASE))
	_bed.volume_db = linear_to_db(maxf(0.0001, smoothstep(0.0, 1.0, _level)))
	if _level <= 0.0: _bed.stop()
	if _level <= 0.0 or _level >= 1.0: set_process(false)
