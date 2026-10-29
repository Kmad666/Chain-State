extends Node
## Sound effects. One-shots come from a small pool of players, with a little
## random pitch so repeats don't sound mechanical; footsteps are one looping
## player that speeds up with your walking pace.
##
##   Sfx.play("jump")                  Sfx.play("land", -6.0, 0.9)
##   Sfx.set_walking(true, speed)      Sfx.set_walking(false)

const SOUNDS := {
	"jump": "res://assets/sounds/jump.ogg",
	"land": "res://assets/sounds/land.ogg",
	"walking": "res://assets/sounds/walking.ogg",
	"fall": "res://assets/sounds/fall.ogg",
	"break": "res://assets/sounds/break.ogg",
	"coin": "res://assets/sounds/coin.ogg",
}
const POOL := 10

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _steps: AudioStreamPlayer
var played: Array[String] = []      # every name played, newest last (tests read it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		var s = load(SOUNDS[k])
		if s:
			_streams[k] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_steps = AudioStreamPlayer.new()
	var w = _streams.get("walking")
	if w is AudioStreamOggVorbis:
		w = w.duplicate()
		w.loop = true
	_steps.stream = w
	_steps.volume_db = -10.0
	add_child(_steps)
	Logbook.evidence_added.connect(func(_e): play("coin", -3.0, 0.9))


func play(name: String, volume_db := 0.0, pitch := 1.0, wobble := 0.07) -> void:
	played.append(name)
	if played.size() > 64:
		played.remove_at(0)
	if not _streams.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * randf_range(1.0 - wobble, 1.0 + wobble))
	p.play()


func set_walking(on: bool, speed := 0.0) -> void:
	if on:
		_steps.pitch_scale = clampf(0.8 + speed * 0.06, 0.8, 1.5)
		if not _steps.playing:
			_steps.play()
	elif _steps.playing:
		_steps.stop()


func stop_all() -> void:
	_steps.stop()
	for p in _pool:
		p.stop()
