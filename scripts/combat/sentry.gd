extends StaticBody3D
## Sentry: a flying enemy (placeholder name and look). It loops a set path and
## stops to fire bullet-hell volleys of slow projectiles with gaps to slip
## through. Some projectiles in each volley are hookable orbs.
##
## Subduing: hook it from close range (within SUBDUE_RANGE), then swing around it.
## Each full lap wraps the chain once more and shortens the rope; WRAPS_NEEDED
## laps bind it. While hooked it stops patrolling and fires at half rate. Hooking
## from too far away fails: it shakes the hook off. Let go mid-wrap and the coils
## slip loose after a moment.
##
## Collision layer 4 (HOOK): grapple-able, but the player passes through it.

signal subdued(sentry: Node)

const SUBDUE_RANGE := 20.0
const WRAPS_NEEDED := 3
const ROPE_PER_WRAP := 2.5       # each coil takes up this much chain
const SLIP_DELAY := 1.5          # seconds after letting go before coils loosen
const TELEGRAPH := 0.7           # wind-up before each volley

@export var path: PackedVector3Array = []     # world-space waypoints, looped
@export var speed := 6.0
@export var volley_every := 2.6               # seconds between volleys
@export var bullet_speed := 7.0

var field: Node                  # BulletField
var player: Node
var is_subdued := false
var wraps := 0.0                 # laps so far (fractional while swinging)
var _turn := 0.0                 # signed total angle swung around it; reversing unwinds
var _wp := 0
var _t := 0.0
var _fire_t := 1.5
var _pattern := 0
var _hooked_by: Node = null
var _last_angle := 0.0
var _slip_t := -1.0
var _fall_v := 0.0
var _body: MeshInstance3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _coils: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	# body: a dark iron diamond with a glowing core and a turning brass ring
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 1.1
	body_mesh.height = 2.6
	body_mesh.radial_segments = 4
	body_mesh.rings = 2
	_body = MeshInstance3D.new()
	_body.mesh = body_mesh
	_body.material_override = Mats.lit(Color(0.16, 0.15, 0.18), 0.5)
	add_child(_body)

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.42
	core_mesh.height = 0.84
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.albedo_color = Color(1.0, 0.45, 0.2)
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

	if path.size() > 0:
		global_position = path[0]


func _physics_process(dt: float) -> void:
	_t += dt
	if is_subdued:
		_fall(dt)
		return
	_halo.rotate_object_local(Vector3.FORWARD, dt * 1.2)
	_halo.rotation.x = 0.6 + sin(_t * 0.8) * 0.2

	var hooked: bool = _hooked_by != null and is_instance_valid(_hooked_by) and _hooked_by.attached
	if hooked:
		_track_wrap(_hooked_by.global_position)
	else:
		_hooked_by = null
		_patrol(dt)
		# coils slip loose if you let go
		if wraps > 0.0:
			if _slip_t < 0.0:
				_slip_t = SLIP_DELAY
			_slip_t -= dt
			if _slip_t <= 0.0:
				_turn = move_toward(_turn, 0.0, dt * 1.5 * TAU)
				wraps = absf(_turn) / TAU
				_update_coils()

	# face the player
	if player and is_instance_valid(player):
		var to: Vector3 = player.global_position - global_position
		to.y *= 0.5
		if to.length_squared() > 0.01:
			var target := Basis.looking_at(to.normalized(), Vector3.UP)
			basis = basis.slerp(target, 1.0 - exp(-4.0 * dt)).orthonormalized()

	# fire: telegraph (core swells and brightens), then the volley
	_fire_t -= dt * (0.5 if hooked else 1.0)
	var wind := clampf(1.0 - _fire_t / TELEGRAPH, 0.0, 1.0)
	_core.scale = Vector3.ONE * (1.0 + wind * 0.8)
	_core_mat.albedo_color = Color(1.0, 0.45, 0.2).lerp(Color(1.0, 0.95, 0.75), wind)
	if _fire_t <= 0.0:
		_fire()
		_fire_t = volley_every


func _patrol(dt: float) -> void:
	if path.size() < 2:
		return
	var goal: Vector3 = path[_wp]
	var to := goal - global_position
	var step := speed * dt
	if to.length() <= step:
		global_position = goal
		_wp = (_wp + 1) % path.size()
	else:
		global_position += to / to.length() * step
	global_position.y += sin(_t * 1.3) * 0.01      # a gentle bob


# ---------------------------------------------------------------- volleys
func _fire() -> void:
	if field == null:
		return
	match _pattern % 3:
		0: _ring_burst()
		1: _aimed_fan()
		2: _double_ring()
	_pattern += 1


## A ring of bullets with a few wide gaps to slip through; every fifth is hookable.
func _ring_burst() -> void:
	var n := 22
	var gap_at := randi() % n
	var off := randf() * TAU
	for i in n:
		if abs(i - gap_at) <= 1:
			continue                       # the gap
		var a := off + TAU * i / n
		var dir := Vector3(cos(a), randf_range(-0.12, 0.12), sin(a)).normalized()
		field.spawn(global_position + dir * 1.8, dir * bullet_speed, 8.0, i % 5 == 0)


## A fan aimed at the player: dodge sideways, or catch the hookable middle orb.
func _aimed_fan() -> void:
	if player == null or not is_instance_valid(player):
		_ring_burst()
		return
	var to: Vector3 = (player.global_position - global_position).normalized()
	var side := to.cross(Vector3.UP).normalized()
	for i in range(-3, 4):
		var dir := (to + side * i * 0.16).normalized()
		field.spawn(global_position + dir * 1.8, dir * bullet_speed * 1.25, 7.0, i == 0)


## Two tilted rings, offset so the holes line up into lanes.
func _double_ring() -> void:
	var n := 16
	for tilt in [-0.35, 0.35]:
		var off := randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			var dir := Vector3(cos(a), tilt * sin(a * 2.0), sin(a)).normalized()
			field.spawn(global_position + dir * 1.8, dir * bullet_speed * 0.85, 9.0, i % 8 == 0)


# ---------------------------------------------------------------- the wrap
## Called by the player's grapple when the arrowhead bites. False = shaken off.
func on_hooked(p: Node) -> bool:
	if is_subdued:
		return false
	if p.global_position.distance_to(global_position) > SUBDUE_RANGE:
		if p.has_signal("notice"):
			p.notice.emit("Too far: the Sentry shakes the chain off. Get within %d m." % int(SUBDUE_RANGE))
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


## Counts laps of the player around the Sentry (in the horizontal plane).
func _track_wrap(player_pos: Vector3) -> void:
	var a := _angle_to(player_pos)
	var delta := wrapf(a - _last_angle, -PI, PI)
	_last_angle = a
	var before := floori(wraps)
	_turn += delta
	wraps = absf(_turn) / TAU
	var after := floori(wraps)
	if after > before and _hooked_by:
		_hooked_by.rope_len = maxf(_hooked_by.rope_len - ROPE_PER_WRAP, 2.5)
		if _hooked_by.has_signal("notice") and after < WRAPS_NEEDED:
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


func _subdue() -> void:
	is_subdued = true
	_core_mat.albedo_color = Color(0.35, 0.35, 0.4)
	_core.scale = Vector3.ONE
	if _hooked_by and is_instance_valid(_hooked_by):
		var p := _hooked_by
		_hooked_by = null
		p.release()
		if p.has_signal("notice"):
			p.notice.emit("Sentry subdued.")
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
