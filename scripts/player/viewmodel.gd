extends Node3D
## First-person arm: her right forearm in a cloak sleeve, a leather glove and a
## silver cuff at the wrist. The silver chain is fastened to a ring on the cuff,
## coils around the forearm, and the arrowhead rests in her fist.
##
## Lives under the camera. The player calls `animate()` every frame; the chain
## asks for `cuff_ring()`, `fist_point()` and `forward()` to know where to draw.

enum { STOWED, FLYING, HOOKED, RETURNING }   # same order as chain.gd

const CLOAK := Color(0.36, 0.20, 0.38)
const GLOVE := Color(0.25, 0.17, 0.12)
const SILVER := Color(0.80, 0.83, 0.90)

const REST_POS := Vector3(0.24, -0.27, -0.10)     # elbow pivot, camera space
const REST_DIR := Vector3(-0.16, 0.10, -1.0)      # forearm points a little in and up
const WRIST_Z := -0.25                            # pivot-local, along -Z
const FIST_Z := -0.37

var pivot: Node3D
var _t := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO          # lags behind mouse look
var _throw := 0.0                  # 0..1 punch-forward when the hook is fired
var _reach := 0.0                  # 0..1 arm raised toward the anchor while hooked
var _dir := REST_DIR.normalized()
var _land := 0.0                   # dips the arm when you hit the ground


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	var sleeve := Mats.lit(CLOAK)
	var glove := Mats.lit(GLOVE)
	var silver := Mats.metal(SILVER)

	# sleeve: wide cloak cuff that tapers toward the wrist
	_zcyl(0.075, 0.062, 0.18, -0.04, sleeve, 7)
	# gloved forearm under the silver cuff
	_zcyl(0.050, 0.044, 0.12, -0.17, glove, 6)
	# silver cuff with a raised rim at each edge and a ring on top for the chain
	_zcyl(0.056, 0.056, 0.045, WRIST_Z, silver, 8)
	_zcyl(0.061, 0.061, 0.010, WRIST_Z + 0.022, silver, 8)
	_zcyl(0.061, 0.061, 0.010, WRIST_Z - 0.022, silver, 8)
	_box(Vector3(0.022, 0.026, 0.012), Vector3(0, 0.066, WRIST_Z), silver)
	# hand: back of the hand, knuckles curled round the arrowhead, thumb on top
	_box(Vector3(0.082, 0.036, 0.085), Vector3(0, 0.002, -0.315), glove)
	for i in 4:
		var x := -0.030 + i * 0.020
		var f := _box(Vector3(0.018, 0.024, 0.040), Vector3(x, -0.016, -0.356), glove)
		f.rotation.x = 1.0
	var thumb := _box(Vector3(0.022, 0.022, 0.055), Vector3(-0.046, 0.012, -0.335), glove)
	thumb.rotation = Vector3(0.2, -0.5, 0.3)
	_apply(1.0)


## Called every frame by the player.
func animate(dt: float, state: int, tip: Vector3, vel: Vector3, on_floor: bool,
		look_delta: Vector2, landed: bool) -> void:
	_t += dt
	var cam := get_parent() as Node3D
	var hs := Vector2(vel.x, vel.z).length()

	# walking bob (only on the ground)
	var walk := clampf(hs / 6.0, 0.0, 1.0) if on_floor else 0.0
	_bob += dt * (6.0 + hs * 1.1) * walk

	# sway lags behind mouse look, then springs back
	_sway = _sway.lerp(Vector2(-look_delta.x, look_delta.y) * 0.00045, 1.0 - exp(-12.0 * dt))
	_sway = _sway.limit_length(0.05)
	if landed:
		_land = 1.0
	_land = maxf(_land - dt * 4.0, 0.0)

	# punch forward while the hook is in flight, reach toward the anchor while hooked
	var throwing := state == FLYING
	_throw = lerpf(_throw, 1.0 if throwing else 0.0, 1.0 - exp(-(22.0 if throwing else 8.0) * dt))
	var hooked := state == HOOKED
	_reach = lerpf(_reach, 1.0 if hooked else 0.0, 1.0 - exp(-(10.0 if hooked else 6.0) * dt))

	var want := REST_DIR.normalized()
	if state != STOWED:
		var local := cam.global_basis.inverse() * (tip - cam.global_position)
		if local.length_squared() > 0.0001:
			local = local.normalized()
			# keep the hand on screen: never point the forearm sideways or backwards
			local.z = minf(local.z, -0.45)
			local.x = clampf(local.x, -0.55, 0.45)
			local.y = clampf(local.y, -0.35, 0.75)
			want = want.slerp(local.normalized(), maxf(_throw, _reach) * 0.85).normalized()
	_dir = _dir.slerp(want, 1.0 - exp(-14.0 * dt)).normalized()
	_apply(walk)


func _apply(walk: float) -> void:
	var p := REST_POS
	p += Vector3(sin(_bob) * 0.012, -absf(cos(_bob)) * 0.014, 0) * walk
	p += Vector3(_sway.x, _sway.y, 0)
	p += Vector3(0, 0.002 * sin(_t * 1.7), 0)              # breathing
	p += Vector3(-0.02, 0.04, -0.07) * _throw              # punch out
	p += Vector3(-0.03, 0.10, -0.02) * _reach              # raise to hold the chain
	p.y -= 0.035 * _land
	pivot.position = p
	var up := Vector3.UP if absf(_dir.y) < 0.95 else Vector3.BACK
	pivot.basis = Basis.looking_at(_dir, up).rotated(_dir, -0.35 * (1.0 - _reach))  # knuckles tilt in at rest


## World-space ring on top of the cuff the chain is fastened to.
func cuff_ring() -> Vector3:
	return pivot.to_global(Vector3(0, 0.074, WRIST_Z))


## World-space point inside her fist where the chain leaves the hand.
func fist_point() -> Vector3:
	return pivot.to_global(Vector3(0, -0.004, FIST_Z + 0.01))


## World-space direction the forearm points.
func forward() -> Vector3:
	return -pivot.global_basis.z.normalized()


## World-space transform of the forearm (for the coil around it).
func arm_xform() -> Transform3D:
	return pivot.global_transform


# ------------------------------------------------------------ mesh helpers
func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, pos, mat)


## Cylinder lying along Z, centred at z.
func _zcyl(r_back: float, r_front: float, length: float, z: float, mat: Material, seg := 6) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_front
	m.bottom_radius = r_back
	m.height = length
	m.radial_segments = seg
	m.rings = 1
	var mi := _mesh(m, Vector3(0, 0, z), mat)
	mi.rotation.x = -PI * 0.5   # cylinder's +Y (top) now points -Z (toward the hand)
	return mi


func _mesh(m: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	return mi
