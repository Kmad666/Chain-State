extends "res://scripts/world/blockout.gd"
## The Keep Isles: a castle on a forested hill island, with three small isles of
## houses floating round it, after a reference drawing Daniel shared.
##
## - **The main island:** a round green hill of pines on a rocky floating base,
##   with roots hanging from its underside. On its summit stands a stone keep:
##   a buttressed wall-block crowned with red-roofed halls, a tall round tower
##   with a red cone roof and a banner turret on top.
## - **The slopes:** two clusters of white, red-roofed houses sit on timber-propped
##   ledges down the hillside.
## - **Three satellite isles** float round it, each with a house cluster and a
##   round watchtower. Plank bridges join the left and right isles to the main
##   island's ledges; the little isle below has no bridge, so you swing to it.
##
## The origin is the main island's rim level, and the keep's tower tops out near 170 m.

const FloatingIsland := preload("res://scripts/world/floating_island.gd")
const PINE := "res://assets/models/kenney/platformer/tree-pine.glb"
const PINE_S := "res://assets/models/kenney/platformer/tree-pine-small.glb"

const STONE := Color(0.79, 0.76, 0.82)       # lavender-grey keep stone
const STONE_DK := Color(0.64, 0.61, 0.68)
const WALL := Color(0.93, 0.91, 0.92)        # whitewashed houses
const RED := Color(0.74, 0.32, 0.34)         # roofs, cones, banners
const TIMBER := Color(0.45, 0.33, 0.30)
const GLASS := Color(0.32, 0.30, 0.38)
const HILL := Color(0.45, 0.57, 0.38)
const ROOT := Color(0.47, 0.42, 0.46)

const R := 105.0                             # the hill's footprint radius
const H := 72.0                              # the hill's height

var top := Vector3.ZERO
var isles: Array = []                        # the satellite FloatingIslands
var bridges: Array = []                      # [from, to] of each plank bridge
var _pines: Array = []
var _small_pines: Array = []


func top_point() -> Vector3:
	return global_position + top


## Height of the hill's surface above the rim at (x, z) from its centre.
static func hill_y(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / R
	return H * sqrt(maxf(0.0, 1.0 - d * d)) if d < 1.0 else 0.0


func build() -> void:
	rng.seed = 3030
	_main_island()
	_keep()
	_slope_town(deg_to_rad(165), 0.86, 5)        # the left-hand cluster, by the left bridge
	_slope_town(deg_to_rad(20), 0.80, 6)         # the right-hand cluster, by the right bridge
	var left := _isle(Vector3(-195, 26, 26), 40.0, 31, 4)
	var right := _isle(Vector3(182, 38, -16), 38.0, 32, 4)
	_isle(Vector3(128, -72, 82), 22.0, 33, 2)
	_bridge(left + Vector3(36, 0.4, 0), _ledge_point(deg_to_rad(165), 0.86) + Vector3(-9, 0.4, 0))
	_bridge(right + Vector3(-34, 0.4, 0), _ledge_point(deg_to_rad(20), 0.80) + Vector3(9, 0.4, -2))
	_birds()
	_plant()


# ---------------------------------------------------------------- the main island
func _main_island() -> void:
	var base := FloatingIsland.new()
	base.radius = R + 8.0
	base.depth = 120.0
	base.island_seed = 3001
	base.grass = false
	add_child(base)
	# the hill: the top half of a squashed sphere, grassy and solid
	var hill := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = H                        # a hemisphere's height is the dome's own
	sm.radial_segments = 48
	sm.rings = 24
	sm.is_hemisphere = true              # just the dome: nothing pokes out of the rock below
	hill.mesh = sm
	hill.material_override = Mats.grid(HILL, HILL.darkened(0.06), 2)
	add_child(hill)
	var cs := CollisionShape3D.new()
	cs.shape = sm.create_trimesh_shape()
	body.add_child(cs)
	_roots(Vector3.ZERO, R + 8.0, 34, 120.0)
	# pines all over the hill, but not where the keep and the ledges stand
	for n in 340:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf_range(0.06, 0.92)) * R
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if Vector2(p.x, p.z).length() < 40.0:
			continue
		if _near_ledge(p):
			continue
		p.y = hill_y(p.x, p.z) - 0.5
		var sc := rng.randf_range(4.5, 7.5)
		(_pines if rng.randf() < 0.6 else _small_pines).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p))


## Roots and rock spikes hanging under an island's rim.
func _roots(c: Vector3, r: float, n: int, depth: float) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.3, 0.85)
		var y := -depth * (1.0 - d / r) * 0.75 - rng.randf_range(2.0, 8.0)
		var length := rng.randf_range(8.0, 30.0)
		var thick := rng.randf_range(0.6, 1.6) if rng.randf() < 0.7 else rng.randf_range(3.0, 6.0)
		part_b("cone", ROOT, c + Vector3(cos(a) * d, y - length * 0.5, sin(a) * d), Vector3(thick, length, thick),
			Basis(Vector3.RIGHT, PI) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15)), false)


# ---------------------------------------------------------------- the keep
func _keep() -> void:
	var y0 := H - 22.0
	# the great wall-block, buttressed, sunk into the summit
	part("box", STONE, Vector3(0, y0 + 20, 0), Vector3(62, 40, 46))
	for i in 7:
		var x := -27.0 + i * 9.0
		part("box", STONE_DK, Vector3(x, y0 + 18, 23.6), Vector3(2.4, 36, 2.2))
		part("box", STONE_DK, Vector3(x, y0 + 18, -23.6), Vector3(2.4, 36, 2.2))
		if i % 2 == 1:
			part("box", RED, Vector3(x + 4.5, y0 + 26, 23.2), Vector3(2.0, 6.0, 0.3), 0.0, false)   # banners
	part("box", STONE_DK, Vector3(0, y0 + 40.6, 0), Vector3(64, 1.4, 48))      # parapet walk
	for i in 16:                                                              # crenellations
		for s in [-1.0, 1.0]:
			part("box", STONE, Vector3(-30.0 + i * 4.0, y0 + 42.2, s * 23.4), Vector3(2.0, 1.8, 1.2), 0.0, false)
	# red-roofed halls on top, stepping up toward the tower
	var y1 := y0 + 41.3
	_hall(Vector3(-18, y1, 8), 20.0, 12.0, 16.0)
	_hall(Vector3(4, y1, 10), 18.0, 16.0, 14.0)
	_hall(Vector3(20, y1, -6), 16.0, 10.0, 18.0, PI * 0.5)
	_hall(Vector3(-16, y1, -12), 16.0, 9.0, 12.0)
	# the round tower and its banner turret
	var t := Vector3(6, y1, -6)
	part("cyl", STONE, t + Vector3(0, 30, 0), Vector3(18, 60, 18))
	part("cyl", STONE_DK, t + Vector3(0, 42, 0), Vector3(21, 2.0, 21))            # a jutting gallery
	part("box", WALL, t + Vector3(9.5, 36, 0), Vector3(5, 7, 9), 0.0)              # a little bay on its side
	part("prism", RED, t + Vector3(9.5, 41, 0), Vector3(9.5, 3.5, 5.5), PI * 0.5)
	for k in 6:
		part("box", GLASS, t + Vector3(0, 10.0 + k * 8.0, 9.05), Vector3(1.6, 3.4, 0.2), 0.0, false)
	part("cone", RED, t + Vector3(0, 60 + 9, 0), Vector3(22, 18, 22))
	part("cyl", STONE, t + Vector3(0, 80, 0), Vector3(6, 10, 6))                    # banner turret
	part("cone", RED, t + Vector3(0, 88, 0), Vector3(7.4, 6, 7.4))
	part("box", RED, t + Vector3(0, 94, 0), Vector3(0.4, 6, 0.4), 0.0, false)
	part("box", RED, t + Vector3(1.6, 95.5, 0), Vector3(3.0, 2.0, 0.15), 0.0, false)
	top = t + Vector3(0, 97, 0)


## A white hall with a red gabled roof and a timber band, like the keep's top.
func _hall(base: Vector3, w: float, h: float, d: float, yaw := 0.0) -> void:
	part("box", WALL, base + Vector3(0, h * 0.5, 0), Vector3(w, h, d), yaw)
	part("box", TIMBER, base + Vector3(0, h * 0.62, 0), Vector3(w + 0.2, 0.6, d + 0.2), yaw, false)
	part("prism", RED, base + Vector3(0, h + d * 0.3, 0), Vector3(d + 1.0, d * 0.6, w + 1.0), yaw + PI * 0.5)
	var out := Basis(Vector3.UP, yaw)
	for i in maxi(1, int(w / 5.0)):
		part("box", GLASS, base + out * Vector3(-w * 0.5 + 2.5 + i * 5.0, h * 0.4, d * 0.5 + 0.06), Vector3(1.4, 2.4, 0.15), yaw, false)


# ---------------------------------------------------------------- the slopes
## Where a slope town's ledge sits: angle round the hill, fraction of its radius.
func _ledge_point(a: float, frac: float) -> Vector3:
	var p := Vector3(cos(a), 0, sin(a)) * R * frac
	p.y = hill_y(p.x, p.z)
	return p


func _near_ledge(p: Vector3) -> bool:
	for lp in [_ledge_point(deg_to_rad(165), 0.86), _ledge_point(deg_to_rad(20), 0.80)]:
		if Vector2(p.x - lp.x, p.z - lp.z).length() < 26.0:
			return true
	return false


## A row of houses on a timber-propped ledge cut into the hillside, facing out.
func _slope_town(a: float, frac: float, n: int) -> void:
	var c := _ledge_point(a, frac)
	var out := Vector3(cos(a), 0, sin(a))
	var yaw := atan2(out.x, out.z)
	var along := Vector3(-out.z, 0, out.x)
	part("box", TIMBER, c + Vector3(0, -0.5, 0) + out * 2.0, Vector3(44, 1.0, 20), yaw)        # the ledge deck
	for i in 5:                                                                               # props
		part("box", TIMBER, c + along * (-18.0 + i * 9.0) + out * 11.0 + Vector3(0, -7, 0), Vector3(0.8, 13, 0.8), yaw, false)
	part("box", STONE_DK, c + Vector3(0, -7, 0) - out * 2.0, Vector3(44, 13, 14), yaw)        # retaining wall
	for i in n:
		var w := rng.randf_range(7.0, 9.0)
		var h := rng.randf_range(7.0, 12.0)
		var p := c + along * (-17.0 + i * (34.0 / maxf(n - 1, 1))) + out * rng.randf_range(-3.0, 1.0)
		_hall(p, w, h, 8.0, yaw)
	# and a small round tower at one end
	var t := c - along * 22.0 - out * 2.0
	part("cyl", STONE, t + Vector3(0, 9, 0), Vector3(7, 18, 7))
	part("cone", RED, t + Vector3(0, 21, 0), Vector3(8.5, 6, 8.5))


# ---------------------------------------------------------------- the isles
## A small floating isle with a cluster of houses, a watchtower and a few pines.
## Returns its centre.
func _isle(c: Vector3, r: float, seed_: int, houses: int) -> Vector3:
	var isl := FloatingIsland.new()
	isl.radius = r
	isl.depth = r * 1.3
	isl.island_seed = seed_
	isl.grass = false
	isl.position = c
	add_child(isl)
	isl.top_mesh.material_override = Mats.grid(HILL, HILL.darkened(0.06), 2)
	isles.append(isl)
	_roots(c, r, int(r * 0.5), r * 1.3)
	part("box", STONE_DK, c + Vector3(0, 3, -r * 0.2), Vector3(r * 1.1, 6, r * 0.8))          # a stone terrace
	for i in houses:
		var a := -0.8 + i * 1.6 / maxf(houses - 1, 1)
		_hall(c + Vector3(sin(a) * r * 0.32, 6, -r * 0.2 + cos(a) * r * 0.1), rng.randf_range(7.0, 9.0), rng.randf_range(7.0, 11.0), 8.0, a * 0.3)
	var t := c + Vector3(r * 0.3, 6, -r * 0.45)
	part("cyl", STONE, t + Vector3(0, 9, 0), Vector3(8, 18, 8))
	for k in 8:
		var aa := TAU * k / 8.0
		part("box", STONE, t + Vector3(cos(aa) * 3.6, 18.9, sin(aa) * 3.6), Vector3(1.6, 1.8, 1.6), -aa, false)
	for n in int(r * 0.5):
		var aa := rng.randf() * TAU
		var d := rng.randf_range(r * 0.45, r * 0.85)
		_small_pines.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(4.0, 6.0)), c + Vector3(cos(aa) * d, 0, sin(aa) * d)))
	return c


## A plank bridge with rope rails between two points (it sags a little).
func _bridge(a: Vector3, b: Vector3) -> void:
	var n := int(a.distance_to(b) / 1.6)
	var dir := (b - a)
	var yaw := atan2(dir.x, dir.z)
	var flat := Vector2(dir.x, dir.z).length()
	for k in n:
		var t := (k + 0.5) / n
		var p := a.lerp(b, t) + Vector3(0, -sin(t * PI) * 2.0, 0)
		var slope := atan2(dir.y - cos(t * PI) * 2.0 * PI, flat)
		part_b("box", TIMBER, p, Vector3(3.2, 0.3, 1.5), Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -slope))
		if k % 3 == 0:
			var side := Vector3(dir.z, 0, -dir.x).normalized() * 1.5
			for s in [-1.0, 1.0]:
				part("box", TIMBER, p + side * s + Vector3(0, 0.7, 0), Vector3(0.2, 1.4, 0.2), 0.0, false)
	bridges.append([a, b])


func _birds() -> void:
	for i in 16:
		var p := Vector3(rng.randf_range(-70, 40), rng.randf_range(110, 165), rng.randf_range(20, 70))
		var yaw := rng.randf_range(-0.4, 0.4)
		for s in [-1.0, 1.0]:
			part("box", Color(0.25, 0.22, 0.28), p + Basis(Vector3.UP, yaw) * Vector3(s * 0.7, 0.2, 0), Vector3(1.5, 0.15, 0.4), yaw, false, s * 0.45)


func _plant() -> void:
	for pair in [[PINE, _pines], [PINE_S, _small_pines]]:
		var mesh := KenneyMesh.get_mesh(pair[0])
		var xfs: Array = pair[1]
		if mesh == null or xfs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
