extends Node
## Game feel for the player: trauma screen shake, hit stop, speed lines and
## particles. Each one reads its strength from the player's `tune`, so the pause
## menu can turn it down or off.
##
## Trauma shake: events add "trauma" (0..1) which drains over time; the shake is
## trauma squared, so small knocks barely move the view and big hits really do.
## The motion comes from smooth noise rather than random jumps.

const DECAY := 1.4               # trauma lost per second
const MAX_ANGLE := 0.045         # radians of pitch / yaw at full shake
const MAX_ROLL := 0.06
const MAX_OFFSET := 0.10         # metres of camera slide at full shake
const NOISE_SPEED := 22.0

var player: Node                 # the player (set before add_child)
var trauma := 0.0
var _t := 0.0
var _noise := FastNoiseLite.new()
var _lines: Control

class SpeedLines extends Control:
	## Thin streaks round the edge of the view, pointing at where you're heading.
	var strength := 0.0
	var focus := Vector2(0.5, 0.5)     # where the streaks converge, in 0..1 screen space
	var _rng := RandomNumberGenerator.new()

	func _draw() -> void:
		if strength <= 0.01:
			return
		var c := size * focus
		var reach := size.length() * 0.6
		var n := int(18 + 34 * strength)
		for i in n:
			var a := _rng.randf() * TAU
			var d := Vector2(cos(a), sin(a))
			var r0 := reach * _rng.randf_range(0.45, 0.8)
			var r1 := r0 + reach * _rng.randf_range(0.12, 0.3) * (0.5 + strength)
			var col := Color(1, 1, 1, _rng.randf_range(0.10, 0.32) * strength)
			draw_line(c + d * r0, c + d * r1, col, _rng.randf_range(1.0, 2.5), true)


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.08
	_noise.seed = 7
	var layer := CanvasLayer.new()
	layer.layer = 0                       # over the 3D view, under the HUD
	add_child(layer)
	_lines = SpeedLines.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_lines)


func _exit_tree() -> void:
	Engine.time_scale = 1.0               # never leave the game frozen


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## How much the view is shaking right now (0..1, after the strength setting).
func shake() -> float:
	return trauma * trauma * float(player.tune.screen_shake)


## Called by the player each frame, after it has set the camera's roll.
func update(dt: float) -> void:
	trauma = maxf(trauma - DECAY * dt, 0.0)
	_t += dt * NOISE_SPEED
	var cam: Camera3D = player.cam
	var s := shake()
	if s > 0.0:
		cam.rotation.x += MAX_ANGLE * s * _noise.get_noise_2d(1.0, _t)
		cam.rotation.y += MAX_ANGLE * s * _noise.get_noise_2d(50.0, _t)
		cam.rotation.z += MAX_ROLL * s * _noise.get_noise_2d(100.0, _t)
	cam.h_offset = MAX_OFFSET * s * _noise.get_noise_2d(150.0, _t)
	cam.v_offset = MAX_OFFSET * s * _noise.get_noise_2d(200.0, _t)
	_update_lines(cam)


func _update_lines(cam: Camera3D) -> void:
	var v: Vector3 = player.velocity
	var walk: float = player.tune.walk_speed
	var top: float = player.top_speed()
	var from := walk * 1.4
	var k := clampf((v.length() - from) / maxf(top - from, 1.0), 0.0, 1.0)
	if player.flying or not Game.playing():
		k = 0.0
	_lines.strength = k * float(player.tune.speed_lines)
	if _lines.strength > 0.0:
		var ahead: Vector3 = cam.global_position + v.normalized() * 10.0
		if not cam.is_position_behind(ahead):
			var vp := cam.get_viewport().get_visible_rect().size
			var f := cam.unproject_position(ahead) / vp
			_lines.focus = _lines.focus.lerp(f.clamp(Vector2(0.2, 0.2), Vector2(0.8, 0.8)), 0.2)
	_lines.queue_redraw()


## A split-second freeze (real time), for a blow that should land hard.
func hit_stop(seconds: float) -> void:
	if player.tune.hit_stop < 0.5 or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	# Engine.set, not a lambda: the time scale comes back even if this node is freed
	get_tree().create_timer(seconds, true, false, true).timeout.connect(Engine.set.bind("time_scale", 1.0))


## Silver sparks where the hook bites, thrown back along `normal`.
func sparks(at: Vector3, normal: Vector3) -> void:
	_burst(at, normal, Color(0.92, 0.95, 1.0), 14, 2.0, 7.0, 0.35, 45.0, 9.0)


## A ring of dust round your feet on a hard landing (strength 0..1).
func dust(at: Vector3, strength: float) -> void:
	_burst(at + Vector3.UP * 0.1, Vector3.UP, Color(0.9, 0.9, 0.86, 0.8), int(10 + 14 * strength), 1.5, 3.0 + 3.0 * strength, 0.55, 80.0, 2.0)


func _burst(at: Vector3, dir: Vector3, col: Color, amount: int, v_min: float, v_max: float,
		life: float, spread: float, grav: float) -> void:
	if player.tune.particles < 0.5 or not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = dir if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3.DOWN * grav
	p.damping_min = 2.0
	p.damping_max = 4.0
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if col.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.material = mat
	p.mesh = m
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	p.scale_amount_curve = shrink
	var host: Node = player.get_parent()
	host.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
