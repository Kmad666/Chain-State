extends StaticBody3D
## A hookable projectile: a slow silver-ringed orb flying in a volley. It still
## hurts on contact, but the chain can catch it. Hooked, it freezes in mid-air
## and becomes a temporary anchor to swing from, then fades shortly after you
## let go. Collision layer 4 (HOOK): the grapple sees it, the player walks through it.

var velocity := Vector3.ZERO
var life := 8.0
var field: Node                 # the BulletField, for the player reference
var hooked := false
var _released_t := -1.0
var _core: MeshInstance3D
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("hook_orb")
	collision_layer = 4
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.9           # generous, so it's catchable mid-volley
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 12
	s.rings = 6
	_core = MeshInstance3D.new()
	_core.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.2, 0.75, 1.0)
	_core.material_override = m
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	var t := TorusMesh.new()
	t.inner_radius = 0.55
	t.outer_radius = 0.68
	t.rings = 16
	t.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = t
	_ring.material_override = Mats.polished(Color(0.93, 0.95, 0.99))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _physics_process(dt: float) -> void:
	_ring.rotate_object_local(Vector3.RIGHT, dt * 2.5)
	_ring.rotate_y(dt * 1.7)
	if hooked:
		return
	global_position += velocity * dt
	life -= dt
	if _released_t >= 0.0:
		_released_t -= dt
		scale = Vector3.ONE * clampf(_released_t / 1.2, 0.05, 1.0)
		if _released_t <= 0.0:
			queue_free()
			return
	if life <= 0.0:
		queue_free()
		return
	var p = field.player if field else null
	if p and is_instance_valid(p) and field._hits_player(global_position, p.global_position):
		p.hit(velocity.normalized())
		queue_free()


## Called by the player's grapple when the arrowhead bites.
func on_hooked(_player: Node) -> bool:
	hooked = true
	return true


func on_released(_player: Node) -> void:
	hooked = false
	velocity = Vector3.ZERO      # it stays where you left it, then fades
	_released_t = 1.2
