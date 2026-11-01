extends Node3D
## The silver chain, seen in first person. It lives inside the gloved hand: at rest
## only the arrowhead's point shows, nosing out of the fist. Fire and the chain
## spools out of the fist behind the flying arrowhead; let go and it reels back
## in, each link slipping into the hand until only the point is left.
##
## The player owns the hook's position and state (it matters for physics);
## this node only draws it. Links are one MultiMesh: one draw call however long.

enum { STOWED, FLYING, HOOKED, RETURNING }

const SILVER := Color(0.80, 0.83, 0.90)
const SILVER_BRIGHT := Color(0.93, 0.95, 1.0)
const LINK_SPACING := 0.06
const MAX_LINKS := 900
const ARROW_LEN := 0.20        # tip to the ring the chain hangs from (first-person scale)
const STOW_SHOW := 0.85       # how much of the arrowhead shows out of the fist at rest (its tail stays inside)
const SLIP := 0.05             # links shrink into the hand over this last stretch

var viewmodel: Node3D
var _mm: MultiMesh
var _links: MultiMeshInstance3D
var arrow: Node3D
var _t := 0.0
var _tension := 0.0            # 0 = slack, 1 = pulled taut
var first_link := Transform3D()   # the links at each end, as last laid (the renderer
var last_link := Transform3D()    # can't be read back in headless runs, so tests use these)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _link_mesh()
	_mm.instance_count = MAX_LINKS
	_mm.visible_instance_count = 0
	_links = MultiMeshInstance3D.new()
	_links.multimesh = _mm
	_links.material_override = Mats.polished(SILVER)
	_links.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_links.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(_links)

	arrow = Node3D.new()
	add_child(arrow)
	var am := MeshInstance3D.new()
	am.mesh = _arrow_mesh()
	am.material_override = Mats.polished(SILVER_BRIGHT)
	am.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(am)


## Where the arrow tip rests while stowed: just its point nosing out of the fist,
## the rest (and all the chain) inside the hand.
func stowed_tip(_aim_dir := Vector3.ZERO) -> Vector3:
	return viewmodel.fist_point() + viewmodel.forward() * ARROW_LEN * STOW_SHOW


## Called every frame by the player, after the arm has animated.
func update(dt: float, state: int, tip: Vector3, _aim_dir := Vector3.ZERO) -> void:
	_t += dt
	var taut := state == FLYING or state == HOOKED
	_tension = lerpf(_tension, 1.0 if taut else 0.0, 1.0 - exp(-(14.0 if taut else 5.0) * dt))

	var fist: Vector3 = viewmodel.fist_point()
	var fwd: Vector3 = viewmodel.forward()

	# Arrow
	var dir: Vector3
	if state == STOWED:
		dir = fwd
		tip = stowed_tip()
	else:
		dir = tip - fist
		dir = fwd if dir.length_squared() < 0.0001 else dir.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	arrow.global_transform = Transform3D(Basis.looking_at(dir, up), tip)
	var tail := tip - dir * ARROW_LEN

	# --- the chain as a polyline from the arrow's tail back to the fist: the links
	# are laid from the arrow end, so they ride out with the arrowhead and vanish
	# into the hand as it reels in
	var pts := PackedVector3Array()
	if state == STOWED:
		_mm.visible_instance_count = 0          # all of it is inside the hand
		return
	# a ripple runs along it while it flies or recoils, and it sags a touch when slack
	var seg := tail - fist
	var length := seg.length()
	var m := clampi(int(length / 0.25), 1, 160)
	var side := seg.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var ripple := 0.14 * (1.0 - _tension) + (0.0 if state == HOOKED else 0.035)
	var sag := 0.0 if state == HOOKED else length * 0.03 * (1.0 - _tension)
	pts.append(fist)
	for j in range(1, m + 1):
		var u := float(j) / m
		var env := sin(u * PI)
		var off := side * sin(u * PI * 3.0 - _t * 22.0) * env * ripple
		off.y -= env * sag
		pts.append(fist + seg * u + off)
	pts.reverse()                                # arrow first, fist last
	_place_links(pts, fist)


func _place_links(pts: PackedVector3Array, fist: Vector3) -> void:
	var n := 0
	var carried := 0.0
	var next_at := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.0001:
			continue
		var z := (b - a) / seg_len
		var helper := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
		var x0 := helper.cross(z).normalized()
		var y0 := z.cross(x0)
		while next_at <= carried + seg_len and n < MAX_LINKS:
			var p := a + z * (next_at - carried)
			# every other link turned 90 degrees, like a real chain
			var basis := Basis(x0, y0, z) if n % 2 == 0 else Basis(y0, -x0, z)
			# the last few centimetres before the fist, each link shrinks as it slips into the glove
			var into := clampf(p.distance_to(fist) / SLIP, 0.0, 1.0)
			if into < 1.0:
				basis = basis.scaled(Vector3.ONE * maxf(into, 0.05))
			var xf := Transform3D(basis, p)
			_mm.set_instance_transform(n, xf)
			if n == 0:
				first_link = xf
			last_link = xf
			n += 1
			next_at += LINK_SPACING
		carried += seg_len
	_mm.visible_instance_count = n


# ------------------------------------------------------------ meshes
## A fine oval chain link, long along Z, made of 8 bars.
static func _link_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := 0.040     # half length
	var b := 0.022     # half width
	var w := 0.011     # wire thickness
	for i in 8:
		var t0 := TAU * i / 8.0
		var t1 := TAU * (i + 1) / 8.0
		var p0 := Vector3(cos(t0) * b, 0, sin(t0) * a)
		var p1 := Vector3(cos(t1) * b, 0, sin(t1) * a)
		var d := p1 - p0
		var bar := BoxMesh.new()
		bar.size = Vector3(w, w, d.length() + w * 0.5)
		st.append_from(bar, 0, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p0 + p1) * 0.5))
	return st.commit()


## Slim diamond arrowhead. Tip at the origin pointing -Z; the body trails back
## along +Z to a small ring at +ARROW_LEN where the chain attaches.
static func _arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := ARROW_LEN / 0.17 * 0.82
	var tip := Vector3.ZERO
	var back := Vector3(0, 0, 0.17 * k)
	var w := 0.05 * k
	var ring := [Vector3(w, 0, 0.075 * k), Vector3(0, w * 0.5, 0.075 * k), Vector3(-w, 0, 0.075 * k), Vector3(0, -w * 0.5, 0.075 * k)]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		_face(st, tip, a, b, (a + b) * 0.5 - Vector3(0, 0, 0.03))
		_face(st, back, a, b, (a + b) * 0.5 + Vector3(0, 0, 0.2))
	# little barbs flaring back from the widest point
	for sx in [-1.0, 1.0]:
		var p := Vector3(sx * w, 0, 0.075 * k)
		_face(st, p, Vector3(sx * w * 1.45, 0, 0.17 * k), Vector3(sx * w * 0.6, 0, 0.13 * k), Vector3(0, 1, 0))
		_face(st, p, Vector3(sx * w * 1.45, 0, 0.17 * k), Vector3(sx * w * 0.6, 0, 0.13 * k), Vector3(0, -1, 0))
	var collar := BoxMesh.new()
	collar.size = Vector3(0.025, 0.025, ARROW_LEN - 0.17 * k)
	st.append_from(collar, 0, Transform3D(Basis(), Vector3(0, 0, (0.17 * k + ARROW_LEN) * 0.5)))
	return st.commit()


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(hint) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	for v in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(v)
