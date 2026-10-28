extends StaticBody3D
## A floating island: a flat, grassy top you can walk on, a short soil lip, and a
## jagged rock cone hanging underneath. Built procedurally from a seed so each
## island has its own outline. Every surface is world geometry, so the grapple can
## hook the top edge, the cliff and the underside alike.
##
## The top surface sits at the node's origin (y = 0); the cone hangs below it.

@export var radius := 24.0       # average radius of the top, metres
@export var depth := 0.0         # how far the rock cone hangs; 0 = radius * 0.9
@export var island_seed := 1
@export var wobble := 0.14       # how irregular the outline is (fraction of radius)

const RIM_POINTS := 56
const SOIL := 1.6                # soil band under the grass edge, metres
const RINGS := 4                 # rings of rock between the soil and the tip

var top_mesh: MeshInstance3D
var rock_mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 1          # world: solid and grapple-able
	collision_mask = 0
	build()


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed
	var d := depth if depth > 0.0 else radius * 0.9

	# outline: a few overlapping sine waves so the shape is organic, not spiky
	var phases := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var rim: Array[Vector3] = []
	for i in RIM_POINTS:
		var a := TAU * i / RIM_POINTS
		var k := 1.0 + wobble * (0.6 * sin(2.0 * a + phases[0]) + 0.3 * sin(3.0 * a + phases[1]) + 0.25 * sin(5.0 * a + phases[2]))
		k += rng.randf_range(-0.02, 0.02)
		rim.append(Vector3(cos(a) * radius * k, 0.0, sin(a) * radius * k))

	# --- grass top: a fan from the centre, flat at y = 0
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	top.set_smooth_group(-1)
	for i in RIM_POINTS:
		var a := rim[i]
		var b := rim[(i + 1) % RIM_POINTS]
		top.add_vertex(Vector3.ZERO)
		top.add_vertex(a)
		top.add_vertex(b)
	top.generate_normals()

	# --- rock: soil lip, then rings narrowing to a tip
	var rings: Array = [rim]
	var lip: Array[Vector3] = []
	for p in rim:
		lip.append(p * 1.01 + Vector3(0, -SOIL, 0))
	rings.append(lip)
	for r in RINGS:
		var t := float(r + 1) / (RINGS + 1)            # 0 near the top, 1 at the tip
		var shrink := pow(1.0 - t, 0.75)
		var y := -SOIL - d * pow(t, 1.15)
		var ring: Array[Vector3] = []
		for i in RIM_POINTS:
			var p: Vector3 = rim[i]
			var j := rng.randf_range(0.82, 1.08)          # jagged rock faces
			ring.append(Vector3(p.x * shrink * j, y + rng.randf_range(-0.12, 0.12) * d * (1.0 - t), p.z * shrink * j))
		rings.append(ring)
	var tip := Vector3(rng.randf_range(-0.1, 0.1) * radius, -SOIL - d, rng.randf_range(-0.1, 0.1) * radius)

	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	rock.set_smooth_group(-1)
	for r in rings.size() - 1:
		var up: Array = rings[r]
		var dn: Array = rings[r + 1]
		for i in RIM_POINTS:
			var i2 := (i + 1) % RIM_POINTS
			rock.add_vertex(up[i]); rock.add_vertex(dn[i]); rock.add_vertex(up[i2])
			rock.add_vertex(up[i2]); rock.add_vertex(dn[i]); rock.add_vertex(dn[i2])
	var last: Array = rings[rings.size() - 1]
	for i in RIM_POINTS:
		rock.add_vertex(last[i]); rock.add_vertex(tip); rock.add_vertex(last[(i + 1) % RIM_POINTS])
	rock.generate_normals()

	var top_arr := top.commit()
	var rock_arr := rock.commit()
	top_mesh = MeshInstance3D.new()
	top_mesh.mesh = top_arr
	top_mesh.material_override = Mats.grid(Color(0.34, 0.48, 0.25), Color(0.31, 0.44, 0.23))
	add_child(top_mesh)
	rock_mesh = MeshInstance3D.new()
	rock_mesh.mesh = rock_arr
	rock_mesh.material_override = Mats.grid(Color(0.47, 0.42, 0.37), Color(0.43, 0.38, 0.34), 1)
	add_child(rock_mesh)

	for m in [top_arr, rock_arr]:
		var col := CollisionShape3D.new()
		col.shape = m.create_trimesh_shape()
		add_child(col)
