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
		"cone": CylinderMesh.new(), "ball": SphereMesh.new()}
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
	_unit.ball.radial_segments = 16
	_unit.ball.rings = 8
	for k in ["prism", "cone"]:
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


func flush() -> void:
	for key in parts:
		var bits: PackedStringArray = key.split("|")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _unit[bits[0]]
		var xfs: Array = parts[key]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = material_for(Color.html(bits[1]))
		add_child(mi)
	parts.clear()


## Override for a different look per colour.
func material_for(col: Color) -> Material:
	return Mats.lit(col)
