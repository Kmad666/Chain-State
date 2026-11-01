extends SceneTree
## Bakes the Brick Spire (scripts/world/brick_tower.gd) into plain meshes, one per
## material, with box-projected UVs for the stone texture, and writes a .glb.
## Run with a real renderer (MultiMesh transforms can't be read back headless).

## Usage: OUT=brick_spire.glb xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/export_brick_spire.gd

var holder: Node3D
var tower: Node3D
var frame := 0


func _initialize() -> void:
	holder = Node3D.new()
	get_root().add_child(holder)
	tower = load("res://scripts/world/brick_tower.gd").new()
	holder.add_child(tower)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	var out := Node3D.new()
	out.name = "BrickSpire"
	var groups := {}
	var names := {
		tower.BRICK.to_html(): "Stone", tower.BRICK_DK.to_html(): "Stone_Dark",
		tower.BRICK_LT.to_html(): "Stone_Light", tower.HOLE.to_html(): "Openings"}
	for n in tower.get_children():
		var src_mesh: Mesh = null
		var xfs: Array = []
		var mat: Material = null
		if n is MultiMeshInstance3D:
			var mm: MultiMesh = n.multimesh
			src_mesh = mm.mesh
			for i in mm.instance_count:
				xfs.append(mm.get_instance_transform(i))
			mat = n.material_override
		elif n is MeshInstance3D:
			src_mesh = n.mesh
			xfs.append(n.transform)
			mat = n.material_override
		else:
			continue
		var col := _colour_of(mat)
		var gname: String = names.get(col.to_html(), "Stone")
		if not groups.has(gname):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var textured := mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null
			groups[gname] = [st, col, textured]
		var st: SurfaceTool = groups[gname][0]
		for xf in xfs:
			_append_box_uv(st, src_mesh, xf)
	for gname in groups:
		var st: SurfaceTool = groups[gname][0]
		var col: Color = groups[gname][1]
		st.generate_normals()
		var m := StandardMaterial3D.new()
		m.resource_name = gname
		m.albedo_color = col
		m.roughness = 1.0
		m.roughness = 0.55
		if groups[gname][2]:                     # the game's material is textured: carry it over
			m.albedo_color = Color.WHITE
			m.albedo_texture = tower._speckle(col)
			m.roughness = 1.0
		var mesh := st.commit()
		mesh.surface_set_material(0, m)
		var mi := MeshInstance3D.new()
		mi.name = gname
		mi.mesh = mesh
		out.add_child(mi)
		mi.owner = out
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(out, state)
	var path := OS.get_environment("OUT")
	var err := doc.write_to_filesystem(state, path)
	var tris := 0
	for c in out.get_children():
		tris += (c as MeshInstance3D).mesh.surface_get_array_len(0) / 3
	print("export ", path, " err=", err, " groups=", groups.keys(), " triangles=", tris)
	return true


func _colour_of(mat: Material) -> Color:
	var sm := mat as StandardMaterial3D
	if sm == null:
		return tower.BRICK
	if sm.albedo_texture:
		for key in tower._tex:
			if tower._tex[key] == sm.albedo_texture:
				return Color.html(key)
	return sm.albedo_color


func _append_box_uv(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var tris := PackedInt32Array()
		if idx != null and idx.size() > 0:
			tris = idx
		else:
			for i in verts.size():
				tris.append(i)
		for t in range(0, tris.size(), 3):
			var a := xf * verts[tris[t]]
			var b := xf * verts[tris[t + 1]]
			var c := xf * verts[tris[t + 2]]
			var nrm := (b - a).cross(c - a)
			if nrm.length_squared() < 1e-12:
				continue
			nrm = nrm.normalized()
			var ax := absf(nrm.x)
			var ay := absf(nrm.y)
			var az := absf(nrm.z)
			for p in [a, b, c]:
				var uv: Vector2
				if ax >= ay and ax >= az:
					uv = Vector2(p.z, -p.y)
				elif ay >= az:
					uv = Vector2(p.x, p.z)
				else:
					uv = Vector2(p.x, -p.y)
				st.set_uv(uv / 4.0)
				st.add_vertex(p)
