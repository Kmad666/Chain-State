extends Node
## Renders the arm model (assets/models/arm/arm.glb) the way design/arm/reference-sheet.png
## lays it out, for side-by-side review: the arm hanging, fist down, on studio grey.
##   front  palm side        back  back of the hand     side  from the little-finger side
## plus close-ups of the hand from the same three sides and two three-quarter views.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/arm_sheet.tscn
## Writes user://arm_sheet/*.png.

const Viewmodel := preload("res://scripts/player/viewmodel.gd")
const OUT := "user://arm_sheet"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(900, 1200)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.21, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# studio lights: a key from the upper left front, a fill from the right, a rim behind
	for l in [[Vector3(-35, -30, 0), 1.25], [Vector3(-10, 60, 0), 0.45], [Vector3(-20, 170, 0), 0.6]]:
		var dl := DirectionalLight3D.new()
		dl.rotation_degrees = l[0]
		dl.light_energy = l[1]
		add_child(dl)

	# the arm hanging: its -Z (toward the fist) points down, the back of the hand away
	var rig := Node3D.new()
	rig.rotation_degrees = Vector3(-90, 0, 0)
	add_child(rig)
	var vm = Viewmodel.new()
	var arm: Node3D = load("res://assets/models/arm/arm.glb").instantiate()
	rig.add_child(arm)
	vm.dress(arm)

	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	# arm space z -> world -y after the turn; the fist's middle is near z = -0.29
	var full_c := Vector3(0, -0.10, 0)            # z = +0.10: from the mid-forearm down
	var hand_c := Vector3(-0.005, -0.255, -0.012)
	var views := {"front": Vector3(0, 0, 1), "back": Vector3(0, 0, -1), "side": Vector3(1, 0, 0)}
	for v in views:
		var off: Vector3 = views[v]
		cam.set_orthogonal(0.52, 0.01, 10.0)
		cam.global_transform = Transform3D(Basis.looking_at(-off, Vector3.UP), full_c + off)
		await _shot("full_" + v)
		cam.set_orthogonal(0.20, 0.01, 10.0)
		cam.global_transform = Transform3D(Basis.looking_at(-off, Vector3.UP), hand_c + off)
		await _shot("hand_" + v)
	for q in [["tq_palm", Vector3(-0.35, 0.18, 0.6)], ["tq_back", Vector3(0.45, 0.25, -0.55)], ["thumb", Vector3(-0.7, -0.1, 0.25)]]:
		cam.set_perspective(30.0, 0.01, 10.0)
		var eye: Vector3 = hand_c + (q[1] as Vector3).normalized() * 0.42
		cam.global_transform = Transform3D(Basis.looking_at(hand_c - eye, Vector3.UP), eye)
		await _shot(q[0])
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("[sheet] ", name)
