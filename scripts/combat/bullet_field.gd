extends Node3D
## Every enemy projectile in the level. Ordinary bullets are plain data drawn in
## one MultiMesh (one draw call however many are flying) and checked against the
## player by distance. Hookable bullets are real HookOrb nodes so the grapple's
## raycast can catch them.

const HookOrb := preload("res://scripts/combat/hook_orb.gd")
const MAX_BULLETS := 600
const RADIUS := 0.6              # large, slow, readable orbs
const PLAYER_RADIUS := 0.38      # a little under the capsule, so grazes feel fair
const COLOR := Color(0.42, 0.02, 0.05)   # dark red

var player: Node                 # set by the world
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _rad := PackedFloat32Array()   # each orb's radius (an apprentice's are larger)
var _mm: MultiMesh


func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	_mm.mesh = sphere
	_mm.instance_count = MAX_BULLETS
	_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	add_child(mi)


func count() -> int:
	return _pos.size() + get_tree().get_nodes_in_group("hook_orb").size()


## Fire one bullet. A hookable bullet becomes a HookOrb the chain can catch.
func spawn(at: Vector3, vel: Vector3, life := 8.0, hookable := false, radius := RADIUS) -> void:
	if hookable:
		var orb := HookOrb.new()
		orb.velocity = vel
		orb.life = life
		orb.field = self
		add_child(orb)
		orb.global_position = at
		return
	if _pos.size() >= MAX_BULLETS:
		return
	_pos.append(at)
	_vel.append(vel)
	_life.append(life)
	_rad.append(radius)


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_rad.clear()
	for o in get_tree().get_nodes_in_group("hook_orb"):
		o.queue_free()


func _physics_process(dt: float) -> void:
	var p_pos := Vector3.INF
	if player and is_instance_valid(player):
		p_pos = player.global_position
	var i := 0
	while i < _pos.size():
		_pos[i] += _vel[i] * dt
		_life[i] -= dt
		var dead := _life[i] <= 0.0
		if not dead and p_pos != Vector3.INF and _hits_player(_pos[i], p_pos, _rad[i]):
			player.hit(_vel[i].normalized())
			dead = true
		if dead:
			# swap-remove keeps this O(1)
			var last := _pos.size() - 1
			_pos[i] = _pos[last]; _vel[i] = _vel[last]; _life[i] = _life[last]; _rad[i] = _rad[last]
			_pos.resize(last); _vel.resize(last); _life.resize(last); _rad.resize(last)
		else:
			i += 1
	var n := _pos.size()
	_mm.visible_instance_count = n
	for k in n:
		_mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * (_rad[k] / RADIUS)), _pos[k]))


## Bullet vs the player's capsule (a vertical segment from feet to head).
func _hits_player(b: Vector3, p: Vector3, radius := RADIUS) -> bool:
	var y := clampf(b.y, p.y - 0.5, p.y + 0.5)
	var dx := b.x - p.x
	var dz := b.z - p.z
	var dy := b.y - y
	var r := radius + PLAYER_RADIUS
	return dx * dx + dy * dy + dz * dz < r * r
