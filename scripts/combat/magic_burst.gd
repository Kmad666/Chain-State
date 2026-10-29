extends Node3D
## The purple magic burst when a Sentry is bound and the chain snaps: a
## semi-transparent sphere that swells fast and fades, with a brighter inner shell.

const LIFE := 0.9
const MAX_RADIUS := 11.0

var _t := 0.0
var warmup := false   # drawn invisibly for a few frames at level load, so its shaders are ready
var _warm_frames := 3
var _outer: MeshInstance3D
var _inner: MeshInstance3D
var _outer_mat: StandardMaterial3D
var _inner_mat: StandardMaterial3D


func _ready() -> void:
	_outer_mat = _mat(Color(0.62, 0.25, 1.0, 0.45))
	_inner_mat = _mat(Color(0.85, 0.65, 1.0, 0.6))
	_outer = _sphere(_outer_mat)
	_inner = _sphere(_inner_mat)
	# No OmniLight here on purpose: on the Compatibility renderer the first light
	# added mid-game makes the driver recompile every lit material in view, which
	# froze the screen for seconds right as the burst fired. The HUD's purple
	# flash carries the "light" instead.
	if warmup:
		_outer.scale = Vector3.ONE * 0.05
		_inner.scale = Vector3.ONE * 0.05
		_outer_mat.albedo_color.a = 0.01
		_inner_mat.albedo_color.a = 0.01


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED      # visible from inside too
	m.albedo_color = c
	return m


func _sphere(m: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 32
	s.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(dt: float) -> void:
	if warmup:
		_warm_frames -= 1
		if _warm_frames <= 0:
			queue_free()
		return
	_t += dt
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - k, 3.0)               # fast out, then eases
	_outer.scale = Vector3.ONE * lerpf(0.5, MAX_RADIUS, grow)
	_inner.scale = Vector3.ONE * lerpf(0.3, MAX_RADIUS * 0.55, grow)
	_outer_mat.albedo_color.a = 0.45 * (1.0 - k)
	_inner_mat.albedo_color.a = 0.6 * (1.0 - k) * (1.0 - k)
	if _t >= LIFE:
		queue_free()
