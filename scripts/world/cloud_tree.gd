extends Node3D
## The Cloud Tree: a vast pale tree whose leaves are clouds, after Daniel's
## reference painting.
##
## - A tall, smooth, blue-white trunk with a flared root rises about 150 m, then
##   splits into great limbs.
## - The limbs fork twice more, out to a crown about 300 m tall and 300 m across.
## - Its foliage is cloud: clusters of soft puffs in white, cream, sky blue, mint,
##   pink and shadow blue, gathered round the branch tips and drifting below
##   the crown.
##
## The wood is solid world (it costs air grapples like any surface). The big cloud
## puffs are solid and magic: you can land on them, and grappling them is free, so
## the canopy can be climbed cloud to cloud. Small wisps are just decoration.
##
##   var t := preload("res://scripts/world/cloud_tree.gd").new()
##   t.position = Vector3(0, 0, 0)       # the trunk's foot sits at the origin
##   add_child(t)                        # builds itself; t.top_point(), t.puffs

const BARK := Color(0.80, 0.85, 0.90)       # pale blue-white wood
const BARK_SHADE := Color(0.70, 0.76, 0.84)
const CLOUDS := [Color(0.98, 0.98, 0.96), Color(0.99, 0.93, 0.78), Color(0.72, 0.86, 0.96),
	Color(0.78, 0.93, 0.88), Color(0.96, 0.76, 0.74), Color(0.66, 0.71, 0.82), Color(0.98, 0.98, 0.96)]
const TRUNK_H := 150.0

@export var tree_seed := 2024

var puffs: Array = []                 # [centre, radius] of every solid cloud
var branches := 0
var _rng := RandomNumberGenerator.new()
var _wood: Array = []                 # Transform3D of each tapered segment
var _cloud := {}                      # colour -> [Transform3D]
var _wood_body: StaticBody3D
var _cloud_body: StaticBody3D
var _seg_mesh: CylinderMesh
var _ball: SphereMesh
var _top := 0.0


func _ready() -> void:
	_rng.seed = tree_seed
	_wood_body = StaticBody3D.new()
	_wood_body.collision_layer = 1
	_wood_body.collision_mask = 0
	add_child(_wood_body)
	_cloud_body = StaticBody3D.new()
	_cloud_body.collision_layer = 1
	_cloud_body.collision_mask = 0
	_cloud_body.add_to_group("magic")            # free to grapple, like any magic
	add_child(_cloud_body)
	_seg_mesh = CylinderMesh.new()
	_seg_mesh.top_radius = 0.36                 # unit segment: 1 m tall, tapering
	_seg_mesh.bottom_radius = 0.5
	_seg_mesh.height = 1.0
	_seg_mesh.radial_segments = 14
	_seg_mesh.rings = 1
	_ball = SphereMesh.new()
	_ball.radius = 0.5
	_ball.height = 1.0
	_ball.radial_segments = 14
	_ball.rings = 8
	_build()
	_flush()


func top_point() -> Vector3:
	return global_position + Vector3(0, _top, 0)


func _build() -> void:
	# root flare: a wide skirt where the trunk meets the meadow
	var flare := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 13.0
	fm.bottom_radius = 30.0
	fm.height = 22.0
	fm.radial_segments = 24
	flare.mesh = fm
	flare.position = Vector3(0, 11.0 - 2.0, 0)
	flare.material_override = _bark_mat()
	add_child(flare)
	var fc := CollisionShape3D.new()
	fc.shape = fm.create_convex_shape()
	fc.position = flare.position
	_wood_body.add_child(fc)
	# the trunk: three gently leaning segments
	var p := Vector3(0, 8.0, 0)
	var r := 13.5
	var dir := Vector3.UP
	for k in 3:
		var piece := (TRUNK_H - 8.0) / 3.0
		dir = (dir + Vector3(_rng.randf_range(-0.05, 0.05), 0, _rng.randf_range(-0.05, 0.05))).normalized()
		_segment(p, dir, piece, r)
		p += dir * piece
		r *= 0.86
	# the great limbs, fanning out round the top of the trunk
	var limbs := 6
	var spin := _rng.randf() * TAU
	for i in limbs:
		var a := spin + TAU * i / limbs + _rng.randf_range(-0.3, 0.3)
		var lean := deg_to_rad(_rng.randf_range(38.0, 60.0))     # spreading wide, like the painting
		var d := Vector3(cos(a) * sin(lean), cos(lean), sin(a) * sin(lean))
		_branch(p - dir * _rng.randf_range(0.0, 14.0), d, _rng.randf_range(95.0, 125.0), r * 0.72, 0)
	# the leader: straight up the middle
	_branch(p, Vector3(0.05, 1, 0).normalized(), 120.0, r * 0.7, 0)
	# pink and blue puffs drifting below the crown, round the trunk
	for n in 18:
		var a := _rng.randf() * TAU
		var dist := _rng.randf_range(35.0, 190.0)
		_cluster(Vector3(cos(a) * dist, _rng.randf_range(95.0, 250.0), sin(a) * dist), _rng.randf_range(10.0, 18.0), 4, true)


## One tapering piece of wood from `p` along `dir`, `length` long, `r` thick at its foot.
func _segment(p: Vector3, dir: Vector3, length: float, r: float) -> void:
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	var rot := Basis(side, up, fwd)
	var mid := p + up * length * 0.5
	_wood.append(Transform3D(rot * Basis.from_scale(Vector3(r * 2.0, length, r * 2.0)), mid))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 0.86                      # between the foot and the tip
	cyl.height = length
	cs.shape = cyl
	cs.transform = Transform3D(rot, mid)
	_wood_body.add_child(cs)
	branches += 1
	_top = maxf(_top, (p + up * length).y)


## A limb that forks: it bends a little as it goes, splits into two or three
## children, and ends (at depth 3) in a cloud.
func _branch(p: Vector3, dir: Vector3, length: float, r: float, depth: int) -> void:
	var parts := 2
	var d := dir
	for k in parts:
		_segment(p, d, length / parts, r * pow(0.8, k))
		p += d * length / parts
		d = (d + Vector3(_rng.randf_range(-0.18, 0.18), _rng.randf_range(0.0, 0.12), _rng.randf_range(-0.18, 0.18))).normalized()
	var end_r := r * 0.64
	if depth >= 2 or end_r < 0.7:
		_cluster(p + d * 8.0, _rng.randf_range(18.0, 30.0), _rng.randi_range(6, 9), true)
		return
	var kids := _rng.randi_range(2, 3)
	var spin := _rng.randf() * TAU
	for i in kids:
		var a := spin + TAU * i / kids
		var out := Vector3(cos(a), 0, sin(a))
		var nd := (d * 0.8 + out * _rng.randf_range(0.6, 1.0) + Vector3.UP * 0.2).normalized()
		_branch(p, nd, length * _rng.randf_range(0.6, 0.75), end_r, depth + 1)
	# leaves along the way: a cloud resting on the fork itself
	if depth >= 1:
		_cluster(p + Vector3(0, 5, 0), _rng.randf_range(12.0, 20.0), 5, true)


## A cloud: a few flattened puffs of one or two colours around `c`. The biggest
## puff of each solid cloud is solid; the rest are soft wisps.
func _cluster(c: Vector3, size: float, n: int, solid: bool) -> void:
	var main: Color = CLOUDS[_rng.randi() % CLOUDS.size()]
	var accent: Color = CLOUDS[_rng.randi() % CLOUDS.size()]
	for i in n:
		var rad := size * (1.0 if i == 0 else _rng.randf_range(0.45, 0.8))
		var off := Vector3.ZERO if i == 0 else Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.4), _rng.randf_range(-1, 1)).normalized() * size * _rng.randf_range(0.6, 1.1)
		var col: Color = main if _rng.randf() < 0.7 else accent
		var sc := Vector3(rad * 2.0 * _rng.randf_range(1.0, 1.4), rad * 2.0 * 0.62, rad * 2.0 * _rng.randf_range(1.0, 1.4))
		var at := c + off
		if not _cloud.has(col):
			_cloud[col] = []
		_cloud[col].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(sc), at))
		if solid and i == 0:
			# a squashed sphere you can land on: a box-ish capsule would snag, so use
			# a flattened cylinder the size of the puff's core
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = rad * 0.85
			cyl.height = rad * 0.9
			cs.shape = cyl
			cs.position = at
			_cloud_body.add_child(cs)
			puffs.append([at, rad])
	_top = maxf(_top, c.y + size * 0.6)


func _flush() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _seg_mesh
	mm.instance_count = _wood.size()
	for i in _wood.size():
		mm.set_instance_transform(i, _wood[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _bark_mat()
	add_child(mi)
	for col in _cloud:
		var cm := MultiMesh.new()
		cm.transform_format = MultiMesh.TRANSFORM_3D
		cm.mesh = _ball
		var xfs: Array = _cloud[col]
		cm.instance_count = xfs.size()
		for i in xfs.size():
			cm.set_instance_transform(i, xfs[i])
		var ci := MultiMeshInstance3D.new()
		ci.multimesh = cm
		ci.material_override = _cloud_mat(col)
		ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ci)


func _bark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = BARK
	m.roughness = 1.0
	m.emission_enabled = true                 # painted-light softness: no deep shadow side
	m.emission = BARK_SHADE * 0.15
	return m


## Soft cloud: matte, lifted by its own colour so the shadow side stays pastel.
static var _cm := {}


static func _cloud_mat(col: Color) -> StandardMaterial3D:
	if not _cm.has(col):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 1.0
		m.metallic_specular = 0.0
		m.emission_enabled = true
		m.emission = col * 0.28
		_cm[col] = m
	return _cm[col]
