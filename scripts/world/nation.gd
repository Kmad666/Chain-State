extends RefCounted
## The Nation (draft): the whole Gordian Empire laid out at 1:50 from the casebook
## map, so you can fly round it (F4 / V) and feel the distances.
##
## Map to metres: the casebook map's scale bar is 30 map units to 10 miles, so one
## unit is about 536 m of real Germany; at 1:50 that is 10.73 m. Delos sits at the
## origin and the state capitals keep their real bearings and (compressed)
## distances: 3.7 to 6.7 km out. Everything is blockout: grid-textured islands,
## plain boxes for city blocks, a landmark tower per capital, Kenney trees for
## scale. Far islands fade into thin fog, which is how distant states read as
## silhouettes.

const FloatingIsland := preload("res://scripts/world/floating_island.gd")
const M_PER_UNIT := 10.73
const MAP_ORIGIN := Vector2(997, 763)       # Delos, in casebook-map units
const START := Vector3(0, 0, 420)          # the spawn, on Delos's south side
const TREE := "res://assets/models/kenney/platformer/tree.glb"
const PINE := "res://assets/models/kenney/platformer/tree-pine.glb"

## name, subtitle, map position, island radius (m), height (m), colour
const STATES := [
	{"name": "DELOS", "sub": "Bundesinsel · the capital", "map": Vector2(997, 763), "r": 500.0, "y": 0.0,
		"col": Color(0.82, 0.74, 0.52), "city": 300.0},
	{"name": "GORDIA", "sub": "Nordöstlicher Staat · Berlin", "map": Vector2(1301, 365), "r": 320.0, "y": 40.0,
		"col": Color(0.55, 0.32, 0.30), "city": 180.0},
	{"name": "RHENISH GORDIA", "sub": "Gordia's west · Köln", "map": Vector2(461, 570), "r": 260.0, "y": -30.0,
		"col": Color(0.55, 0.32, 0.30), "city": 150.0},
	{"name": "DELOSEN", "sub": "Mittelstaat · Dresden", "map": Vector2(1456, 730), "r": 280.0, "y": 20.0,
		"col": Color(0.36, 0.46, 0.62), "city": 160.0},
	{"name": "ARCADEN", "sub": "Südlicher Staat · München", "map": Vector2(1387, 1250), "r": 300.0, "y": 60.0,
		"col": Color(0.40, 0.56, 0.38), "city": 170.0},
	{"name": "DAEDALEN", "sub": "Südwestlicher Staat · Stuttgart", "map": Vector2(806, 1045), "r": 260.0, "y": -50.0,
		"col": Color(0.62, 0.52, 0.30), "city": 150.0},
]

var w: Node3D
var labels: Array = []               # [pos, title, sub, colour, big, fade]
var places: Array = []                 # {name, pos, r} for the fly readout
var trees: Array = []
var pines: Array = []
var blocks := {}                       # colour -> [Transform3D]
var rng := RandomNumberGenerator.new()


static func to_world(map: Vector2, y := 0.0) -> Vector3:
	var d := (map - MAP_ORIGIN) * M_PER_UNIT
	return Vector3(d.x, y, d.y)


func build(world: Node3D) -> void:
	w = world
	rng.seed = 1871
	var capitals: Array[Vector3] = []
	for i in STATES.size():
		var s: Dictionary = STATES[i]
		var c := to_world(s.map, s.y)
		capitals.append(c)
		_make_island(c, s.r, s.r * 0.7, 700 + i)
		_city(c, s.city, s.col, i == 0)
		_trees_ring(c, s.city + 20.0, s.r * 0.85, int(s.r * 0.5))
		_label(c + Vector3(0, 180 if i == 0 else 120, 0), s.name, "%s\n%d m across" % [s.sub, roundi(s.r * 2.0)], s.col.lightened(0.35), 1.0)
		places.append({"name": s.name, "pos": c, "r": s.r})
		# satellites: every state's own little islands, within 2 km of its capital
		if i > 0:
			for k in 3:
				var ang := rng.randf() * TAU
				var dist: float = rng.randf_range(s.r + 250.0, 1500.0)
				var r := rng.randf_range(60.0, 140.0)
				var p := c + Vector3(cos(ang) * dist, rng.randf_range(-70.0, 70.0), sin(ang) * dist)
				_isle(p, r, 800 + i * 10 + k, "%s isle" % s.name.capitalize())

	# twelve ordinary islands, 100-400 m across, scattered between the states:
	# halfway along each spoke from Delos, round the ring of neighbours, and two more
	var spots: Array[Vector3] = []
	for i in range(1, 6):
		spots.append(capitals[0].lerp(capitals[i], rng.randf_range(0.4, 0.6)))
	for pair in [[1, 3], [3, 4], [4, 5], [5, 2], [2, 1]]:
		spots.append(capitals[pair[0]].lerp(capitals[pair[1]], rng.randf_range(0.4, 0.6)))
	spots.append(capitals[0].lerp(capitals[1], 0.25))
	spots.append(capitals[0].lerp(capitals[4], 0.75))
	for n in spots.size():
		var p := spots[n] + Vector3(rng.randf_range(-300, 300), rng.randf_range(-90, 110), rng.randf_range(-300, 300))
		_isle(p, rng.randf_range(50.0, 200.0), 900 + n, "Isle %d" % (n + 1))

	# all the dressing, in bulk: one draw call per kind
	w._multimesh(TREE, trees)
	w._multimesh(PINE, pines)
	for col in blocks:
		_boxes(blocks[col], col)

	# thin haze: near islands crisp, the far states fading to silhouettes
	w.env.fog_density = 0.00008
	w.start_pos = START + Vector3(0, 1.0, 0)


func _isle(p: Vector3, r: float, seed_: int, nm: String) -> void:
	_make_island(p, r, r * 0.8, seed_)
	_trees_ring(p, 0.0, r * 0.82, int(r * 0.6))
	_label(p + Vector3(0, 45, 0), nm, "%d m across" % roundi(r * 2.0), Color(0.9, 0.95, 1.0), 0.55, 3500.0)
	places.append({"name": nm, "pos": p, "r": r})


func _make_island(p: Vector3, r: float, depth: float, seed_: int) -> void:
	var isl := FloatingIsland.new()
	isl.radius = r
	isl.depth = depth
	isl.island_seed = seed_
	isl.grass = false                  # tufts are invisible at this scale and cost thousands
	isl.position = p
	w.add_child(isl)
	w.islands.append(isl)


## Trees between `r0` and `r1` from the centre.
func _trees_ring(c: Vector3, r0: float, r1: float, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf_range(r0 * r0 / (r1 * r1), 1.0)) * r1
		var sc := rng.randf_range(4.5, 7.0)
		var at := c + Vector3(cos(a) * d, 0, sin(a) * d)
		if at.distance_to(START) < 40.0:
			continue                       # keep the spawn clear
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), c + Vector3(cos(a) * d, 0, sin(a) * d))
		(pines if rng.randf() < 0.45 else trees).append(xf)


## A blockout city: a grid of five-storey blocks (about 16 m) with 12 m streets,
## a tall landmark tower in the middle, and on Delos a domed parliament.
func _city(c: Vector3, radius: float, col: Color, capital: bool) -> void:
	var pitch := 52.0
	var list: Array = blocks.get(col, [])
	var n := int(radius / pitch)
	for gx in range(-n, n + 1):
		for gz in range(-n, n + 1):
			var off := Vector3(gx * pitch, 0, gz * pitch)
			if off.length() > radius or off.length() < (90.0 if capital else 40.0):
				continue
			var h := rng.randf_range(13.0, 19.0)
			var sz := Vector3(pitch - 12.0, h, pitch - 12.0)
			list.append(Transform3D(Basis.from_scale(sz), c + off + Vector3(0, h * 0.5, 0)))
	# landmark: a tower you can pick out from the next state over
	var th := 110.0 if capital else 75.0
	list.append(Transform3D(Basis.from_scale(Vector3(16, th, 16)), c + Vector3(0, th * 0.5, 0)))
	blocks[col] = list
	if capital:
		var stone := Color(0.86, 0.84, 0.78)
		var plinth: Array = blocks.get(stone, [])
		plinth.append(Transform3D(Basis.from_scale(Vector3(120, 22, 80)), c + Vector3(0, 11, -60)))
		blocks[stone] = plinth
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 32.0
		sm.height = 64.0
		dome.mesh = sm
		dome.material_override = Mats.lit(Color(0.55, 0.72, 0.62))   # verdigris copper
		dome.position = c + Vector3(0, 22, -60)
		w.add_child(dome)


## Plain boxes, one MultiMesh per colour, solid so you can land on the roofs.
func _boxes(xfs: Array, col: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = xfs.size()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	w.add_child(body)
	for k in xfs.size():
		var t: Transform3D = xfs[k]
		mm.set_instance_transform(k, t)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = t.basis.get_scale()
		cs.shape = box
		cs.position = t.origin
		body.add_child(cs)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Mats.grid(col, col.darkened(0.08), 1)
	w.add_child(mi)


## A floating name over an island; drawn on the HUD by PlaceLabels (world.gd).
func _label(at: Vector3, title: String, sub: String, col: Color, size: float, fade := 0.0) -> void:
	labels.append([at, title, sub, col, size >= 1.0, fade])


## Nearest place to `p`, for the fly readout: "over DELOS" or "ARCADEN 2.4 km".
func where(p: Vector3) -> String:
	var best := ""
	var bd := INF
	for pl in places:
		var d: float = Vector2(p.x - pl.pos.x, p.z - pl.pos.z).length() - pl.r
		if d < bd:
			bd = d
			best = pl.name
	if bd <= 0.0:
		return "over %s" % best
	return "%s %.1f km" % [best, bd / 1000.0] if bd >= 1000.0 else "%s %d m" % [best, roundi(bd)]
