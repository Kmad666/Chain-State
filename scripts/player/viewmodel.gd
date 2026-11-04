extends Node3D
## First-person arm: the detective's right forearm in a black suit sleeve, a
## centimetre of white shirt cuff, and a fitted black leather glove on a hand of
## real proportions (arm_mesh.gd builds it as one mesh).
##
## The hand rests relaxed, fingers loosely curled, and clenches into a fist round
## the chain while you swing (the mesh's "fist" blend shape). The chain lives
## inside the hand: it spools out when fired and reels back in (chain.gd); at rest
## only the arrowhead's point shows.
##
## Lives under the camera. The player calls `animate()` every frame; the chain
## asks for `cuff_ring()`, `fist_point()` and `forward()` to know where to draw.

enum { STOWED, FLYING, HOOKED, RETURNING }   # same order as chain.gd

const SUIT := Color(0.055, 0.055, 0.065)          # black wool
const LINING := Color(0.02, 0.02, 0.025)
const SHIRT := Color(0.86, 0.86, 0.84)            # white cotton
const LEATHER := Color(0.035, 0.032, 0.035)       # black glove leather
const HORN := Color(0.03, 0.028, 0.03)            # cuff buttons

const REST_POS := Vector3(0.23, -0.25, -0.05)     # elbow pivot, camera space
const REST_DIR := Vector3(-0.16, 0.10, -1.0)      # forearm points a little in and up
const WRIST_Z := ArmMesh.WRIST_Z                  # pivot-local, along -Z

var pivot: Node3D
var _t := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO          # lags behind mouse look
var _throw := 0.0                  # 0..1 punch-forward when the hook is fired
var _reach := 0.0                  # 0..1 arm raised toward the anchor while hooked
var _dir := REST_DIR.normalized()
var _land := 0.0                   # dips the arm when you hit the ground
var grip := 0.0                    # 0 relaxed hand .. 1 fist round the chain
var arm: MeshInstance3D


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	arm = MeshInstance3D.new()
	arm.mesh = ArmMesh.build()
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.set_surface_override_material(ArmMesh.WOOL, _cloth(SUIT))
	arm.set_surface_override_material(ArmMesh.LINING, _cloth(LINING))
	arm.set_surface_override_material(ArmMesh.SHIRT, _cotton(SHIRT))
	arm.set_surface_override_material(ArmMesh.LEATHER, _leather(LEATHER))
	arm.set_surface_override_material(ArmMesh.BUTTONS, _leather(HORN))
	pivot.add_child(arm)
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

	# the hand closes round the chain while you hang from it, and opens again after
	grip = lerpf(grip, 1.0 if hooked else 0.0, 1.0 - exp(-(16.0 if hooked else 7.0) * dt))

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
	if arm:
		arm.set_blend_shape_value(0, grip)
	var up := Vector3.UP if absf(_dir.y) < 0.95 else Vector3.BACK
	pivot.basis = Basis.looking_at(_dir, up).rotated(_dir, -0.35 * (1.0 - _reach))  # knuckles tilt in at rest


## World-space point on top of the glove's wrist strap (the buckle).
func cuff_ring() -> Vector3:
	return pivot.to_global(Vector3(0, 0.022, WRIST_Z))


## World-space point at the front of the fist, where the chain leaves the hand
## (between the curled fingers and the thumb).
func fist_point() -> Vector3:
	return pivot.to_global(ArmMesh.CHAIN_RELAXED.lerp(ArmMesh.CHAIN_FIST, grip))


## World-space direction the forearm points.
func forward() -> Vector3:
	return -pivot.global_basis.z.normalized()


## World-space transform of the forearm (for the coil around it).
func arm_xform() -> Transform3D:
	return pivot.global_transform


# ------------------------------------------------------------ materials
## Black wool: matte, a faint sheen at grazing angles.
func _cloth(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.92
	m.metallic_specular = 0.2
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.3
	return m


## Black leather: darker than the wool, with a soft highlight on its curves.
func _leather(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.38
	m.metallic_specular = 0.55
	m.clearcoat_enabled = true
	m.clearcoat = 0.35
	m.clearcoat_roughness = 0.35
	return m


## White shirt cotton: matte.
func _cotton(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	return m
