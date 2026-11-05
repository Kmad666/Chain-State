class_name ChainLinks
## Steel chain: the link meshes and how links are laid along a path.
##
## A link is an oval of round wire: two half circles joined by short straights,
## 30 mm long and 19 mm wide in 5.2 mm wire, every other link turned 90 degrees
## so each threads through the next, a link's inner length (PITCH) apart.
##
## Two levels of detail keep a long chain cheap. Near the hand, where you can see
## the wire, each link is a smooth tube (`link_mesh`, 280 triangles). Farther out
## a link is a few pixels, so the chain is drawn in runs of four coarse links baked
## into one mesh (`run_mesh`, 48 triangles a link) and placed a quarter as often.
## Both are MultiMeshes: one draw call each, however long the chain.

const LENGTH := 0.030                   # outside length of a link
const WIDTH := 0.019                    # outside width
const WIRE := 0.0052                    # wire thickness
const PITCH := LENGTH - 2.0 * WIRE      # one link to the next: the inside length
const RUN := 4                          # links in one far-off run

static var _link: ArrayMesh
static var _run: ArrayMesh


## The detailed link, long along Z, wide along X, flat in Y, centred.
static func link_mesh() -> ArrayMesh:
	if _link == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_link(st, Transform3D.IDENTITY, 9, 8)
		_link = st.commit()
	return _link


## Four coarse links in a row along +Z from the origin, alternately turned.
static func run_mesh() -> ArrayMesh:
	if _run == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in RUN:
			var b := Basis() if i % 2 == 0 else Basis(Vector3.BACK, PI * 0.5)
			_add_link(st, Transform3D(b, Vector3(0, 0, i * PITCH)), 3, 3)
		_run = st.commit()
	return _run


## One link as a tube swept round a stadium-shaped centre line. `arc` segments
## round each rounded end, `tube` round the wire.
static func _add_link(st: SurfaceTool, xf: Transform3D, arc: int, tube: int) -> void:
	var rw := WIRE * 0.5
	var rc := WIDTH * 0.5 - rw                       # radius of the ends' centre line
	var h := (LENGTH * 0.5 - rw) - rc                # half the straight between them
	# the centre line, all the way round: one end's half circle, then the other's
	var path: Array[Vector3] = []
	for e in 2:
		var cz := h if e == 0 else -h
		for k in arc + 1:
			var phi := PI * (e + float(k) / arc)
			path.append(Vector3(rc * cos(phi), 0, cz + rc * sin(phi)))
	var n := path.size()
	var rings := []
	for i in n:
		var c: Vector3 = path[i]
		# every point lies on one of the half circles: out is away from its centre
		var out := (c - Vector3(0, 0, signf(c.z) * h)).normalized()
		var ring := []
		for j in tube:
			var a := TAU * j / tube
			var nrm := out * cos(a) + Vector3.UP * sin(a)
			ring.append([c + nrm * rw, nrm])
		rings.append(ring)
	for i in n:
		var r0: Array = rings[i]
		var r1: Array = rings[(i + 1) % n]
		for j in tube:
			var a: Array = r0[j]
			var b: Array = r0[(j + 1) % tube]
			var c: Array = r1[j]
			var d: Array = r1[(j + 1) % tube]
			_tri(st, xf, a, b, c)
			_tri(st, xf, b, d, c)


## A triangle wound so it faces along its vertices' normals (Godot fronts are clockwise).
static func _tri(st: SurfaceTool, xf: Transform3D, a: Array, b: Array, c: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var nsum: Vector3 = a[1] + b[1] + c[1]
	if (pc - pa).cross(pb - pa).dot(nsum) < 0.0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(xf.basis * (v[1] as Vector3))
		st.add_vertex(xf * (v[0] as Vector3))


## Lay links along a polyline, a PITCH apart, starting at its first point. Links
## are alternately turned 90 degrees about the line. `ups`, when given, holds a
## direction per point that the flat links should face (a surface's normal, so a
## coil lies on the arm); otherwise the chain picks its own. `sink`, for a path
## lying on a surface, lifts each link off it by its own half depth.
## Returns the transforms.
static func lay(pts: PackedVector3Array, ups := PackedVector3Array(), sink := false) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var carried := 0.0
	var next_at := 0.0
	var n := 0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.00001:
			continue
		var z := (b - a) / seg_len
		var up: Vector3 = ups[k] if ups.size() > k else (Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT)
		var y0 := (up - z * up.dot(z)).normalized()
		var x0 := y0.cross(z).normalized()
		while next_at <= carried + seg_len:
			var p := a + z * (next_at - carried)
			var flat := n % 2 == 0
			var basis := Basis(x0, y0, z) if flat else Basis(y0, -x0, z)
			if sink:
				p += y0 * ((WIRE * 0.5) if flat else (WIDTH * 0.5))
			out.append(Transform3D(basis, p))
			n += 1
			next_at += PITCH
		carried += seg_len
	return out
