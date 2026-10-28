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

const Chain := preload("res://scripts/player/chain.gd")
const Viewmodel := preload("res://scripts/player/viewmodel.gd")

const LAYER_WORLD := 1          # grapple-able and solid
const LAYER_NPC := 2            # solid, talk-able, NOT grapple-able
const EYE_HEIGHT := 0.7         # camera height above the capsule centre
const MIN_ROPE := 2.0
const ATTACH_PULL := 0.03       # rope shortens by this fraction on attach (the "tug")
const MAX_CORRECTION := 25.0    # caps rope-yank velocity so it never explodes
const RELEASE_HOP := 3.5
const TALK_RANGE := 3.5
const RETURN_SPEED := 55.0
const OVERSPEED_ALLOW := 1.3    # dash/release boost may briefly exceed the cap by 30%...
const OVERSPEED_BLEED := 2.5    # ...then bleed back down (per second)
const CAM_ROLL := 0.045
const CAM_ROLL_MAX := 0.16

## Tunable feel. Sliders in the pause menu are generated from TUNING.
var tune := {
	"gravity": 13.0,
	"walk_speed": 6.0,
	"jump": 6.0,
	"air_accel": 22.0,
	"air_speed": 9.0,
	"rope_gravity": 0.6,
	"elastic": 1.4,
	"pump": 16.0,
	"reel_speed": 7.0,
	"max_speed": 25.0,
	"grapple_range": 40.0,
	"air_grapples": 3.0,
	"arrow_speed": 90.0,
	"release_boost": 0.15,
	"dash_speed": 10.0,
	"mouse_sensitivity": 0.25,
}
const TUNING := [
	{"key": "gravity", "label": "Gravity", "min": 4.0, "max": 30.0, "step": 0.5},
	{"key": "walk_speed", "label": "Walk speed", "min": 2.0, "max": 14.0, "step": 0.5},
	{"key": "jump", "label": "Jump", "min": 2.0, "max": 14.0, "step": 0.5},
	{"key": "air_speed", "label": "Air steer speed", "min": 2.0, "max": 20.0, "step": 0.5},
	{"key": "rope_gravity", "label": "Gravity while hooked", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "elastic", "label": "Rope pull (bungee)", "min": 0.0, "max": 4.0, "step": 0.1},
	{"key": "pump", "label": "Swing push", "min": 0.0, "max": 30.0, "step": 0.5},
	{"key": "reel_speed", "label": "Reel speed", "min": 1.0, "max": 20.0, "step": 0.5},
	{"key": "max_speed", "label": "Top speed (m/s)", "min": 8.0, "max": 60.0, "step": 1.0},
	{"key": "grapple_range", "label": "Grapple reach (m)", "min": 10.0, "max": 120.0, "step": 1.0},
	{"key": "air_grapples", "label": "Air grapples", "min": 1.0, "max": 10.0, "step": 1.0},
	{"key": "arrow_speed", "label": "Hook speed", "min": 20.0, "max": 300.0, "step": 5.0},
	{"key": "release_boost", "label": "Release boost", "min": 0.0, "max": 0.6, "step": 0.01},
	{"key": "dash_speed", "label": "Dash speed", "min": 0.0, "max": 30.0, "step": 0.5},
	{"key": "mouse_sensitivity", "label": "Mouse sensitivity", "min": 0.05, "max": 1.0, "step": 0.01},
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
var dash_cd := 0.0

# what the crosshair is on (read by the HUD)
var aim_valid := false
var aim_point := Vector3.ZERO
var aim_distance := 0.0
var look_npc: Node = null        # NPC or evidence under the crosshair within reach

var _look_delta := Vector2.ZERO
var _was_on_floor := true
var _just_landed := false
var _bob_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_WORLD | LAYER_NPC
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
	cam.fov = 80
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
	elif event.is_action_pressed("grapple"):
		if look_npc:
			talk_requested.emit(look_npc)
		else:
			try_grapple()
	elif event.is_action_released("grapple"):
		release()
	elif event.is_action_pressed("interact") and look_npc:
		talk_requested.emit(look_npc)
	elif event is InputEventMouseButton and event.pressed and attached:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rope_len = maxf(MIN_ROPE, rope_len - 0.75)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rope_len = minf(tune.grapple_range, rope_len + 0.75)


func _ray(mask: int, length: float) -> Dictionary:
	var from := cam.global_position
	var to := from - cam.global_basis.z * length
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


# ---------------------------------------------------------------- grapple
## Fire the arrowhead at whatever surface is under the crosshair.
func try_grapple() -> void:
	if hook_state == Chain.FLYING or attached:
		return
	var hit := _ray(LAYER_WORLD | LAYER_NPC, tune.grapple_range)
	if hit.is_empty() or (hit.collider.collision_layer & LAYER_WORLD) == 0:
		return
	if not is_on_floor():
		if air_left <= 0:
			return
		air_left -= 1
	hook_goal = hit.position
	hook_state = Chain.FLYING


func _attach() -> void:
	attached = true
	hook_state = Chain.HOOKED
	anchor = hook_goal
	hook_tip = anchor
	rope_len = minf(global_position.distance_to(anchor), tune.grapple_range)
	pull_left = rope_len * ATTACH_PULL
	grappled.emit()


## Let go (or cancel a shot still in flight).
func release(hop := false) -> void:
	if hook_state == Chain.FLYING:
		hook_state = Chain.RETURNING
		return
	if not attached:
		return
	attached = false
	hook_state = Chain.RETURNING
	if velocity.length() > 6.0:
		velocity *= 1.0 + tune.release_boost
	if hop:
		velocity.y = maxf(velocity.y, 0.0) + RELEASE_HOP


func _update_hook(dt: float) -> void:
	match hook_state:
		Chain.FLYING:
			var to := hook_goal - hook_tip
			var step: float = tune.arrow_speed * dt
			if to.length() <= step:
				_attach()
			else:
				hook_tip += to / to.length() * step
		Chain.HOOKED:
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


func respawn() -> void:
	release()
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
	if Game.playing():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_basis * Vector3(input.x, 0, input.y)
	wish.y = 0
	wish = wish.normalized()

	velocity.y -= tune.gravity * (tune.rope_gravity if attached else 1.0) * dt

	if attached:
		if is_on_floor():
			_walk(wish, dt)
		var look_wish := (cam.global_basis * Vector3(input.x, 0, input.y)).normalized()
		_swing(look_wish, dt)
	elif is_on_floor():
		_walk(wish, dt)
		if Game.playing() and Input.is_action_just_pressed("jump"):
			velocity.y = tune.jump
	else:
		# air strafe: steer, but can't accelerate past air_speed in the wish direction
		var cur := Vector3(velocity.x, 0, velocity.z).dot(wish)
		if wish != Vector3.ZERO and cur < tune.air_speed:
			velocity += wish * minf(tune.air_accel * dt, tune.air_speed - cur)

	# Dash: snap your momentum toward where you look
	dash_cd = maxf(dash_cd - dt, 0.0)
	if Game.playing() and dash_cd == 0.0 and Input.is_action_just_pressed("dash") and tune.dash_speed > 0.0:
		velocity = -cam.global_basis.z * maxf(velocity.length(), tune.dash_speed) * (1.0 + tune.release_boost)
		dash_cd = 1.2

	if Game.playing() and Input.is_action_just_pressed("restart"):
		respawn()

	# speed cap: boosts may poke above it briefly and bleed back down
	var spd := velocity.length()
	var cap: float = tune.max_speed
	if spd > cap * OVERSPEED_ALLOW:
		velocity = velocity / spd * cap * OVERSPEED_ALLOW
	elif spd > cap:
		velocity = velocity / spd * maxf(cap, spd - cap * OVERSPEED_BLEED * dt)

	floor_snap_length = 0.0 if attached else 0.3
	move_and_slide()
	if is_on_floor():
		air_left = int(tune.air_grapples)
		if not _was_on_floor:
			_just_landed = true
	_was_on_floor = is_on_floor()
	_update_hook(dt)
	if global_position.y < -60.0:
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

	# bungee: the rope tugs you toward the hook, harder the farther you are
	if tune.elastic > 0.0:
		var dist := global_position.distance_to(anchor)
		velocity -= rope_dir * minf(tune.elastic * maxf(dist - 3.0, 0.0), 22.0) * dt
		rope_len = minf(rope_len, dist + 0.5)

	if pull_left > 0.0:
		var p := minf(pull_left, tune.reel_speed * 1.5 * dt)
		rope_len -= p
		pull_left -= p
	if Game.playing():
		if Input.is_action_pressed("reel_in") or Input.is_action_pressed("jump"):
			rope_len -= tune.reel_speed * dt
		if Input.is_action_pressed("reel_out"):
			rope_len += tune.reel_speed * dt
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
	if Game.playing():
		var hit := _ray(LAYER_WORLD | LAYER_NPC, tune.grapple_range)
		if not hit.is_empty():
			var d := cam.global_position.distance_to(hit.position)
			if hit.collider.is_in_group("npc") or hit.collider.is_in_group("evidence"):
				if d <= TALK_RANGE:
					look_npc = hit.collider
			else:
				aim_valid = true
				aim_point = hit.position
				aim_distance = d

	var spd := velocity.length()
	cam.fov = lerpf(cam.fov, 80.0 + clampf((spd - 6.0) * 0.8, 0.0, 18.0), 0.08)

	# head bob on foot, and a lean into sideways swings
	var hs := Vector2(velocity.x, velocity.z).length()
	var walking := is_on_floor() and hs > 0.5
	if walking:
		_bob_t += dt * (6.0 + hs * 1.1)
	var bob_amt := clampf(hs / tune.walk_speed, 0.0, 1.0) if walking else 0.0
	cam.position.y = lerpf(cam.position.y, -absf(cos(_bob_t)) * 0.035 * bob_amt, 0.25)
	var side_speed := velocity.dot(global_basis.x)
	var roll := 0.0 if is_on_floor() else clampf(-side_speed * CAM_ROLL, -CAM_ROLL_MAX, CAM_ROLL_MAX)
	cam.rotation.z = lerp_angle(cam.rotation.z, roll, 1.0 - exp(-5.0 * dt))

	viewmodel.animate(dt, hook_state, hook_tip, velocity, is_on_floor(), _look_delta, _just_landed)
	_look_delta = Vector2.ZERO
	_just_landed = false
	chain.update(dt, hook_state, hook_tip)
