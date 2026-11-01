extends "res://scripts/world/blockout.gd"
## The Brick Spire: a cluster of medieval brick towers grown into one mass, after a
## reference sculpture Daniel shared (it looks like Bologna's tower houses).
##
## - **The base:** a battered plinth that flares toward the ground, ribbed with
##   buttresses. Its front has a tall arched doorway, paired arched windows and a
##   three-bay loggia.
## - **On the base**, stepped blocks of different heights:
##   - a front block with a four-arch loggia on a corbelled balcony, under a
##     stepped gable
##   - a rear block on the right
##   - a second tower, front right, with a little bartizan on its flank
##   - the tallest tower, back left, with a band course half way up, a
##     three-light window near its top and a cornice under a low hipped cap
## - **The masonry** is rough pale beige stone flecked with grit. Small arched
##   windows and putlog holes pepper every face.
##
## Everything is solid and grapple-able. Cornices, the band course, the loggia
## balconies and the corbelled ledges are the rest stops on the way up. The origin
## is the ground at the tower's foot, and the main tower's cap tops out near 250 m.

const BRICK := Color(0.78, 0.67, 0.50)        # pale beige stone (warm enough to stay beige in hard sun)
const BRICK_DK := Color(0.66, 0.55, 0.40)
const BRICK_LT := Color(0.84, 0.74, 0.57)
const HOLE := Color(0.12, 0.10, 0.08)

var top := Vector3.ZERO
var ledges: Array = []            # [centre, size] of every walkable rest ledge


func top_point() -> Vector3:
	return global_position + top


func build() -> void:
	rng.seed = 1119
	_base()
	_front_block()
	_rear_block()
	_second_tower()
	_main_tower()


# ---------------------------------------------------------------- helpers
## An arched opening on a wall facing along `yaw` (0 = +z): a dark recess with a
## round head. `c` is the opening's foot.
func opening(c: Vector3, yaw: float, w: float, h: float, solid_sill := false) -> void:
	var out := Basis(Vector3.UP, yaw)
	part("box", HOLE, c + out * Vector3(0, h * 0.5, 0.05), Vector3(w, h, 0.3), yaw, false)
	part_b("cyl", HOLE, c + out * Vector3(0, h, 0.05), Vector3(w, 0.3, w), out * Basis(Vector3.RIGHT, PI * 0.5), false)
	if solid_sill:
		part("box", BRICK_LT, c + out * Vector3(0, -0.3, 0.5), Vector3(w + 0.8, 0.6, 1.2), yaw)


## Small dark putlog holes and slit windows scattered over a face.
func pepper(c: Vector3, yaw: float, w: float, h: float, n: int) -> void:
	var out := Basis(Vector3.UP, yaw)
	for i in n:
		var p := Vector3(rng.randf_range(-w * 0.42, w * 0.42), rng.randf_range(-h * 0.45, h * 0.45), 0.05)
		if rng.randf() < 0.75:
			part("box", HOLE, c + out * p, Vector3(0.6, 0.6, 0.25), yaw, false)
		else:
			opening(c + out * p, yaw, 1.2, 2.4)


## Holes and slits over a battered face: `out0` is the face's distance from the
## centre at the ground, and it leans in by `lean` per metre of height.
func pepper_batter(out0: float, lean: float, yaw: float, w: float, h: float, n: int) -> void:
	var out := Basis(Vector3.UP, yaw)
	for i in n:
		var y := rng.randf_range(4.0, h - 4.0)
		var p := Vector3(rng.randf_range(-w * 0.42, w * 0.42), y, out0 - lean * y + 0.05)
		if rng.randf() < 0.75:
			part("box", HOLE, out * p, Vector3(0.6, 0.6, 0.4), yaw, false)
		else:
			opening(out * p, yaw, 1.2, 2.4)


## A walkable cornice ring round a square mass (w x d) at height y.
func cornice(c: Vector3, w: float, d: float, y: float, reach := 1.4, thick := 1.0) -> void:
	part("box", BRICK_LT, Vector3(c.x, y, c.z), Vector3(w + reach * 2.0, thick, d + reach * 2.0))
	ledges.append([Vector3(c.x, y + thick * 0.5, c.z), Vector3(w + reach * 2.0, thick, d + reach * 2.0)])


## A row of arches (a loggia) on a face, on a corbelled balcony you can stand on.
func loggia(c: Vector3, yaw: float, bays: int, bay_w: float, h: float) -> void:
	var out := Basis(Vector3.UP, yaw)
	var span := bays * bay_w
	part("box", HOLE, c + out * Vector3(0, h * 0.5, -0.6), Vector3(span, h, 1.0), yaw, false)          # the shadowed gallery behind
	for k in bays + 1:
		var x := -span * 0.5 + k * bay_w
		part("box", BRICK_LT, c + out * Vector3(x, h * 0.5, 0.1), Vector3(0.9, h, 0.9), yaw)             # columns
	for k in bays:
		var x := -span * 0.5 + (k + 0.5) * bay_w
		part_b("cyl", BRICK, c + out * Vector3(x, h, 0.1), Vector3(bay_w - 0.9, 0.9, bay_w - 0.9), out * Basis(Vector3.RIGHT, PI * 0.5), false)
	part("box", BRICK, c + out * Vector3(0, h + bay_w * 0.5 + 0.8, 0.1), Vector3(span + 1.0, 1.6, 1.0), yaw)  # the wall over the arches
	# the balcony: a slab on corbels, with a low parapet
	var slab := c + out * Vector3(0, -0.4, 1.6)
	part("box", BRICK_LT, slab, Vector3(span + 2.0, 0.8, 3.6), yaw)
	ledges.append([slab + Vector3(0, 0.4, 0), Vector3(span + 2.0, 0.8, 3.6)])
	part("box", BRICK, c + out * Vector3(0, 0.6, 3.25), Vector3(span + 2.0, 1.2, 0.3), yaw, false)
	for k in bays + 2:
		var x := -span * 0.5 - 1.0 + k * (span + 2.0) / (bays + 1)
		part("box", BRICK_DK, c + out * Vector3(x, -1.4, 1.2), Vector3(0.8, 1.6, 2.4), yaw, false)


# ---------------------------------------------------------------- the masses
func _base() -> void:
	# a battered plinth: a frustum, wide at the ground, drawn as its own mesh
	var bw := 64.0
	var bd := 48.0
	var tw := 54.0
	var td := 40.0
	var h := 70.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := [Vector3(-bw / 2, 0, -bd / 2), Vector3(bw / 2, 0, -bd / 2), Vector3(bw / 2, 0, bd / 2), Vector3(-bw / 2, 0, bd / 2)]
	var hi := [Vector3(-tw / 2, h, -td / 2), Vector3(tw / 2, h, -td / 2), Vector3(tw / 2, h, td / 2), Vector3(-tw / 2, h, td / 2)]
	for i in 4:
		var j := (i + 1) % 4
		st.add_vertex(lo[i]); st.add_vertex(hi[i]); st.add_vertex(lo[j])
		st.add_vertex(lo[j]); st.add_vertex(hi[i]); st.add_vertex(hi[j])
	st.add_vertex(hi[0]); st.add_vertex(hi[3]); st.add_vertex(hi[2])
	st.add_vertex(hi[0]); st.add_vertex(hi[2]); st.add_vertex(hi[1])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material_for(BRICK)
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_convex_shape()
	body.add_child(cs)
	# buttress ribs down every face, leaning with the batter
	var lean_x := atan2((bw - tw) * 0.5, h)
	var lean_z := atan2((bd - td) * 0.5, h)
	for f in 4:
		var along_x := f % 2 == 0                  # front / back faces run along x
		var span := (tw if along_x else td)
		var n := 6 if along_x else 4
		for k in n:
			var t := (k + 0.5) / n
			var off := -span * 0.5 + t * span
			var sgn := 1.0 if f < 2 else -1.0
			var pos: Vector3
			var rot: Basis
			if along_x:
				pos = Vector3(off * ((bw + tw) / (2.0 * tw)), h * 0.5, sgn * ((bd + td) * 0.25 + 0.6))
				rot = Basis(Vector3.RIGHT, -sgn * lean_z)       # its top leans in with the wall
			else:
				pos = Vector3(sgn * ((bw + tw) * 0.25 + 0.6), h * 0.5, off * ((bd + td) / (2.0 * td)))
				rot = Basis(Vector3.BACK, sgn * lean_x)
			part_b("box", BRICK_DK, pos, Vector3(2.0, h, 2.0), rot, false)
	# the front (+z) face: a tall arched door, paired windows, a three-bay loggia.
	# The face leans in as it rises, so each opening sits where the face is at its height
	var zf := func(y: float) -> float: return bd * 0.5 - (bd - td) * 0.5 * y / h
	opening(Vector3(8, 0, zf.call(6.0)), 0.0, 5.0, 12.0)
	for x in [-14.0, -9.0]:
		opening(Vector3(x, 14, zf.call(17.0)), 0.0, 3.0, 6.0, true)
	loggia(Vector3(-11, 40, zf.call(44.0) + 0.6), 0.0, 3, 4.6, 7.0)
	pepper_batter(bd * 0.5, (bd - td) * 0.5 / h, 0.0, 44.0, h, 22)
	pepper_batter(bw * 0.5, (bw - tw) * 0.5 / h, PI * 0.5, 36.0, h, 14)
	pepper_batter(bw * 0.5, (bw - tw) * 0.5 / h, -PI * 0.5, 36.0, h, 14)
	cornice(Vector3(0, 0, 0), tw, td, h + 0.5, 1.0, 1.0)


func _front_block() -> void:
	# a block on the front of the base, its loggia over a corbelled balcony, a stepped gable on top
	var c := Vector3(-4, 71, 8)
	var w := 26.0
	var d := 18.0
	var h := 62.0
	part("box", BRICK, c + Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	loggia(c + Vector3(0, 30, d * 0.5 + 0.1), 0.0, 4, 4.4, 7.5)
	cornice(c, w, d, c.y + 27.0, 1.0, 0.8)
	for x in [-3.0, 3.0]:
		opening(c + Vector3(x, 46, d * 0.5 + 0.05), 0.0, 1.8, 4.0)
	pepper(c + Vector3(0, 14, d * 0.5 + 0.05), 0.0, w, 22, 8)
	# stepped gable
	for k in 4:
		var sw := w - k * 6.0
		part("box", BRICK, c + Vector3(0, h + 1.5 + k * 3.0, 0), Vector3(sw, 3.0, d))
	part("box", BRICK_LT, c + Vector3(0, h + 0.4, d * 0.5 + 0.7), Vector3(w + 1.0, 0.8, 1.4))


func _rear_block() -> void:
	var c := Vector3(16, 71, -8)
	part("box", BRICK, c + Vector3(0, 41, 0), Vector3(16, 82, 20))
	cornice(c, 16, 20, c.y + 82.5, 1.0, 1.0)
	part("pyramid", BRICK_LT, c + Vector3(0, 86.0, 0), Vector3(17, 6, 21), PI / 4.0)
	for k in 3:
		opening(c + Vector3(8.05, 20 + k * 20.0, 4), PI * 0.5, 2.0, 4.5)
	pepper(c + Vector3(8.05, 40, 0), PI * 0.5, 18, 70, 8)


func _second_tower() -> void:
	var c := Vector3(14, 71, 8)
	var s := 17.0
	var h := 108.0
	part("box", BRICK, c + Vector3(0, h * 0.5, 0), Vector3(s, h, s))
	cornice(c, s, s, c.y + h + 0.5, 1.4, 1.2)
	part("pyramid", BRICK_LT, c + Vector3(0, h + 4.6, 0), Vector3(s + 2.0, 7.0, s + 2.0), PI / 4.0)
	# a little bartizan on its left flank
	part("box", BRICK, c + Vector3(-s * 0.5 - 2.0, 92, 3), Vector3(4.0, 7.0, 5.0))
	part("box", BRICK_DK, c + Vector3(-s * 0.5 - 2.0, 87.6, 3), Vector3(3.0, 1.8, 4.0), 0.0, false)
	ledges.append([c + Vector3(-s * 0.5 - 2.0, 95.5, 3), Vector3(4.0, 0.1, 5.0)])
	# windows: a pair high up, slits below
	for x in [-2.6, 2.6]:
		opening(c + Vector3(x, 88, s * 0.5 + 0.05), 0.0, 1.6, 4.0)
	pepper(c + Vector3(0, 50, s * 0.5 + 0.05), 0.0, s, 80, 10)
	pepper(c + Vector3(s * 0.5 + 0.05, 55, 0), PI * 0.5, s, 90, 10)


func _main_tower() -> void:
	var c := Vector3(-14, 71, -6)
	var s := 22.0
	var h := 166.0
	part("box", BRICK, c + Vector3(0, h * 0.5, 0), Vector3(s, h, s))
	# the band course half way up, a walkable ledge all round
	cornice(c, s, s, c.y + 70.0, 1.2, 0.8)
	# a three-light window near the top, on the front and the side
	for f in [0.0, -PI * 0.5]:
		var out := Basis(Vector3.UP, f)
		for k in 3:
			opening(c + out * Vector3(-3.0 + k * 3.0, 138, s * 0.5 + 0.05), f, 1.8, 4.6)
		part("box", BRICK_LT, c + out * Vector3(0, 137.6, s * 0.5 + 0.6), Vector3(10, 0.6, 1.2), f)
	# a corbelled ledge on the side, as in the sculpture
	part("box", BRICK_LT, c + Vector3(-s * 0.5 - 1.6, 98, 0), Vector3(3.2, 0.8, 9.0))
	ledges.append([c + Vector3(-s * 0.5 - 1.6, 98.4, 0), Vector3(3.2, 0.1, 9.0)])
	for z in [-3.0, 0.0, 3.0]:
		part("box", BRICK_DK, c + Vector3(-s * 0.5 - 0.9, 96.8, z), Vector3(1.8, 1.6, 0.8), 0.0, false)
	pepper(c + Vector3(0, 60, s * 0.5 + 0.05), 0.0, s, 110, 14)
	pepper(c + Vector3(-s * 0.5 - 0.05, 60, 0), -PI * 0.5, s, 110, 12)
	pepper(c + Vector3(0, 80, -s * 0.5 - 0.05), PI, s, 140, 12)
	# the cornice and the low hipped cap
	cornice(c, s, s, c.y + h + 0.6, 1.6, 1.4)
	part("pyramid", BRICK_LT, c + Vector3(0, h + 5.2, 0), Vector3(s + 3.0, 8.0, s + 3.0), PI / 4.0)
	top = c + Vector3(0, h + 9.2, 0)


# ---------------------------------------------------------------- the masonry
## Rough pale stone: courses of uneven blocks flecked with light grit and dark
## pits, laid in world space so it reads the same size everywhere.
func material_for(col: Color) -> Material:
	if col.r < 0.2:
		return Mats.lit(col)                            # openings stay plain and dark
	var m := StandardMaterial3D.new()
	m.albedo_texture = _speckle(col)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 4.0                     # one tile = 4 m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	m.metallic_specular = 0.15
	return m


static var _tex := {}


static func _speckle(col: Color) -> ImageTexture:
	var key := col.to_html()
	if _tex.has(key):
		return _tex[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var course_tone := []
	for i in 8:
		course_tone.append(r.randf_range(-0.05, 0.05))
	for y in n:
		var course := y / 16
		for x in n:
			var c := col.lightened(course_tone[course]) if course_tone[course] > 0.0 else col.darkened(-course_tone[course])
			var k := r.randf()
			if k < 0.05:
				c = c.lightened(r.randf_range(0.15, 0.35))      # grit
			elif k < 0.09:
				c = c.darkened(r.randf_range(0.2, 0.4))         # pits
			if y % 16 == 0 or (x + (course % 2) * 20) % 40 == 0:
				c = c.darkened(0.12)                            # faint joints
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t
