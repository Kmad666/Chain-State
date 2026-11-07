extends RefCounted
## Custom levels: the file format the in-game Level Editor writes, and the builder
## that turns one into real game pieces, both for the editor's view and for playing.
##
## A level is a Dictionary (saved as JSON):
##   {"name": "My level", "version": 1, "pieces": [ {piece}, ... ]}
## Every piece has an "id", a "type" and "pos" [x, y, z] in metres (y up).
##   island      r (radius), seed, grass (bool)
##   shape       shape (box / cylinder / cone / ramp / pyramid / ball),
##               size [x, y, z], rot [pitch, yaw, roll] in degrees, color "#rrggbb"
##   anchor      free (bool): a grapple crate; free ones cost no air grapple
##   start       yaw (degrees): where you begin, facing
##   checkpoint  a pad: land on it and it's where you respawn
##   finish      a gold pad: land on it to finish
##   enemy       enemy (wizard / apprentice / sage / cherub), radius (patrol, m)
##   prop        prop (a model from PROPS_FILE, e.g. ionic), size [x, y, z] (its
##               bounding box: it's scaled to fit), rot, color (a tint)

const FloatingIsland := preload("res://scripts/world/floating_island.gd")
const SwingAnchor := preload("res://scripts/world/swing_anchor.gd")

const SHAPES := ["box", "cylinder", "cone", "ramp", "pyramid", "ball"]
## Modelled props (tools/props/): name -> label, model file, natural size and
## simple collision shapes.
const PROPS_FILE := "res://assets/models/props/pillars/props.json"
const ENEMIES := ["wizard", "apprentice", "sage", "cherub"]
const PICK_LAYER := 16              # the editor picks pieces on this physics layer
const USER_DIR := "user://levels"
const SHIPPED_DIR := "res://data/levels"


static var _props := {}


## The modelled props, by name, in the order they're listed in.
static func props() -> Dictionary:
	if _props.is_empty() and FileAccess.file_exists(PROPS_FILE):
		_props = JSON.parse_string(FileAccess.get_file_as_string(PROPS_FILE))
	return _props


static func v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() >= 3 else Vector3.ZERO


static func arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func blank(level_name := "New level") -> Dictionary:
	return {"name": level_name, "version": 1, "pieces": [
		{"id": "p1", "type": "island", "pos": [0, 0, 0], "r": 30.0, "seed": 1, "grass": true},
		{"id": "p2", "type": "start", "pos": [0, 1, 20], "yaw": 0.0},
	]}


## A new piece of a type (and sub-kind) with sensible defaults, at `at`.
static func make_piece(type: String, sub: String, at: Vector3, id: String) -> Dictionary:
	var p := {"id": id, "type": type, "pos": arr(at)}
	match type:
		"island":
			p.merge({"r": 25.0, "seed": randi() % 10000, "grass": true})
		"shape":
			var size := Vector3(6, 6, 6)
			if sub == "ramp":
				size = Vector3(8, 4, 12)
			elif sub in ["cylinder", "cone"]:
				size = Vector3(4, 12, 4)
			p.merge({"shape": sub, "size": arr(size), "rot": [0, 0, 0], "color": "#e8ecf2"})
		"anchor":
			p["free"] = sub == "free"
		"prop":
			var info: Dictionary = props().get(sub, {})
			p.merge({"prop": sub, "size": info.get("size", [1, 1, 1]), "rot": [0, 0, 0], "color": "#f2ede4"})
		"start":
			p["yaw"] = 0.0
		"enemy":
			p.merge({"enemy": sub, "radius": {"wizard": 16.0, "apprentice": 25.0, "sage": 5.0, "cherub": 0.0}.get(sub, 10.0)})
	return p


# ---------------------------------------------------------------- building
## Build one piece as a node. `editor` true: markers for start / enemies, and
## everything pickable on PICK_LAYER. In play, start and enemy pieces return null
## (the world handles them).
static func make(p: Dictionary, editor: bool) -> Node3D:
	var n: Node3D = null
	var pos := v3(p.get("pos", [0, 0, 0]))
	match String(p.get("type", "")):
		"island":
			var isl := FloatingIsland.new()
			isl.radius = maxf(float(p.get("r", 25.0)), 4.0)
			isl.island_seed = int(p.get("seed", 1))
			isl.grass = bool(p.get("grass", true))
			n = isl
		"shape":
			n = _shape(p)
		"prop":
			n = _prop(p)
		"anchor":
			var a := SwingAnchor.new()
			a.free = bool(p.get("free", false))
			n = a
		"checkpoint":
			n = _pad(Vector3(6, 0.6, 6), Color(0.25, 0.75, 0.70), "checkpoint")
		"finish":
			n = _pad(Vector3(8, 0.6, 8), Color(0.95, 0.75, 0.25), "finish")
			_flag(n)
		"start":
			if not editor:
				return null
			n = _marker(Color(0.3, 0.9, 0.4), 1.8, "START")
			n.rotation.y = deg_to_rad(float(p.get("yaw", 0.0)))
		"enemy":
			if not editor:
				return null
			var kind := String(p.get("enemy", "wizard"))
			var col: Color = {"wizard": Color(0.55, 0.3, 0.9), "apprentice": Color(0.3, 0.5, 1.0),
				"sage": Color(0.95, 0.95, 0.6), "cherub": Color(1.0, 0.85, 0.4)}.get(kind, Color.WHITE)
			n = _marker(col, 6.0 if kind == "cherub" else 2.0, kind.to_upper())
			var r := float(p.get("radius", 0.0))
			if r > 0.5:
				n.add_child(_ring(r, col))
	if n == null:
		return null
	n.position = pos
	n.set_meta("pid", p.get("id", ""))
	if editor:
		n.ready.connect(func(): _pickable(n), CONNECT_ONE_SHOT)
	return n


## Plain shape pieces: a solid, grapple-able body with the mesh scaled to `size`.
static func _shape(p: Dictionary) -> Node3D:
	var kind := String(p.get("shape", "box"))
	var size := v3(p.get("size", [4, 4, 4]))
	size = Vector3(maxf(size.x, 0.2), maxf(size.y, 0.2), maxf(size.z, 0.2))
	var rot := v3(p.get("rot", [0, 0, 0]))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	var mesh := unit_mesh(kind)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = size
	mi.rotation.y = PI / 4.0 if kind == "pyramid" else 0.0
	var col := Color.html(String(p.get("color", "#e8ecf2")))
	mi.material_override = Mats.lit(col)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	if kind == "box":
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
	else:
		var hull := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		var turn := Basis(Vector3.UP, PI / 4.0) if kind == "pyramid" else Basis.IDENTITY
		for q in mesh.create_convex_shape().points:
			pts.append((turn * q) * size)
		hull.points = pts
		cs.shape = hull
	body.add_child(cs)
	return body


## A modelled prop: the model scaled to the piece's size, in marble tinted by its
## colour, solid and grapple-able through a few simple collision shapes.
static var _scenes := {}


static func _prop(p: Dictionary) -> Node3D:
	var info: Dictionary = props().get(String(p.get("prop", "")), {})
	if info.is_empty():
		return null
	var natural := v3(info.size)
	var size := v3(p.get("size", info.size))
	size = Vector3(maxf(size.x, 0.1), maxf(size.y, 0.1), maxf(size.z, 0.1))
	var s := size / natural
	var rot := v3(p.get("rot", [0, 0, 0]))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	var file := String(info.file)
	if not _scenes.has(file):
		_scenes[file] = load(file)
	var model: Node3D = (_scenes[file] as PackedScene).instantiate()
	model.scale = s
	var mat := Mats.marble(Color.html(String(p.get("color", "#f2ede4"))))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	body.add_child(model)
	for c in info.collide:
		var cs := CollisionShape3D.new()
		cs.position = v3(c.at) * s
		if c.has("box"):
			var b := BoxShape3D.new()
			b.size = v3(c.box) * s
			cs.shape = b
		else:
			var cy := CylinderShape3D.new()
			cy.radius = float(c.cyl) * minf(s.x, s.z)
			cy.height = float(c.height) * s.y
			cs.shape = cy
		body.add_child(cs)
	return body


static var _units := {}


static func unit_mesh(kind: String) -> Mesh:
	if _units.has(kind):
		return _units[kind]
	var m: Mesh
	match kind:
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 24
			m = c
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 24
			m = c
		"pyramid":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.70711
			c.height = 1.0
			c.radial_segments = 4
			c.rings = 1
			m = c
		"ramp":
			var pr := PrismMesh.new()
			pr.left_to_right = 0.0              # a wedge: the slope rises toward -x
			m = pr
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			m = s
		_:
			m = BoxMesh.new()
	_units[kind] = m
	return m


static func _pad(size: Vector3, col: Color, meta: String) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(meta, true)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := Mats.lit(col)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	return body


static func _flag(pad: Node3D) -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.08
	pm.height = 5.0
	pole.mesh = pm
	pole.position = Vector3(3.2, 2.8, -3.2)
	pole.material_override = Mats.lit(Color(0.25, 0.22, 0.2))
	pad.add_child(pole)
	var cloth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 1.2, 0.05)
	cloth.mesh = bm
	cloth.position = Vector3(2.2, 4.6, -3.2)
	cloth.material_override = Mats.lit(Color(0.95, 0.75, 0.25))
	pad.add_child(cloth)


## An editor marker: a capsule, an arrow showing which way it faces, and a label.
static func _marker(col: Color, height: float, text: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = height * 0.25
	cap.height = height
	mi.mesh = cap
	mi.position.y = height * 0.5
	var mat := Mats.lit(col)
	mi.material_override = mat
	root.add_child(mi)
	var arrow := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = height * 0.18
	am.height = height * 0.5
	arrow.mesh = am
	arrow.rotation.x = -PI * 0.5           # points along -z (forward)
	arrow.position = Vector3(0, height * 0.6, -height * 0.45)
	arrow.material_override = mat
	root.add_child(arrow)
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 28
	l.outline_size = 8
	l.position.y = height + 1.2
	root.add_child(l)
	return root


## A thin circle on the ground showing an enemy's patrol range.
static func _ring(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.15
	tm.outer_radius = r + 0.15
	tm.rings = 48
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	return mi


## In the editor every piece can be clicked: its bodies join the pick layer, and
## markers get a pick box of their own.
static func _pickable(n: Node3D) -> void:
	var bodies := n.find_children("*", "CollisionObject3D", true, false)
	if n is CollisionObject3D:
		bodies.append(n)
	if bodies.is_empty():
		var b := StaticBody3D.new()
		b.collision_layer = 1 << (PICK_LAYER - 1)
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3, 6, 3)
		cs.shape = bs
		cs.position.y = 3.0
		b.add_child(cs)
		n.add_child(b)
	else:
		for b in bodies:
			b.collision_layer |= 1 << (PICK_LAYER - 1)


# ---------------------------------------------------------------- files
static func slug(level_name: String) -> String:
	var s := level_name.strip_edges().to_lower()
	var out := ""
	for ch in s:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	return out.trim_prefix("-").trim_suffix("-") if out.strip_edges() != "" else "level"


static func save(data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var path := "%s/%s.json" % [USER_DIR, slug(String(data.get("name", "level")))]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return path


static func parse(text: String) -> Dictionary:
	var d = JSON.parse_string(text)
	if d is Dictionary and d.get("pieces") is Array:
		return d
	return {}


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse(FileAccess.get_file_as_string(path))


## Every level you can open: your saved ones, then any shipped with the game.
## [[display name, path], ...]
static func list_levels() -> Array:
	var out: Array = []
	for dir in [USER_DIR, SHIPPED_DIR]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".json"):
				var data := load_file("%s/%s" % [dir, f])
				if not data.is_empty():
					out.append([String(data.get("name", f.get_basename())), "%s/%s" % [dir, f]])
	return out
