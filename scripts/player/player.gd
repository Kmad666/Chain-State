extends CharacterBody3D
## First-person detective with a Verlet-style grapple: a silver chain wound round
## the right forearm, with a silver arrowhead held in the fist.
##
## Like Verlet Swing, the hook bites into ANY world surface under the crosshair
## (collision layer 1) within reach. Hold LEFT MOUSE to fire; you swing once the
## arrowhead lands. Let go to fly; the chain zips back into your hand.
##
## The rope is a distance constraint: each tick we predict where gravity and
## momentum would carry us, and if that point is farther from the anchor than the
## rope allows, we project it back onto the rope's sphere (classic Verlet
## constraint) and derive the velocity from the corrected position.
##
## Every feel number lives in `tune` so the pause menu can adjust it live.

signal grappled
signal talk_requested(npc: Node)
signal notice(text: String)      # short messages for the HUD
signal hurt(health: int)
signal downed
signal snapped                   # the chain broke on a bound enemy
signal stun_started              # touched a magic projectile or a ward

const Chain := preload("res://scripts/player/chain.gd")
const Viewmodel := preload("res://scripts/player/viewmodel.gd")

const LAYER_WORLD := 1          # grapple-able and solid
const LAYER_NPC := 2            # solid, talk-able, NOT grapple-able
const LAYER_HOOK := 4           # moving grapple targets (enemies, hookable orbs): not solid
const LAYER_LAND := 8           # solid ground you can stand on but NOT grapple (landing platforms)
const LATCH_RANGE := 120.0      # how far down the land-below check looks
const LATCH_REEL := 40.0        # m/s the ground latch reels you in
const MAX_HEALTH := 3
const INVULN_TIME := 1.2
const STUN_TIME := 3.0          # touching magic: no control, no chain, you drop
const EYE_HEIGHT := 0.7         # camera height above the capsule centre
const MIN_ROPE := 2.0
const ATTACH_PULL := 0.03       # rope shortens by this fraction on attach (the "tug")
const MAX_CORRECTION := 25.0    # caps rope-yank velocity so it never explodes
const RELEASE_HOP := 3.5
const TALK_RANGE := 3.5
const RETURN_SPEED := 55.0
const TUNE_VERSION := 2         # bump to discard saved values whose meaning changed
const CAM_ROLL := 0.045
const CAM_ROLL_MAX := 0.16

## Tunable feel. Sliders in the pause menu are generated from TUNING.
var tune := {
	"gravity": 13.0,
	"walk_speed": 6.0,
	"jump": 6.0,
	"air_accel": 22.0,
	"air_speed": 6.0,                # air steering tops out at walking pace
	"rope_gravity": 0.6,
	"elastic": 1.4,
	"pump": 16.0,
	"reel_speed": 7.0,
	"top_over_walk": 10.0,           # top speed = walk speed + this (16 m/s by default)
	"grapple_range": 40.0,
	"air_grapples": 3.0,
	"arrow_speed": 90.0,
	"release_boost": 0.15,
	"dash_speed": 10.0,
	"mouse_sensitivity": 0.25,
	"aim_assist": 70.0,
	"fov": 90.0,
	"lock_cone": 30.0,
}
const TUNING := [
	{"key": "gravity", "label": "Gravity", "min": 4.0, "max": 30.0, "step": 0.5},
	{"key": "walk_speed", "label": "Walk speed", "min": 2.0, "max": 14.0, "step": 0.5},
	{"key": "jump", "label": "Jump", "min": 2.0, "max": 14.0, "step": 0.5},
	{"key": "air_speed", "label": "Air steer speed (default = walk speed)", "min": 2.0, "max": 20.0, "step": 0.5},
	{"key": "rope_gravity", "label": "Gravity while hooked", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "elastic", "label": "Rope pull (bungee)", "min": 0.0, "max": 4.0, "step": 0.1},
	{"key": "pump", "label": "Swing push", "min": 0.0, "max": 30.0, "step": 0.5},
	{"key": "reel_speed", "label": "Reel speed", "min": 1.0, "max": 20.0, "step": 0.5},
	{"key": "top_over_walk", "label": "Top speed above walk (m/s)", "min": 0.0, "max": 40.0, "step": 1.0},
	{"key": "grapple_range", "label": "Grapple reach (m)", "min": 10.0, "max": 120.0, "step": 1.0},
	{"key": "air_grapples", "label": "Air grapples", "min": 1.0, "max": 10.0, "step": 1.0},
	{"key": "arrow_speed", "label": "Hook speed", "min": 20.0, "max": 300.0, "step": 5.0},
	{"key": "release_boost", "label": "Release boost", "min": 0.0, "max": 0.6, "step": 0.01},
	{"key": "dash_speed", "label": "Dash speed", "min": 0.0, "max": 30.0, "step": 0.5},
	{"key": "mouse_sensitivity", "label": "Mouse sensitivity", "min": 0.05, "max": 1.0, "step": 0.01},
	{"key": "aim_assist", "label": "Reticle size (aim assist)", "min": 0.0, "max": 160.0, "step": 5.0},
	{"key": "fov", "label": "Field of view", "min": 70.0, "max": 110.0, "step": 1.0},
	{"key": "lock_cone", "label": "Auto-aim lock cone (deg)", "min": 0.0, "max": 60.0, "step": 1.0},
]
const PRESETS := [
	{"name": "Float", "desc": "No gravity on the rope. Drift on your momentum.",
		"values": {"rope_gravity": 0.0, "elastic": 0.0, "pump": 7.0}},
	{"name": "Pendulum", "desc": "Full gravity on a rigid rope. Classic Verlet swing arcs.",
		"values": {"rope_gravity": 1.0, "elastic": 0.0, "pump": 10.0}},
	{"name": "Bungee", "desc": "Rope pulls you toward the hook like a stretchy band, 60% gravity. Fast and slingy.",
		"values": {"rope_gravity": 0.6, "elastic": 1.4, "pump": 16.0}},
]

var head: Node3D
var cam: Camera3D
var viewmodel: Node3D
var chain: Node3D
var spawn := Transform3D.IDENTITY

var attached := false
var anchor := Vector3.ZERO
var rope_len := 0.0
var pull_left := 0.0
var air_left := 3
var hook_state := 0              # chain.gd: STOWED, FLYING, HOOKED, RETURNING
var hook_tip := Vector3.ZERO
var hook_goal := Vector3.ZERO
var hook_node: Node3D = null     # a moving target the hook is flying to / attached to
var hook_offset := Vector3.ZERO  # where on it, in its local space
var health := MAX_HEALTH
var invuln := 0.0
var stunned := 0.0               # seconds of stun left
var aim_enemy: Node = null       # enemy under the crosshair (read by the HUD)
var dash_cd := 0.0

# what the crosshair is on (read by the HUD)
var aim_valid := false
var aim_point := Vector3.ZERO
var aim_distance := 0.0
var swings := 0                 # grapples that bit (not counting the ground latch): the course counts these
var latching := false            # Space in the air over land: hook straight down and reel in fast
var land_below := -1.0           # metres to land straight below, or -1 if none (read by the HUD)
var _land_point := Vector3.ZERO
var aim_blocked := false         # the centre of the view is on something you can't grapple
signal landed_on(body: Node)
signal fell                      # dropped into the void and respawned
var fall_limit := -60.0     # touched down on something (the world uses it for checkpoints)
var wrap_lock := false
var _hooked_body: Object = null  # what the current grapple bit
var _skip_body: Object = null    # the anchor you just let go of: ignored by the aim for a moment
var _skip_t := 0.0          # E on a hooked caster: circle them automatically
var _wrap_t := 0.0
var lock_target: Node3D = null   # the grapple target auto-aim has locked onto
var highlight_target: Node3D = null   # what the chain would bite right now, lit up (read by the HUD)
var _lock_lost := 0.0
var look_npc: Node = null        # NPC or evidence under the crosshair within reach

var _look_delta := Vector2.ZERO
var _was_on_floor := true
var _just_landed := false
var _bob_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_WORLD | LAYER_NPC | LAYER_LAND
	floor_max_angle = deg_to_rad(50)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	add_child(col)

	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	cam = Camera3D.new()
	cam.fov = tune.fov
	cam.near = 0.02
	cam.far = 2000
	head.add_child(cam)

	viewmodel = Viewmodel.new()
	cam.add_child(viewmodel)
	chain = Chain.new()
	chain.viewmodel = viewmodel
	add_child(chain)

	spawn = global_transform
	air_left = int(tune.air_grapples)


## Top speed: walking pace plus the margin (16 m/s with the defaults).
func top_speed() -> float:
	return tune.walk_speed + tune.top_over_walk


func apply_values(values: Dictionary) -> void:
	for k in values:
		if tune.has(k):
			tune[k] = float(values[k])


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if not Game.playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = tune.mouse_sensitivity * 0.01
		rotate_y(-event.relative.x * s)
		head.rotate_x(-event.relative.y * s)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88), deg_to_rad(88))
		_look_delta += event.relative
	elif stunned > 0.0 and (event.is_action_pressed("grapple") or event.is_action_pressed("interact")):
		return
	elif event.is_action_pressed("grapple"):
		if look_npc:
			talk_requested.emit(look_npc)
		else:
			try_grapple()
	elif event.is_action_released("grapple"):
		if not latching:
			release()
	elif event.is_action_pressed("interact"):
		interact()
	elif event is InputEventMouseButton and event.pressed and attached:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rope_len = maxf(MIN_ROPE, rope_len - 0.75)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rope_len = minf(tune.grapple_range, rope_len + 0.75)


func _ray(mask: int, length: float) -> Dictionary:
	var from := cam.global_position
	var to := from - cam.global_basis.z * length
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = _excludes()
	return get_world_3d().direct_space_state.intersect_ray(q)


## The reticle's radius in screen pixels (tune.aim_assist is given at 1080p).
func reticle_px() -> float:
	return tune.aim_assist * get_viewport().get_visible_rect().size.y / 1080.0


func _ray_dir(dir: Vector3, mask: int, length: float) -> Dictionary:
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, mask)
	q.exclude = _excludes()
	return get_world_3d().direct_space_state.intersect_ray(q)


## Aim assist. What the grapple would bite if fired now, anywhere inside the reticle:
##  1. magic (blue orbs, casters) inside the circle and in sight: the nearest to you;
##  2. else whatever surface is dead centre;
##  3. else the surface closest to the centre of the circle, scanning outward ring by ring.
## Returns a ray-style hit {collider, position} or {} if nothing is in reach.
func find_target() -> Dictionary:
	const MASK := LAYER_WORLD | LAYER_HOOK | LAYER_LAND     # LAND blocks the view but is never a target
	var r_px := reticle_px()
	var centre := get_viewport().get_visible_rect().size * 0.5
	var reach: float = tune.grapple_range
	var eye := cam.global_position

	# 1. a caster inside the reticle and in sight: the nearest one
	if r_px > 0.0:
		var best: Dictionary = {}
		var best_d := INF
		for n in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(n) or not (n is Node3D):
				continue
			var p: Vector3 = n.global_position
			var d := eye.distance_to(p)
			if d > reach or d >= best_d or cam.is_position_behind(p):
				continue
			if cam.unproject_position(p).distance_to(centre) > r_px:
				continue
			if _in_sight(n):
				best = {"collider": n, "position": p}
				best_d = d
		if not best.is_empty():
			return best

	# 2. the locked grapple target, if it's inside the reticle
	var lock_ok := lock_target != null and is_instance_valid(lock_target)
	var lock_hit := {}
	if lock_ok:
		lock_hit = {"collider": lock_target, "position": lock_target.global_position}
		if _in_reticle(lock_target.global_position):
			return lock_hit

	# 3. the surface dead centre (unless it's land you can't grapple)
	var hit := _ray(MASK, reach)
	if not hit.is_empty() and not _is_land(hit.collider):
		return hit

	# 4. a surface elsewhere in the reticle, closest to the centre
	if r_px > 0.0:
		const RINGS := 4
		const SPOKES := 16
		for ring in range(1, RINGS + 1):
			var rr := r_px * ring / RINGS
			var found: Dictionary = {}
			var found_off := INF
			for k in SPOKES:
				var a := TAU * (k + 0.5 * (ring % 2)) / SPOKES
				var sp := centre + Vector2(cos(a), sin(a)) * rr
				var h := _ray_dir(cam.project_ray_normal(sp), MASK, reach)
				if h.is_empty() or _is_land(h.collider):
					continue
				var off := cam.unproject_position(h.position).distance_to(centre)
				if off < found_off:
					found = h
					found_off = off
			if not found.is_empty():
				return found

	# 5. nothing under the reticle at all: the lock, even if it's off to the side or off-screen
	return lock_hit


## Rays ignore you, and for half a second the anchor you just let go of,
## so swapping to the next anchor never re-hooks the one you were on.
func _excludes() -> Array[RID]:
	var ex: Array[RID] = [get_rid()]
	if _skip_t > 0.0 and is_instance_valid(_skip_body) and _skip_body is CollisionObject3D:
		ex.append((_skip_body as CollisionObject3D).get_rid())
	return ex


## Not a lock-on candidate right now: the anchor you're hanging from, or the one
## you just let go of. (Auto-aim moves on to the next.)
func _is_spent(n: Object) -> bool:
	return (attached and n == _hooked_body) or (n == _skip_body and _skip_t > 0.0)


func _is_land(n: Object) -> bool:
	return n is CollisionObject3D and (n.collision_layer & LAYER_LAND) != 0 and (n.collision_layer & LAYER_WORLD) == 0


func _in_reticle(p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var centre := get_viewport().get_visible_rect().size * 0.5
	return cam.unproject_position(p).distance_to(centre) <= maxf(reticle_px(), 10.0)


## Clear line from the eye to this node (nothing solid or hookable in between).
func _in_sight(n: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, n.global_position, LAYER_WORLD | LAYER_HOOK | LAYER_LAND)
	q.exclude = _excludes()
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return h.is_empty() or h.collider == n


func _view_angle(p: Vector3) -> float:
	return rad_to_deg((-cam.global_basis.z).angle_to(p - cam.global_position))


## Auto-aim lock-on for explicitly grapple-able things (group "grapple_target").
## It picks the one nearest the crosshair within tune.lock_cone degrees, then holds
## on to it while it stays in reach and in sight, even once it's left the screen.
## It switches when you aim clearly closer to another one, and moves on from the
## one you're hanging from.
func _update_lock(dt: float) -> void:
	var cone: float = tune.lock_cone
	if cone <= 0.0 or stunned > 0.0:
		lock_target = null
		return
	var reach: float = tune.grapple_range
	var eye := cam.global_position
	var best: Node3D = null
	var best_ang := INF
	for n in get_tree().get_nodes_in_group("grapple_target"):
		if not is_instance_valid(n) or n == hook_node or not (n is Node3D) or _is_spent(n):
			continue
		var p: Vector3 = n.global_position
		if eye.distance_to(p) > reach:
			continue
		var ang := _view_angle(p)
		if ang > cone or ang >= best_ang:
			continue
		if _in_sight(n):
			best = n
			best_ang = ang

	# keep the current lock while it's valid; a brief loss of sight is forgiven
	if lock_target != null:
		if not is_instance_valid(lock_target) or lock_target == hook_node or _is_spent(lock_target) \
				or eye.distance_to(lock_target.global_position) > reach:
			lock_target = null
		elif not _in_sight(lock_target):
			_lock_lost += dt
			if _lock_lost > 0.25:
				lock_target = null
		else:
			_lock_lost = 0.0

	if best == null:
		return
	if lock_target == null:
		lock_target = best
		_lock_lost = 0.0
	elif best != lock_target:
		var la := _view_angle(lock_target.global_position)
		if (_in_reticle(best.global_position) and not _in_reticle(lock_target.global_position)) or best_ang < la - 10.0:
			lock_target = best
			_lock_lost = 0.0


func _set_highlight(n: Node3D) -> void:
	if n == highlight_target:
		return
	if highlight_target and is_instance_valid(highlight_target) and highlight_target.has_method("set_highlight"):
		highlight_target.set_highlight(false)
	highlight_target = n
	if n and n.has_method("set_highlight"):
		n.set_highlight(true)


## E: on a hooked caster, start the auto-wrap, then arrest once they're bound;
## otherwise talk to / examine whatever's in front of you.
func interact() -> void:
	var e := hook_node if attached and hook_node and is_instance_valid(hook_node) and hook_node.is_in_group("enemy") else null
	if e:
		if e.ready_to_arrest:
			wrap_lock = false
			e.arrest()
		elif wrap_lock:
			wrap_lock = false                # E again: free your view
		elif e.can_wrap(self):
			wrap_lock = true
			_wrap_t = 0.0
			notice.emit("Locked on: swing round it (A / D to circle).")
		elif e.ward and is_instance_valid(e.ward) and not e.ward.is_inside(global_position):
			notice.emit("Get inside her ward first: fly in through the gold opening.")
		else:
			notice.emit("Too far to wrap. Get within %d m." % int(e.subdue_range()))
		return
	if look_npc:
		talk_requested.emit(look_npc)


## Locked on: A / D push you round the caster (sideways to your view, which is held
## on them), building up to top speed. You steer; this just makes circling quick.
const CIRCLE_ACCEL := 26.0

func _circle_push(side: float, dt: float) -> void:
	if absf(side) < 0.1:
		return
	var right := cam.global_basis.x
	right.y = 0.0
	if right.length_squared() < 0.01:
		return
	right = right.normalized() * signf(side)
	var along := velocity.dot(right)
	if along < top_speed():
		velocity += right * minf(CIRCLE_ACCEL * dt, top_speed() - along)


## Thrown: a wizard burned the chain and flung you back.
func knockback(v: Vector3) -> void:
	velocity = v


## Keep the hooked caster dead centre while the wrap lock is on (you still do the swinging).
func _face_wrap_target(dt: float) -> void:
	var d := hook_node.global_position - cam.global_position
	# ease the view round over the first half-second, then hold them dead centre
	_wrap_t += dt
	var k := lerpf(1.0 - exp(-10.0 * dt), 1.0, clampf(_wrap_t / 0.5, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), k)
	head.rotation.x = lerp_angle(head.rotation.x, atan2(d.y, Vector2(d.x, d.z).length()), k)


## Space in mid-air with land below: aim straight down, hook the ground and reel
## in fast for a quick, safe landing. Free: it isn't a swing and costs no air grapple.
func ground_latch() -> void:
	if land_below < 0.0 or stunned > 0.0:
		return
	if attached or hook_state == Chain.FLYING:
		release()
	latching = true
	hook_node = null
	_hooked_body = null              # a latch isn't an anchor: nothing to skip afterwards
	hook_goal = _land_point
	hook_state = Chain.FLYING
	Sfx.play("chain_throw", -5.0, 1.1)


## Straight down from your feet: is there land within LATCH_RANGE?
func _check_land_below() -> void:
	land_below = -1.0
	if is_on_floor():
		return
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * LATCH_RANGE, LAYER_WORLD | LAYER_LAND)
	q.exclude = _excludes()
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		land_below = global_position.y - 0.9 - h.position.y
		_land_point = h.position


# ---------------------------------------------------------------- grapple
## Fire the arrowhead at whatever surface is under the crosshair.
func try_grapple() -> void:
	if hook_state == Chain.FLYING or attached or stunned > 0.0:
		return
	var hit := find_target()
	if hit.is_empty():
		return
	# grapples on ordinary things are limited per jump; on magic they're free
	if not is_on_floor() and not is_magic(hit.collider):
		if air_left <= 0:
			return
		air_left -= 1
	hook_goal = hit.position
	_hooked_body = hit.collider
	hook_node = null
	if hit.collider.collision_layer & LAYER_HOOK:
		hook_node = hit.collider
		hook_offset = Vector3.ZERO          # aim for its centre: it's moving
		if hit.collider.is_in_group("ward"):
			hook_offset = hit.collider.to_local(hit.position)   # a fixed shell: hook where you hit
	hook_state = Chain.FLYING
	Sfx.play("chain_throw", -5.0, 1.25)


func _attach() -> void:
	if hook_node:
		if not is_instance_valid(hook_node) or not hook_node.has_method("on_hooked") or not hook_node.on_hooked(self):
			hook_node = null
			hook_state = Chain.RETURNING      # shaken off
			return
	attached = true
	if not latching:
		swings += 1
	Sfx.play("land", -6.0, 1.7)          # the hook bites: a short, bright clack
	hook_state = Chain.HOOKED
	anchor = hook_goal
	hook_tip = anchor
	rope_len = minf(global_position.distance_to(anchor), tune.grapple_range)
	pull_left = rope_len * ATTACH_PULL
	grappled.emit()


## Let go (or cancel a shot still in flight).
func release(hop := false) -> void:
	latching = false
	if hook_state == Chain.FLYING:
		hook_state = Chain.RETURNING
		return
	if not attached:
		return
	attached = false
	hook_state = Chain.RETURNING
	_skip_body = _hooked_body
	_skip_t = 0.5 if _hooked_body != null else 0.0
	_hooked_body = null
	if hook_node and is_instance_valid(hook_node) and hook_node.has_method("on_released"):
		hook_node.on_released(self)
	hook_node = null
	if velocity.length() > 6.0:
		velocity = (velocity * (1.0 + tune.release_boost)).limit_length(maxf(top_speed(), velocity.length()))
	if hop:
		velocity.y = maxf(velocity.y, 0.0) + RELEASE_HOP


func _update_hook(dt: float) -> void:
	match hook_state:
		Chain.FLYING:
			if hook_node:
				if not is_instance_valid(hook_node):
					hook_node = null
					hook_state = Chain.RETURNING
					return
				hook_goal = hook_node.to_global(hook_offset)
			var to := hook_goal - hook_tip
			var step: float = tune.arrow_speed * dt
			if to.length() <= step:
				_attach()
			else:
				hook_tip += to / to.length() * step
		Chain.HOOKED:
			if hook_node:
				if not is_instance_valid(hook_node):
					hook_node = null
					release()
					return
				anchor = hook_node.to_global(hook_offset)
			hook_tip = anchor
		Chain.RETURNING:
			var home: Vector3 = chain.stowed_tip()
			var to := home - hook_tip
			var step := maxf(RETURN_SPEED * dt, to.length() * (1.0 - exp(-18.0 * dt)))
			if to.length() <= step + 0.02:
				hook_state = Chain.STOWED
			else:
				hook_tip += to / to.length() * step
		_:
			hook_tip = chain.stowed_tip()


## The chain snaps after binding an enemy. No release boost, and your speed is
## capped so you don't get flung somewhere unexpected; you keep your direction.
func chain_snapped(max_speed: float) -> void:
	if hook_node and is_instance_valid(hook_node) and hook_node.has_method("on_released"):
		hook_node.on_released(self)
	hook_node = null
	attached = false
	hook_state = Chain.RETURNING
	velocity = velocity.limit_length(max_speed)
	wrap_lock = false
	snapped.emit()


static func is_magic(n: Node) -> bool:
	return n.is_in_group("magic") or n.is_in_group("hook_orb") or n.is_in_group("enemy")


## Touched magic (a red orb, a projectile, a ward): stunned for STUN_TIME. The
## chain drops, your sideways motion dies and you fall straight down, passing
## through wards. Control returns when it wears off. A short grace period follows.
func hit(_from_dir: Vector3) -> void:
	if invuln > 0.0 or stunned > 0.0 or not Game.playing():
		return
	_drop_chain()
	stunned = STUN_TIME
	invuln = STUN_TIME + 0.8
	velocity = Vector3(velocity.x * 0.15, minf(velocity.y, 0.0), velocity.z * 0.15)
	Sfx.play("hurt", 0.0, 0.9)
	Sfx.play("fall", -4.0, 0.6)
	stun_started.emit()


func _drop_chain() -> void:
	if hook_node and is_instance_valid(hook_node) and hook_node.has_method("on_released"):
		hook_node.on_released(self)
	hook_node = null
	attached = false
	if hook_state != Chain.STOWED:
		hook_state = Chain.RETURNING


func respawn() -> void:
	release()
	latching = false
	_skip_t = 0.0
	stunned = 0.0
	global_transform = spawn
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	hook_state = Chain.STOWED
	air_left = int(tune.air_grapples)


## Drop the hook and stop (used when a conversation starts).
func halt() -> void:
	release()
	velocity = Vector3(0, minf(velocity.y, 0.0), 0)


# ---------------------------------------------------------------- movement
func _physics_process(dt: float) -> void:
	var input := Vector2.ZERO
	stunned = maxf(stunned - dt, 0.0)
	if Game.playing() and stunned <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_basis * Vector3(input.x, 0, input.y)
	wish.y = 0
	wish = wish.normalized()

	velocity.y -= tune.gravity * (tune.rope_gravity if attached else 1.0) * dt

	if wrap_lock and not (attached and hook_node and is_instance_valid(hook_node) and hook_node.is_in_group("enemy") and not hook_node.is_subdued):
		wrap_lock = false
	if wrap_lock:
		_face_wrap_target(dt)
		_circle_push(input.x, dt)
	if attached:
		if is_on_floor():
			_walk(wish, dt)
		var look_wish := (cam.global_basis * Vector3(input.x, 0, input.y)).normalized()
		_swing(look_wish, dt)
	elif is_on_floor():
		_walk(wish, dt)
		if Game.playing() and stunned <= 0.0 and Input.is_action_just_pressed("jump"):
			velocity.y = tune.jump
			Sfx.play("jump", -4.0)
	else:
		# air strafe: steer, but can't accelerate past air_speed in the wish direction
		var cur := Vector3(velocity.x, 0, velocity.z).dot(wish)
		if wish != Vector3.ZERO and cur < tune.air_speed:
			velocity += wish * minf(tune.air_accel * dt, tune.air_speed - cur)
	if not is_on_floor() and Game.playing() and stunned <= 0.0 and not latching \
			and Input.is_action_just_pressed("jump") and land_below >= 0.0 and not wrap_lock:
		ground_latch()

	# Dash: snap your momentum toward where you look
	dash_cd = maxf(dash_cd - dt, 0.0)
	invuln = maxf(invuln - dt, 0.0)
	if Game.playing() and stunned <= 0.0 and dash_cd == 0.0 and Input.is_action_just_pressed("dash") and tune.dash_speed > 0.0:
		velocity = -cam.global_basis.z * maxf(velocity.length(), tune.dash_speed) * (1.0 + tune.release_boost)
		dash_cd = 1.2

	if Game.playing() and Input.is_action_just_pressed("restart"):
		respawn()

	# speed cap: never faster than walk speed + top_over_walk. Swinging, the whole
	# velocity is capped; in free flight only the horizontal part (you can still fall)
	var cap: float = top_speed()
	if latching:
		pass                         # the ground latch is a landing aid, not travel: it may reel faster
	elif attached:
		velocity = velocity.limit_length(cap)
	else:
		var hv := Vector2(velocity.x, velocity.z)
		if hv.length() > cap:
			hv = hv.limit_length(cap)
			velocity.x = hv.x
			velocity.z = hv.y

	floor_snap_length = 0.0 if attached else 0.3
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor():
		air_left = int(tune.air_grapples)
		if not _was_on_floor:
			_just_landed = true
			if fall_speed > 2.0:
				# harder landings are louder and a touch deeper
				var k := clampf((fall_speed - 2.0) / 18.0, 0.0, 1.0)
				Sfx.play("land", lerpf(-10.0, 0.0, k), lerpf(1.1, 0.8, k))
			var col := get_last_slide_collision()
			if col:
				landed_on.emit(col.get_collider())
		if latching and attached:
			release()
	_was_on_floor = is_on_floor()
	_update_hook(dt)
	if global_position.y < fall_limit:
		fell.emit()
		respawn()


func _walk(wish: Vector3, dt: float) -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	var ws: float = tune.walk_speed
	if h.length() > ws * 1.05:
		h = h.lerp(wish * ws, clampf(2.8 * dt, 0.0, 1.0))   # landed with momentum: bleed it off
	elif wish != Vector3.ZERO:
		h = h.move_toward(wish * ws, 25.0 * dt)
	else:
		h = h.move_toward(Vector3.ZERO, 25.0 * dt)
	velocity.x = h.x
	velocity.z = h.z


func _swing(wish: Vector3, dt: float) -> void:
	var rope_dir := (global_position - anchor).normalized()

	# pump: push perpendicular to the rope toward where you're holding
	var push := wish - rope_dir * wish.dot(rope_dir)
	velocity += push * tune.pump * dt

	# E held: give slack. The rope pays out freely (no bungee tug, no auto pull-in)
	var slack: bool = Game.playing() and Input.is_action_pressed("reel_out") \
			and not (hook_node and is_instance_valid(hook_node) and hook_node.is_in_group("enemy"))
	if slack:
		pull_left = 0.0

	# bungee: the rope tugs you toward the hook, harder the farther you are
	if tune.elastic > 0.0 and not slack:
		var dist := global_position.distance_to(anchor)
		velocity -= rope_dir * minf(tune.elastic * maxf(dist - 3.0, 0.0), 22.0) * dt
		rope_len = minf(rope_len, dist + 0.5)

	if pull_left > 0.0:
		var p := minf(pull_left, tune.reel_speed * 1.5 * dt)
		rope_len -= p
		pull_left -= p
	if Game.playing():
		if Input.is_action_pressed("reel_in"):
			rope_len -= tune.reel_speed * dt
		if slack:
			rope_len += tune.reel_speed * dt
	if latching:
		rope_len -= LATCH_REEL * dt
	rope_len = clampf(rope_len, MIN_ROPE, tune.grapple_range)

	# Verlet distance constraint: predict, then project back onto the rope sphere
	var next := global_position + velocity * dt
	var off := next - anchor
	var d := off.length()
	if d > rope_len and d > 0.001:
		var corrected := anchor + off / d * rope_len
		var fix := (corrected - next) / dt
		if fix.length() > MAX_CORRECTION:
			fix = fix.normalized() * MAX_CORRECTION
		velocity += fix


# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	# crosshair: an NPC in talk range wins over a grapple target
	look_npc = null
	aim_valid = false
	aim_enemy = null
	var lit: Node3D = null
	aim_blocked = false
	_skip_t = maxf(_skip_t - dt, 0.0)
	_check_land_below()
	if latching and hook_state == Chain.FLYING:
		head.rotation.x = lerp_angle(head.rotation.x, deg_to_rad(-80.0), 1.0 - exp(-14.0 * dt))
	if Game.playing():
		_update_lock(dt)
		var near := _ray(LAYER_WORLD | LAYER_NPC | LAYER_HOOK, TALK_RANGE)
		if not near.is_empty() and (near.collider.is_in_group("npc") or near.collider.is_in_group("evidence")):
			look_npc = near.collider
		else:
			var hit := find_target()
			if not hit.is_empty() and hit.collider.is_in_group("grapple_target") and hit.collider != hook_node:
				lit = hit.collider
			if not hit.is_empty():
				if hit.collider.is_in_group("enemy") or hit.collider.is_in_group("hook_orb") or hit.collider.is_in_group("ward"):
					aim_enemy = hit.collider
				aim_valid = true
				aim_point = hit.position
				aim_distance = cam.global_position.distance_to(hit.position)
			else:
				var c := _ray(LAYER_WORLD | LAYER_HOOK | LAYER_LAND, tune.grapple_range)
				aim_blocked = not c.is_empty() and _is_land(c.collider)
	_set_highlight(lit)

	var spd := velocity.length()
	cam.fov = lerpf(cam.fov, tune.fov + clampf((spd - 6.0) * 0.6, 0.0, 12.0), 0.08)

	# head bob on foot, and a lean into sideways swings
	var hs := Vector2(velocity.x, velocity.z).length()
	var walking := is_on_floor() and hs > 0.5
	Sfx.set_walking(walking and Game.playing() and hs > 1.5, hs)
	if walking:
		_bob_t += dt * (6.0 + hs * 1.1)
	var bob_amt := clampf(hs / tune.walk_speed, 0.0, 1.0) if walking else 0.0
	cam.position.y = lerpf(cam.position.y, -absf(cos(_bob_t)) * 0.035 * bob_amt, 0.25)
	var side_speed := velocity.dot(global_basis.x)
	var roll := 0.0 if is_on_floor() else clampf(-side_speed * CAM_ROLL, -CAM_ROLL_MAX, CAM_ROLL_MAX)
	if wrap_lock:
		roll *= 0.4          # a gentle lean only: circling at speed shouldn't tip the horizon
	cam.rotation.z = lerp_angle(cam.rotation.z, roll, 1.0 - exp(-5.0 * dt))

	viewmodel.animate(dt, hook_state, hook_tip, velocity, is_on_floor(), _look_delta, _just_landed)
	_look_delta = Vector2.ZERO
	_just_landed = false
	chain.update(dt, hook_state, hook_tip)
