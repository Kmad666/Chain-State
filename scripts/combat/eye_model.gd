class_name EyeModel
## The winged eye shared by the Cherub (giant) and the Sage (caster-sized): a white
## eyeball looking down its -Z axis, a gold iris and black pupil, and a fan of white
## feathers on either side. Simple shapes, lit materials, no lights or effects.
##
##   var parts := EyeModel.build(parent, radius)
##   parts.pupil, parts.iris (MeshInstance3D), parts.wings (Array of the two wing pivots)


static func build(parent: Node3D, r: float) -> Dictionary:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.95, 0.92)
	white.roughness = 0.35
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.72, 0.22)
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.38, 0.08)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.03, 0.02, 0.04)
	var feather := StandardMaterial3D.new()
	feather.albedo_color = Color(0.98, 0.97, 0.93)
	feather.roughness = 0.8

	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	ball.mesh = sm
	ball.material_override = white
	parent.add_child(ball)

	var iris := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = r * 0.5
	im.bottom_radius = r * 0.5
	im.height = r * 0.08
	im.radial_segments = 24
	iris.mesh = im
	iris.material_override = gold
	iris.rotation.x = PI * 0.5
	iris.position = Vector3(0, 0, -r * 0.93)
	parent.add_child(iris)

	var pupil := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = r * 0.24
	pm.bottom_radius = r * 0.24
	pm.height = r * 0.1
	pm.radial_segments = 16
	pupil.mesh = pm
	pupil.material_override = black
	pupil.rotation.x = PI * 0.5
	pupil.position = Vector3(0, 0, -r * 0.97)
	parent.add_child(pupil)

	# wings: a fan of five long feathers each side, on a pivot at the eye's flank
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * r * 0.85, r * 0.15, r * 0.2)
		parent.add_child(pivot)
		for k in 5:
			var f := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var length := r * (2.6 - k * 0.32)
			bm.size = Vector3(length, r * 0.08, r * 0.42)
			f.mesh = bm
			f.material_override = feather
			var fan := deg_to_rad(38.0 - k * 19.0)            # upswept to drooping
			f.rotation = Vector3(0, 0, side * fan)
			f.position = Vector3(side * cos(fan) * length * 0.5, sin(fan) * length * 0.5, k * r * 0.05)
			pivot.add_child(f)
		wings.append(pivot)
	return {"ball": ball, "iris": iris, "pupil": pupil, "wings": wings}
