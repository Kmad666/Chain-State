class_name KenneyMesh
## Pulls the first Mesh out of a Kenney .glb, so it can be drawn many times
## through a MultiMesh (one draw call) instead of as many scene instances.

static var _cache := {}


static func get_mesh(path: String) -> Mesh:
	if _cache.has(path):
		return _cache[path]
	var mesh: Mesh = null
	var scene = load(path)
	if scene is PackedScene:
		var root: Node = scene.instantiate()
		var stack: Array[Node] = [root]
		while not stack.is_empty() and mesh == null:
			var n: Node = stack.pop_back()
			if n is MeshInstance3D and n.mesh:
				mesh = n.mesh
			stack.append_array(n.get_children())
		root.free()
	_cache[path] = mesh
	return mesh
