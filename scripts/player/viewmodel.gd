extends Node3D
## First-person arm: the detective's right forearm in a black suit sleeve, with a
## fitted black leather glove on an anatomically built hand, closed in a fist.
##
## The hand is modelled bone by bone: a palm with the thumb's fleshy base, four
## fingers of three phalanges each (index to little, real proportions, knuckles
## in an arc), and a thumb of metacarpal and two phalanges wrapping across the
## front of the fist. The glove has three stitched points on its back and a strap
## at the wrist. The chain lives inside the hand: it spools out of the fist when
## fired and reels back into it (chain.gd); at rest only the arrowhead's point shows.
##
## Lives under the camera. The player calls `animate()` every frame; the chain
## asks for `cuff_ring()`, `fist_point()` and `forward()` to know where to draw.

enum { STOWED, FLYING, HOOKED, RETURNING }   # same order as chain.gd

const SUIT := Color(0.055, 0.055, 0.065)          # black wool
const LINING := Color(0.02, 0.02, 0.025)
const LEATHER := Color(0.035, 0.032, 0.035)       # black glove leather
const STITCH := Color(0.12, 0.115, 0.12)
const STEEL := Color(0.55, 0.57, 0.62)

const REST_POS := Vector3(0.24, -0.27, -0.10)     # elbow pivot, camera space
const REST_DIR := Vector3(-0.16, 0.10, -1.0)      # forearm points a little in and up
const WRIST_Z := -0.235                           # pivot-local, along -Z
const FIST_Z := -0.37

## Finger bones, index to little: knuckle (MCP) position, then the lengths and
## radii of the proximal, middle and distal phalanges. Metres, glove included.
const FINGERS := [
	{"mcp": Vector3(-0.026, -0.001, -0.347), "len": [0.040, 0.024, 0.019], "r": 0.0098, "splay": -0.06},
	{"mcp": Vector3(-0.008, 0.001, -0.351), "len": [0.044, 0.028, 0.020], "r": 0.0100, "splay": -0.01},
	{"mcp": Vector3(0.010, -0.001, -0.347), "len": [0.041, 0.026, 0.019], "r": 0.0094, "splay": 0.03},
	{"mcp": Vector3(0.026, -0.005, -0.338), "len": [0.032, 0.020, 0.017], "r": 0.0084, "splay": 0.08},
]
## A closed fist: each joint's bend, measured from straight ahead and curling
## down and back (MCP about 85 degrees, PIP 100 more, DIP 55 more).
const CURL := [deg_to_rad(85.0), deg_to_rad(185.0), deg_to_rad(240.0)]
## The thumb: carpometacarpal base, MCP, IP and tip, wrapped across the front of
## the index and middle fingers.
const THUMB := [Vector3(-0.034, -0.008, -0.268), Vector3(-0.048, -0.024, -0.304),
	Vector3(-0.034, -0.044, -0.334), Vector3(-0.010, -0.048, -0.350)]
const THUMB_R := [0.0135, 0.0115, 0.0105]

var pivot: Node3D
var _t := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO          # lags behind mouse look
var _throw := 0.0                  # 0..1 punch-forward when the hook is fired
var _reach := 0.0                  # 0..1 arm raised toward the anchor while hooked
var _dir := REST_DIR.normalized()
var _land := 0.0                   # dips the arm when you hit the ground
var bones := 0                     # how many hand segments were built (for tests)


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	var suit := _cloth(SUIT)
	var lining := _cloth(LINING)
	var leather := _leather(LEATHER)
	var stitch := _leather(STITCH)
	var steel := Mats.metal(STEEL, 0.4)

	# --- the suit sleeve: wool tapering to the cuff, a dark opening at its end,
	# and four cuff buttons on the outer side
	var sleeve := _zcyl(0.058, 0.049, 0.27, -0.075, suit, 18)
	sleeve.scale = Vector3(1.0, 1.0, 0.9)    # (local z is the arm's up, local y its length)
	_zcyl(0.050, 0.050, 0.006, -0.212, lining, 18).scale = Vector3(1.0, 1.0, 0.9)
	for k in 4:
		var b := _ball(0.0055, Vector3(0.047, -0.016, -0.192 + k * 0.014), stitch)
		b.scale = Vector3(0.5, 1.0, 1.0)

	# --- the glove's cuff over the wrist, and a strap with the chain's ring
	var cuff := _zcyl(0.036, 0.032, 0.06, -0.226, leather, 16)
	cuff.scale = Vector3(1.12, 1.0, 0.82)          # a wrist is wider than it is deep
	var strap := _zcyl(0.0345, 0.0345, 0.012, WRIST_Z, stitch, 16)
	strap.scale = Vector3(1.14, 1.0, 0.84)
	_box(Vector3(0.012, 0.004, 0.014), Vector3(0.0, 0.029, WRIST_Z), steel)            # buckle

	# --- the hand
	# palm: the back of the hand is broad and flat, the heel and the thumb's
	# fleshy base (thenar eminence) rounder underneath
	var palm := _ball(0.5, Vector3(-0.001, -0.002, -0.298), leather)
	palm.scale = Vector3(0.086, 0.032, 0.108)
	var back := _ball(0.5, Vector3(0.0, 0.005, -0.306), leather)      # the back of the hand, over the metacarpals
	back.scale = Vector3(0.080, 0.024, 0.088)
	back.rotation.z = 0.05
	var thenar := _ball(0.5, Vector3(-0.029, -0.014, -0.284), leather)
	thenar.scale = Vector3(0.034, 0.030, 0.052)
	var hypothenar := _ball(0.5, Vector3(0.030, -0.012, -0.282), leather)
	hypothenar.scale = Vector3(0.026, 0.024, 0.050)
	# three stitched points on the glove's back, running toward the knuckles
	for k in 3:
		var x := -0.016 + k * 0.016
		var st := _box(Vector3(0.0018, 0.0014, 0.044), Vector3(x, 0.0166, -0.304), stitch)
		st.rotation.y = -0.05 + k * 0.05
	# fingers: three phalanges each, curled into the fist, a knuckle at each joint
	for f in FINGERS:
		var p: Vector3 = f.mcp
		var r: float = f.r
		_ball(r * 1.12, p + Vector3(0, 0.002, 0), leather)          # the knuckle head
		for k in 3:
			var th: float = CURL[k]
			var d := Vector3(sin(f.splay) * cos(th), -sin(th), -cos(th)).normalized()
			var q: Vector3 = p + d * float(f.len[k])
			_bone(p, q, r, leather)
			_ball(r * 1.02, q, leather)                              # PIP / DIP joint, fingertip
			p = q
			r *= 0.9
	# thumb: metacarpal, proximal and distal phalanges
	for k in 3:
		_bone(THUMB[k], THUMB[k + 1], THUMB_R[k], leather)
		_ball(THUMB_R[k] * 1.04, THUMB[k + 1], leather)
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


## World-space point on top of the glove's wrist strap (the buckle).
func cuff_ring() -> Vector3:
	return pivot.to_global(Vector3(0, 0.036, WRIST_Z))


## World-space point at the front of the fist, where the chain leaves the hand
## (between the curled fingers and the thumb).
func fist_point() -> Vector3:
	return pivot.to_global(Vector3(-0.012, -0.034, FIST_Z + 0.012))


## World-space direction the forearm points.
func forward() -> Vector3:
	return -pivot.global_basis.z.normalized()


## World-space transform of the forearm (for the coil around it).
func arm_xform() -> Transform3D:
	return pivot.global_transform


# ------------------------------------------------------------ mesh helpers
## One bone of the hand: a capsule from a to b.
func _bone(a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	var length := a.distance_to(b)
	m.radius = r
	m.height = length + r * 2.0
	m.radial_segments = 12
	m.rings = 3
	var mi := _mesh(m, (a + b) * 0.5, mat)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	bones += 1
	return mi


func _ball(r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	return _mesh(m, pos, mat)


func _torus(r: float, thick: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = r - thick
	m.outer_radius = r + thick
	m.rings = 16
	m.ring_segments = 6
	return _mesh(m, pos, mat)


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
