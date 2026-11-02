extends Node3D
## The Level Editor: build your own Chain State levels in the browser (or desktop
## build), then play-test them with the real grapple, enemies and physics.
##
## Camera:   hold the RIGHT mouse button to look; WASD fly, E up, Q down, Shift fast.
##           F frames the selected piece.
## Pieces:   click a button on the left to drop that piece where you're looking.
##           LEFT-click a piece to select it; drag it to slide it across the ground
##           (1 m snap; hold Alt for free movement).
##           Arrows nudge it, Page Up / Down raise and lower it (Shift = x10),
##           R / Shift+R turn it 15 degrees, Ctrl+D duplicates, Delete removes.
##           Drag a coloured handle on a shape's face to resize it along that axis
##           (Shift scales evenly, Alt skips the 0.5 m snap); drag a gold handle on
##           an island's rim or an enemy's patrol ring to change its radius.
## File:     Ctrl+S saves to your levels (kept in this browser), Ctrl+Z undoes,
##           P play-tests. Copy / Paste JSON moves a level between computers, or to
##           Claude to ship with the game.
##
## The level format and the piece builder live in scripts/world/custom_level.gd.

const CL := preload("res://scripts/world/custom_level.gd")
const PICK_MASK := 1 << (CL.PICK_LAYER - 1)
const FLY := 30.0
const UNDO_MAX := 60

var data: Dictionary
var nodes := {}                   # piece id -> Node3D in the scene
var sel := ""                     # selected piece id
var cam: Camera3D
var _yaw := 0.0
var _pitch := -0.35
var _looking := false
var _drag := {}                   # {id, plane_y, offset, before}
var _undo: Array = []
var _next_id := 1
var _box: MeshInstance3D          # the gold box round the selection
var _grips: Array = []            # resize handle meshes (up to 6)
var _hover_grip := -1
var dirty := false

# UI
var ui: Control
var name_edit: LineEdit
var inspector: VBoxContainer
var status: Label
var open_menu: PopupMenu
var paste_panel: PanelContainer
var paste_text: TextEdit
var _open_paths: Array = []


func _ready() -> void:
	Game.set_ui_mode("menu")
	data = Game.custom.duplicate(true) if not Game.custom.is_empty() else CL.blank()
	_environment()
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 6000
	add_child(cam)
	cam.make_current()
	_grid()
	_box = MeshInstance3D.new()
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.8, 0.25)
	bm.no_depth_test = true
	_box.material_override = bm
	add_child(_box)
	for i in 6:
		var g := MeshInstance3D.new()
		g.mesh = BoxMesh.new()
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.no_depth_test = true
		gm.render_priority = 2
		g.material_override = gm
		g.visible = false
		add_child(g)
		_grips.append(g)
	_build_ui()
	_rebuild_all()
	_frame_level()
	_status("Hold the right mouse button to look around. Click a piece on the left to add it.")


# ---------------------------------------------------------------- scene
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.02, 0.07, 0.36)
	sky.sky_horizon_color = Color(0.36, 0.50, 0.82)
	sky.ground_horizon_color = Color(0.36, 0.50, 0.82)
	sky.ground_bottom_color = Color(0.02, 0.07, 0.36)
	sky.sky_curve = 0.18
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.92)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	sun.light_energy = 1.1
	var d := Basis.from_euler(Vector3(deg_to_rad(52.0), -TAU / 6.0, 0)) * Vector3.FORWARD
	sun.basis = Basis.looking_at(-d, Vector3.UP)
	add_child(sun)


## A faint 10 m reference grid at y = 0 (bolder every 50 m).
func _grid() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-40, 41):
		var a := 0.55 if i % 5 == 0 else 0.22
		im.surface_set_color(Color(0.8, 0.9, 1.0, a))
		im.surface_add_vertex(Vector3(i * 10.0, 0, -400))
		im.surface_add_vertex(Vector3(i * 10.0, 0, 400))
		im.surface_set_color(Color(0.8, 0.9, 1.0, a))
		im.surface_add_vertex(Vector3(-400, 0, i * 10.0))
		im.surface_add_vertex(Vector3(400, 0, i * 10.0))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _rebuild_all() -> void:
	for id in nodes:
		if is_instance_valid(nodes[id]):
			nodes[id].queue_free()
	nodes.clear()
	_next_id = 1
	for p in data.pieces:
		var n := String(p.get("id", "")).trim_prefix("p")
		if n.is_valid_int():
			_next_id = maxi(_next_id, int(n) + 1)
	for p in data.pieces:
		if String(p.get("id", "")) == "":
			p["id"] = _new_id()
		_spawn(p)
	if name_edit:
		name_edit.text = String(data.get("name", "New level"))
	if not nodes.has(sel):
		sel = ""
	_refresh_inspector()


func _spawn(p: Dictionary) -> void:
	var n := CL.make(p, true)
	if n == null:
		return
	add_child(n)
	nodes[String(p.id)] = n


func _rebuild(id: String) -> void:
	if nodes.has(id) and is_instance_valid(nodes[id]):
		nodes[id].queue_free()
	nodes.erase(id)
	var p := piece(id)
	if not p.is_empty():
		_spawn(p)


func _new_id() -> String:
	var id := "p%d" % _next_id
	_next_id += 1
	return id


func piece(id: String) -> Dictionary:
	for p in data.pieces:
		if String(p.get("id", "")) == id:
			return p
	return {}


# ---------------------------------------------------------------- editing
func _remember() -> void:
	_undo.append(JSON.stringify(data))
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	dirty = true


func undo() -> void:
	if _undo.is_empty():
		_status("Nothing to undo.")
		return
	var d = JSON.parse_string(_undo.pop_back())
	if d is Dictionary:
		data = d
		_rebuild_all()
		_status("Undone.")


## Add a piece of `type` (and sub-kind) where the camera is looking.
func add_piece(type: String, sub := "") -> Dictionary:
	if type == "start":
		for p in data.pieces:
			if p.type == "start":
				select(String(p.id))
				_status("A level has one start: it's selected. Move it where you want to begin.")
				return p
	_remember()
	var at := _aim_point()
	var p := CL.make_piece(type, sub, at, _new_id())
	# rest things on the surface they're dropped on
	match type:
		"shape":
			var size := CL.v3(p.size)
			p.pos = CL.arr(at + Vector3(0, size.y * 0.5, 0))
		"anchor":
			p.pos = CL.arr(at + Vector3(0, 6, 0))
		"enemy":
			p.pos = CL.arr(at + Vector3(0, 3 if sub != "cherub" else 40, 0))
		"start", "checkpoint", "finish":
			p.pos = CL.arr(at + Vector3(0, 0.3, 0))
	data.pieces.append(p)
	_spawn(p)
	select(String(p.id))
	_status("Added %s. Drag it into place." % _label(p))
	return p


func delete_selected() -> void:
	var p := piece(sel)
	if p.is_empty():
		return
	if p.type == "start":
		_status("The start can't be deleted: move it instead.")
		return
	_remember()
	data.pieces.erase(p)
	if nodes.has(sel):
		nodes[sel].queue_free()
		nodes.erase(sel)
	_status("Deleted %s." % _label(p))
	select("")


func duplicate_selected() -> void:
	var p := piece(sel)
	if p.is_empty() or p.type == "start":
		return
	_remember()
	var q: Dictionary = p.duplicate(true)
	q.id = _new_id()
	q.pos = CL.arr(CL.v3(p.pos) + Vector3(4, 0, 4))
	if q.type == "island":
		q.pos = CL.arr(CL.v3(p.pos) + Vector3(float(p.r) * 2.5, 0, 0))
	data.pieces.append(q)
	_spawn(q)
	select(String(q.id))
	_status("Duplicated.")


## Change fields of the selected piece (from the inspector or keys) and rebuild it.
func set_fields(changes: Dictionary, remember := true) -> void:
	var p := piece(sel)
	if p.is_empty():
		return
	if remember:
		_remember()
	p.merge(changes, true)
	_rebuild(sel)
	_refresh_inspector()


func move_selected(delta: Vector3) -> void:
	var p := piece(sel)
	if p.is_empty():
		return
	set_fields({"pos": CL.arr(CL.v3(p.pos) + delta)})


func turn_selected(deg: float) -> void:
	var p := piece(sel)
	if p.is_empty():
		return
	if p.type == "shape":
		var r := CL.v3(p.rot)
		r.y = fposmod(r.y + deg, 360.0)
		set_fields({"rot": CL.arr(r)})
	elif p.type == "start":
		set_fields({"yaw": fposmod(float(p.get("yaw", 0.0)) + deg, 360.0)})


func select(id: String) -> void:
	sel = id
	_refresh_inspector()


func _label(p: Dictionary) -> String:
	match String(p.get("type", "")):
		"shape":
			return String(p.get("shape", "shape")).capitalize()
		"enemy":
			return String(p.get("enemy", "enemy")).capitalize()
		"anchor":
			return "Free anchor" if p.get("free", false) else "Anchor"
	return String(p.get("type", "piece")).capitalize()


# ---------------------------------------------------------------- input
func _unhandled_input(e: InputEvent) -> void:
	if paste_panel.visible:
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			_looking = e.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if e.pressed else Input.MOUSE_MODE_VISIBLE
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_press(e.position)
			else:
				_release()
		elif e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
			cam.position += -cam.global_basis.z * (6.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -6.0)
	elif e is InputEventMouseMotion:
		if _looking:
			_yaw -= e.relative.x * 0.004
			_pitch = clampf(_pitch - e.relative.y * 0.004, -1.5, 1.5)
			cam.rotation = Vector3(_pitch, _yaw, 0)
		elif not _drag.is_empty() and _drag.has("grip"):
			_grip_to(e.position, e.alt_pressed, e.shift_pressed)
		elif not _drag.is_empty():
			_drag_to(e.position, e.alt_pressed)
		else:
			_hover_grip = _grip_at(e.position)
	elif e is InputEventKey and e.pressed and not e.echo:
		_key(e)


func _key(e: InputEventKey) -> void:
	var big := 10.0 if e.shift_pressed else 1.0
	var handled := true
	if e.ctrl_pressed or e.meta_pressed:
		match e.keycode:
			KEY_S:
				save()
			KEY_Z:
				undo()
			KEY_D:
				duplicate_selected()
			_:
				handled = false
	else:
		match e.keycode:
			KEY_DELETE, KEY_BACKSPACE:
				delete_selected()
			KEY_P:
				play_test()
			KEY_F:
				_frame_selected()
			KEY_R:
				turn_selected(-15.0 if e.shift_pressed else 15.0)
			KEY_LEFT:
				move_selected(_flat(-cam.global_basis.x) * big)
			KEY_RIGHT:
				move_selected(_flat(cam.global_basis.x) * big)
			KEY_UP:
				move_selected(_flat(-cam.global_basis.z) * big)
			KEY_DOWN:
				move_selected(_flat(cam.global_basis.z) * big)
			KEY_PAGEUP:
				move_selected(Vector3.UP * big)
			KEY_PAGEDOWN:
				move_selected(Vector3.DOWN * big)
			KEY_ESCAPE:
				select("")
			_:
				handled = false
	if handled:
		get_viewport().set_input_as_handled()


## The nearest grid axis to a camera direction, so arrow keys move along the grid.
func _flat(v: Vector3) -> Vector3:
	v.y = 0
	if absf(v.x) > absf(v.z):
		return Vector3(signf(v.x), 0, 0)
	return Vector3(0, 0, signf(v.z))


func _process(dt: float) -> void:
	var typing := get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit \
		or get_viewport().gui_get_focus_owner() is SpinBox
	if not typing and not paste_panel.visible:
		var v := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): v.z -= 1
		if Input.is_physical_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL): v.z += 1
		if Input.is_physical_key_pressed(KEY_A): v.x -= 1
		if Input.is_physical_key_pressed(KEY_D) and not Input.is_key_pressed(KEY_CTRL): v.x += 1
		if Input.is_physical_key_pressed(KEY_E): v.y += 1
		if Input.is_physical_key_pressed(KEY_Q): v.y -= 1
		if v != Vector3.ZERO:
			var speed := FLY * (5.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
			var move := cam.global_basis * Vector3(v.x, 0, v.z)
			cam.position += (move.normalized() * Vector2(v.x, v.z).length() + Vector3(0, v.y, 0)) * speed * dt
	_draw_selection()
	_draw_grips()


func _ray(screen: Vector2, mask: int) -> Dictionary:
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 4000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _owner_id(n: Node) -> String:
	while n:
		if n.has_meta("pid"):
			return String(n.get_meta("pid"))
		n = n.get_parent()
	return ""


func _press(screen: Vector2) -> void:
	# a resize handle on the selected piece wins over picking
	var gi := _grip_at(screen)
	if gi >= 0:
		var g: Dictionary = grips()[gi]
		_drag = {"grip": g, "id": sel, "start": piece(sel).duplicate(true), "before": JSON.stringify(data), "moved": false}
		return
	var hit := _ray(screen, PICK_MASK)
	var id := _owner_id(hit.collider) if not hit.is_empty() else ""
	select(id)
	if id == "":
		return
	var p := piece(id)
	var pos := CL.v3(p.pos)
	var on_plane := _plane_point(screen, pos.y)
	_drag = {"id": id, "plane_y": pos.y, "offset": pos - on_plane, "before": JSON.stringify(data), "moved": false}


func _plane_point(screen: Vector2, y: float) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return o + d * 50.0
	var t := (y - o.y) / d.y
	if t < 0.0:
		t = 200.0
	return o + d * minf(t, 3000.0)


func _drag_to(screen: Vector2, free: bool) -> void:
	var p := piece(_drag.id)
	if p.is_empty():
		return
	var at: Vector3 = _plane_point(screen, _drag.plane_y) + _drag.offset
	if not free:
		at = Vector3(roundf(at.x), at.y, roundf(at.z))
	at.y = _drag.plane_y
	p.pos = CL.arr(at)
	if nodes.has(_drag.id):
		nodes[_drag.id].position = at
	_drag.moved = true
	_refresh_inspector()


func _release() -> void:
	if not _drag.is_empty() and _drag.moved:
		_undo.append(_drag.before)
		dirty = true
		if not _drag.has("grip"):
			_rebuild(_drag.id)          # rebuild so physics shapes sit where the piece now is
	_drag = {}


# ---------------------------------------------------------------- resize handles
## The resize handles of the selected piece, in world space:
##   shapes:   a handle on each of the six faces; drag one to stretch or shrink
##             the shape along that axis (the opposite face stays put),
##             Shift to scale it evenly
##   islands and patrolling enemies: four handles on the rim / patrol ring;
##             drag one to change the radius
## Each is {pos, dir (the axis it slides along), axis, kind, col}.
func grips() -> Array:
	var p := piece(sel)
	if p.is_empty() or not nodes.has(sel):
		return []
	var out: Array = []
	match String(p.type):
		"shape":
			var size := CL.v3(p.size)
			var b: Basis = nodes[sel].global_basis.orthonormalized()
			var c: Vector3 = nodes[sel].global_position
			var cols := [Color(1.0, 0.35, 0.3), Color(0.4, 1.0, 0.4), Color(0.4, 0.6, 1.0)]
			for axis in 3:
				for sgn in [1.0, -1.0]:
					var local := Vector3.ZERO
					local[axis] = sgn
					var dir: Vector3 = b * local
					out.append({"pos": c + dir * size[axis] * 0.5, "dir": dir, "axis": axis, "kind": "size", "col": cols[axis]})
		"island", "enemy":
			if p.type == "enemy" and (p.get("enemy") == "cherub"):
				return []
			var key := "r" if p.type == "island" else "radius"
			var r := float(p.get(key, 0.0))
			var c := CL.v3(p.pos)
			for k in 4:
				var a := TAU * k / 4.0
				var dir := Vector3(cos(a), 0, sin(a))
				out.append({"pos": c + dir * maxf(r, 1.0), "dir": dir, "axis": -1, "kind": key, "col": Color(1.0, 0.8, 0.25)})
	return out


## Which handle is under the mouse (within a few pixels), or -1.
func _grip_at(screen: Vector2) -> int:
	var best := -1
	var best_d := 16.0
	var gs := grips()
	for i in gs.size():
		var w: Vector3 = gs[i].pos
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(screen)
		if d < best_d:
			best_d = d
			best = i
	return best


func _grip_to(screen: Vector2, free: bool, even: bool) -> void:
	var g: Dictionary = _drag.grip
	var p0: Dictionary = _drag.start
	var p := piece(_drag.id)
	if p.is_empty():
		return
	var changes := {}
	if g.kind == "size":
		# slide along the handle's axis: the closest point on that line to the mouse ray
		var o := cam.project_ray_origin(screen)
		var r := cam.project_ray_normal(screen)
		var a: Vector3 = g.pos
		var d: Vector3 = g.dir
		var w := o - a
		var rd := r.dot(d)
		var denom := 1.0 - rd * rd
		if denom < 0.0001:
			return                                    # looking straight down the axis
		var t := (w.dot(d) - w.dot(r) * rd) / denom
		var size0 := CL.v3(p0.size)
		var s0: float = size0[g.axis]
		var s1 := maxf(0.2, s0 + t)
		if not free:
			s1 = maxf(0.5, snappedf(s1, 0.5))
		if even:
			var k := s1 / s0
			changes["size"] = CL.arr(size0 * k)
			changes["pos"] = p0.pos
		else:
			var size1 := size0
			size1[g.axis] = s1
			changes["size"] = CL.arr(size1)
			changes["pos"] = CL.arr(CL.v3(p0.pos) + d * (s1 - s0) * 0.5)   # the far face stays put
	else:
		var c := CL.v3(p0.pos)
		var at := _plane_point(screen, c.y)
		var rad := Vector2(at.x - c.x, at.z - c.z).length()
		rad = rad if free else roundf(rad)
		changes[g.kind] = maxf(rad, 4.0 if g.kind == "r" else 0.0)
	var same := true
	for k in changes:
		if JSON.stringify(changes[k]) != JSON.stringify(p.get(k)):
			same = false
	if same:
		return
	p.merge(changes, true)
	_rebuild(_drag.id)
	_drag.moved = true
	_refresh_inspector()


func _draw_grips() -> void:
	var gs := grips() if _drag.is_empty() or _drag.has("grip") else []
	for i in _grips.size():
		var m: MeshInstance3D = _grips[i]
		if i >= gs.size():
			m.visible = false
			continue
		var g: Dictionary = gs[i]
		var active: bool = i == _hover_grip or (_drag.has("grip") and _drag.grip.pos.is_equal_approx(g.pos))
		m.visible = true
		m.global_position = g.pos
		var k := cam.global_position.distance_to(g.pos) * (0.034 if active else 0.024)
		m.scale = Vector3.ONE * maxf(k, 0.15)
		(m.material_override as StandardMaterial3D).albedo_color = Color.WHITE if active else g.col


## Where a new piece goes: on whatever the camera looks at, else 40 m ahead.
func _aim_point() -> Vector3:
	var centre := get_viewport().get_visible_rect().size * 0.5
	var hit := _ray(centre, 1 | PICK_MASK)
	if not hit.is_empty() and cam.global_position.distance_to(hit.position) < 400.0:
		return Vector3(roundf(hit.position.x), snappedf(hit.position.y, 0.1), roundf(hit.position.z))
	var p := cam.global_position - cam.global_basis.z * 40.0
	return Vector3(roundf(p.x), roundf(p.y), roundf(p.z))


func _frame_selected() -> void:
	if not nodes.has(sel):
		return
	var at: Vector3 = nodes[sel].global_position
	var p := piece(sel)
	var back := 30.0 + (float(p.get("r", 0.0)) * 2.0 if p.type == "island" else 0.0)
	cam.position = at + Vector3(0, back * 0.5, back)
	_pitch = -0.4
	_yaw = 0.0
	cam.rotation = Vector3(_pitch, _yaw, 0)


func _frame_level() -> void:
	var c := Vector3.ZERO
	var n := 0
	for p in data.pieces:
		c += CL.v3(p.pos)
		n += 1
	c = c / maxi(n, 1)
	cam.position = c + Vector3(0, 45, 90)
	_pitch = -0.45
	_yaw = 0.0
	cam.rotation = Vector3(_pitch, _yaw, 0)


## The gold box round the selected piece.
func _draw_selection() -> void:
	if sel == "" or not nodes.has(sel) or not is_instance_valid(nodes[sel]):
		_box.mesh = null
		return
	var n: Node3D = nodes[sel]
	var aabb := AABB()
	var first := true
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Label3D:
			continue
		var b: AABB = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	if first:
		aabb = AABB(n.global_position - Vector3.ONE, Vector3.ONE * 2.0)
	aabb = aabb.grow(0.3)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 12:
		var e := _edge(aabb, i)
		im.surface_add_vertex(e[0])
		im.surface_add_vertex(e[1])
	im.surface_end()
	_box.mesh = im


static func _edge(b: AABB, i: int) -> Array:
	var c := []
	for k in 8:
		c.append(b.position + Vector3(b.size.x * (k & 1), b.size.y * ((k >> 1) & 1), b.size.z * ((k >> 2) & 1)))
	var pairs := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	return [c[pairs[i][0]], c[pairs[i][1]]]


# ---------------------------------------------------------------- file
func save() -> void:
	data.name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Untitled level"
	var path := CL.save(data)
	if path == "":
		_status("Couldn't save. Copy the JSON instead so nothing is lost.")
		return
	dirty = false
	Game.custom = data.duplicate(true)
	_status("Saved \"%s\" to your levels." % data.name)


func play_test() -> void:
	data.name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Untitled level"
	CL.save(data)
	Game.play_custom(data.duplicate(true), true)


func open_path(path: String) -> void:
	var d := CL.load_file(path)
	if d.is_empty():
		_status("That level couldn't be read.")
		return
	_remember()
	data = d
	sel = ""
	_rebuild_all()
	_frame_level()
	_status("Opened \"%s\"." % data.get("name", ""))


func copy_json() -> void:
	data.name = name_edit.text.strip_edges()
	var text := JSON.stringify(data, "\t")
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), CL.slug(String(data.name)) + ".json", "application/json")
		_status("Copied the level's JSON and downloaded it as a .json file.")
	else:
		_status("Copied the level's JSON to the clipboard.")


func paste_json(text: String) -> void:
	var d := CL.parse(text)
	if d.is_empty():
		_status("That isn't a Chain State level (expected JSON with a \"pieces\" list).")
		return
	_remember()
	data = d
	sel = ""
	_rebuild_all()
	_frame_level()
	paste_panel.visible = false
	_status("Loaded \"%s\" from pasted JSON." % data.get("name", ""))


func _status(t: String) -> void:
	if status:
		status.text = t


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	# top bar
	var top := _panel(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 46
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	bar.add_child(_tag("LEVEL EDITOR"))
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size.x = 220
	name_edit.placeholder_text = "Level name"
	name_edit.text = String(data.get("name", "New level"))
	bar.add_child(name_edit)
	bar.add_child(_btn("New", func():
		_remember()
		data = CL.blank()
		_rebuild_all()
		_frame_level()
		_status("New level.")))
	var open := _btn("Open…", _show_open)
	bar.add_child(open)
	open_menu = PopupMenu.new()
	open_menu.id_pressed.connect(func(i): open_path(_open_paths[i]))
	add_child(open_menu)
	bar.add_child(_btn("Save (Ctrl+S)", save))
	bar.add_child(_btn("Undo (Ctrl+Z)", undo))
	var play := _btn("▶ Play-test (P)", play_test)
	play.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	bar.add_child(play)
	bar.add_child(_btn("Copy JSON", copy_json))
	bar.add_child(_btn("Paste JSON", func():
		paste_text.text = ""
		paste_panel.visible = true
		paste_text.grab_focus()))
	bar.add_child(_btn("Exit", Game.to_level_select))

	# left: the palette
	var left := _panel(Control.PRESET_LEFT_WIDE)
	left.offset_top = 52
	left.offset_right = 170
	left.offset_bottom = -34
	var pal := VBoxContainer.new()
	pal.add_theme_constant_override("separation", 3)
	left.add_child(pal)
	pal.add_child(_tag("TERRAIN"))
	pal.add_child(_btn("Island", func(): add_piece("island")))
	pal.add_child(_tag("SHAPES"))
	for s in CL.SHAPES:
		pal.add_child(_btn(String(s).capitalize(), func(): add_piece("shape", s)))
	pal.add_child(_tag("GRAPPLE"))
	pal.add_child(_btn("Anchor", func(): add_piece("anchor", "")))
	pal.add_child(_btn("Free anchor", func(): add_piece("anchor", "free")))
	pal.add_child(_tag("COURSE"))
	pal.add_child(_btn("Start", func(): add_piece("start")))
	pal.add_child(_btn("Checkpoint", func(): add_piece("checkpoint")))
	pal.add_child(_btn("Finish", func(): add_piece("finish")))
	pal.add_child(_tag("ENEMIES"))
	for k in CL.ENEMIES:
		pal.add_child(_btn(String(k).capitalize(), func(): add_piece("enemy", k)))

	# right: the inspector
	var right := _panel(Control.PRESET_RIGHT_WIDE)
	right.offset_top = 52
	right.offset_left = -300
	right.offset_bottom = -34
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 6)
	scroll.add_child(inspector)

	# bottom: status and the controls
	var bottom := _panel(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -30
	var bl := HBoxContainer.new()
	bottom.add_child(bl)
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	bl.add_child(status)
	var keys := Label.new()
	keys.text = "RMB look · WASD/QE fly · drag to move · drag handles to resize (Shift even, Alt free) · arrows / PgUp PgDn nudge · R turn · Ctrl+D copy · Del · F frame"
	keys.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.75))
	keys.add_theme_font_size_override("font_size", 13)
	bl.add_child(keys)

	# the paste box
	paste_panel = PanelContainer.new()
	paste_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paste_panel.offset_left = -320
	paste_panel.offset_right = 320
	paste_panel.offset_top = -200
	paste_panel.offset_bottom = 200
	paste_panel.add_theme_stylebox_override("panel", _style(0.96))
	paste_panel.visible = false
	ui.add_child(paste_panel)
	var pv := VBoxContainer.new()
	paste_panel.add_child(pv)
	pv.add_child(_tag("PASTE A LEVEL'S JSON"))
	paste_text = TextEdit.new()
	paste_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(paste_text)
	var ph := HBoxContainer.new()
	pv.add_child(ph)
	ph.add_child(_btn("Load it", func(): paste_json(paste_text.text)))
	ph.add_child(_btn("Cancel", func(): paste_panel.visible = false))


func _show_open() -> void:
	open_menu.clear()
	_open_paths.clear()
	for l in CL.list_levels():
		open_menu.add_item(String(l[0]) + ("   (shipped)" if String(l[1]).begins_with("res://") else ""))
		_open_paths.append(l[1])
	if _open_paths.is_empty():
		_status("No saved levels yet: Ctrl+S saves this one.")
		return
	open_menu.position = Vector2i(get_viewport().get_mouse_position()) + Vector2i(0, 20)
	open_menu.popup()


func _refresh_inspector() -> void:
	if inspector == null:
		return
	for c in inspector.get_children():
		c.queue_free()
	var p := piece(sel)
	if p.is_empty():
		inspector.add_child(_tag("NOTHING SELECTED"))
		var hint := Label.new()
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = "Click a piece in the view to select it.\n\nAdd pieces from the list on the left: they drop where you're looking.\n\n%d pieces in this level." % data.pieces.size()
		inspector.add_child(hint)
		return
	inspector.add_child(_tag(_label(p).to_upper()))
	var pos := CL.v3(p.pos)
	_vec_row("Position (m)", pos, func(v): set_fields({"pos": CL.arr(v)}))
	match String(p.type):
		"island":
			_num_row("Radius (m)", float(p.r), 4, 600, 1, func(v): set_fields({"r": v}))
			_num_row("Shape seed", float(p.seed), 0, 99999, 1, func(v): set_fields({"seed": int(v)}))
			_check_row("Grass tufts", bool(p.get("grass", true)), func(v): set_fields({"grass": v}))
		"shape":
			_vec_row("Size (m)", CL.v3(p.size), func(v): set_fields({"size": CL.arr(v)}))
			_vec_row("Rotation (pitch, yaw, roll)", CL.v3(p.rot), func(v): set_fields({"rot": CL.arr(v)}))
			var opt := OptionButton.new()
			for s in CL.SHAPES:
				opt.add_item(String(s).capitalize())
			opt.selected = CL.SHAPES.find(String(p.shape))
			opt.item_selected.connect(func(i): set_fields({"shape": CL.SHAPES[i]}))
			_row("Shape", opt)
			var cp := ColorPickerButton.new()
			cp.color = Color.html(String(p.get("color", "#e8ecf2")))
			cp.custom_minimum_size = Vector2(80, 28)
			cp.popup_closed.connect(func(): set_fields({"color": "#" + cp.color.to_html(false)}))
			_row("Colour", cp)
		"anchor":
			_check_row("Free (costs no air grapple)", bool(p.get("free", false)), func(v): set_fields({"free": v}))
		"start":
			_num_row("Facing (degrees)", float(p.get("yaw", 0.0)), -360, 360, 15, func(v): set_fields({"yaw": v}))
		"enemy":
			var opt := OptionButton.new()
			for k in CL.ENEMIES:
				opt.add_item(String(k).capitalize())
			opt.selected = CL.ENEMIES.find(String(p.enemy))
			opt.item_selected.connect(func(i): set_fields({"enemy": CL.ENEMIES[i]}))
			_row("Enemy", opt)
			if p.enemy != "cherub":
				_num_row("Patrol radius (m)", float(p.get("radius", 10.0)), 0, 200, 1, func(v): set_fields({"radius": v}))
	var acts := HBoxContainer.new()
	inspector.add_child(acts)
	acts.add_child(_btn("Duplicate", duplicate_selected))
	if p.type != "start":
		acts.add_child(_btn("Delete", delete_selected))


func _row(label: String, ctl: Control) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	l.add_theme_font_size_override("font_size", 13)
	inspector.add_child(l)
	inspector.add_child(ctl)


func _spin(v: float, lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.allow_greater = true
	s.allow_lesser = true
	s.value = v
	s.select_all_on_focus = true
	s.custom_minimum_size.x = 84
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _num_row(label: String, v: float, lo: float, hi: float, step: float, on_change: Callable) -> void:
	var s := _spin(v, lo, hi, step)
	s.value_changed.connect(func(nv): on_change.call(nv))
	_row(label, s)


func _vec_row(label: String, v: Vector3, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var boxes: Array = []
	for k in 3:
		var s := _spin(v[k], -100000, 100000, 0.5)
		boxes.append(s)
		h.add_child(s)
	for k in 3:
		boxes[k].value_changed.connect(func(_nv):
			on_change.call(Vector3(boxes[0].value, boxes[1].value, boxes[2].value)))
	_row(label, h)


func _check_row(label: String, v: bool, on_change: Callable) -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = v
	c.toggled.connect(func(nv): on_change.call(nv))
	inspector.add_child(c)


func _panel(preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(preset)
	p.add_theme_stylebox_override("panel", _style(0.82))
	ui.add_child(p)
	return p


func _style(alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.11, 0.22, alpha)
	s.set_content_margin_all(8)
	s.set_corner_radius_all(6)
	return s


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE           # keys stay with the editor, not the button
	return b


func _tag(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	return l
