extends StaticBody3D
## Sentry: a spellcaster on a broom (placeholder low-poly model) that loops a
## set path. The ground kind is a wizard, the air kind a witch.
##
## Three kinds:
##   ground - hovers low over an island. When you come within ENGAGE_RANGE it
##            turns to face you and fires spread-out lines of large dark red orbs
##            straight across, parallel to the ground (NieR-style). Few orbs, with gaps.
##   air    - the witch. She doesn't shoot. She hovers inside her ward (ward.gd) at
##            the top of her orb tree (orb_tree.gd). You can only wrap her once you're
##            inside the ward: fly in through its opening.
##
##   apprentice - a weaker flyer: a smaller broom-rider in green who hovers on a
##            small loop and, within its engage range, fires single large, fast orbs
##            straight at you (leading your movement a little). One wrap binds it.
##
## Arresting (all kinds): hook it from within subdue_range(), then wrap the
## chain around it three times, either swinging round yourself or by pressing E
## to auto-wrap (the player circles it with the camera locked on). Each lap adds
## a silver coil. After the third, press E again to ARREST:
## the chain comes free with your momentum untouched (no slow motion, so it
## doesn't break the flow when there are several casters about). Hooking from too
## far away fails. Let go mid-wrap and the coils slip loose after a moment.
##
## Collision layer 4 (HOOK): grapple-able, but the player passes through it.

signal subdued(sentry: Node)

const HookOrb := preload("res://scripts/combat/hook_orb.gd")

const SUBDUE_RANGE := 20.0
const ENGAGE_RANGE := 38.0
const WRAPS_NEEDED := 3
const SLIP_DELAY := 1.5
const TELEGRAPH := 0.8
const BREAK_SPEED := INF         # no speed cap when the chain comes free: keep your momentum

@export var kind := "ground"
@export var path: PackedVector3Array = []     # world-space waypoints, looped
@export var speed := 5.0
@export var volley_every := 2.4
@export var bullet_speed := 9.0
var wraps_needed := WRAPS_NEEDED   # 3 for the wizard and witch, 1 for an apprentice
var engage_range := ENGAGE_RANGE
const APPRENTICE_SHOT_SPEED := 24.0
const APPRENTICE_SHOT_RADIUS := 1.1

var field: Node                  # BulletField (ground kind)
var player: Node
var is_subdued := false
var ready_to_arrest := false     # three wraps done: press E to arrest
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
var _landed := false
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _rig: Node3D                 # the broom and rider, tilted and bobbed for life
var title := "witch"             # used in messages: "witch" or "wizard"
var _coils: Array[MeshInstance3D] = []
var ward: Node = null            # air kind: the ward she sits in


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	_build_rider()

	if path.size() > 0:
		global_position = path[0]


## A simple low-poly caster on a broom, facing -Z (the way the Sentry looks).
## Wizard (ground kind): deep blue robe and hat, white beard. Witch (air kind):
## purple robe, near-black hat. The glowing orb in the casting hand is _core,
## which swells as the warning before each volley.
func _build_rider() -> void:
	var wizard := kind == "ground"
	var apprentice := kind == "apprentice"
	title = "wizard" if wizard else ("apprentice" if apprentice else "witch")
	var robe := Color(0.14, 0.19, 0.45) if wizard else Color(0.32, 0.12, 0.38)
	var hat := Color(0.12, 0.16, 0.38) if wizard else Color(0.10, 0.07, 0.12)
	var skin := Color(0.86, 0.72, 0.60) if wizard else Color(0.62, 0.78, 0.55)   # a green-tinged witch
	if apprentice:
		robe = Color(0.16, 0.42, 0.24)       # green: reads apart from the blue wizard and purple witch
		hat = Color(0.30, 0.22, 0.12)
		skin = Color(0.86, 0.72, 0.60)
		wraps_needed = 1
		engage_range = 45.0
		volley_every = 2.2
	var wood := Color(0.42, 0.28, 0.16)
	var straw := Color(0.80, 0.66, 0.36)

	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * (1.0 if apprentice else 1.3)
	add_child(_rig)

	# broom: handle along Z, bristles at the back
	var handle := _part(_cyl(0.06, 0.06, 2.8, 6), Vector3(0, 0, -0.1), Mats.lit(wood), Vector3(deg_to_rad(90), 0, 0))
	handle.position.y = 0.0
	_part(_cyl(0.07, 0.34, 0.9, 7), Vector3(0, 0, 1.55), Mats.lit(straw), Vector3(deg_to_rad(-90), 0, 0))
	_part(_cyl(0.09, 0.09, 0.12, 6), Vector3(0, 0, 1.1), Mats.lit(wood.darkened(0.3)), Vector3(deg_to_rad(90), 0, 0))   # binding

	# rider, seated on the broom
	_part(_cyl(0.16, 0.5, 0.95, 6), Vector3(0, 0.5, 0.15), Mats.lit(robe))                       # robe
	_part(_cyl(0.07, 0.07, 0.55, 5), Vector3(0.2, 0.62, -0.25), Mats.lit(robe.darkened(0.15)), Vector3(deg_to_rad(-55), 0, deg_to_rad(-12)))   # arm on the broom
	_part(_cyl(0.07, 0.07, 0.6, 5), Vector3(-0.28, 0.72, -0.3), Mats.lit(robe.darkened(0.15)), Vector3(deg_to_rad(-75), 0, deg_to_rad(25)))   # casting arm
	_part(_sphere(0.24, 6, 4), Vector3(0, 1.12, 0.05), Mats.lit(skin))                          # head
	_part(_cyl(0.48, 0.48, 0.04, 10), Vector3(0, 1.3, 0.05), Mats.lit(hat))                      # hat brim
	_part(_cyl(0.0, 0.27, 0.85, 7), Vector3(0, 1.72, 0.14), Mats.lit(hat), Vector3(deg_to_rad(-16), 0, 0))   # pointy crown
	if apprentice:
		pass                                                                                     # young: no beard
	elif wizard:
		_part(_cyl(0.17, 0.0, 0.42, 6), Vector3(0, 0.88, -0.14), Mats.lit(Color(0.92, 0.92, 0.9)))   # beard
	else:
		_part(_cyl(0.05, 0.0, 0.16, 4), Vector3(0, 1.08, -0.26), Mats.lit(skin.darkened(0.1)), Vector3(deg_to_rad(-90), 0, 0))   # pointed nose

	# the casting hand's orb (the telegraph)
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.44
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core.material_override = _core_mat
	_core.position = Vector3(-0.38, 0.86, -0.6)
	_rig.add_child(_core)


func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _sphere(r: float, seg: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


func _part(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_rig.add_child(mi)
	return mi


func _physics_process(dt: float) -> void:
	_t += dt
	if is_subdued:
		_fall(dt)
		return
	_rig.position.y = sin(_t * 1.6) * 0.12                    # hover bob
	_rig.rotation.z = sin(_t * 0.9) * 0.08                    # lazy roll on the broom

	var p_ok := player != null and is_instance_valid(player)
	engaged = p_ok and global_position.distance_to(player.global_position) <= engage_range
	var hooked: bool = _hooked_by != null and is_instance_valid(_hooked_by) and _hooked_by.attached
	if hooked:
		_track_wrap(_hooked_by.global_position)
	else:
		_hooked_by = null
		ready_to_arrest = false
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
			to.y = 0.0                   # an apprentice turns fully to face you: it aims
		if to.length_squared() > 0.01:
			basis = basis.slerp(Basis.looking_at(to.normalized(), Vector3.UP), 1.0 - exp(-4.0 * dt)).orthonormalized()

	if kind == "air":
		_core_mat.albedo_color = Color(0.85, 0.4, 1.0) if engaged else Color(0.7, 0.45, 0.2)
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
		if kind == "apprentice":
			_fire_aimed()
		else:
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
	Sfx.play_at("cast", global_position, -2.0, 0.85)
	_volley += 1


## Apprentice: one large, fast orb straight at you, leading your movement a little.
func _fire_aimed() -> void:
	if field == null or player == null:
		return
	var from := global_position + Vector3(0, 0.6, 0)
	var target: Vector3 = player.global_position + Vector3(0, 0.6, 0)
	var t := from.distance_to(target) / APPRENTICE_SHOT_SPEED
	target += player.velocity * t * 0.5
	var dir := (target - from).normalized()
	field.spawn(from + dir * 1.6, dir * APPRENTICE_SHOT_SPEED, 4.0, false, APPRENTICE_SHOT_RADIUS)
	Sfx.play_at("cast", global_position, -4.0, 1.25)
	_volley += 1


# ---------------------------------------------------------------- the wrap
## Called by the player's grapple when the arrowhead bites. False = shaken off.
## How close you must be to hook it for a wrap. A witch's ward pushes this out,
## so you can still hook her through the opening from just outside the shell.
func subdue_range() -> float:
	if ward and is_instance_valid(ward):
		return maxf(SUBDUE_RANGE, ward.radius + 8.0)
	return SUBDUE_RANGE


func on_hooked(p: Node) -> bool:
	if is_subdued:
		return false
	if p.global_position.distance_to(global_position) > subdue_range():
		if p.has_signal("notice"):
			p.notice.emit("Too far: the %s shakes the chain off. Get within %d m." % [title, int(subdue_range())])
		return false
	_hooked_by = p
	_slip_t = -1.0
	_last_angle = _angle_to(p.global_position)
	if p.has_signal("notice"):
		if ward and is_instance_valid(ward) and not ward.is_inside(p.global_position):
			p.notice.emit("Hooked through the opening. Get inside the ward to wrap her.")
		else:
			p.notice.emit("Hooked! Press E to auto-wrap, or swing around it yourself.")
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
	if ward and is_instance_valid(ward) and not ward.is_inside(player_pos):
		_last_angle = a              # laps only count inside her ward
		return
	var delta := wrapf(a - _last_angle, -PI, PI)
	_last_angle = a
	var before := floori(wraps)
	_turn += delta
	wraps = absf(_turn) / TAU
	var after := floori(wraps)
	if after > before and _hooked_by and _hooked_by.has_signal("notice") and after < wraps_needed:
		_hooked_by.notice.emit("Wrap %d of %d" % [after, wraps_needed])
	if wraps >= wraps_needed:
		_turn = signf(_turn) * TAU * wraps_needed     # bound: extra laps don't pile up
		wraps = wraps_needed
		if not ready_to_arrest:
			ready_to_arrest = true
			if _hooked_by and _hooked_by.has_signal("notice"):
				_hooked_by.notice.emit("Bound! Press E to ARREST the %s." % title)
	_update_coils()


## Can this player start wrapping it right now? (In range, and inside her ward.)
func can_wrap(p: Node3D) -> bool:
	if is_subdued:
		return false
	if p.global_position.distance_to(global_position) > subdue_range():
		return false
	return not (ward and is_instance_valid(ward) and not ward.is_inside(p.global_position))


## The widest circle the auto-wrap may fly: inside a ward it keeps clear of the shell.
func wrap_radius_max() -> float:
	if ward and is_instance_valid(ward):
		return ward.radius - 3.5
	return subdue_range() - 2.0


## E after the third wrap. Returns true if it worked.
func arrest() -> bool:
	if is_subdued or not ready_to_arrest:
		return false
	_subdue()
	return true


func _update_coils() -> void:
	var want := mini(floori(wraps), wraps_needed)
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
		c.position.y = 0.35 + (k - 1) * 0.4
		c.rotation = Vector3(0.25 * (k - 1), k * 0.9, 0.15)
		add_child(c)
		_coils.append(c)
	while _coils.size() > want:
		_coils.pop_back().queue_free()


## Arrested. Deliberately bare: no effects, sounds, flashes or new nodes. The
## caster drops to the ground with the chain coils still around them, a witch's
## ward goes, and the player's chain comes free with their momentum untouched.
func _subdue() -> void:
	is_subdued = true
	ready_to_arrest = false
	engaged = false
	_core.visible = false            # the casting glow goes out
	if ward and is_instance_valid(ward):
		ward.queue_free()            # her ward goes with her
	if _hooked_by and is_instance_valid(_hooked_by):
		var p := _hooked_by
		_hooked_by = null
		if p.has_method("chain_snapped"):
			p.chain_snapped(BREAK_SPEED)
		else:
			p.release()
	subdued.emit(self)


## Arrested: it drops like a stone until it hits something solid, then lies there
## tipped over on its side, coils and all (or falls out of sight off an edge).
func _fall(dt: float) -> void:
	if _landed:
		return
	_fall_v = minf(_fall_v + 20.0 * dt, 30.0)
	var step := _fall_v * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (1.2 + step), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position.y -= step
		rotation.z = lerp_angle(rotation.z, 1.2, minf(1.0, dt * 4.0))
	else:
		global_position.y = hit.position.y + 1.2
		rotation.z = 1.2
		_landed = true
	if global_position.y < -80.0:
		queue_free()
