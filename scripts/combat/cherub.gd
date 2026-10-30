extends Node3D
## The Cherub: a giant floating eye with angel wings. A boss.
##
## Come within WAKE_RANGE and it turns its eye on you (a TELEGRAPH-long stare) and
## casts a vast transparent cone from its eye toward where you stood, big enough to
## swallow an island. You're trapped inside: the cone's wall pushes you back. Then
## the eye pours bullet-hell patterns down the cone (spirals, expanding rings, aimed
## fans) for you to dodge, and releases Sages (small winged eyes, see sentry.gd kind
## "sage"): the only things in the fight you can grapple. They shoot too.
## Arrest SAGES_TO_WIN of them and the Cherub is spent: the cone fades, the barrage
## stops and the eye closes.
##
## Performance: projectiles go through the shared BulletField (one MultiMesh); the
## cone is one transparent mesh; no lights. The cone's material is warmed (drawn
## invisibly) at load so it never stalls a frame when it first appears.

signal spent

const EyeModel := preload("res://scripts/combat/eye_model.gd")
const RADIUS := 8.0
const WAKE_RANGE := 135.0
const TELEGRAPH := 2.0
const CONE_LENGTH := 175.0
const CONE_HALF := 38.0            # degrees
const MAX_SAGES := 3
const SAGE_EVERY := 5.0
const SAGES_TO_WIN := 5
const SHOT := 0.85                 # barrage orb radius

var player: Node
var field: Node                    # the BulletField
var spawn_sage: Callable           # world hook: (eye_pos: Vector3, hover: Vector3) -> Node

var state := "idle"                # idle, waking, fight, spent
var axis := Vector3.FORWARD        # the cone's axis (fixed once cast)
var sages: Array = []
var arrested := 0
var _t := 0.0
var _state_t := 0.0
var _pattern := 0
var _pattern_t := 0.0
var _emit_t := 0.0
var _spin := 0.0
var _sage_t := 2.0
var _parts := {}
var _body: Node3D
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _cone_k := 0.0                 # 0..1 grow-in


func _ready() -> void:
	add_to_group("cherub")
	_body = Node3D.new()
	add_child(_body)
	_parts = EyeModel.build(_body, RADIUS)
	# the cone: a cylinder with a pointed end at the eye, opening down the axis
	var cm := CylinderMesh.new()
	cm.top_radius = 0.01
	cm.bottom_radius = CONE_LENGTH * tan(deg_to_rad(CONE_HALF))
	cm.height = CONE_LENGTH
	cm.radial_segments = 48
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.albedo_color = Color(1.0, 0.86, 0.45, 0.01)
	_cone = MeshInstance3D.new()
	_cone.mesh = cm
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.top_level = true
	add_child(_cone)
	_place_cone(Vector3.FORWARD, 0.02)       # drawn tiny and faint from the start: warms its shader


func _physics_process(dt: float) -> void:
	_t += dt
	_state_t += dt
	# wings beat slowly; the eye bobs
	var flap := sin(_t * 1.6) * 0.35
	_parts.wings[0].rotation.z = -flap
	_parts.wings[1].rotation.z = flap
	_body.position.y = sin(_t * 0.7) * 1.2
	var p_ok := player != null and is_instance_valid(player)
	match state:
		"idle":
			_body.rotation.y = sin(_t * 0.3) * 0.6          # gazing about
			if p_ok and global_position.distance_to(player.global_position) < WAKE_RANGE:
				state = "waking"
				_state_t = 0.0
				if player.has_signal("notice"):
					player.notice.emit("The Cherub has seen you.")
		"waking":
			_look_at_player(dt, 2.0)
			if _state_t >= TELEGRAPH:
				axis = (player.global_position - global_position).normalized()
				state = "fight"
				_state_t = 0.0
		"fight":
			_look_at_player(dt, 3.0)
			_cone_k = minf(1.0, _cone_k + dt * 1.2)
			_place_cone(axis, _cone_k)
			_cone_mat.albedo_color.a = 0.14 * _cone_k
			if _cone_k >= 1.0:
				_trap_player()
				_barrage(dt)
				_tend_sages(dt)
		"spent":
			_cone_k = maxf(0.0, _cone_k - dt * 0.8)
			_place_cone(axis, maxf(_cone_k, 0.02))
			_cone_mat.albedo_color.a = 0.14 * _cone_k
			_body.rotation.x = lerpf(_body.rotation.x, 0.7, dt)     # droops
			_parts.pupil.visible = false                              # the eye closes
			_parts.iris.visible = false


func _look_at_player(dt: float, rate: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to: Vector3 = player.global_position - _body.global_position
	if to.length_squared() < 1.0:
		return
	var want := Basis.looking_at(to.normalized(), Vector3.UP)
	_body.global_basis = _body.global_basis.slerp(want, 1.0 - exp(-rate * dt)).orthonormalized()


## The cone from the eye along `dir`, grown to fraction k of its length.
func _place_cone(dir: Vector3, k: float) -> void:
	var len := CONE_LENGTH * k
	var y := -dir                                  # the mesh's +Y (its point) faces back at the eye
	var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_cone.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3(k, k, k)), global_position + dir * len * 0.5)


## Inside the cone? Push the player back off its wall (and out of the eye's mouth).
func _trap_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var v: Vector3 = player.global_position - global_position
	var along := v.dot(axis)
	var radial := v - axis * along
	along = clampf(along, RADIUS + 3.0, CONE_LENGTH)
	var max_r := along * tan(deg_to_rad(CONE_HALF)) - 0.6
	if radial.length() > max_r:
		var out := radial.normalized()
		player.global_position = global_position + axis * along + out * max_r
		var vo: float = player.velocity.dot(out)
		if vo > 0.0:
			player.velocity -= out * vo                # stop dead against the wall
	elif v.dot(axis) < RADIUS + 3.0:
		player.global_position = global_position + axis * along + radial


func is_trapped(p: Vector3) -> bool:
	if state != "fight" or _cone_k < 1.0:
		return false
	var v := p - global_position
	var along := v.dot(axis)
	return along > 0.0 and along <= CONE_LENGTH and (v - axis * along).length() <= along * tan(deg_to_rad(CONE_HALF)) + 0.01


# ---------------------------------------------------------------- the barrage
## Cycles through patterns, 6 s each with a short breather between.
func _barrage(dt: float) -> void:
	_pattern_t += dt
	if _pattern_t > 7.0:
		_pattern_t = 0.0
		_pattern = (_pattern + 1) % 3
	if _pattern_t > 6.0 or field == null:
		return                                         # breather
	_emit_t -= dt
	match _pattern:
		0:  # spiral: two arms turning down the cone
			if _emit_t <= 0.0:
				_emit_t = 0.07
				_spin += 0.33
				for arm in 2:
					_shoot(_cone_dir(_spin + arm * PI, 0.55), 13.0)
		1:  # rings: two rings at once, opening as they fly
			if _emit_t <= 0.0:
				_emit_t = 0.9
				var off := randf() * TAU
				for i in 18:
					_shoot(_cone_dir(off + TAU * i / 18.0, 0.35), 11.0)
					_shoot(_cone_dir(off + TAU * (i + 0.5) / 18.0, 0.75), 11.0)
		2:  # aimed fan at you
			if _emit_t <= 0.0 and player and is_instance_valid(player):
				_emit_t = 0.75
				var to: Vector3 = (player.global_position - global_position).normalized()
				var side := to.cross(Vector3.UP).normalized()
				for i in 7:
					_shoot((to + side * (i - 3) * 0.09).normalized(), 17.0)


## A direction inside the cone: angle `phi` round the axis, `frac` of the way out to its wall.
func _cone_dir(phi: float, frac: float) -> Vector3:
	var u := axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var w := axis.cross(u)
	var e := deg_to_rad(CONE_HALF) * frac
	return (axis * cos(e) + (u * cos(phi) + w * sin(phi)) * sin(e)).normalized()


func _shoot(dir: Vector3, speed: float) -> void:
	field.spawn(_body.global_position + dir * (RADIUS + 1.0), dir * speed, 12.0, false, SHOT)


# ---------------------------------------------------------------- sages
func _tend_sages(dt: float) -> void:
	sages = sages.filter(func(s): return is_instance_valid(s) and not s.is_subdued)
	_sage_t -= dt
	if _sage_t > 0.0 or sages.size() >= MAX_SAGES or not spawn_sage.is_valid():
		return
	_sage_t = SAGE_EVERY
	# a hover spot somewhere in the cone, 35-75 m down it and not too far out
	var phi := randf() * TAU
	var along := randf_range(35.0, 75.0)
	var hover := global_position + _cone_dir(phi, randf_range(0.2, 0.7)) * along
	var s = spawn_sage.call(_body.global_position + axis * (RADIUS + 1.0), hover)
	if s:
		sages.append(s)
		s.subdued.connect(_on_sage_arrested)


func _on_sage_arrested(_s: Node) -> void:
	arrested += 1
	if arrested >= SAGES_TO_WIN and state == "fight":
		state = "spent"
		_state_t = 0.0
		if field:
			field.clear()
		for s in sages:
			if is_instance_valid(s) and not s.is_subdued:
				s.queue_free()
		spent.emit()
