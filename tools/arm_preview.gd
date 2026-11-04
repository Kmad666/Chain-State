extends Node
## Renders the first-person arm for review, into user://arm/:
##   game_rest / game_fist   from the player's camera (90 degree FOV), over the default sky
##   <view>_<pose>           orthographic studio views (side, top, front, bottom, palm)
##                           and a three-quarter close-up, on grey
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/arm_preview.tscn

const Viewmodel := preload("res://scripts/player/viewmodel.gd")
const World := preload("res://scripts/world/world.gd")
const OUT := "user://arm"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1600, 900)
	var s: Dictionary = World.SKIES[World.DEFAULT_SKY]
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = s.top
	sky.sky_horizon_color = s.horizon
	sky.ground_horizon_color = s.horizon
	sky.ground_bottom_color = Color(0.25, 0.27, 0.3)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = s.ambient_col
	env.ambient_light_energy = s.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	var dir := Basis.from_euler(Vector3(deg_to_rad(s.elev), -s.u * TAU, 0)) * Vector3.FORWARD
	sun.basis = Basis.looking_at(-dir, Vector3.UP)
	sun.light_color = s.light
	sun.light_energy = s.energy
	add_child(sun)
	# a floor far below, so the game view has a horizon
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor.mesh = pm
	floor.material_override = Mats.lit(Color(0.36, 0.35, 0.33))
	floor.position.y = -1.7
	add_child(floor)

	# --- the game view
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	var vm = Viewmodel.new()
	cam.add_child(vm)
	for i in 3:
		await get_tree().process_frame
	await _shot("game_rest")
	vm.grip = 1.0
	vm._reach = 1.0
	vm._dir = Vector3(-0.25, 0.55, -1.0).normalized()
	vm._apply(0.0)
	await _shot("game_fist")
	# the same two under the night sky, to check the arm still reads in the dark
	var night: Dictionary = World.SKIES["night"]
	sky.sky_top_color = Color(0.02, 0.03, 0.08)
	sky.sky_horizon_color = Color(0.08, 0.10, 0.18)
	env.ambient_light_color = night.get("ambient_col", night.fog)
	env.ambient_light_energy = night.ambient
	sun.light_color = night.light
	sun.light_energy = night.energy
	await _shot("night_fist")
	vm.grip = 0.0
	vm._reach = 0.0
	vm._dir = vm.REST_DIR.normalized()
	vm._apply(0.0)
	await _shot("night_rest")
	sky.sky_top_color = s.top
	sky.sky_horizon_color = s.horizon
	env.ambient_light_color = s.ambient_col
	env.ambient_light_energy = s.ambient
	sun.light_color = s.light
	sun.light_energy = s.energy
	vm.queue_free()

	# --- studio views of the arm alone
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.43, 0.45)
	floor.visible = false
	var key := DirectionalLight3D.new()            # a soft studio key from above-front-left
	key.basis = Basis.looking_at(Vector3(0.5, -0.8, 0.4), Vector3.UP)
	key.light_energy = 0.9
	add_child(key)
	var holder = Viewmodel.new()
	add_child(holder)
	holder.grip = 0.0
	holder.pivot.transform = Transform3D.IDENTITY
	var arm: MeshInstance3D = holder.arm
	var c := Vector3(-0.005, -0.015, -0.27)          # the hand's middle
	var views := {
		"side": [Vector3(-1, 0, 0), Vector3.UP],      # from the thumb side
		"top": [Vector3(0, 1, 0), Vector3.FORWARD],
		"front": [Vector3(0, 0, -1), Vector3.UP],
		"bottom": [Vector3(0, -1, 0), Vector3.FORWARD],
		"outer": [Vector3(1, 0, 0), Vector3.UP],      # from the little-finger side
	}
	sun.visible = false
	for pose in ["rest", "fist"]:
		arm.set_blend_shape_value(0, 0.0 if pose == "rest" else 1.0)
		for v in views:
			cam.set_orthogonal(0.26, 0.02, 10.0)
			var off: Vector3 = views[v][0]
			cam.global_transform = Transform3D(Basis.looking_at(-off, views[v][1]), c + off * 1.0)
			await _shot("%s_%s" % [v, pose])
		cam.set_perspective(35.0, 0.02, 10.0)
		var eye := c + Vector3(-0.22, 0.20, -0.30)
		cam.global_transform = Transform3D(Basis.looking_at(c - eye, Vector3.UP), eye)
		await _shot("three_quarter_%s" % pose)
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("[arm] ", name)
