extends "res://scripts/world/blockout.gd"
## The White Citadel: a pale city-castle rising in tiers straight out of a still
## lake, after a reference painting Daniel shared (by snowskadi on DeviantArt).
##
## - **Base:** a broad white plinth stands in the water, with arcades along its
##   front.
## - **Front:** grand stairs climb from the water at the front left, and a
##   waterfront row of low houses with slate-blue roofs lines the front right.
## - **The city:** two more tiers of white town step back above the plinth. On
##   the left are a cathedral with tall lancet windows and a cluster of slender
##   towers with warm tan spires.
## - **The clock tower:** in the middle, about 200 m tall, with a rose window,
##   a gallery and a gold crown-spire.
## - **The right side:** a great double-arched gateway and a tall gabled tower
##   joined to the clock tower by a sky bridge, with thin watchtowers at the
##   right edge.
##
## The front faces +z. The origin is the water line, and the footprint is about
## 210 m by 140 m.

const WHITE := Color(0.94, 0.96, 0.98)
const SHADE := Color(0.83, 0.89, 0.95)       # the cool side of the stone
const TAN := Color(0.90, 0.74, 0.52)         # warm roofs and spires
const GOLD := Color(0.93, 0.78, 0.42)
const SLATE := Color(0.46, 0.57, 0.72)       # the waterfront roofs
const GLASS := Color(0.42, 0.60, 0.78)
const DARK := Color(0.30, 0.42, 0.58)        # arch shadows, doorways

var top := Vector3.ZERO
var stairs: Array = []                       # [bottom, top] of each grand stair


func top_point() -> Vector3:
	return global_position + top


func build() -> void:
	rng.seed = 1999
	_plinth()
	_waterfront()
	_stairs()
	_tiers()
	_cathedral()
	_left_towers()
	_clock_tower()
	_gateway()
	_right_tower()
	_back_towers()


# ---------------------------------------------------------------- helpers
## A grid of windows on a wall facing out along `yaw` (0 = +z), centred at `c`.
func windows(c: Vector3, yaw: float, w: float, h: float, cols: int, rows: int, ww := 1.6, wh := 3.2) -> void:
	var out := Basis(Vector3.UP, yaw)
	for i in cols:
		for j in rows:
			var x := (i - (cols - 1) * 0.5) * (w / maxi(cols, 1))
			var y := (j - (rows - 1) * 0.5) * (h / maxi(rows, 1))
			part("box", GLASS, c + out * Vector3(x, y, 0.08), Vector3(ww, wh, 0.18), yaw, false)


## A round tower: drum, cornice, tan (or gold) cone spire and a finial.
func tower(base: Vector3, r: float, h: float, cone_h: float, roof := TAN) -> Vector3:
	part("cyl", WHITE, base + Vector3(0, h * 0.5, 0), Vector3(r * 2, h, r * 2))
	part("cyl", SHADE, base + Vector3(0, h - 0.5, 0), Vector3(r * 2.3, 1.0, r * 2.3))
	part("cone", roof, base + Vector3(0, h + cone_h * 0.5, 0), Vector3(r * 2.25, cone_h, r * 2.25))
	for k in int(h / 7.0):
		part("box", GLASS, base + Vector3(0, 5.0 + k * 7.0, r + 0.05), Vector3(r * 0.35, 2.6, 0.15), 0.0, false)
	var tip := base + Vector3(0, h + cone_h, 0)
	part("ball", GOLD, tip + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), 0.0, false)
	top = tip if tip.y > top.y else top
	return tip


## A white house block with a gabled tan roof and windows on its front.
func house(base: Vector3, w: float, h: float, d: float, yaw := 0.0, roof := TAN) -> void:
	part("box", WHITE, base + Vector3(0, h * 0.5, 0), Vector3(w, h, d), yaw)
	part("prism", roof, base + Vector3(0, h + w * 0.28, 0), Vector3(d + 0.6, w * 0.56, w + 0.6), yaw + PI * 0.5)
	windows(base + Basis(Vector3.UP, yaw) * Vector3(0, h * 0.55, d * 0.5), yaw, w * 0.7, h * 0.6, maxi(1, int(w / 4.0)), maxi(1, int(h / 5.0)))


## A round-headed arch in a wall facing +z: two jambs and a curve of voussoirs.
func arch(c: Vector3, span: float, rise: float, depth: float, thick := 3.0) -> void:
	var n := 9
	for k in n:
		var t := (k + 0.5) / n
		var a := PI * (1.0 - t)
		var p := c + Vector3(cos(a) * span * 0.5, sin(a) * rise, 0)
		part("box", WHITE, p, Vector3(span * PI * 0.5 / n + 1.2, thick, depth), 0.0, true, a - PI * 0.5)


# ---------------------------------------------------------------- the city
func _plinth() -> void:
	# the broad base, standing in the lake, with an arcade along its front
	part("box", WHITE, Vector3(0, 7, -5), Vector3(200, 16, 130))
	for i in 14:
		var x := -84.0 + i * 13.0
		part("box", DARK, Vector3(x, 4.5, 60.1), Vector3(6, 8, 0.4), 0.0, false)
		part("ball", DARK, Vector3(x, 8.4, 60.1), Vector3(6, 6, 0.4), 0.0, false)


func _waterfront() -> void:
	# a low quay wall at the front right, and a row of small houses on it
	part("box", WHITE, Vector3(48, 5, 72), Vector3(96, 10, 22))
	part("box", SHADE, Vector3(48, 10.5, 82.5), Vector3(96, 1.2, 1.2))
	for i in 7:
		var x := 7.0 + i * 13.0
		house(Vector3(x, 10, 70), 11.0, rng.randf_range(6.0, 9.0), 10.0, 0.0, SLATE)
	# and squat towers at its ends
	tower(Vector3(-2, 10, 80), 3.6, 14.0, 6.0)
	tower(Vector3(98, 10, 78), 4.0, 22.0, 8.0)


func _stairs() -> void:
	# two grand flights from the water up to the plinth at the front left
	for x in [-80.0, -44.0]:
		var bottom := Vector3(x, 0.0, 96.0)
		var top_ := Vector3(x, 15.0, 60.0)
		var run := bottom.distance_to(top_)
		var mid := (bottom + top_) * 0.5
		var tilt := atan2(top_.y - bottom.y, bottom.z - top_.z)
		part_b("box", SHADE, mid, Vector3(16, 1.0, run), Basis(Vector3.RIGHT, tilt))
		for s in [-1.0, 1.0]:                    # balustrade walls
			part_b("box", WHITE, mid + Vector3(s * 8.5, 1.5, 0), Vector3(1.2, 3.0, run), Basis(Vector3.RIGHT, tilt))
		stairs.append([bottom, top_])
	# a landing pavilion at the head of each
	for x in [-80.0, -44.0]:
		house(Vector3(x, 15, 52), 12.0, 10.0, 10.0)


func _tiers() -> void:
	# second tier: a long block of town stepped back from the plinth's edge
	part("box", WHITE, Vector3(-5, 30, -12), Vector3(150, 30, 90))
	windows(Vector3(-5, 30, 33), 0.0, 140, 22, 22, 3)
	# houses along the second tier's front edge
	for i in 9:
		var x := -70.0 + i * 15.0
		if (x > 15.0 and x < 95.0) or x < -40.0:
			continue                                  # the gateway and the cathedral stand here
		house(Vector3(x, 15, 40), 12.0, rng.randf_range(8.0, 14.0), 10.0)
	# third tier
	part("box", SHADE, Vector3(-10, 60, -22), Vector3(110, 30, 66))
	windows(Vector3(-10, 60, 11), 0.0, 100, 22, 16, 3)
	for i in 6:
		var x := -58.0 + i * 15.0
		house(Vector3(x, 45, 16), 12.0, rng.randf_range(10.0, 18.0), 10.0)
	# rooftop houses on the third tier
	for i in 4:
		house(Vector3(-55.0 + i * 13.0, 75, -10.0 - rng.randf_range(0, 20)), 11.0, rng.randf_range(10.0, 22.0), 10.0)


func _cathedral() -> void:
	# a tall church front at the left, its lancet windows like the painting's
	var c := Vector3(-62, 15, 30)
	part("box", WHITE, c + Vector3(0, 32, 0), Vector3(36, 64, 24))
	part("prism", TAN, c + Vector3(0, 70, 0), Vector3(36, 12, 25), PI * 0.5)
	for i in 4:
		part("box", GLASS, c + Vector3(-12.0 + i * 8.0, 34, 12.1), Vector3(4.0, 22, 0.25), 0.0, false)
		part("prism", GLASS, c + Vector3(-12.0 + i * 8.0, 47, 12.1), Vector3(4.0, 4, 0.25), 0.0, false)
	part("ball", GLASS, c + Vector3(0, 55, 12.2), Vector3(9, 9, 0.4), 0.0, false)   # rose window
	for s in [-1.0, 1.0]:
		tower(c + Vector3(s * 19.5, 0, 12.5), 3.4, 70.0, 14.0)


func _left_towers() -> void:
	tower(Vector3(-96, 15, 20), 4.5, 62.0, 16.0)
	tower(Vector3(-92, 15, -12), 5.0, 78.0, 18.0)
	tower(Vector3(-80, 45, -30), 4.0, 70.0, 16.0)
	house(Vector3(-82, 15, 4), 14.0, 40.0, 14.0)
	house(Vector3(-40, 75, 6), 18.0, 26.0, 16.0)


func _clock_tower() -> void:
	var c := Vector3(5, 75, -8)
	part("cyl", WHITE, c + Vector3(0, 40, 0), Vector3(30, 80, 30))       # the great drum
	part("cyl", SHADE, c + Vector3(0, 52, 0), Vector3(34, 2.0, 34))      # gallery
	for k in 18:
		var a := TAU * k / 18.0
		part("box", WHITE, c + Vector3(cos(a) * 16.5, 54.0, sin(a) * 16.5), Vector3(1.2, 3.0, 1.2), -a, false)
	part_b("cyl", DARK, c + Vector3(0, 33, 15.0), Vector3(16, 0.6, 16), Basis(Vector3.RIGHT, PI * 0.5), false)   # clock face rim
	part_b("cyl", GLASS, c + Vector3(0, 33, 15.2), Vector3(14, 0.4, 14), Basis(Vector3.RIGHT, PI * 0.5), false)
	part_b("box", GOLD, c + Vector3(0, 35, 15.6), Vector3(0.6, 6, 0.2), Basis.IDENTITY, false)       # hands
	part_b("box", GOLD, c + Vector3(2.0, 33, 15.6), Vector3(4.5, 0.6, 0.2), Basis.IDENTITY, false)
	windows(c + Vector3(0, 66, 15.1), 0.0, 14, 8, 4, 1, 2.0, 6.0)
	part("cyl", WHITE, c + Vector3(0, 88, 0), Vector3(20, 16, 20))       # upper drum
	for k in 8:
		var a := TAU * k / 8.0
		part("box", GLASS, c + Vector3(cos(a) * 10.05, 88, sin(a) * 10.05), Vector3(1.8, 8, 0.2), PI * 0.5 - a, false)
	part("cone", GOLD, c + Vector3(0, 96 + 14, 0), Vector3(22, 28, 22))  # the crown-spire
	for k in 6:                                                           # crown points
		var a := TAU * k / 6.0
		part("cone", GOLD, c + Vector3(cos(a) * 9.0, 100, sin(a) * 9.0), Vector3(3, 9, 3), 0.0, false)
	top = c + Vector3(0, 124, 0)
	part("ball", GOLD, top + Vector3(0, 1, 0), Vector3(2, 2, 2), 0.0, false)


func _gateway() -> void:
	# a great wall with two arches at the right, the lake showing through them
	var z := 45.0
	var y0 := 15.0
	for x in [26.0, 54.0, 82.0]:                 # piers
		part("box", WHITE, Vector3(x, y0 + 38, z), Vector3(8, 76, 14))
	for x in [40.0, 68.0]:
		arch(Vector3(x, y0 + 46, z), 20.0, 14.0, 14.0, 4.0)
	part("box", WHITE, Vector3(54, y0 + 70, z), Vector3(64, 12, 14))     # wall above the arches
	windows(Vector3(54, y0 + 70, z + 7), 0.0, 56, 6, 10, 1, 1.4, 2.8)
	for i in 4:                                                          # houses on the gate's top
		house(Vector3(32.0 + i * 15.0, y0 + 76, z - 1.0), 12.0, rng.randf_range(8.0, 14.0), 11.0)


func _right_tower() -> void:
	# the tall gabled tower block at the right, and its sky bridge to the clock tower
	var c := Vector3(78, 15, -20)
	part("box", WHITE, c + Vector3(0, 70, 0), Vector3(26, 140, 26))
	part("prism", TAN, c + Vector3(0, 146, 0), Vector3(28, 12, 28), PI * 0.5)
	for f in 4:
		windows(c + Basis(Vector3.UP, f * PI * 0.5) * Vector3(0, 90, 13.0), f * PI * 0.5, 18, 90, 4, 12, 2.0, 4.0)
	tower(c + Vector3(16, 0, 10), 3.2, 150.0, 16.0)
	part("box", WHITE, Vector3(43, 150, -14), Vector3(50, 6, 8))           # sky bridge
	part("box", SHADE, Vector3(43, 153.6, -14), Vector3(50, 1.2, 8.6))
	# thin watchtowers at the right edge
	tower(Vector3(100, 15, 40), 3.0, 66.0, 10.0)
	tower(Vector3(102, 15, -20), 3.6, 88.0, 12.0)
	house(Vector3(96, 15, 12), 12.0, 50.0, 12.0)


func _back_towers() -> void:
	# a stand of slender spires behind the clock tower, linked by little bridges
	var bases := [Vector3(-36, 75, -36), Vector3(-24, 75, -46), Vector3(-12, 75, -38), Vector3(26, 75, -40)]
	var hs := [70.0, 84.0, 92.0, 76.0]
	for i in bases.size():
		tower(bases[i], 3.6, hs[i], 14.0)
	part("box", WHITE, Vector3(-30, 125, -41), Vector3(14, 3, 3))
	part("box", WHITE, Vector3(-18, 140, -42), Vector3(14, 3, 3))
	part("box", WHITE, Vector3(-4, 150, -24), Vector3(3, 3, 26))
