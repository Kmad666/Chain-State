class_name Blockout
extends Node3D
## Base for kit-bashed landmarks built from a few unit shapes (box, prism, cylinder,
## cone, ball), each scaled and placed, then batched: one MultiMesh draw call per
## shape and colour. Solid pieces also get a matching collision shape on one
## StaticBody3D (world layer: solid and grapple-able).
##
## Subclasses override build() and call part() / part_b(); flush happens after.

var parts := {}                 # "kind|colour" -> [Transform3D]
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
var _unit := {}
var _hull := {}


func _ready() -> void:
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_unit = {"box": BoxMesh.new(), "prism": PrismMesh.new(), "cyl": CylinderMesh.new(),
		"cone": CylinderMesh.new(), "ball": SphereMesh.new(), "pyramid": CylinderMesh.new()}
	# a four-sided pyramid with a 1 x 1 base once turned 45 degrees (pass yaw = PI / 4)
	_unit.pyramid.top_radius = 0.0
	_unit.pyramid.bottom_radius = 0.70711
	_unit.pyramid.height = 1.0
	_unit.pyramid.radial_segments = 4
	_unit.pyramid.rings = 1
	_unit.cyl.top_radius = 0.5
	_unit.cyl.bottom_radius = 0.5
	_unit.cyl.height = 1.0
	_unit.cyl.radial_segments = 18
	_unit.cone.top_radius = 0.0
	_unit.cone.bottom_radius = 0.5
	_unit.cone.height = 1.0
	_unit.cone.radial_segments = 18
	_unit.ball.radius = 0.5
	_unit.ball.height = 1.0
	_unit.ball.radial_segments = 12      # half the triangles of 16 x 8; balls are trees,
	_unit.ball.rings = 6                 # bushes and clouds, read from a distance
	for k in ["prism", "cone", "pyramid"]:
		_hull[k] = (_unit[k] as Mesh).create_convex_shape().points
	build()
	flush()


## Override: lay out the pieces.
func build() -> void:
	pass


## A unit shape scaled to `size`, turned by `yaw` (and tipped by `tilt` about its own
## z axis), centred at `pos`.
func part(kind: String, col: Color, pos: Vector3, size: Vector3, yaw := 0.0, solid := true, tilt := 0.0) -> void:
	part_b(kind, col, pos, size, Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt), solid)


## The same with any rotation.
func part_b(kind: String, col: Color, pos: Vector3, size: Vector3, rot: Basis, solid := true) -> void:
	var key := "%s|%s" % [kind, col.to_html()]
	if not parts.has(key):
		parts[key] = []
	parts[key].append(Transform3D(rot * Basis.from_scale(size), pos))
	if not solid:
		return
	var cs := CollisionShape3D.new()
	match kind:
		"box":
			var b := BoxShape3D.new()
			b.size = size
			cs.shape = b
		"cyl":
			var c := CylinderShape3D.new()
			c.radius = size.x * 0.5
			c.height = size.y
			cs.shape = c
		"ball":
			var s := SphereShape3D.new()
			s.radius = size.x * 0.5
			cs.shape = s
		_:
			var hull := ConvexPolygonShape3D.new()
			var pts := PackedVector3Array()
			for p in _hull[kind]:
				pts.append(p * size)
			hull.points = pts
			cs.shape = hull
	cs.transform = Transform3D(rot, pos)
	body.add_child(cs)


## Batches are split into cells on the ground plan, so the camera can skip the cells
## it isn't looking at (one batch spanning a whole landmark is always drawn, even
## behind you). Cells are at least CHUNK metres and grow so a batch makes at most
## MAX_CELLS x MAX_CELLS of them; small batches stay whole, since below MIN_SPLIT
## pieces the extra draw calls cost more than the culling saves.
const CHUNK := 80.0
const MAX_CELLS := 3
const MIN_SPLIT := 48


func flush() -> void:
	for key in parts:
		var bits: PackedStringArray = key.split("|")
		var xfs: Array = parts[key]
		var cells := {}
		if xfs.size() < MIN_SPLIT:
			cells[Vector2i.ZERO] = xfs
		else:
			var lo := Vector2(INF, INF)
			var hi := -lo
			for xf in xfs:
				var o: Vector3 = xf.origin
				lo = Vector2(minf(lo.x, o.x), minf(lo.y, o.z))
				hi = Vector2(maxf(hi.x, o.x), maxf(hi.y, o.z))
			var span := hi - lo
			var size := maxf(CHUNK, maxf(span.x, span.y) / MAX_CELLS + 0.01)
			for xf in xfs:
				var o: Vector3 = xf.origin
				var c := Vector2i(floori((o.x - lo.x) / size), floori((o.z - lo.y) / size))
				if not cells.has(c):
					cells[c] = []
				cells[c].append(xf)
		var mat := material_for(Color.html(bits[1]))
		for c in cells:
			var list: Array = cells[c]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _unit[bits[0]]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = mat
			if not casts_shadow(Color.html(bits[1])):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
	parts.clear()


## Override to keep a colour out of the shadow pass (clouds, haze, far-off scenery).
func casts_shadow(_col: Color) -> bool:
	return true


## Override for a different look per colour.
func material_for(col: Color) -> Material:
	return Mats.lit(col)
