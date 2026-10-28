extends Control
## Sun glare: a lens-glare overlay drawn additively over the 3D view.
## A soft core and slowly turning rays sit on the sun; faint coloured ghosts
## run along the line from the sun through the screen centre. It brightens as
## you look toward the sun and fades out when anything solid blocks it.

var camera: Camera3D
var sun_dir := Vector3.UP        # world direction TOWARD the sun
var tint := Color(1.0, 0.95, 0.85)
var strength := 1.0              # per sky: bright day sun 1.0, moon ~0.35

var _vis := 0.0                  # smoothed 0..1 visibility
var _t := 0.0
var _soft: Texture2D

const OCCLUDE_MASK := 1 | 2      # world and NPCs/props block the sun


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	# soft round falloff used for the core, halo and ghosts
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	g.add_point(0.6, Color(1, 1, 1, 0.12))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_soft = gt


func _process(dt: float) -> void:
	_t += dt
	var target := 0.0
	if camera and is_instance_valid(camera) and strength > 0.0:
		var fwd := -camera.global_basis.z
		var facing := fwd.dot(sun_dir)                       # 1 = looking straight at it
		if facing > 0.2 and not camera.is_position_behind(camera.global_position + sun_dir * 100.0):
			target = smoothstep(0.2, 0.97, facing)
			if target > 0.0 and _occluded():
				target = 0.0
	_vis = lerpf(_vis, target, 1.0 - exp(-(10.0 if target < _vis else 6.0) * dt))
	queue_redraw()


func _occluded() -> bool:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + sun_dir * 800.0, OCCLUDE_MASK)
	var p := camera.get_parent()
	while p and not (p is CollisionObject3D):
		p = p.get_parent()
	if p:
		q.exclude = [p.get_rid()]
	return not camera.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _draw() -> void:
	if _vis < 0.01 or camera == null:
		return
	var pos := camera.unproject_position(camera.global_position + sun_dir * 100.0)
	var vs := get_viewport_rect().size
	# the viewport the camera renders into may differ from this canvas
	var cam_vs := camera.get_viewport().get_visible_rect().size
	if cam_vs.x > 0:
		pos *= vs / cam_vs
	var a := _vis * strength
	var unit := vs.y / 1080.0

	# wide halo, then a hot core
	_disc(pos, 520.0 * unit, Color(tint, 0.22 * a))
	_disc(pos, 190.0 * unit, Color(tint, 0.55 * a))
	_disc(pos, 70.0 * unit, Color(1, 1, 1, 0.9 * a))

	# starburst rays, turning slowly
	var rays := 12
	for i in rays:
		var ang := _t * 0.05 + TAU * i / rays + (0.13 if i % 2 else 0.0)
		var length := (420.0 if i % 3 == 0 else 260.0) * unit
		var width := (5.0 if i % 3 == 0 else 3.0) * unit
		var d := Vector2(cos(ang), sin(ang))
		var n := Vector2(-d.y, d.x) * width
		var tip := pos + d * length
		draw_polygon(PackedVector2Array([pos + n, tip, pos - n]),
			PackedColorArray([Color(tint, 0.5 * a), Color(tint, 0.0), Color(tint, 0.5 * a)]))

	# ghosts along the line through the screen centre
	var c := vs * 0.5
	var axis := c - pos
	var ghosts := [[0.45, 34.0, Color(0.6, 0.85, 1.0)], [0.8, 18.0, Color(1.0, 0.75, 0.5)],
		[1.25, 60.0, Color(0.75, 0.6, 1.0)], [1.6, 26.0, Color(0.6, 1.0, 0.8)]]
	for gh in ghosts:
		_disc(pos + axis * gh[0], gh[1] * unit, Color(gh[2], 0.16 * a))


func _disc(at: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(_soft, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
