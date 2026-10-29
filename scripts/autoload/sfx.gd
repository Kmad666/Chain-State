extends Node
## Sound effects. One-shots come from a small pool of players, with a little
## random pitch so repeats don't sound mechanical; footsteps are one looping
## player that speeds up with your walking pace.
##
##   Sfx.play("jump")                  Sfx.play("land", -6.0, 0.9)
##   Sfx.play_at("cast", wizard.global_position)   (positional, fades with distance)
##   Sfx.set_walking(true, speed)      Sfx.set_walking(false)

## A name can map to several files: one is picked at random each time.
const SOUNDS := {
	"jump": ["res://assets/sounds/jump.ogg", "res://assets/sounds/fps/jump_a.ogg",
		"res://assets/sounds/fps/jump_b.ogg", "res://assets/sounds/fps/jump_c.ogg"],
	"land": "res://assets/sounds/land.ogg",
	"walking": "res://assets/sounds/fps/walking_long.ogg",     # a long loop: repeats less obviously
	"chain_throw": "res://assets/sounds/fps/weapon_change.ogg",
	"hurt": "res://assets/sounds/fps/enemy_hurt.ogg",
	"cast": "res://assets/sounds/fps/enemy_attack.ogg",
	"fall": "res://assets/sounds/fall.ogg",
	"coin": "res://assets/sounds/coin.ogg",
}
const POOL := 10
const POOL_3D := 8

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next_3d := 0
var _steps: AudioStreamPlayer
var played: Array[String] = []      # every name played, newest last (tests read it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		var paths: Array = SOUNDS[k] if SOUNDS[k] is Array else [SOUNDS[k]]
		var list: Array = []
		for path in paths:
			var st = load(path)
			if st:
				list.append(st)
		if not list.is_empty():
			_streams[k] = list
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 12.0
		p3.max_distance = 140.0
		add_child(p3)
		_pool_3d.append(p3)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_steps = AudioStreamPlayer.new()
	var w = _streams.get("walking", [null])[0]
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
	p.stream = _streams[name].pick_random()
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * randf_range(1.0 - wobble, 1.0 + wobble))
	p.play()


## A sound out in the world, at a position: it gets quieter with distance and
## pans with where it is relative to the camera.
func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, wobble := 0.07) -> void:
	played.append(name)
	if played.size() > 64:
		played.remove_at(0)
	if not _streams.has(name):
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_3D
	p.stream = _streams[name].pick_random()
	p.global_position = pos
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
	for p in _pool_3d:
		p.stop()
