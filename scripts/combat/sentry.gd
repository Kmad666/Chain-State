extends StaticBody3D
## Sentry: an enemy (placeholder name and look) that loops a set path.
##
## Two kinds:
##   ground - hovers low over an island. When you come within ENGAGE_RANGE it
##            turns to face you and fires spread-out lines of large dark red orbs
##            straight across, parallel to the ground (NieR-style). Few orbs, with gaps.
##   air    - flies high and doesn't shoot. A constellation of dark red orbs spins
##            around it, with blue hookable orbs in a wider ring to swing from.
##
## Subduing (both kinds): hook it from within SUBDUE_RANGE, then swing around it.
## Each full lap adds a silver coil. On the third lap it releases a purple magic
## burst and the chain snaps: you keep your swing but at a capped speed, with a
## moment of slow motion so you can see where you're going. Hooking from too far
## away fails. Let go mid-wrap and the coils slip loose after a moment.
##
## Collision layer 4 (HOOK): grapple-able, but the player passes through it.

signal subdued(sentry: Node)

const MagicBurst := preload("res://scripts/combat/magic_burst.gd")
const HookOrb := preload("res://scripts/combat/hook_orb.gd")

const SUBDUE_RANGE := 20.0
const ENGAGE_RANGE := 38.0
const WRAPS_NEEDED := 3
const SLIP_DELAY := 1.5
const TELEGRAPH := 0.8
const BREAK_SPEED := 9.0         # your speed is capped to this when the chain snaps

# air constellation
const RED_ORBS := 10
const RED_RADIUS := 5.0
const RED_ORB_SIZE := 0.6
const BLUE_ORBS := 3
const BLUE_RADIUS := 9.0
const BLUE_RESPAWN := 4.0

@export var kind := "ground"
@export var path: PackedVector3Array = []     # world-space waypoints, looped
@export var speed := 5.0
@export var volley_every := 2.4
@export var bullet_speed := 9.0

var field: Node                  # BulletField (ground kind)
var player: Node
var is_subdued := false
var engaged := false
var wraps := 0.0
var _turn := 0.0
var _wp := 0
var _t := 0.0
var _fire_t := 1.0
var _volley := 0
var _hooked_by: Node = null
var _last_angle := 0.0
var _slip_t := -1.0
var _fall_v := 0.0
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _coils: Array[MeshInstance3D] = []
var _reds: Array[MeshInstance3D] = []
var _blues: Array = []           # HookOrb or null (respawning)
var _blue_t: Array[float] = []


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	var body_mesh := SphereMesh.new()
	body_mesh.radius = 1.1
	body_mesh.height = 2.6
	body_mesh.radial_segments = 4
	body_mesh.rings = 2
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = Mats.lit(Color(0.16, 0.15, 0.18), 0.5)
	add_child(body)

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.42
	core_mesh.height = 0.84
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core.material_override = _core_mat
	_core.position = Vector3(0, 0, -0.95)
	add_child(_core)

	var ring := TorusMesh.new()
	ring.inner_radius = 1.45
	ring.outer_radius = 1.65
	ring.rings = 24
	ring.ring_segments = 6
	_halo = MeshInstance3D.new()
	_halo.mesh = ring
	_halo.material_override = Mats.lit(Color(0.72, 0.55, 0.28), 0.4)
	add_child(_halo)

	if kind == "air":
		_build_constellation()
	if path.size() > 0:
		global_position = path[0]


func _build_constellation() -> void:
	var s := SphereMesh.new()
	s.radius = RED_ORB_SIZE
	s.height = RED_ORB_SIZE * 2.0
	s.radial_segments = 12
	s.rings = 6
	for i in RED_ORBS:
		var m := MeshInstance3D.new()
		m.mesh = s
		m.material_override = _red_mat()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.top_level = true       # placed in world space each frame, not spun with the body
		add_child(m)
		_reds.append(m)
	for i in BLUE_ORBS:
		_blues.append(null)
		_blue_t.append(0.0)


static func _red_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.42, 0.02, 0.05)
	return m


func _physics_process(dt: float) -> void:
	_t += dt
	if is_subdued:
		_fall(dt)
		return
	_halo.rotate_object_local(Vector3.FORWARD, dt * 1.2)
	_halo.rotation.x = 0.6 + sin(_t * 0.8) * 0.2

	var p_ok := player != null and is_instance_valid(player)
	engaged = p_ok and global_position.distance_to(player.global_position) <= ENGAGE_RANGE
	var hooked: bool = _hooked_by != null and is_instance_valid(_hooked_by) and _hooked_by.attached
	if hooked:
		_track_wrap(_hooked_by.global_position)
	else:
		_hooked_by = null
		_patrol(dt)
		if wraps > 0.0:
			if _slip_t < 0.0:
				_slip_t = SLIP_DELAY
			_slip_t -= dt
			if _slip_t <= 0.0:
				_turn = move_toward(_turn, 0.0, dt * 1.5 * TAU)
				wraps = absf(_turn) / TAU
				_update_coils()

	# face the player once engaged (ground kind keeps level so its shots stay level)
	if engaged:
		var to: Vector3 = player.global_position - global_position
		if kind == "ground":
			to.y = 0.0
		if to.length_squared() > 0.01:
			basis = basis.slerp(Basis.looking_at(to.normalized(), Vector3.UP), 1.0 - exp(-4.0 * dt)).orthonormalized()

	if kind == "air":
		_update_constellation(dt)
		_core_mat.albedo_color = Color(0.9, 0.15, 0.2) if engaged else Color(0.7, 0.45, 0.2)
		return

	# ground: telegraph (core swells, goes from ember to bright red) then fire
	if engaged and not hooked:
		_fire_t -= dt
	else:
		_fire_t = maxf(_fire_t, TELEGRAPH + 0.3)
	var wind := clampf(1.0 - _fire_t / TELEGRAPH, 0.0, 1.0) if engaged and not hooked else 0.0
	_core.scale = Vector3.ONE * (1.0 + wind * 0.9)
	_core_mat.albedo_color = (Color(0.9, 0.15, 0.2) if engaged else Color(0.7, 0.45, 0.2)).lerp(Color(1.0, 0.85, 0.8), wind)
	if _fire_t <= 0.0:
		_fire_line()
		_fire_t = volley_every


func _patrol(dt: float) -> void:
	if path.size() < 2:
		return
	var goal: Vector3 = path[_wp]
	var to := goal - global_position
	var step := speed * dt * (0.4 if engaged else 1.0)     # slows down while it fights
	if to.length() <= step:
		global_position = goal
		_wp = (_wp + 1) % path.size()
	else:
		global_position += to / to.length() * step


# ---------------------------------------------------------------- ground: lines of orbs
## A spread-out line of large orbs, aimed at the player, flying parallel to the
## ground. Alternate volleys shift by half a gap so standing still doesn't work.
func _fire_line() -> void:
	if field == null or player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return
	to = to.normalized()
	var count := 5
	var spread := deg_to_rad(64.0)
	var shift := 0.5 if _volley % 2 else 0.0
	for i in count:
		var f := (float(i) + shift) / float(count - 1) - 0.5
		var dir := to.rotated(Vector3.UP, f * spread)
		field.spawn(global_position + dir * 1.8 + Vector3(0, -0.4, 0), dir * bullet_speed, 7.0)
	_volley += 1


# ---------------------------------------------------------------- air: constellation
func _update_constellation(dt: float) -> void:
	var c := global_position
	for i in _reds.size():
		var a := _t * 1.1 + TAU * i / _reds.size()
		var tilt := sin(a * 2.0 + _t * 0.5) * 1.6
		_reds[i].global_position = c + Vector3(cos(a) * RED_RADIUS, tilt, sin(a) * RED_RADIUS)
		if player and is_instance_valid(player) and _touches(_reds[i].global_position, player.global_position):
			player.hit((player.global_position - _reds[i].global_position).normalized())
	for i in _blues.size():
		var orb = _blues[i]
		var a := -_t * 0.6 + TAU * i / _blues.size()
		var at := c + Vector3(cos(a) * BLUE_RADIUS, 1.5 + sin(_t + i) * 1.2, sin(a) * BLUE_RADIUS)
		if orb == null or not is_instance_valid(orb):
			_blues[i] = null
			_blue_t[i] -= dt
			if _blue_t[i] <= 0.0:
				var o := HookOrb.new()
				o.orbiting = true
				o.harmless = true
				add_child(o)
				o.top_level = true
				o.global_position = at
				_blues[i] = o
		elif orb.orbiting:
			orb.global_position = at
		else:
			_blues[i] = null          # it was caught; a new one grows in after a while
			_blue_t[i] = BLUE_RESPAWN


func _touches(orb_pos: Vector3, p: Vector3) -> bool:
	var y := clampf(orb_pos.y, p.y - 0.5, p.y + 0.5)
	return orb_pos.distance_to(Vector3(p.x, y, p.z)) < RED_ORB_SIZE + 0.38


# ---------------------------------------------------------------- the wrap
## Called by the player's grapple when the arrowhead bites. False = shaken off.
func on_hooked(p: Node) -> bool:
	if is_subdued:
		return false
	if p.global_position.distance_to(global_position) > SUBDUE_RANGE:
		if p.has_signal("notice"):
			p.notice.emit("Too far: it shakes the chain off. Get within %d m." % int(SUBDUE_RANGE))
		return false
	_hooked_by = p
	_slip_t = -1.0
	_last_angle = _angle_to(p.global_position)
	if p.has_signal("notice"):
		p.notice.emit("Hooked! Swing around it to wrap the chain.")
	return true


func on_released(_p: Node) -> void:
	_hooked_by = null
	_slip_t = SLIP_DELAY


func _angle_to(pos: Vector3) -> float:
	var d := pos - global_position
	return atan2(d.z, d.x)


## Counts laps of the player around it (in the horizontal plane); reversing unwinds.
func _track_wrap(player_pos: Vector3) -> void:
	var a := _angle_to(player_pos)
	var delta := wrapf(a - _last_angle, -PI, PI)
	_last_angle = a
	var before := floori(wraps)
	_turn += delta
	wraps = absf(_turn) / TAU
	var after := floori(wraps)
	if after > before and _hooked_by and _hooked_by.has_signal("notice") and after < WRAPS_NEEDED:
		_hooked_by.notice.emit("Wrap %d of %d" % [after, WRAPS_NEEDED])
	_update_coils()
	if wraps >= WRAPS_NEEDED:
		_subdue()


func _update_coils() -> void:
	var want := mini(floori(wraps), WRAPS_NEEDED)
	while _coils.size() < want:
		var t := TorusMesh.new()
		t.inner_radius = 1.05
		t.outer_radius = 1.22
		t.rings = 20
		t.ring_segments = 6
		var c := MeshInstance3D.new()
		c.mesh = t
		c.material_override = Mats.polished(Color(0.93, 0.95, 0.99))
		var k := _coils.size()
		c.position.y = (k - 1) * 0.42
		c.rotation = Vector3(0.25 * (k - 1), k * 0.9, 0.15)
		add_child(c)
		_coils.append(c)
	while _coils.size() > want:
		_coils.pop_back().queue_free()


## Third lap: a purple magic burst, and the chain snaps.
func _subdue() -> void:
	is_subdued = true
	_core_mat.albedo_color = Color(0.35, 0.35, 0.4)
	_core.scale = Vector3.ONE
	var burst := MagicBurst.new()
	get_parent().add_child(burst)
	burst.global_position = global_position
	for r in _reds:
		r.queue_free()
	_reds.clear()
	for o in _blues:
		if o and is_instance_valid(o) and o.orbiting:
			o.queue_free()
	_blues.clear()
	if _hooked_by and is_instance_valid(_hooked_by):
		var p := _hooked_by
		_hooked_by = null
		if p.has_method("chain_snapped"):
			p.chain_snapped(BREAK_SPEED)
		else:
			p.release()
	subdued.emit(self)


## Bound: it sinks slowly until it settles on something solid (or drops out of sight).
func _fall(dt: float) -> void:
	_fall_v = minf(_fall_v + 6.0 * dt, 9.0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (1.3 + _fall_v * dt), 1)
	if space.intersect_ray(q).is_empty():
		global_position.y -= _fall_v * dt
		rotation.z = lerp_angle(rotation.z, 0.5, dt)
	if global_position.y < -80.0:
		queue_free()
