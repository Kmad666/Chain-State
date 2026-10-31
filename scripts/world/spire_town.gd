extends Node3D
## Spire Town: a fairy-tale town on two great rock pillars rising out of the clouds,
## after Daniel's reference painting.
##
## - The **west pillar** is broad. A palace with a great window front and a teal
##   hipped roof crowns it, with turrets round it and a 90 m main tower whose
##   spire is the highest point. Two tiers of houses ring its sides.
## - The **east pillar** is slim and taller, with a lone tower on top. Pastel
##   houses cling round it on shelves, with a timber walkway spiralling up
##   between them.
## - **Three crossings** join the pillars:
##   - a stone viaduct on arches near the bottom
##   - a rock arch higher up
##   - a rope-railed plank bridge from a palace turret to the east tower
##
## Everything is world geometry (solid and grapple-able) built from a handful of
## unit meshes in MultiMesh batches: one draw call per shape and colour.
## The node's origin is the cloud line, where the pillars' bases fade into the
## cloud sea, and the town climbs about 250 m above it.
##
##   var t := preload("res://scripts/world/spire_town.gd").new()
##   t.position = Vector3(0, 0, 0)
##   add_child(t)          # builds itself; t.start_point() and t.top_point()

const STONE := Color(0.87, 0.86, 0.79)      # cream castle stone
const ROCK := Color(0.56, 0.60, 0.56)       # grey-green cliff
const ROCK_DARK := Color(0.45, 0.49, 0.46)
const MOSS := Color(0.42, 0.58, 0.36)
const TEAL := Color(0.32, 0.60, 0.58)       # verdigris copper roofs and spires
const SLATE := Color(0.26, 0.31, 0.40)      # house roofs
const GLASS := Color(0.16, 0.20, 0.30)      # windows
const TIMBER := Color(0.40, 0.28, 0.18)
const GOLD := Color(0.85, 0.68, 0.25)
const WALLS := [Color(0.50, 0.62, 0.82), Color(0.93, 0.84, 0.47), Color(0.90, 0.90, 0.86),
	Color(0.62, 0.72, 0.86), Color(0.86, 0.80, 0.62)]   # pastel blue, butter, white, sky, sand

## the two pillars: centre (x, z) and [height, radius] going up
const WEST := Vector2(-55, 0)
const WEST_LEVELS := [[0.0, 47.0], [40.0, 45.0], [80.0, 42.0], [120.0, 39.0], [150.0, 37.0]]
const EAST := Vector2(50, 0)
const EAST_LEVELS := [[0.0, 29.0], [50.0, 27.0], [100.0, 25.0], [140.0, 22.0], [160.0, 21.0]]
const RIM := 30

var parts := {}                 # "kind|colour" -> [Transform3D]
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _unit := {}                 # kind -> unit Mesh
var _hull := {}                 # kind -> unit convex points (for prisms and cones)
var spire_top := Vector3.ZERO
var shelves: Array = []         # [centre, size] of every walkable house shelf


func _ready() -> void:
	_rng.seed = 4711
	_body = StaticBody3D.new()
	_body.collision_layer = 1            # world: solid and grapple-able
	_body.collision_mask = 0
	add_child(_body)
	_unit = {"box": BoxMesh.new(), "prism": PrismMesh.new(), "cyl": CylinderMesh.new(),
		"cone": CylinderMesh.new(), "ball": SphereMesh.new()}
	_unit.cyl.top_radius = 0.5
	_unit.cyl.bottom_radius = 0.5
	_unit.cyl.height = 1.0
	_unit.cyl.radial_segments = 16
	_unit.cone.top_radius = 0.0
	_unit.cone.bottom_radius = 0.5
	_unit.cone.height = 1.0
	_unit.cone.radial_segments = 16
	_unit.ball.radius = 0.5
	_unit.ball.height = 1.0
	_unit.ball.radial_segments = 10
	_unit.ball.rings = 6
	for k in ["prism", "cone"]:
		var pts: PackedVector3Array = (_unit[k] as Mesh).create_convex_shape().points
		_hull[k] = pts

	_column(WEST, WEST_LEVELS, 11)
	_column(EAST, EAST_LEVELS, 23)
	_viaduct()
	_rock_arch()
	_west_town()
	_east_town()
	_crown()
	_plank_bridge()
	_flush()


func start_point() -> Vector3:
	return Vector3(0, 41, 95)


func top_point() -> Vector3:
	return spire_top


static func radius_at(levels: Array, y: float) -> float:
	for i in levels.size() - 1:
		if y <= levels[i + 1][0]:
			var t: float = (y - levels[i][0]) / (levels[i + 1][0] - levels[i][0])
			return lerpf(levels[i][1], levels[i + 1][1], clampf(t, 0.0, 1.0))
	return levels[levels.size() - 1][1]


# ---------------------------------------------------------------- shapes
## Queue one piece: a unit mesh scaled to `size`, turned by `yaw`, at `pos` (its
## centre). Solid pieces also get a matching collision shape.
func part(kind: String, col: Color, pos: Vector3, size: Vector3, yaw := 0.0, solid := true, tilt := 0.0) -> void:
	var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt)
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
	_body.add_child(cs)


func _flush() -> void:
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
		mi.material_override = Mats.lit(Color.html(bits[1]))
		add_child(mi)
	parts.clear()


## A rock pillar: jagged rings stacked up the given [height, radius] levels, a flat
## top, and its foot sunk below the cloud line.
func _column(c: Vector2, levels: Array, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var rings: Array = []
	var phase := rng.randf() * TAU
	var lv: Array = [[-60.0, levels[0][1] * 1.08]] + levels
	for l in lv:
		var ring: Array[Vector3] = []
		for i in RIM:
			var a := TAU * i / RIM
			var k := 1.0 + 0.07 * sin(3.0 * a + phase + l[0] * 0.03) + rng.randf_range(-0.06, 0.06)
			ring.append(Vector3(c.x + cos(a) * l[1] * k, l[0] + rng.randf_range(-2.0, 2.0) * (1.0 if l[0] > 0.0 and l != lv[lv.size() - 1] else 0.0), c.y + sin(a) * l[1] * k))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings.size() - 1:
		var dn: Array = rings[r]
		var up: Array = rings[r + 1]
		for i in RIM:
			var j := (i + 1) % RIM
			st.add_vertex(up[i]); st.add_vertex(dn[i]); st.add_vertex(up[j])    # same winding as FloatingIsland
			st.add_vertex(up[j]); st.add_vertex(dn[i]); st.add_vertex(dn[j])
	var top: Array = rings[rings.size() - 1]
	var mid := Vector3(c.x, top[0].y, c.y)
	for i in RIM:
		st.add_vertex(mid); st.add_vertex(top[i]); st.add_vertex(top[(i + 1) % RIM])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.grid(ROCK, ROCK_DARK, 1)
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	_body.add_child(cs)
	# moss: soft green tufts clinging to the cliff
	for n in 26:
		var y := rng.randf_range(10.0, levels[levels.size() - 1][0] - 6.0)
		var a := rng.randf() * TAU
		var r := radius_at(levels, y) * 0.97
		var sz := rng.randf_range(4.0, 9.0)
		part("ball", MOSS, Vector3(c.x + cos(a) * r, y, c.y + sin(a) * r), Vector3(sz, sz * 0.6, sz), 0.0, false)


# ---------------------------------------------------------------- crossings
## A stone viaduct low between the pillars: a deck on three round-topped arches.
func _viaduct() -> void:
	var x0 := WEST.x + radius_at(WEST_LEVELS, 52.0) - 4.0
	var x1 := EAST.x - radius_at(EAST_LEVELS, 52.0) + 4.0
	var y := 52.0
	var span := x1 - x0
	part("box", STONE, Vector3((x0 + x1) * 0.5, y, 0), Vector3(span, 2.0, 9.0))
	for s in [-1.0, 1.0]:
		part("box", STONE, Vector3((x0 + x1) * 0.5, y + 1.6, s * 4.2), Vector3(span, 1.2, 0.6))
	var piers := 4
	for i in piers:
		var x := lerpf(x0 + 3.0, x1 - 3.0, float(i) / (piers - 1))
		part("box", STONE, Vector3(x, y - 16.0, 0), Vector3(5.0, 30.0, 8.0))
	for i in piers - 1:
		var xa := lerpf(x0 + 3.0, x1 - 3.0, float(i) / (piers - 1))
		var xb := lerpf(x0 + 3.0, x1 - 3.0, float(i + 1) / (piers - 1))
		for k in 7:                                  # arch voussoirs under the deck
			var t := (k + 0.5) / 7.0
			var x := lerpf(xa + 2.5, xb - 2.5, t)
			var dy := sin(t * PI) * 5.0
			part("box", STONE, Vector3(x, y - 7.0 + dy, 0), Vector3((xb - xa - 5.0) / 7.0 + 0.2, 3.0, 8.0), 0.0, false)


## A rock arch springing between the pillars higher up (the window you see sky through).
func _rock_arch() -> void:
	var xa := WEST.x + radius_at(WEST_LEVELS, 100.0) - 6.0
	var xb := EAST.x - radius_at(EAST_LEVELS, 100.0) + 6.0
	var n := 11
	for k in n:
		var t := (k + 0.5) / n
		var x := lerpf(xa, xb, t)
		var y := 100.0 + sin(t * PI) * 22.0
		var slope := atan(cos(t * PI) * 22.0 * PI / (xb - xa))      # tip each block along the curve
		part("box", ROCK, Vector3(x, y, 2.0), Vector3((xb - xa) / n + 3.0, 9.0 - sin(t * PI) * 3.0, 14.0), 0.0, true, slope)
		if k % 3 == 1:
			part("ball", MOSS, Vector3(x, y + 4.0, 2.0), Vector3(6, 3, 8), 0.0, false)


## A plank bridge with rope rails, from a palace turret across to the east tower.
func _plank_bridge() -> void:
	var a := Vector3(WEST.x + 27.5 + 3.0, 168.0, 0.0)     # the east-edge turret's side
	var b := Vector3(EAST.x - 5.5, 168.0, 0.0)            # the east tower's west face
	var n := 22
	for k in n:
		var t := (k + 0.5) / n
		var p := a.lerp(b, t) + Vector3(0, -sin(t * PI) * 2.5, 0)      # a slight sag
		part("box", TIMBER, p, Vector3((b.x - a.x) / n - 0.15, 0.3, 3.2))
		if k % 3 == 0:
			for s in [-1.0, 1.0]:
				part("box", TIMBER, p + Vector3(0, 0.6, s * 1.5), Vector3(0.2, 1.2, 0.2), 0.0, false)
	for s in [-1.0, 1.0]:
		for k in n:
			var t := (k + 0.5) / n
			var p := a.lerp(b, t) + Vector3(0, 1.2 - sin(t * PI) * 2.5, s * 1.5)
			part("box", Color(0.62, 0.52, 0.36), p, Vector3((b.x - a.x) / n, 0.08, 0.08), 0.0, false)


# ---------------------------------------------------------------- buildings
## A pastel town house facing out (yaw), standing on a stone shelf jutting from the
## cliff: walls, a steep slate roof, windows and a chimney.
func _house(base: Vector3, yaw: float, w: float, h: float, d: float, wall: Color) -> void:
	var out := Basis(Vector3.UP, yaw)
	part("box", STONE, base + Vector3(0, -0.8, 0), Vector3(w + 2.0, 1.6, d + 2.0), yaw)          # shelf
	part("box", ROCK_DARK, base + out * Vector3(0, -4.5, -d * 0.25), Vector3(w * 0.7, 6.0, d * 0.5), yaw, false)   # corbel
	shelves.append([base, Vector3(w + 2.0, 1.6, d + 2.0)])
	part("box", wall, base + Vector3(0, h * 0.5, 0), Vector3(w, h, d), yaw)
	part("prism", SLATE, base + Vector3(0, h + 2.6, 0), Vector3(w + 0.8, 5.2, d + 0.8), yaw)
	for row in int(h / 3.2):
		for col in [-1.0, 1.0]:
			part("box", GLASS, base + out * Vector3(col * w * 0.25, 2.0 + row * 3.0, d * 0.5 + 0.06), Vector3(1.0, 1.5, 0.12), yaw, false)
	part("box", ROCK_DARK, base + out * Vector3(w * 0.3, h + 4.5, -d * 0.2), Vector3(1.0, 3.0, 1.0), yaw, false)


## A round turret: stone drum, a teal cone spire and a gold finial.
func _turret(base: Vector3, r: float, h: float, cone_h: float, finial := true) -> Vector3:
	part("cyl", STONE, base + Vector3(0, h * 0.5, 0), Vector3(r * 2.0, h, r * 2.0))
	part("cyl", STONE, base + Vector3(0, h - 0.4, 0), Vector3(r * 2.3, 0.8, r * 2.3))
	part("cone", TEAL, base + Vector3(0, h + cone_h * 0.5, 0), Vector3(r * 2.4, cone_h, r * 2.4))
	for k in int(h / 6.0):
		part("box", GLASS, base + Vector3(0, 4.0 + k * 6.0, r + 0.05), Vector3(1.0, 2.2, 0.15), 0.0, false)
	var tip := base + Vector3(0, h + cone_h, 0)
	if finial:
		part("ball", GOLD, tip + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), 0.0, false)
		part("box", GOLD, tip + Vector3(0, 1.8, 0), Vector3(0.25, 2.4, 0.25), 0.0, false)
	return tip


## Houses ringed round a pillar at height y, skipping the side that faces the other pillar.
func _ring_of_houses(c: Vector2, levels: Array, y: float, from_a: float, to_a: float, count: int) -> void:
	for i in count:
		var a := lerpf(from_a, to_a, (i + 0.5) / count) + _rng.randf_range(-0.06, 0.06)
		var w := _rng.randf_range(7.0, 10.0)
		var h := _rng.randf_range(7.0, 11.0)
		var d := _rng.randf_range(6.0, 8.0)
		var r := radius_at(levels, y) + d * 0.5 - 0.5
		var base := Vector3(c.x + cos(a) * r, y + _rng.randf_range(-2.0, 2.0), c.y + sin(a) * r)
		var yaw := atan2(cos(a), sin(a))          # local +z (the front) faces out
		_house(base, yaw, w, h, d, WALLS[_rng.randi() % WALLS.size()])


func _west_town() -> void:
	# lower tier, round the front and west sides (the east side meets the viaduct)
	_ring_of_houses(WEST, WEST_LEVELS, 62.0, deg_to_rad(40), deg_to_rad(300), 11)
	# upper tier
	_ring_of_houses(WEST, WEST_LEVELS, 104.0, deg_to_rad(55), deg_to_rad(290), 9)
	# turrets standing out from each tier
	for a in [deg_to_rad(80), deg_to_rad(170), deg_to_rad(250)]:
		var r := radius_at(WEST_LEVELS, 70.0) + 3.0
		var base := Vector3(WEST.x + cos(a) * r, 66.0, WEST.y + sin(a) * r)
		part("box", ROCK_DARK, base + Vector3(0, -4.0, 0), Vector3(7, 8, 7), 0.0)
		_turret(base, 3.2, _rng.randf_range(16.0, 24.0), 9.0)
	for a in [deg_to_rad(120), deg_to_rad(215)]:
		var r := radius_at(WEST_LEVELS, 112.0) + 3.0
		var base := Vector3(WEST.x + cos(a) * r, 110.0, WEST.y + sin(a) * r)
		part("box", ROCK_DARK, base + Vector3(0, -4.0, 0), Vector3(7, 8, 7), 0.0)
		_turret(base, 3.0, _rng.randf_range(14.0, 20.0), 8.0)


## The west pillar's crown: the palace with its great window front, turrets, and the
## tall main tower whose finial is the top of the town.
func _crown() -> void:
	var top := 150.0
	var c := Vector3(WEST.x, top, WEST.y)
	# palace: a long hall, its tall window front facing the viewer (+z)
	var hall := c + Vector3(6, 0, -2)
	part("box", STONE, hall + Vector3(0, 14, 0), Vector3(34, 28, 22))
	part("prism", TEAL, hall + Vector3(0, 33, 0), Vector3(36, 10, 24))
	for col in 6:
		for row in 3:
			part("box", GLASS, hall + Vector3(-12.5 + col * 5.0, 6.0 + row * 7.5, 11.05), Vector3(3.2, 5.6, 0.2), 0.0, false)
			part("box", GOLD, hall + Vector3(-12.5 + col * 5.0, 9.0 + row * 7.5, 11.15), Vector3(3.4, 0.25, 0.1), 0.0, false)
	for s in [-1.0, 1.0]:                           # corner turrets on the hall
		for e in [-1.0, 1.0]:
			_turret(hall + Vector3(s * 17.5, 0, e * 11.0), 2.6, 34.0, 10.0)
	# the main tower, west of the hall
	var mt := c + Vector3(-17, 0, 6)
	spire_top = _turret(mt, 7.0, 72.0, 24.0) + Vector3(0, 2.4, 0)
	part("cyl", STONE, mt + Vector3(0, 52, 0), Vector3(17, 1.2, 17))                 # gallery
	for k in 12:
		var a := TAU * k / 12.0
		part("box", STONE, mt + Vector3(cos(a) * 8.2, 53.2, sin(a) * 8.2), Vector3(1.2, 1.4, 1.2), -a, false)
	# a slim turret at the east edge, where the plank bridge sets off
	_turret(c + Vector3(27.5, 0, 0), 3.0, 22.0, 9.0)
	part("box", STONE, c + Vector3(27.5, 18.0, 0), Vector3(3.0, 0.6, 4.0))
	# lawns and a few trees of moss on the crown
	for n in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(10.0, 30.0)
		part("ball", MOSS, c + Vector3(cos(a) * r, 0.5, sin(a) * r + 14.0), Vector3(5, 3, 5), 0.0, false)


## The east pillar: houses clinging all the way round, a timber walkway spiralling up
## between their tiers, and the lone tower on top.
func _east_town() -> void:
	var y0 := 53.2                                    # level with the viaduct's deck
	var y1 := 158.0
	var turns := 3.0
	var pitch := (y1 - y0) / turns
	var steps := 280
	for k in steps:
		var t := float(k) / (steps - 1)
		var a := t * turns * TAU + PI                 # starts on the west face, off the viaduct
		var y := lerpf(y0, y1, t)
		var r := radius_at(EAST_LEVELS, y) + 2.6
		var p := Vector3(EAST.x + cos(a) * r, y, EAST.y + sin(a) * r)
		# each plank runs along the spiral (local x) and is tipped to its slope, so
		# the walkway is one continuous ramp you can walk up
		var slope := atan(pitch / (TAU * r))
		part("box", TIMBER, p, Vector3(3.2, 0.35, 3.0), atan2(cos(a), sin(a)), true, -slope)
		if k % 4 == 0:
			var po := Vector3(EAST.x + cos(a) * (r + 2.0), y + 0.7, EAST.y + sin(a) * (r + 2.0))
			part("box", TIMBER, po, Vector3(0.2, 1.4, 0.2), 0.0, false)
	# houses between the walkway's turns
	for k in 16:
		var t := (k + 0.5) / 16.0
		var a := t * turns * TAU + PI + 0.35
		var y := lerpf(y0, y1, t) + pitch * 0.32
		if y > y1 - 4.0:
			continue
		var w := _rng.randf_range(6.5, 8.5)
		var h := _rng.randf_range(7.0, 9.0)
		var d := 6.5
		var r := radius_at(EAST_LEVELS, y) + d * 0.5 + 0.5
		var base := Vector3(EAST.x + cos(a) * r, y, EAST.y + sin(a) * r)
		_house(base, atan2(cos(a), sin(a)), w, h, d, WALLS[_rng.randi() % WALLS.size()])
	# the lone tower on the summit, with a door onto the plank bridge
	var c := Vector3(EAST.x, 160.0, EAST.y)
	_turret(c, 5.5, 46.0, 18.0)
	part("box", STONE, c + Vector3(-6.0, 7.4, 0), Vector3(2.0, 0.6, 4.0))          # bridge landing
	part("cyl", STONE, c + Vector3(0, 30, 0), Vector3(14, 1.0, 14))                 # balcony
	_turret(c + Vector3(9.0, 0, 6.0), 2.2, 14.0, 6.0, false)
