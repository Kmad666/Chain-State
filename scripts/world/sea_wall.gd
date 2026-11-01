extends "res://scripts/world/blockout.gd"
## The Sea Wall: a white limestone fortress on the lip of a sheer cliff over a deep
## ultramarine sea, after a painting Daniel shared. Its colour and style carry over:
## a deep blue sky and sea, chalk-white stone, hard sunlight, vivid greens and red roofs.
##
## - A paved wall-walk runs along the cliff edge behind a crenellated parapet.
## - A towering colonnaded palace rises on the landward side: three tiers of
##   arcades over a band of carved meander.
## - The walk climbs by stairs to a raised wall section, then to a gatehouse with a
##   columned arch, and ends at a tall square tower crowned with battlements.
## - Far below, an army is drawn up in dark blocks on green plains, with red
##   banners. A red-roofed villa stands among cypresses, a town covers a
##   peninsula, and galleons ride at anchor.
## - A long low coast lies on the horizon, under a great white cumulus.
##
## A cloaked knight keeps watch on the walk.
##
## The origin is the cliff's sea-side edge at its base. The plateau is 220 m up,
## the sea is at y = 0, and north (-z) runs along the wall.

const CHALK := Color(0.82, 0.81, 0.77)       # limestone in sun
const CHALK_SH := Color(0.64, 0.65, 0.68)    # limestone in shade
const PAVE := Color(0.78, 0.76, 0.70)
const GREEN := Color(0.22, 0.40, 0.19)
const GREEN_DK := Color(0.10, 0.25, 0.12)
const RED := Color(0.86, 0.12, 0.10)
const WHITE := Color(0.96, 0.95, 0.92)
const TROOP := Color(0.12, 0.14, 0.22)
const HULL := Color(0.24, 0.17, 0.12)
const SAIL := Color(0.92, 0.90, 0.84)
const CLOUD := Color(1.0, 1.0, 1.0)
const TOP := 220.0                           # the plateau and the wall-walk

var top := Vector3.ZERO
var walk_start := Vector3(-5, TOP + 1.2, 118)
var knight: Node3D


func top_point() -> Vector3:
	return global_position + top


func build() -> void:
	rng.seed = 1453
	_cliff()
	_walk()
	_palace()
	_gatehouse()
	_lowlands()
	_army()
	_villa()
	_peninsula()
	_ships()
	_horizon()
	_knight()


## A round arch in a wall facing along `yaw` (0 faces +z): voussoirs round a half circle.
func arch_y(c: Vector3, span: float, rise: float, depth: float, thick: float, yaw: float, col := CHALK) -> void:
	var n := 9
	var out := Basis(Vector3.UP, yaw)
	for k in n:
		var t := (k + 0.5) / n
		var a := PI * (1.0 - t)
		var p := c + out * Vector3(cos(a) * span * 0.5, sin(a) * rise, 0)
		part("box", col, p, Vector3(span * PI * 0.5 / n + 0.8, thick, depth), yaw, true, a - PI * 0.5)


# ---------------------------------------------------------------- the cliff
func _cliff() -> void:
	# the plateau, a great block of rock from the sea up to the walk
	part("box", CHALK_SH, Vector3(-160, TOP * 0.5, -200), Vector3(320, TOP, 720))
	# the sea-facing face, broken into crags and buttresses of limestone
	for i in 190:
		var z := rng.randf_range(-550.0, 150.0)
		var y := rng.randf_range(4.0, TOP - 6.0)
		var s := rng.randf_range(10.0, 34.0)
		var col := CHALK if rng.randf() < 0.65 else CHALK_SH
		var reach := rng.randf_range(-2.0, 18.0) * (1.0 - y / TOP * 0.6)   # wider at the foot
		var sy := minf(s * rng.randf_range(0.9, 1.8), (TOP - 3.0 - y) * 2.0)  # never up through the walk
		if sy < 4.0:
			continue
		part_b("box", col, Vector3(reach, y, z), Vector3(s * rng.randf_range(0.5, 0.9), sy, s),
			Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15)))
	# scrub and pines clinging to the ledges
	for i in 120:
		var z := rng.randf_range(-540.0, 140.0)
		var y := rng.randf_range(20.0, TOP - 4.0)
		var s := rng.randf_range(4.0, 11.0)
		part("ball", GREEN if rng.randf() < 0.6 else GREEN_DK, Vector3(rng.randf_range(4.0, 20.0) * (1.0 - y / TOP * 0.6), y, z), Vector3(s * 1.4, s * 0.8, s * 1.4), 0.0, false)
	# a green lip of turf along the top of the cliff
	part("box", GREEN, Vector3(1.5, TOP - 0.6, -200), Vector3(3.0, 1.6, 700), 0.0, false)


# ---------------------------------------------------------------- the wall-walk
func _walk() -> void:
	# stage 1: the long walk at the plateau's edge
	_paving(Vector3(-5, TOP, 20), 8.0, 200.0)
	_parapet(-120.0, 120.0, TOP)
	# stairs up to the raised wall section
	_stairs(Vector3(-5, TOP, -80), Vector3(-5, TOP + 14, -120), 8.0)
	part("box", CHALK, Vector3(-8, TOP + 7, -165), Vector3(16, 14, 90))           # raised section
	_paving(Vector3(-5, TOP + 14, -165), 8.0, 90.0)
	_parapet(-210.0, -120.0, TOP + 14)
	# the square wall-house on the raised section
	part("box", CHALK, Vector3(-11, TOP + 14 + 9, -150), Vector3(10, 18, 16))
	for k in 4:
		part("box", CHALK, Vector3(-11 + (k % 2) * 4.0 - 2.0, TOP + 32.8, -150 + (k / 2) * 6.0 - 3.0), Vector3(2, 1.6, 2), 0.0, false)
	part("box", Color(0.1, 0.1, 0.12), Vector3(-5.9, TOP + 25, -150), Vector3(0.3, 2.2, 1.2), 0.0, false)
	# stairs up to the gatehouse
	_stairs(Vector3(-5, TOP + 14, -210), Vector3(-5, TOP + 34, -255), 7.0)
	_parapet(-300.0, -255.0, TOP + 34)
	part("box", CHALK, Vector3(-9, TOP + 17, -278), Vector3(18, 34, 46))           # the gate's platform
	_paving(Vector3(-5, TOP + 34, -278), 8.0, 46.0)


func _paving(c: Vector3, w: float, length: float) -> void:
	part("box", PAVE, c + Vector3(0, 0.3, 0), Vector3(w, 0.6, length))


## The sea-side parapet: a low wall along x = 0 with merlons, from z0 to z1.
func _parapet(z0: float, z1: float, y: float) -> void:
	var length := absf(z1 - z0)
	var mid := (z0 + z1) * 0.5
	part("box", CHALK, Vector3(-0.4, y + 1.0, mid), Vector3(1.4, 2.0, length))
	var n := int(length / 2.6)
	for k in n:
		part("box", CHALK, Vector3(-0.4, y + 2.6, minf(z0, z1) + 1.3 + k * 2.6), Vector3(1.4, 1.2, 1.3), 0.0, false)


## A flight of stairs climbing from a to b, w wide: a walkable ramp with step
## treads on it.
func _stairs(a: Vector3, b: Vector3, w: float) -> void:
	var run := Vector2(a.z - b.z, b.y - a.y)
	var length := run.length()
	var tilt := atan2(b.y - a.y, absf(b.z - a.z))
	var mid := (a + b) * 0.5
	var rot := Basis(Vector3.RIGHT, tilt if b.z < a.z else -tilt)
	part_b("box", PAVE, mid + Vector3(0, 0.3, 0), Vector3(w, 0.6, length), rot)
	var steps := int(length / 1.2)
	for k in steps:
		var t := (k + 0.5) / steps
		part("box", CHALK_SH, a.lerp(b, t) + Vector3(0, 0.75, 0), Vector3(w, 0.12, 0.25), 0.0, false)
	# a solid wall under the flight, and its sea-side parapet
	var lo := minf(a.y, b.y)
	part("box", CHALK, Vector3(mid.x - 3.0, lo - 6.0 + (absf(b.y - a.y)) * 0.25, mid.z), Vector3(w + 6.0, absf(b.y - a.y) * 0.5 + 12.0, absf(b.z - a.z)), 0.0, false)
	part_b("box", CHALK, mid + Vector3(w * 0.5 + 0.2, 1.4, 0), Vector3(1.2, 2.0, length), rot)


# ---------------------------------------------------------------- the palace
func _palace() -> void:
	var x_face := -14.0
	var z0 := 120.0
	var z1 := -70.0
	var h := 84.0
	# the body of the palace
	part("box", CHALK, Vector3(-44, TOP + h * 0.5, (z0 + z1) * 0.5), Vector3(48, h, z0 - z1))
	# three tiers of arcades facing the walk (+x)
	var tier_h := 24.0
	for t in 3:
		var y0 := TOP + t * tier_h
		part("box", CHALK_SH.darkened(0.35), Vector3(x_face - 4.5, y0 + tier_h * 0.5, (z0 + z1) * 0.5), Vector3(1.0, tier_h, z0 - z1), 0.0, false)   # shadowed loggia wall
		part("box", CHALK, Vector3(x_face, y0 + 0.6, (z0 + z1) * 0.5), Vector3(8.0, 1.2, z0 - z1))         # tier floor / balcony
		var bay := 11.0
		var n := int((z0 - z1) / bay)
		for k in n + 1:
			var z := z1 + k * bay
			part("cyl", CHALK, Vector3(x_face + 2.0, y0 + 1.2 + (tier_h - 7.0) * 0.5, z), Vector3(2.6, tier_h - 7.0, 2.6))
			part("box", CHALK, Vector3(x_face + 2.0, y0 + 1.6, z), Vector3(3.4, 0.8, 3.4), 0.0, false)          # bases
			part("box", CHALK, Vector3(x_face + 2.0, y0 + tier_h - 5.6, z), Vector3(3.6, 1.0, 3.6), 0.0, false)  # capitals
			if k < n:
				arch_y(Vector3(x_face + 2.0, y0 + tier_h - 5.0, z + bay * 0.5), bay - 2.6, 3.6, 3.0, 1.4, PI * 0.5)
		# entablature and a band of carved meander
		part("box", CHALK, Vector3(x_face + 1.5, y0 + tier_h - 1.5, (z0 + z1) * 0.5), Vector3(5.0, 3.0, z0 - z1))
		for k in int((z0 - z1) / 3.0):
			part("box", CHALK_SH, Vector3(x_face + 4.05, y0 + tier_h - 1.5, z1 + 1.5 + k * 3.0), Vector3(0.2, 1.6, 1.6 if k % 2 == 0 else 0.6), 0.0, false)
		# balustrade along the tier's edge
		part("box", CHALK, Vector3(x_face + 3.8, y0 + 2.4, (z0 + z1) * 0.5), Vector3(0.6, 1.4, z0 - z1), 0.0, false)
	# a cornice to finish
	part("box", CHALK, Vector3(-42, TOP + h + 1.0, (z0 + z1) * 0.5), Vector3(56, 2.0, z0 - z1 + 6.0))


# ---------------------------------------------------------------- the gatehouse
func _gatehouse() -> void:
	var y0 := TOP + 34.0
	var c := Vector3(-12, y0, -300)
	# the gate block, with a tall arched window of columns facing the walk (+z)
	part("box", CHALK, c + Vector3(0, 17, 0), Vector3(26, 34, 14))
	part("box", Color(0.08, 0.14, 0.42), c + Vector3(0, 14, 7.05), Vector3(10, 16, 0.2), 0.0, false)   # sea and sky through the window
	arch_y(c + Vector3(0, 22, 7.2), 10.0, 4.5, 1.0, 1.0, 0.0)
	for k in 4:
		part("cyl", CHALK, c + Vector3(-3.75 + k * 2.5, 13.5, 7.4), Vector3(1.0, 15, 1.0), 0.0, false)
	for k in 8:                                                                      # crenellations
		part("box", CHALK, c + Vector3(-12.0 + k * 3.4, 35, 6.4), Vector3(1.6, 2.0, 1.2), 0.0, false)
	# a passage through it so the walk carries on
	part("box", Color(0.10, 0.10, 0.13), c + Vector3(7, 4, 7.06), Vector3(4, 7, 0.2), 0.0, false)
	# the tall square tower beyond, the highest point
	var t := Vector3(-8, y0, -335)
	var th := 96.0
	part("box", CHALK, t + Vector3(0, th * 0.5, 0), Vector3(17, th, 17))
	part("box", CHALK, t + Vector3(0, th - 1.0, 0), Vector3(19.5, 2.0, 19.5))          # machicolation band
	for k in 6:
		for f in 4:
			var out := Basis(Vector3.UP, f * PI * 0.5)
			part("box", CHALK, t + Vector3(0, th + 1.6, 0) + out * Vector3(-8.2 + k * 3.3, 0, 9.0), Vector3(1.6, 2.4, 1.2), f * PI * 0.5, false)
	for row in 3:                                                                    # arched windows
		for f in 4:
			var out := Basis(Vector3.UP, f * PI * 0.5)
			part("box", Color(0.08, 0.10, 0.18), t + out * Vector3(0, 30.0 + row * 22.0, 8.55), Vector3(3.0, 6.0, 0.2), f * PI * 0.5, false)
	part("box", PAVE, t + Vector3(0, th + 0.3, 0), Vector3(16.5, 0.6, 16.5))
	top = t + Vector3(0, th + 3.0, 0)
	# a stair up the tower's walk-side face, so you can climb it on foot too
	for k in 30:
		var yy := 2.0 + k * (th - 4.0) / 30.0
		var side := 1.0 if k % 2 == 0 else -1.0
		part("box", CHALK, t + Vector3(9.5, yy, side * 3.5), Vector3(2.2, 0.6, 6.0))


# ---------------------------------------------------------------- below
func _lowlands() -> void:
	# the plain at the cliff's foot (south, +z) and the sea north of it
	part("box", GREEN, Vector3(650, 20, 70), Vector3(1300, 40, 380))
	part("box", Color(0.93, 0.90, 0.80), Vector3(650, 20.2, -122), Vector3(1300, 40, 16), 0.0, false)   # beach
	# copses and cypresses
	for i in 160:
		var p := Vector3(rng.randf_range(40, 1250), 40, rng.randf_range(-100, 250))
		var s := rng.randf_range(6, 16)
		part("ball", GREEN_DK if rng.randf() < 0.6 else GREEN, p + Vector3(0, s * 0.3, 0), Vector3(s, s * 0.6, s), 0.0, false)
	for i in 50:
		var p := Vector3(rng.randf_range(60, 1200), 40, rng.randf_range(-90, 240))
		part("cone", GREEN_DK, p + Vector3(0, 9, 0), Vector3(3, 18, 3), 0.0, false)
	# paths across the plain
	for i in 6:
		part("box", Color(0.85, 0.83, 0.70), Vector3(rng.randf_range(100, 1200), 40.15, 70), Vector3(4, 0.2, 380), rng.randf_range(-0.3, 0.3), false)


func _army() -> void:
	# regiments drawn up in dark blocks, red banners over each
	for r in 34:
		var c := Vector3(rng.randf_range(110, 1150), 40, rng.randf_range(-80, 220))
		var yaw := rng.randf_range(-0.25, 0.25)
		var rows := rng.randi_range(8, 14)
		var cols := rng.randi_range(14, 24)
		var rot := Basis(Vector3.UP, yaw)
		for i in rows:
			for j in cols:
				var p := c + rot * Vector3((j - cols * 0.5) * 1.6, 0.9, (i - rows * 0.5) * 1.6)
				part("box", TROOP, p, Vector3(0.8, 1.8, 0.8), yaw, false)
		for b in 2:
			var bp := c + rot * Vector3((b - 0.5) * cols * 0.8, 0, -rows * 0.8 - 1.0)
			part("box", Color(0.3, 0.25, 0.2), bp + Vector3(0, 3.5, 0), Vector3(0.2, 7, 0.2), 0.0, false)
			part("box", RED, bp + Vector3(1.1, 6.0, 0), Vector3(2.0, 1.6, 0.1), yaw, false)


func _villa() -> void:
	var c := Vector3(420, 40, 190)
	part("box", WHITE, c + Vector3(0, 0.8, 0), Vector3(70, 1.6, 50), 0.0, false)                 # walled garden
	for s in [-1.0, 1.0]:
		part("box", WHITE, c + Vector3(0, 2.0, s * 25.0), Vector3(70, 4, 1), 0.0, false)
		part("box", WHITE, c + Vector3(s * 35.0, 2.0, 0), Vector3(1, 4, 50), 0.0, false)
	for b in [[Vector3(-8, 0, -4), Vector3(24, 9, 14)], [Vector3(14, 0, 6), Vector3(14, 7, 12)], [Vector3(-22, 0, 10), Vector3(10, 6, 10)]]:
		part("box", WHITE, c + b[0] + Vector3(0, b[1].y * 0.5, 0), b[1], 0.0, false)
		part("prism", RED, c + b[0] + Vector3(0, b[1].y + 2.0, 0), Vector3(b[1].x + 1, 4.0, b[1].z + 1), 0.0, false)
	for i in 10:
		part("cone", GREEN_DK, c + Vector3(rng.randf_range(-40, 40), 10, rng.randf_range(-30, 30)), Vector3(3, 20, 3), 0.0, false)


func _peninsula() -> void:
	# a long low spit of land reaching north-east into the sea, covered in a red-roofed town
	var a := Vector3(40, 0, -200)
	for k in 9:
		var t := k / 8.0
		var p := a + Vector3(t * 620.0, 0, -t * 120.0 - sin(t * PI) * 60.0)
		var w := lerpf(140.0, 60.0, t)
		part("box", Color(0.88, 0.86, 0.78), p + Vector3(0, 4, 0), Vector3(90, 8, w), -0.18, false)
		part("box", GREEN, p + Vector3(0, 8.1, 0), Vector3(80, 0.3, w * 0.7), -0.18, false)
	for i in 110:
		var t := rng.randf()
		var p := a + Vector3(t * 620.0, 8, -t * 120.0 - sin(t * PI) * 60.0 + rng.randf_range(-30, 30) * (1.0 - t * 0.5))
		var w := rng.randf_range(6, 12)
		var d := rng.randf_range(6, 12)
		var h := rng.randf_range(4, 8)
		part("box", WHITE, p + Vector3(0, h * 0.5, 0), Vector3(w, h, d), 0.0, false)
		part("prism", RED, p + Vector3(0, h + 1.5, 0), Vector3(w + 0.6, 3.0, d + 0.6), 0.0, false)


func _ships() -> void:
	for s in [Vector3(560, 0, -470), Vector3(780, 0, -430), Vector3(1020, 0, -500), Vector3(300, 0, -560)]:
		var yaw := rng.randf_range(-0.4, 0.4)
		var rot := Basis(Vector3.UP, yaw)
		part("box", HULL, s + Vector3(0, 2.5, 0), Vector3(38, 5, 9), yaw, false)
		part("box", HULL, s + rot * Vector3(-16, 6.0, 0), Vector3(8, 4, 9), yaw, false)       # aft castle
		for m in [-8.0, 2.0, 11.0]:
			part("box", HULL, s + rot * Vector3(m, 16, 0), Vector3(0.6, 24, 0.6), yaw, false)
			part("box", SAIL, s + rot * Vector3(m, 17, 0), Vector3(0.3, 10, 12), yaw, false)


func _horizon() -> void:
	# the far coast: long low land under the haze
	part("box", Color(0.24, 0.30, 0.46), Vector3(800, 15, -4200), Vector3(9000, 30, 300), 0.0, false)
	part("box", Color(0.30, 0.36, 0.52), Vector3(-1800, 40, -4500), Vector3(3000, 80, 300), 0.0, false)
	# the great cumulus, and a line of fair-weather clouds along the horizon
	var c := Vector3(1200, 520, -3400)
	for i in 40:
		var s := rng.randf_range(120, 320)
		var off := Vector3(rng.randf_range(-450, 450), rng.randf_range(-120, 260) * (1.0 - absf(i - 20) / 40.0), rng.randf_range(-120, 120))
		part("ball", CLOUD, c + off, Vector3(s, s * 0.8, s), 0.0, false)
	for i in 50:
		var p := Vector3(rng.randf_range(-3000, 5000), rng.randf_range(200, 320), rng.randf_range(-3800, -2600))
		var s := rng.randf_range(60, 180)
		part("ball", CLOUD, p, Vector3(s * 1.8, s * 0.6, s), 0.0, false)


func _knight() -> void:
	# a watchman in a white cloak and black helm, looking out along the wall
	var p := Vector3(-6.0, TOP + 0.6, 70)
	part("cone", WHITE, p + Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 1.2), 0.0, false)          # the cloak
	part("cyl", Color(0.18, 0.18, 0.20), p + Vector3(0, 1.75, 0), Vector3(0.7, 0.5, 0.6), 0.0, false)   # mail at the shoulders
	part("ball", Color(0.08, 0.09, 0.12), p + Vector3(0, 2.2, 0), Vector3(0.5, 0.6, 0.5), 0.0, false)   # the helm
	part("box", Color(0.08, 0.09, 0.12), p + Vector3(0, 2.6, 0), Vector3(0.08, 0.25, 0.08), 0.0, false) # its spike
	part_b("cyl", Color(0.1, 0.1, 0.12), p + Vector3(-0.6, 1.2, 0.2), Vector3(1.1, 0.12, 1.1), Basis(Vector3.BACK, PI * 0.5), false)   # round shield
	part("box", Color(0.45, 0.45, 0.50), p + Vector3(0.55, 1.2, 0.1), Vector3(0.08, 1.8, 0.08), 0.0, false)   # spear


## Materials: matte and saturated, white clouds lit by their own colour.
func material_for(col: Color) -> Material:
	if _near(col, CLOUD):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 1.0
		m.emission_enabled = true
		m.emission = Color(0.72, 0.78, 0.92)
		return m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mat.metallic_specular = 0.25
	if _near(col, CHALK) or _near(col, CHALK_SH) or _near(col, PAVE):
		# dressed stone: coursed blocks with dark mortar joints, laid in world space
		mat.albedo_color = Color.WHITE
		mat.albedo_texture = _ashlar(col)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE / 3.2            # one texture tile = 3.2 m: two courses
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Colours come back from the batch keys through hex, so compare them loosely.
static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01


static var _ash := {}


## A tile of ashlar: two courses of blocks, offset by half a block, with a little
## tone variation per block and darker joints.
static func _ashlar(col: Color) -> ImageTexture:
	if _ash.has(col):
		return _ash[col]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = int(col.r * 1000)
	var tones := []
	for i in 8:
		tones.append(r.randf_range(-0.06, 0.05))
	for y in n:
		var course := y / 32
		for x in n:
			var off := 16 if course == 1 else 0
			var bx := ((x + off) % n) / 32
			var c := col.lightened(tones[course * 2 + bx]) if tones[course * 2 + bx] > 0 else col.darkened(-tones[course * 2 + bx])
			if y % 32 < 2 or (x + off) % 32 < 2:
				c = col.darkened(0.28)             # mortar joint
			elif r.randf() < 0.08:
				c = c.darkened(0.06)               # grain
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_ash[col] = t
	return t
