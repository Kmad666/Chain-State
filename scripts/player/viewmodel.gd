extends Node3D
## First-person arm: the detective's right forearm in a black suit sleeve, a
## centimetre of white shirt cuff, and a black leather glove closed in a fist on
## the chain. The model is built by tools/arm_model/build_arm.py (a seamless hand,
## meshed from a distance field) and dressed here in wool, cotton and leather.
##
## The arm is only in view while the chain is out: it comes up into frame as you
## fire and drops away once the chain is stowed. The chain is gripped in the fist
## and wound twice round the forearm (the coil, built here from chain_links.gd);
## the live chain runs out of the fist to the arrowhead (chain.gd).
##
## Lives under the camera. The player calls `animate()` every frame; the chain
## asks for `cuff_ring()`, `fist_point()` and `forward()` to know where to draw.

enum { STOWED, FLYING, HOOKED, RETURNING }   # same order as chain.gd

const SUIT := Color(0.055, 0.055, 0.065)          # black wool
const LINING := Color(0.02, 0.02, 0.025)
const SHIRT := Color(0.74, 0.74, 0.72)            # white cotton (kept off-white so it doesn't glare)
const LEATHER := Color(0.035, 0.032, 0.035)       # black glove leather
const HORN := Color(0.03, 0.028, 0.03)            # cuff buttons

const MODEL := "res://assets/models/arm/arm.glb"
const REST_POS := Vector3(0.21, -0.215, -0.08)     # elbow pivot, camera space
const REST_DIR := Vector3(-0.16, 0.12, -1.0)      # forearm points a little in and up
## A touch of turn past facing the eye square on, so the knuckles' edge still
## shows and the fist reads as a fist (radians, about the forearm).
const FACE_ROLL := 0.25
const WRIST_Z := -0.215                           # pivot-local, along -Z
## Where the chain runs out of the fist: the thumb side of the tunnel the fingers
## close round (arm space).
const CHAIN_EXIT := Vector3(-0.048, -0.032, -0.302)

var pivot: Node3D
var _t := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO          # lags behind mouse look
var _throw := 0.0                  # 0..1 punch-forward when the hook is fired
var _reach := 0.0                  # 0..1 arm raised toward the anchor while hooked
var _dir := REST_DIR.normalized()
var _land := 0.0                   # dips the arm when you hit the ground
var _show := 0.0                   # 0 out of view .. 1 up in frame
var always_show := false           # for tools and tests: keep it in view at rest
var arm: Node3D
var coil: MultiMeshInstance3D

## Lowered out of view: this far down and back (camera space) at _show = 0.
const AWAY := Vector3(0.06, -0.34, 0.10)
## The coil: two turns round the forearm just above the cuff.
const COIL_FROM := -0.166
const COIL_TO := -0.074
const COIL_START := -0.35             # angle round the arm the turns begin at (radians, from +X)


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	arm = (load(MODEL) as PackedScene).instantiate()
	pivot.add_child(arm)
	dress(arm)
	coil = build_coil()
	pivot.add_child(coil)
	_show = 1.0 if always_show else 0.0
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
	# up into frame as soon as the chain is fired, away again once it's stowed
	var up := state != STOWED or always_show
	_show = lerpf(_show, 1.0 if up else 0.0, 1.0 - exp(-(16.0 if up else 5.0) * dt))
	if up and _show > 0.995:
		_show = 1.0
	_apply(walk)


func _apply(walk: float) -> void:
	var p := REST_POS
	p += Vector3(sin(_bob) * 0.012, -absf(cos(_bob)) * 0.014, 0) * walk
	p += Vector3(_sway.x, _sway.y, 0)
	p += Vector3(0, 0.002 * sin(_t * 1.7), 0)              # breathing
	p += Vector3(-0.02, 0.04, -0.07) * _throw              # punch out
	p += Vector3(-0.03, 0.10, -0.02) * _reach              # raise to hold the chain
	p.y -= 0.035 * _land
	# roll the forearm so the palm side of the fist, its curled fingers and the
	# thumb across them, faces the camera (the arm's -Y toward the eye)
	var to_eye := -p.normalized()
	var away := 1.0 - _show
	p += AWAY * away * away * (3.0 - 2.0 * away)
	pivot.position = p
	pivot.visible = _show > 0.01
	var palm := to_eye - _dir * to_eye.dot(_dir)
	var up := -palm.normalized() if palm.length_squared() > 0.0001 else Vector3.UP
	pivot.basis = Basis.looking_at(_dir, up).rotated(_dir, FACE_ROLL)


## Give the model's parts their materials (by mesh name) and keep the arm out of
## the shadow pass.
func dress(model: Node) -> void:
	var mats := {"glove": _leather(LEATHER), "sleeve": _cloth(SUIT), "lining": _cloth(LINING),
		"shirt": _cotton(SHIRT), "buttons": _horn(HORN)}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in mats:
			if String(m.name).begins_with(k):
				m.material_override = mats[k]


## True while the arm is up in frame (the chain hides its arrowhead otherwise).
func shown() -> bool:
	return pivot != null and pivot.visible


## Radius of the sleeve at z, round the arm (tools/arm_model/build_arm.py's
## sleeve, without its folds): half-width, half-height, and its centre's drop.
static func sleeve_at(z: float) -> Vector3:
	var t := (0.30 - z) / (0.30 + 0.178)
	var belly := sin(clampf(t, 0.0, 1.0) * PI) * 0.0035
	var e := pow(clampf(t, 0.0, 1.0), 1.15)
	return Vector3(0.0675 + (0.0462 - 0.0675) * e + belly, 0.0625 + (0.0432 - 0.0625) * e + belly, -0.004 * t)


## A point on the sleeve's surface at angle a (from +X toward +Y) and height z,
## standing `lift` off it, and the surface's outward normal there.
static func on_sleeve(a: float, z: float, lift: float) -> Array:
	var r := sleeve_at(z)
	var ry: float = r.y * (1.0 + 0.06 * clampf((0.30 - z) / 0.478, 0, 1) * maxf(0.0, -sin(a)))
	var nrm := Vector3(cos(a) / r.x, sin(a) / ry, 0).normalized()
	return [Vector3(cos(a) * r.x, sin(a) * ry + r.z, z) + nrm * lift, nrm]


## The chain held in the fist and wound round the arm, in arm space: in at the
## thumb side of the grip, through the fist, out past the little finger, back
## along the wrist and twice round the forearm above the cuff, then up the sleeve
## out of sight. One MultiMesh of steel links.
static func build_coil() -> MultiMeshInstance3D:
	var pts := PackedVector3Array()
	var ups := PackedVector3Array()
	# through the grip and out of the little-finger side, curving back to the arm
	var lead := [CHAIN_EXIT, Vector3(-0.020, -0.034, -0.302), Vector3(0.020, -0.034, -0.300),
		Vector3(0.050, -0.034, -0.294), Vector3(0.054, -0.030, -0.272), Vector3(0.046, -0.024, -0.246),
		Vector3(0.044, -0.020, -0.214)]
	var first: Array = on_sleeve(COIL_START, COIL_FROM, 0.0035)
	lead.append(first[0] + Vector3(0, 0, -0.02))
	lead.append(first[0])
	for i in range(lead.size() - 1):
		var a: Vector3 = lead[i]
		var b: Vector3 = lead[i + 1]
		var pre: Vector3 = lead[i - 1] if i > 0 else a - (b - a)
		var post: Vector3 = lead[i + 2] if i + 2 < lead.size() else b + (b - a)
		for k in 8:
			pts.append(a.cubic_interpolate(b, pre, post, k / 8.0))
			ups.append(Vector3.UP if i < 3 else Vector3.RIGHT)
	# two turns, wound snug against the wool
	var steps := 160
	for k in steps + 1:
		var u := float(k) / steps
		var s: Array = on_sleeve(COIL_START + u * TAU * 2.0, lerpf(COIL_FROM, COIL_TO, u), 0.0035)
		pts.append(s[0])
		ups.append(s[1])
	# then up the arm, out of view toward the elbow
	var end_a := COIL_START + TAU * 2.0
	for z in [COIL_TO + 0.02, 0.0, 0.08, 0.16, 0.24]:
		var s: Array = on_sleeve(end_a + (z - COIL_TO) * 0.6, z, 0.0035)
		pts.append(s[0])
		ups.append(s[1])
	var xfs := ChainLinks.lay(pts, ups, true)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ChainLinks.link_mesh()
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Coil"
	mi.multimesh = mm
	mi.material_override = Mats.steel()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## World-space point on top of the glove's wrist strap (the buckle).
func cuff_ring() -> Vector3:
	return pivot.to_global(Vector3(0, 0.022, WRIST_Z))


## World-space point at the front of the fist, where the chain leaves the hand
## (between the curled fingers and the thumb).
func fist_point() -> Vector3:
	return pivot.to_global(CHAIN_EXIT)


## World-space direction the forearm points.
func forward() -> Vector3:
	return -pivot.global_basis.z.normalized()


## World-space transform of the forearm (for the coil around it).
func arm_xform() -> Transform3D:
	return pivot.global_transform


# ------------------------------------------------------------ materials
## Surface detail is a fine normal map laid on in the arm's own space (triplanar,
## local), so the grain stays put on the arm instead of sliding as it moves.

static var _grain: Texture2D
static var _crease: Texture2D
static var _weave: Texture2D


## Pebbled glove leather: tiny cells about a millimetre across.
static func _leather_grain() -> Texture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.06
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0
		t.noise = n
		_grain = t
	return _grain


## Worn glove leather: a net of fine creases a few millimetres apart, where the
## leather has flexed (ridged noise reads as crinkles rather than bumps).
static func _leather_crease() -> Texture2D:
	if _crease == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		n.fractal_octaves = 2
		n.fractal_gain = 0.4
		var t := NoiseTexture2D.new()
		t.width = 512
		t.height = 512
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 1.6
		t.noise = n
		_crease = t
	return _crease


## Worsted wool: a faint, fine weave.
static func _wool_weave() -> Texture2D:
	if _weave == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX
		n.frequency = 0.25
		n.fractal_octaves = 2
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 3.0
		t.noise = n
		_weave = t
	return _weave


static func _detail(m: StandardMaterial3D, tex: Texture2D, strength: float, metres: float) -> void:
	m.normal_enabled = true
	m.normal_texture = tex
	m.normal_scale = strength
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3.ONE / metres         # one tile per this many metres
	m.uv1_triplanar_sharpness = 2.0


## Black wool: matte, a soft sheen at grazing angles, a faint weave.
func _cloth(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.88
	m.metallic_specular = 0.3
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.4
	_detail(m, _wool_weave(), 0.35, 0.03)
	return m


## Black glove leather: a satin sheen rather than a gloss, broken up by the grain.
func _leather(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.46
	m.metallic_specular = 0.5
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.6
	_detail(m, _leather_grain(), 0.40, 0.02)
	# the creases ride on a second, larger tiling, laid on the same way
	m.detail_enabled = true
	m.detail_normal = _leather_crease()
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_world_triplanar = false
	m.uv2_scale = Vector3.ONE / 0.07
	m.uv2_triplanar_sharpness = 2.0
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL     # no detail colour: white times black stays black
	return m


## Horn buttons: smooth and polished.
func _horn(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.25
	return m


## Cotton (the shirt cuff, the glove's thread): matte.
func _cotton(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	_detail(m, _wool_weave(), 0.15, 0.02)
	return m
