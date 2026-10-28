extends StaticBody3D
## A witch's ward: a large faceted forcefield shell (a subdivided icosahedron)
## with one small opening. It protects whoever is inside.
##
## - The grapple can hook its outside (it's magic: hooking it is free).
## - Touching the shell anywhere but the opening stuns the player for 3 s; they
##   drop straight down and phase through it.
## - Fly in through the opening and you're inside, safe, and able to wrap the caster.
##
## Collision layer 4 (HOOK): grapple-able, not solid. Faces point outward and are
## one-sided for rays, so from inside your grapple goes straight through the shell.

@export var radius := 8.5
@export var open_dir := Vector3(0, -0.35, 1.0)   # where the opening faces (world space)
@export var open_angle_deg := 22.0                # how wide the opening is

const TOUCH := 0.55              # how close to the shell counts as touching, metres

var player: Node
var _open: Vector3
var _shell_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	add_to_group("ward")
	add_to_group("magic")
	collision_layer = 4
	collision_mask = 0
	_open = open_dir.normalized()
	_build()


func is_inside(p: Vector3) -> bool:
	return p.distance_to(global_position) < radius


## Is this point in the opening (within the opening's cone from the centre)?
func in_opening(p: Vector3) -> bool:
	var d := p - global_position
	if d.length_squared() < 0.0001:
		return false
	return rad_to_deg(d.normalized().angle_to(_open)) < open_angle_deg


func touching(p: Vector3) -> bool:
	return absf(p.distance_to(global_position) - radius) < TOUCH and not in_opening(p)


func _physics_process(dt: float) -> void:
	_t += dt
	_shell_mat.albedo_color.a = 0.16 + sin(_t * 1.7) * 0.04
	if player and is_instance_valid(player) and player.stunned <= 0.0 and touching(player.global_position):
		player.notice.emit("You touched the ward!")
		player.hit((player.global_position - global_position).normalized())


func _build() -> void:
	# icosahedron, subdivided once and pushed out to the sphere: 80 faces
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
		[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	var tris: Array = []
	for tri in f:
		var a: Vector3 = v[tri[0]].normalized()
		var b: Vector3 = v[tri[1]].normalized()
		var c: Vector3 = v[tri[2]].normalized()
		var ab := (a + b).normalized()
		var bc := (b + c).normalized()
		var ca := (c + a).normalized()
		tris += [[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]]

	# drop the faces in the opening; this node isn't rotated, so world == local directions
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var lines := PackedVector3Array()
	var edge_count := {}
	var edge_pts := {}
	for tri in tris:
		var centre: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
		if rad_to_deg(centre.normalized().angle_to(_open)) < open_angle_deg:
			continue
		var a: Vector3 = tri[0] * radius
		var b: Vector3 = tri[1] * radius
		var c: Vector3 = tri[2] * radius
		# outward-facing winding (Godot: clockwise seen from the front)
		if (b - a).cross(c - a).dot(centre) > 0.0:
			var tmp := b
			b = c
			c = tmp
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		lines.append_array([a, b, b, c, c, a])
		for e in [[a, b], [b, c], [c, a]]:
			var key := _edge_key(e[0], e[1])
			edge_count[key] = edge_count.get(key, 0) + 1
			edge_pts[key] = e
	st.generate_normals()
	var mesh := st.commit()

	_shell_mat = StandardMaterial3D.new()
	_shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shell_mat.albedo_color = Color(0.62, 0.3, 1.0, 0.16)
	var shell := MeshInstance3D.new()
	shell.mesh = mesh
	shell.material_override = _shell_mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)

	# bright facet edges so the shape reads clearly
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for p in lines:
		im.surface_add_vertex(p)
	im.surface_end()
	var edge_mat := StandardMaterial3D.new()
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.albedo_color = Color(0.85, 0.65, 1.0)
	var edges := MeshInstance3D.new()
	edges.mesh = im
	edges.material_override = edge_mat
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edges)

	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	add_child(col)

	# the opening's rim: edges used by only one kept face. Traced in thick glowing gold.
	var rim: Array = []
	for key in edge_count:
		if edge_count[key] == 1:
			rim.append(edge_pts[key])
	_build_rim(rim)


func _edge_key(a: Vector3, b: Vector3) -> String:
	var ka := "%.3f,%.3f,%.3f" % [a.x, a.y, a.z]
	var kb := "%.3f,%.3f,%.3f" % [b.x, b.y, b.z]
	return ka + "|" + kb if ka < kb else kb + "|" + ka


const GOLD := Color(1.0, 0.8, 0.25)
var rim_edges := 0               # how many edges the gold rim traces (tests read it)


func _build_rim(edges: Array) -> void:
	rim_edges = edges.size()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = GOLD
	var thick := 0.22
	var tube := CylinderMesh.new()
	tube.top_radius = thick
	tube.bottom_radius = thick
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	var knob := SphereMesh.new()
	knob.radius = thick * 1.9
	knob.height = thick * 3.8
	knob.radial_segments = 10
	knob.rings = 5
	var corners := {}
	for e in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var mi := MeshInstance3D.new()
		mi.mesh = tube
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var y := (b - a).normalized()
		var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		mi.transform = Transform3D(Basis(x, y * a.distance_to(b), z), (a + b) * 0.5)
		add_child(mi)
		corners["%.3f,%.3f,%.3f" % [a.x, a.y, a.z]] = a
		corners["%.3f,%.3f,%.3f" % [b.x, b.y, b.z]] = b
	for k in corners:
		var s := MeshInstance3D.new()
		s.mesh = knob
		s.material_override = mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = corners[k]
		add_child(s)


## The ward is hookable (it's magic). Hooking it never needs a free air grapple.
func on_hooked(_p: Node) -> bool:
	return true


func on_released(_p: Node) -> void:
	pass
