extends StaticBody3D
## A hookable projectile: a slow silver-ringed orb flying in a volley. It still
## hurts on contact, but the chain can catch it. Hooked, it freezes in mid-air
## and becomes a temporary anchor to swing from, then fades shortly after you
## let go. Collision layer 4 (HOOK): the grapple sees it, the player walks through it.

var velocity := Vector3.ZERO
var life := 8.0
var field: Node                 # the BulletField, for the player reference
var hooked := false
var orbiting := false            # placed by a Sentry's constellation each frame
var harmless := false            # tree / constellation blue orbs don't hurt
var persistent := false          # stays in its tree when hooked or released
var highlighted := false        # lit gold while it's the grapple's current target
var grapple_name := "blue orb"   # the label the HUD shows for this grapple target
var _released_t := -1.0
var _t := 0.0
var _core_mat: StandardMaterial3D
const BLUE := Color(0.2, 0.75, 1.0)
const LIT := Color(1.0, 0.86, 0.3)
var _core: MeshInstance3D
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("hook_orb")
	add_to_group("magic")
	add_to_group("grapple_target")   # explicitly grapple-able: auto-aim can lock on to it
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
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.albedo_color = BLUE
	_core.material_override = _core_mat
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
	if highlighted:
		_t += dt
		_core.scale = Vector3.ONE * (1.15 + sin(_t * 9.0) * 0.08)
	if hooked or orbiting:
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
	if not harmless and field and p and is_instance_valid(p) and field._hits_player(global_position, p.global_position):
		p.hit(velocity.normalized())
		queue_free()


## Auto-aim's highlight: gold and pulsing while this is what the chain will bite.
func set_highlight(on: bool) -> void:
	highlighted = on
	_t = 0.0
	if _core_mat:
		_core_mat.albedo_color = LIT if on else BLUE
	if _core:
		_core.scale = Vector3.ONE


## Called by the player's grapple when the arrowhead bites.
func on_hooked(_player: Node) -> bool:
	if persistent:
		return true              # keeps riding its tree; the anchor follows it
	hooked = true
	orbiting = false             # caught: it leaves the constellation and holds still
	return true


func on_released(_player: Node) -> void:
	if persistent:
		return
	hooked = false
	velocity = Vector3.ZERO      # it stays where you left it, then fades
	_released_t = 1.2
