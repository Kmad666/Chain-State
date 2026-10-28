extends Node3D
## The witch's tree: a tall, wide cone of magic orbs, slowly turning, set out as a
## platforming climb. RED_COUNT (40) large dark red orbs stun on touch; BLUE_COUNT blue orbs
## spiral up the cone as the route, and can be hooked as often as you like
## (magic grapples are free). Hooked blue orbs keep riding the tree; your anchor
## moves with them.
##
## The node's origin is the centre of the cone's base. Tiers rise to HEIGHT.

const HookOrb := preload("res://scripts/combat/hook_orb.gd")

@export var base_radius := 26.0
@export var height := 48.0
@export var spin := 0.06                      # radians per second
@export var tiers := 9

const RED_COUNT := 40
const BLUE_COUNT := 10
const RED_SIZE := 1.8           # 3x the old 0.6: big, slow, readable hazards
const CLEAR := 6.5               # red orbs keep this far from any blue, so you can swing in
const SPACING := 4.8             # and this far from each other, so the big ones never clump

var player: Node
var _angle := 0.0
var _red_local := PackedVector3Array()
var _blue_local := PackedVector3Array()
var _blues: Array = []
var _mm: MultiMesh


func _ready() -> void:
	add_to_group("orb_tree")
	_layout()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = RED_SIZE
	s.height = RED_SIZE * 2.0
	s.radial_segments = 20
	s.rings = 10
	_mm.mesh = s
	_mm.instance_count = _red_local.size()
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.42, 0.02, 0.05)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 200, 400))
	add_child(mi)
	for p in _blue_local:
		var o := HookOrb.new()
		o.orbiting = true
		o.harmless = true
		o.persistent = true
		add_child(o)
		o.top_level = true
		_blues.append(o)
	_place()


func red_count() -> int:
	return _red_local.size()


## Tier radius shrinks toward the top, like a tree.
func _radius_at(t: float) -> float:
	return base_radius * (1.0 - 0.85 * t)


func _layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# blue route: one per tier, turning ~72 degrees each tier, plus one more near the top
	for k in tiers:
		var t := float(k) / (tiers - 1)
		var a := k * 1.25
		var r := _radius_at(t) * 0.82
		_blue_local.append(Vector3(cos(a) * r, t * height, sin(a) * r))
	var top_t := 0.97
	_blue_local.append(Vector3(cos(tiers * 1.25) * _radius_at(top_t) * 0.6, top_t * height + 3.0, sin(tiers * 1.25) * _radius_at(top_t) * 0.6))

	# red ornaments: generous candidates per tier, kept clear of the blue route
	var sum_r := 0.0
	for k in tiers:
		sum_r += _radius_at(float(k) / (tiers - 1))
	var cands: Array[Vector3] = []
	for k in tiers:
		var t := float(k) / (tiers - 1)
		var r := _radius_at(t)
		var n := maxi(3, ceili(r / sum_r * 150.0))
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			var rr := r * rng.randf_range(0.55, 1.0)          # some sit inside the cone
			var p := Vector3(cos(a) * rr, t * height + rng.randf_range(-1.2, 1.2), sin(a) * rr)
			var ok := true
			for b in _blue_local:
				if p.distance_to(b) < CLEAR:
					ok = false
					break
			if ok:
				cands.append(p)
	# take RED_COUNT, spread evenly through the candidates, skipping any that would crowd another
	var step := float(cands.size()) / RED_COUNT
	var used := {}
	for i in RED_COUNT:
		var start := int(i * step)
		for j in cands.size():
			var idx := (start + j) % cands.size()
			if used.has(idx):
				continue
			var ok := true
			for q in _red_local:
				if q.distance_to(cands[idx]) < SPACING:
					ok = false
					break
			if ok:
				used[idx] = true
				_red_local.append(cands[idx])
				break


func _physics_process(dt: float) -> void:
	_angle += spin * dt
	_place()
	if player and is_instance_valid(player) and player.stunned <= 0.0:
		var p: Vector3 = player.global_position
		var b := Basis(Vector3.UP, _angle)
		for lp in _red_local:
			var w: Vector3 = global_position + b * lp
			var y := clampf(w.y, p.y - 0.5, p.y + 0.5)
			if w.distance_to(Vector3(p.x, y, p.z)) < RED_SIZE + 0.38:
				player.notice.emit("A red orb!")
				player.hit((p - w).normalized())
				break


func _place() -> void:
	var b := Basis(Vector3.UP, _angle)
	for i in _red_local.size():
		_mm.set_instance_transform(i, Transform3D(Basis(), b * _red_local[i]))
	for i in _blues.size():
		var o = _blues[i]
		if is_instance_valid(o):
			o.global_position = global_position + b * _blue_local[i]


func blue_orbs() -> Array:
	return _blues
