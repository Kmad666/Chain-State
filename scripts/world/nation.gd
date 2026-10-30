extends RefCounted
## The Nation (draft): the whole Gordian Empire laid out at 1:50 from the casebook
## map, so you can fly round it (F4 / V) and feel the distances.
##
## Map to metres: the casebook map's scale bar is 30 map units to 10 miles, so one
## unit is about 536 m of real Germany; at 1:50 that is 10.73 m. Delos sits at the
## origin and the state capitals keep their real bearings, pulled in to CLUSTER of
## their 1:50 distance so the nation reads as one archipelago: 1.6 to 2.8 km out.
## Everything is blockout: grid-textured islands, plain boxes for city blocks, a
## landmark tower per capital, Kenney trees for scale, and a Victorian railway
## across every island (ballast, timber sleepers, iron rails, buffer stops, and a
## canopied station on each capital). Far islands fade into thin fog, which is how
## distant states read as silhouettes.

const FloatingIsland := preload("res://scripts/world/floating_island.gd")
const M_PER_UNIT := 10.73
const MAP_ORIGIN := Vector2(997, 763)       # Delos, in casebook-map units
const CLUSTER := 0.42                       # states sit at 42% of their 1:50 map distance
const GAP := 80.0                           # least clear air between two islands' rims
const GAUGE := 1.435                        # standard gauge, metres between the rails
const SLEEPER_EVERY := 0.9
## Fog and draw distance (tunable in dev fly: [ ] haze distance, - = sea of cloud).
## The haze is depth fog: clear to FOG_BEGIN, solid by fog_end. The camera stops
## drawing just past fog_end, and each island's detail (city, trees, railway)
## switches off DETAIL_RANGE out, deep enough in the haze that you don't see it go.
const FOG_BEGIN := 250.0
const FOG_END := 3600.0
const FOG_CURVE := 0.75            # under 1: the haze builds quickly, then eases
const DETAIL_RANGE := 1700.0
const SEA_HEIGHT := -40.0          # cloud sea: fog thickens below this
const SEA_DENSITY := 0.02
const FLOOR_Y := -300.0            # the cloud floor the sea fog settles on
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
var rails: Array = []                  # one line per island: {o, dir, half, station}
var _iron: Array = []
var _timber: Array = []
var _ballast: Array = []
var _buffers: Array = []
var _platforms: Array = []
var _canopy: Array = []
var _spots: Array = []                 # [centre, radius] of every island placed so far
var landmarks: Array = []              # the towers: never culled, they're how you navigate
var detail_nodes: Array = []           # every per-island detail batch (for tests)
var fog_end := FOG_END
var sea_density := SEA_DENSITY
var cloud_floor: MeshInstance3D
var rng := RandomNumberGenerator.new()


static func to_world(map: Vector2, y := 0.0) -> Vector3:
	var d := (map - MAP_ORIGIN) * M_PER_UNIT * CLUSTER
	return Vector3(d.x, y, d.y)


func build(world: Node3D) -> void:
	w = world
	rng.seed = 1871
	# 1. where everything goes: the states, their satellites, the ordinary islands
	var capitals: Array[Vector3] = []
	for s in STATES:
		var c := to_world(s.map, s.y)
		capitals.append(c)
		_spots.append([c, s.r])
	var sats: Array = []
	for i in range(1, STATES.size()):
		var s: Dictionary = STATES[i]
		for k in 3:
			var r := rng.randf_range(60.0, 140.0)
			var p := _free_spot(func():
				var ang := rng.randf() * TAU
				var dist: float = rng.randf_range(s.r + r + GAP, s.r + r + 650.0)
				return capitals[i] + Vector3(cos(ang) * dist, rng.randf_range(-60.0, 60.0), sin(ang) * dist), r)
			if p != Vector3.INF:
				sats.append([p, r, 800 + i * 10 + k, "%s isle" % s.name.capitalize()])
	# twelve ordinary islands, 100-400 m across: along each spoke from Delos, round
	# the ring of neighbours, and two more
	var mids: Array[Vector3] = []
	for i in range(1, 6):
		mids.append(capitals[0].lerp(capitals[i], rng.randf_range(0.45, 0.6)))
	for pair in [[1, 3], [3, 4], [4, 5], [5, 2], [2, 1]]:
		mids.append(capitals[pair[0]].lerp(capitals[pair[1]], rng.randf_range(0.4, 0.6)))
	mids.append(capitals[0].lerp(capitals[1], 0.8))
	mids.append(capitals[0].lerp(capitals[4], 0.8))
	var ords: Array = []
	for n in mids.size():
		var r := rng.randf_range(50.0, 200.0)
		var m: Vector3 = mids[n]
		var p := _free_spot(func():
			return m + Vector3(rng.randf_range(-260, 260), rng.randf_range(-80, 100), rng.randf_range(-260, 260)), r)
		if p != Vector3.INF:
			ords.append([p, r, 900 + n, "Isle %d" % (n + 1)])

	# 2. build them; every island's railway points at its nearest neighbour
	for i in STATES.size():
		var s: Dictionary = STATES[i]
		var c: Vector3 = capitals[i]
		_make_island(c, s.r, s.r * 0.7, 700 + i)
		var line := _railway(c, s.r, 45.0 if i == 0 else 30.0, true)
		_city(c, s.city, s.col, i == 0, line)
		_trees_ring(c, s.city + 20.0, s.r * 0.85, int(s.r * 0.5), line)
		_flush(c, s.r)
		_label(c + Vector3(0, 180 if i == 0 else 120, 0), s.name, "%s\n%d m across" % [s.sub, roundi(s.r * 2.0)], s.col.lightened(0.35), 1.0)
		places.append({"name": s.name, "pos": c, "r": s.r})
	for it in sats + ords:
		_isle(it[0], it[1], it[2], it[3])

	# the capitals' towers, always drawn: landmarks to steer by through the haze
	for t in landmarks:
		_boxes([t[0]], t[1], 0.0)
	# the cloud floor: one big flat sheet far below, kept under you as you fly, that
	# the fog paints into a sea of cloud fading out to the horizon
	cloud_floor = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	cloud_floor.mesh = pm
	cloud_floor.material_override = Mats.lit(Color(0.93, 0.94, 0.97), 1.0)
	cloud_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_floor.position.y = FLOOR_Y
	w.add_child(cloud_floor)
	apply_fog()
	# you arrive by train: start on Delos's station platform, looking down the line
	var home: Dictionary = rails[0]
	var side: Vector3 = home.dir.cross(Vector3.UP).normalized()
	w.start_pos = home.o + side * 4.7 + home.dir * 10.0 + Vector3(0, 1.6, 0)
	w.start_yaw = atan2(-home.dir.x, -home.dir.z)


## Try up to 30 positions from `pick` until one clears every island so far by GAP.
func _free_spot(pick: Callable, r: float) -> Vector3:
	for attempt in 30:
		var p: Vector3 = pick.call()
		var ok := true
		for sp in _spots:
			if Vector2(p.x - sp[0].x, p.z - sp[0].z).length() < r + sp[1] + GAP:
				ok = false
				break
		if ok:
			_spots.append([p, r])
			return p
	return Vector3.INF


func _isle(p: Vector3, r: float, seed_: int, nm: String) -> void:
	_make_island(p, r, r * 0.8, seed_)
	var line := _railway(p, r, 0.0, false)
	_trees_ring(p, 0.0, r * 0.82, int(r * 0.6), line)
	_flush(p, r)
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
func _trees_ring(c: Vector3, r0: float, r1: float, n: int, line: Dictionary) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf_range(r0 * r0 / (r1 * r1), 1.0)) * r1
		var sc := rng.randf_range(4.5, 7.0)
		var at := c + Vector3(cos(a) * d, 0, sin(a) * d)
		if _near_line(at, line, 14.0 if line.station else 6.0):
			continue                       # keep the railway clear
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), c + Vector3(cos(a) * d, 0, sin(a) * d))
		(pines if rng.randf() < 0.45 else trees).append(xf)


## A blockout city: a grid of five-storey blocks (about 16 m) with 12 m streets,
## a tall landmark tower in the middle, and on Delos a domed parliament.
func _city(c: Vector3, radius: float, col: Color, capital: bool, line: Dictionary) -> void:
	var pitch := 52.0
	var list: Array = blocks.get(col, [])
	var n := int(radius / pitch)
	for gx in range(-n, n + 1):
		for gz in range(-n, n + 1):
			var off := Vector3(gx * pitch, 0, gz * pitch)
			if off.length() > radius or off.length() < (90.0 if capital else 40.0):
				continue
			if _near_line(c + off, line, 34.0):
				continue                   # the railway cuts through town
			var h := rng.randf_range(13.0, 19.0)
			var sz := Vector3(pitch - 12.0, h, pitch - 12.0)
			list.append(Transform3D(Basis.from_scale(sz), c + off + Vector3(0, h * 0.5, 0)))
	# landmark: a tower you can pick out from the next state over
	var th := 110.0 if capital else 75.0
	landmarks.append([Transform3D(Basis.from_scale(Vector3(16, th, 16)), c + Vector3(0, th * 0.5, 0)), col])
	blocks[col] = list
	if capital:
		var stone := Color(0.86, 0.84, 0.78)
		var plinth: Array = blocks.get(stone, [])
		# the parliament stands across the tracks from the station
		var away: Vector3 = -line.dir.cross(Vector3.UP).normalized() * 60.0
		var yaw: float = atan2(line.dir.x, line.dir.z)
		plinth.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(80, 22, 120)), c + away + Vector3(0, 11, 0)))
		blocks[stone] = plinth
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 32.0
		sm.height = 64.0
		dome.mesh = sm
		dome.material_override = Mats.lit(Color(0.55, 0.72, 0.62))   # verdigris copper
		dome.position = c + away + Vector3(0, 22, 0)
		dome.visibility_range_end = DETAIL_RANGE + 500.0
		w.add_child(dome)


## A Victorian railway straight across an island, aimed at its nearest neighbour
## (so the lines read as one network): stone ballast, timber sleepers every 0.9 m,
## two iron rails at standard gauge, red buffer stops at both ends, and on the
## capitals a stone platform under a green iron canopy. `off` shifts the line
## sideways off the island's centre (clear of the landmark tower).
func _railway(c: Vector3, r: float, off: float, station: bool) -> Dictionary:
	var dir := Vector3.RIGHT
	var best := INF
	for sp in _spots:
		var d := Vector2(sp[0].x - c.x, sp[0].z - c.z)
		if d.length() > 1.0 and d.length() - sp[1] < best:
			best = d.length() - sp[1]
			dir = Vector3(d.x, 0, d.y).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var reach := r * 0.8                       # stay inside the wobbly rim
	var half := sqrt(maxf(reach * reach - off * off, 100.0))
	var o := c + side * off
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z))   # local +z runs along the line
	var line := {"o": o, "dir": dir, "half": half, "station": station}
	rails.append(line)

	var at := func(along: float, across: float, y: float) -> Vector3:
		return o + dir * along + side * across + Vector3(0, y, 0)
	var piece := func(list: Array, size: Vector3, pos: Vector3) -> void:
		list.append(Transform3D(basis * Basis.from_scale(size), pos))

	# ballast bed: solid, so you can walk the line
	piece.call(_ballast, Vector3(3.4, 0.3, half * 2.0), at.call(0.0, 0.0, 0.15))
	var bed := StaticBody3D.new()
	bed.collision_layer = 1
	bed.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 0.3, half * 2.0)
	cs.shape = box
	bed.transform = Transform3D(basis, at.call(0.0, 0.0, 0.15))
	bed.add_child(cs)
	w.add_child(bed)
	# sleepers and rails
	var k := -half + 0.5
	while k < half - 0.4:
		piece.call(_timber, Vector3(2.6, 0.16, 0.26), at.call(k, 0.0, 0.38))
		k += SLEEPER_EVERY
	for s in [-1.0, 1.0]:
		piece.call(_iron, Vector3(0.08, 0.16, half * 2.0 - 0.6), at.call(0.0, s * GAUGE * 0.5, 0.54))
	# buffer stops: a red beam on a timber frame at each end
	for e in [-1.0, 1.0]:
		piece.call(_buffers, Vector3(2.4, 0.5, 0.4), at.call(e * (half - 0.4), 0.0, 1.0))
		piece.call(_timber, Vector3(0.3, 0.9, 1.6), at.call(e * (half - 1.0), -0.9, 0.75))
		piece.call(_timber, Vector3(0.3, 0.9, 1.6), at.call(e * (half - 1.0), 0.9, 0.75))
	if station:
		# 70 m platform beside the line, solid, under a canopy on iron columns
		var plat := Vector3(6.0, 1.0, 70.0)
		piece.call(_platforms, plat, at.call(0.0, 4.7, 0.5))
		var pb := StaticBody3D.new()
		pb.collision_layer = 1
		pb.collision_mask = 0
		var pcs := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = plat
		pcs.shape = pbox
		pb.transform = Transform3D(basis, at.call(0.0, 4.7, 0.5))
		pb.add_child(pcs)
		w.add_child(pb)
		piece.call(_canopy, Vector3(7.0, 0.3, 66.0), at.call(0.0, 4.4, 5.6))
		var z := -30.0
		while z <= 30.0:
			piece.call(_canopy, Vector3(0.25, 4.6, 0.25), at.call(z, 6.6, 3.3))
			z += 10.0
	return line


## Is `p` within `width` of `line` (sideways), along the line's length?
func _near_line(p: Vector3, line: Dictionary, width: float) -> bool:
	var d: Vector3 = p - line.o
	var along: float = d.dot(line.dir)
	var across: float = absf(d.dot(line.dir.cross(Vector3.UP).normalized()))
	return absf(along) < line.half + width and across < width


## Decoration boxes, one MultiMesh per material (no collision).
func _mm(xfs: Array, mat: Material, range_end: float) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	_cull(mi, range_end)
	w.add_child(mi)


## Plain boxes, one MultiMesh per colour, solid so you can land on the roofs.
func _boxes(xfs: Array, col: Color, range_end: float) -> void:
	if xfs.is_empty():
		return
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
	_cull(mi, range_end)
	w.add_child(mi)


## Turn this island's gathered dressing into draw batches of its own, so the engine
## can skip a whole island's detail when it's off-screen or deep in the haze, and
## start the next island's lists fresh.
func _flush(c: Vector3, r: float) -> void:
	var far := DETAIL_RANGE + r           # measured to the batch's centre: allow for its size
	var t = w._multimesh(TREE, trees)
	var pn = w._multimesh(PINE, pines)
	for mi in [t, pn]:
		if mi:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_cull(mi, far)
	for col in blocks:
		_boxes(blocks[col], col, far)
	_mm(_ballast, Mats.lit(Color(0.42, 0.40, 0.37)), far)
	_mm(_timber, Mats.lit(Color(0.33, 0.22, 0.14)), far)
	_mm(_iron, Mats.metal(Color(0.24, 0.23, 0.22), 0.45), far)
	_mm(_buffers, Mats.lit(Color(0.62, 0.12, 0.10)), far)
	_mm(_platforms, Mats.grid(Color(0.74, 0.70, 0.62), Color(0.70, 0.66, 0.58), 1), far)
	_mm(_canopy, Mats.lit(Color(0.16, 0.30, 0.22)), far)     # railway green ironwork
	trees = []
	pines = []
	blocks = {}
	for list in [_ballast, _timber, _iron, _buffers, _platforms, _canopy]:
		list.clear()


func _cull(gi: GeometryInstance3D, range_end: float) -> void:
	if range_end > 0.0:
		gi.visibility_range_end = range_end
		detail_nodes.append(gi)


## Depth haze that turns solid at fog_end, a cloud sea pooling under the islands,
## and the camera's far plane just past the haze (nothing hidden gets drawn).
func apply_fog() -> void:
	var e: Environment = w.env
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_depth_begin = FOG_BEGIN
	e.fog_depth_end = fog_end
	e.fog_depth_curve = FOG_CURVE
	e.fog_density = 1.0
	e.fog_sky_affect = 0.0
	e.fog_height = SEA_HEIGHT
	e.fog_height_density = sea_density
	if w.player:
		w.player.cam.far = fog_end + 200.0
	if cloud_floor:
		cloud_floor.scale = Vector3(fog_end * 2.4, 1, fog_end * 2.4)


## Keep the cloud floor centred under the camera, so it never runs out.
func follow(p: Vector3) -> void:
	if cloud_floor:
		cloud_floor.position = Vector3(p.x, FLOOR_Y, p.z)


## Dev fly tuning: [ and ] move the haze in or out, - and = thin or thicken the sea.
func tune_fog(key: int) -> bool:
	match key:
		KEY_BRACKETLEFT:
			fog_end = maxf(fog_end - 250.0, 800.0)
		KEY_BRACKETRIGHT:
			fog_end = minf(fog_end + 250.0, 12000.0)
		KEY_MINUS:
			sea_density = maxf(sea_density - 0.005, 0.0)
		KEY_EQUAL:
			sea_density = minf(sea_density + 0.005, 0.2)
		_:
			return false
	apply_fog()
	return true


func fog_text() -> String:
	return "HAZE %.1f km [ ]   ·   CLOUD SEA %.3f - =" % [fog_end / 1000.0, sea_density]


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
