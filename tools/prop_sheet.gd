extends Node
## Renders the modelled props (tools/props/) for review, built exactly as the level
## editor builds them: the whole set in a row, then a close look at each one's top.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/prop_sheet.tscn
## Writes user://prop_sheet/*.png.

const CL := preload("res://scripts/world/custom_level.gd")
const World := preload("res://scripts/world/world.gd")
const OUT := "user://prop_sheet"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1600, 900)
	var s: Dictionary = World.SKIES["day"]
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.30, 0.50, 0.85)
	sky.sky_horizon_color = Color(0.72, 0.80, 0.92)
	sky.ground_horizon_color = Color(0.72, 0.80, 0.92)
	sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.80)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -40, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	ground.material_override = Mats.lit(Color(0.45, 0.43, 0.38))
	add_child(ground)

	var names: Array = CL.props().keys()
	var x := 0.0
	var spots := {}
	for k in names:
		var p := CL.make_piece("prop", k, Vector3.ZERO, k)
		var size := CL.v3(p.size)
		x += size.x * 0.5 + 1.6
		p.pos = CL.arr(Vector3(x, size.y * 0.5, 0))
		spots[k] = [Vector3(x, size.y, 0), size]
		x += size.x * 0.5 + 1.6
		add_child(CL.make(p, false))
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.fov = 40.0
	var mid := Vector3(x * 0.5, 4.5, 0)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -0.12, -1), Vector3.UP), mid + Vector3(0, 0.6, 34))
	await _shot("row")
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(-0.5, -0.25, -1).normalized(), Vector3.UP), mid + Vector3(9, 2.0, 24))
	await _shot("row_angle")
	for k in names:
		var top: Vector3 = spots[k][0]
		var size: Vector3 = spots[k][1]
		var look := top - Vector3(0, minf(0.55, size.y * 0.5), 0)
		var eye := look + Vector3(0.9, 0.30, 2.4).normalized() * maxf(size.x, 1.5) * 1.9
		cam.global_transform = Transform3D(Basis.looking_at((look - eye).normalized(), Vector3.UP), eye)
		await _shot("top_" + k)
		var base := Vector3(top.x, 0.5, 0)
		eye = base + Vector3(-1.2, 1.4, 3.0).normalized() * maxf(size.x, 1.6) * 2.4
		cam.global_transform = Transform3D(Basis.looking_at((base - eye).normalized(), Vector3.UP), eye)
		await _shot("base_" + k)
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("[props] ", name)
