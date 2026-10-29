extends Node3D
## The playable world. Builds the level picked in the level select (Game.level):
## the test range, or one of the island levels. Wires the player, HUD, pause
## menu, dialogue panel, editor and logbook together.

const Player := preload("res://scripts/player/player.gd")
const Npc := preload("res://scripts/world/npc.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const DialoguePanel := preload("res://scripts/ui/dialogue_panel.gd")
const DialogueEditor := preload("res://scripts/ui/dialogue_editor.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const LogbookPanel := preload("res://scripts/ui/logbook_panel.gd")
const SunGlare := preload("res://scripts/ui/sun_glare.gd")
const Evidence := preload("res://scripts/world/evidence.gd")
const FloatingIsland := preload("res://scripts/world/floating_island.gd")
const BulletField := preload("res://scripts/combat/bullet_field.gd")
const Sentry := preload("res://scripts/combat/sentry.gd")
const OrbTree := preload("res://scripts/combat/orb_tree.gd")
const Ward := preload("res://scripts/combat/ward.gd")
const Clouds := preload("res://scripts/world/clouds.gd")
const PerfOverlay := preload("res://scripts/ui/perf_overlay.gd")
const SwingAnchor := preload("res://scripts/world/swing_anchor.gd")

const START_POS := Vector3(0, 1.0, 14)
const SKY_SAVE := "user://sky.txt"

## Kenney "Skyboxes" (CC0): 360-degree panoramas. `u` and `elev` locate the painted
## sun in the image so the real light comes from the same place.
const SKIES := {
	"day": {"name": "Day", "top": Color(0.548, 0.718, 0.942), "glare": 1.0, "u": 0.916, "elev": 49.9, "light": Color(1.0, 0.97, 0.90), "energy": 0.8,
		"ambient": 0.45, "fog": Color(0.685, 0.766, 0.949)},
	"morning": {"name": "Morning", "top": Color(0.992, 0.929, 0.84), "glare": 1.0, "u": 0.912, "elev": 51.3, "light": Color(1.0, 0.84, 0.66), "energy": 0.75,
		"ambient": 0.45, "fog": Color(0.977, 0.874, 0.765)},
	"night": {"name": "Night", "top": Color(0.194, 0.248, 0.451), "glare": 0.35, "u": 0.916, "elev": 51.3, "light": Color(0.62, 0.72, 1.0), "energy": 0.35,
		"ambient": 1.7, "fog": Color(0.179, 0.229, 0.407)},
	"space": {"name": "Space", "top": Color(0.099, 0.157, 0.322), "glare": 0.15, "u": 0.623, "elev": 9.1, "light": Color(0.72, 0.76, 1.0), "energy": 0.35,
		"ambient": 1.9, "fog": Color(0.143, 0.181, 0.381)},
	"alien": {"name": "Alien", "top": Color(0.853, 0.714, 0.951), "glare": 1.0, "u": 0.889, "elev": 62.6, "light": Color(1.0, 0.86, 1.0), "energy": 0.8,
		"ambient": 0.45, "fog": Color(0.843, 0.777, 0.914)},
}

var player: CharacterBody3D
var hud: Control
var panel: Control
var editor: Control
var pause_menu: Control
var logbook: Control
var env: Environment
var sun: DirectionalLight3D
var islands: Array = []
var sentries: Array = []
var tree: Node3D
var ward: Node3D
var clouds: Node3D
# Platform Test course
var pads: Array = []              # landing pads, in order
var anchors: Array = []
var par := 0
var checkpoint := 0
var falls := 0
var finished := false
var bullets: Node3D
var start_pos := START_POS
var start_yaw := 0.0
var glare: Control
var sky_id := "day"
var _talking_to: Node = null
var _had_capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menus keep working while paused...
	_build_environment()
	_build_world()

	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE   # ...but the player freezes
	add_child(player)
	player.global_position = start_pos
	player.rotation.y = start_yaw
	player.spawn = player.global_transform
	player.talk_requested.connect(_talk)
	player.landed_on.connect(_on_landed)
	player.fell.connect(func(): falls += 1)
	if not pads.is_empty():
		player.fall_limit = -30.0
	if bullets:
		bullets.player = player
	for s in sentries:
		s.player = player
	if tree:
		tree.player = player
	if ward:
		ward.player = player

	# sun glare sits between the 3D view and the HUD
	var glare_layer := CanvasLayer.new()
	glare_layer.layer = 5
	add_child(glare_layer)
	glare = SunGlare.new()
	glare.camera = player.cam
	glare_layer.add_child(glare)
	set_sky(sky_id)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Hud.new()
	hud.player = player
	ui.add_child(hud)
	var perf := PerfOverlay.new()
	ui.add_child(perf)
	player.notice.connect(func(t):
		hud.toast(t, 2.5)
		perf.note(t))
	player.stun_started.connect(func():
		hud.flash(Color(0.55, 0.25, 1.0), 0.5)
		hud.toast("Stunned! You drop for %d seconds." % int(player.STUN_TIME), 2.5))
	player.snapped.connect(_on_chain_snapped)
	player.downed.connect(func():
		hud.toast("Down! Back to the start.", 3.0)
		if bullets:
			bullets.clear())
	panel = DialoguePanel.new()
	panel.closed.connect(_on_dialogue_closed)
	ui.add_child(panel)
	pause_menu = PauseMenu.new()
	pause_menu.editor_requested.connect(open_editor)
	pause_menu.sky_selected.connect(set_sky)
	ui.add_child(pause_menu)
	pause_menu.bind(player)
	editor = DialogueEditor.new()
	editor.close_requested.connect(close_editor)
	editor.play_test_requested.connect(_play_test)
	ui.add_child(editor)
	logbook = LogbookPanel.new()
	logbook.closed.connect(func(): Game.set_ui_mode("play"))
	ui.add_child(logbook)

	Game.set_ui_mode("play")


# ---------------------------------------------------------------- world
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	# ambient comes from a colour matched to each sky: lighting straight from the
	# bright panoramas washes the ground out in the Compatibility renderer
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	var saved := "day"
	if FileAccess.file_exists(SKY_SAVE):
		saved = FileAccess.get_file_as_string(SKY_SAVE).strip_edges()
	set_sky(saved if SKIES.has(saved) else "day")


## Swap the panorama and move the sun, its colour and the fog to match it.
func set_sky(id: String) -> void:
	if not SKIES.has(id):
		return
	sky_id = id
	var s: Dictionary = SKIES[id]
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = load("res://assets/skyboxes/skybox-%s.png" % id)
	env.sky.sky_material = mat
	env.ambient_light_color = s.fog
	env.ambient_light_energy = s.ambient
	env.fog_light_color = s.fog
	# Godot's panorama yaw is the negative of the image's horizontal position
	var sun_dir := Basis.from_euler(Vector3(deg_to_rad(s.elev), -s.u * TAU, 0)) * Vector3.FORWARD
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.BACK)
	Mats.set_chrome_env(s.top, s.fog, Color(0.26, 0.29, 0.24) * (1.0 if s.energy > 0.5 else 0.6),
		1.0 if s.energy > 0.5 else 1.2)
	if glare:
		glare.sun_dir = sun_dir
		glare.tint = s.light
		glare.strength = s.glare
	sun.light_color = s.light
	sun.light_energy = s.energy
	var f := FileAccess.open(SKY_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(id)


func _build_world() -> void:
	match Game.level:
		"level_1":
			_build_level_1()
		"level_2":
			_build_level_2()
		"enemy_test":
			_build_enemy_test()
		"enemy_test_air":
			_build_enemy_test_air()
		"platform_test":
			_build_platform_test()
		"hamlet":
			_build_hamlet()
		"city":
			_build_city()
		_:
			_build_range()
	if Game.level != "range" and (not islands.is_empty() or not pads.is_empty()):
		var c := Vector3.ZERO
		var spots: Array = islands if not islands.is_empty() else pads
		for isl in spots:
			c += isl.position
		clouds = Clouds.new()
		clouds.centre = c / spots.size()
		if Game.level == "hamlet" or Game.level == "city":
			clouds.y_low = -70.0           # keep them under the island, out of the streets
			clouds.y_high = -14.0
			clouds.spread = 170.0
		add_child(clouds)


## Level 1: two islands at the same height, a short gap between them.
func _build_level_1() -> void:
	var a := _island(Vector3(0, 0, 0), 22.0, 11)
	var b := _island(Vector3(6, 2, -72), 26.0, 23)
	_start_on(a, b)


## Level 2: the far island is further away and higher, so you'll need height and momentum.
func _build_level_2() -> void:
	var a := _island(Vector3(0, 0, 0), 20.0, 37)
	var b := _island(Vector3(38, 16, -70), 28.0, 41)
	_start_on(a, b)


## Enemy test (ground): one wide island, one low-flying Sentry that fires
## spread-out lines of orbs across the ground once you come within range.
func _build_enemy_test() -> void:
	_island(Vector3(0, 0, 0), 34.0, 5)
	_island(Vector3(-52, 10, -30), 12.0, 7)
	var loop := PackedVector3Array()
	for i in 8:
		var a := TAU * i / 8.0
		loop.append(Vector3(cos(a) * 16.0, 2.4, sin(a) * 16.0 - 6.0))
	_sentry("ground", loop)
	start_pos = Vector3(0, 1.0, 30)
	start_yaw = 0.0


## Enemy test (air): the witch's tree. A tall, slowly turning cone of 80 red
## orbs (touch one and you're stunned) and 10 blue ones spiralling up as the
## route. At the top the witch hovers inside her ward; fly in through its opening.
func _build_enemy_test_air() -> void:
	_island(Vector3(0, 0, 0), 26.0, 5)
	_island(Vector3(-46, 6, -40), 12.0, 7)
	var base := Vector3(0, 12, -6)
	tree = OrbTree.new()
	tree.position = base
	add_child(tree)
	ward = Ward.new()
	ward.radius = 17.0                                            # twice the old 8.5
	ward.position = base + Vector3(0, tree.height + 4.5 + ward.radius, 0)   # same gap above the tree
	ward.open_dir = Vector3(0, -0.5, 1.0)
	add_child(ward)
	var witch := _sentry("air", PackedVector3Array([ward.position]))
	witch.ward = ward
	start_pos = Vector3(0, 1.0, 18)
	start_yaw = 0.0


func _sentry(kind: String, loop: PackedVector3Array) -> Node:
	if bullets == null:
		bullets = BulletField.new()
		add_child(bullets)
	var s := Sentry.new()
	s.kind = kind
	s.path = loop
	s.field = bullets
	add_child(s)
	s.subdued.connect(_on_sentry_subdued)
	sentries.append(s)
	return s


## A caster arrested: just a line of text. No flash, banner or sound.
func _on_chain_snapped() -> void:
	hud.toast("Arrested.", 2.0)


func _on_sentry_subdued(_s: Node) -> void:
	pass   # the snap itself is the feedback (see _on_chain_snapped)


## Platform Test: placeholder cubes over the void, one swing per gap.
## Grey pads (LAND: stand on them, can't grapple them), orange anchors (the only
## grapple-able things) hung high above each gap. Every gap is too wide to jump
## or dash across, and they get wider and less level as you go.
## Each entry: pad top-centre position, plus the anchor between it and the next.
const COURSE := [
	{"pad": Vector3(0, 0, 0), "size": Vector3(12, 1.5, 12)},
	{"pad": Vector3(0, 0, -40), "anchor": Vector3(0, 14, -20), "size": Vector3(8, 1.5, 8)},     # 30 m gap, level
	{"pad": Vector3(0, 4, -82), "anchor": Vector3(0, 18, -61), "size": Vector3(8, 1.5, 8)},     # 34 m gap, step up
	{"pad": Vector3(0, 0, -126), "anchor": Vector3(0, 16, -104), "size": Vector3(7, 1.5, 7)},   # 37 m gap, step down
	{"pad": Vector3(10, 5, -164), "anchor": Vector3(5, 20, -145), "size": Vector3(7, 1.5, 7)},  # 31 m gap, up and to the side
	{"pad": Vector3(0, 4, -204), "anchor": Vector3(5, 20, -184), "size": Vector3(10, 1.5, 10), "finish": true},  # 33 m gap
]


const KIT := "res://assets/models/kenney/platformer/%s.glb"
const KIT_BLOCK := 2.082125        # the grass blocks' width in kit units (1 unit tall, base at 0)


## A Kenney Platformer Kit model, placed for looks only (no collision).
func _kit(model: String, pos: Vector3, scale_by: float, yaw := 0.0, parent: Node = null) -> Node3D:
	var sc = load(KIT % model)
	if sc == null:
		return null
	var n: Node3D = sc.instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale_by
	(parent if parent else self).add_child(n)
	_tone_kit(n)
	return n


var _toned := {}


## The kit's pastel colours blow out under this sky's light: tone them down a
## touch (shared materials are toned once and reused, so this stays cheap).
func _tone_kit(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var m = mi.get_active_material(si)
			if not (m is BaseMaterial3D):
				continue
			if not _toned.has(m):
				var t: BaseMaterial3D = m.duplicate()
				t.albedo_color = t.albedo_color * Color(0.72, 0.72, 0.72, 1.0)
				t.roughness = 1.0
				t.metallic = 0.0
				t.metallic_specular = 0.2
				_toned[m] = t
			mi.set_surface_override_material(si, _toned[m])


func _build_platform_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1871
	for i in COURSE.size():
		var c: Dictionary = COURSE[i]
		if c.has("anchor"):
			var a := SwingAnchor.new()
			a.position = c.anchor
			add_child(a)
			anchors.append(a)
		var size: Vector3 = c.get("size", Vector3(10, 1.5, 10))
		var top: Vector3 = c.pad
		var finish: bool = c.get("finish", false)
		# a grass block from the kit, scaled to the pad's width; its collision matches it
		var k := size.x / KIT_BLOCK
		var body := StaticBody3D.new()
		body.collision_layer = Player.LAYER_LAND
		body.collision_mask = 0
		body.position = top
		var shape := BoxShape3D.new()
		shape.size = Vector3(size.x, k, size.z)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position.y = -k * 0.5
		body.add_child(col)
		add_child(body)
		if _kit("block-grass-large" if finish else "block-grass-overhang-large", Vector3(0, -k, 0), k, 0.0, body) == null:
			# kit missing: fall back to a plain grey box
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = shape.size
			mi.mesh = bm
			mi.position.y = -k * 0.5
			mi.material_override = Mats.grid(Color(0.55, 0.56, 0.6), Color(0.5, 0.51, 0.55))
			body.add_child(mi)
		body.add_to_group("pad")
		body.set_meta("pad_index", i)
		pads.append(body)
		# dressing round the rim, clear of the middle where you land
		var h := size.x * 0.5 - 1.2
		var props := ["rocks", "flowers", "grass", "mushrooms"]
		for j in 3:
			var ang := rng.randf() * TAU
			if i == 0:
				ang = rng.randf_range(PI * 0.15, PI * 0.85)    # start pad: behind you (+Z), out of the opening view
			var r := rng.randf_range(h * 0.75, h)
			_kit(props[rng.randi() % props.size()], top + Vector3(cos(ang) * r, 0, sin(ang) * r), 1.8, rng.randf() * TAU)
		if i == 0 or finish:
			_kit("tree-pine-small" if i == 0 else "tree", top + Vector3(-h, 0, h * 0.6), 2.6, rng.randf() * TAU)
		if finish:
			_kit("flag", top + Vector3(h * 0.5, 0, -h * 0.5), 4.0, PI * 0.5)
	par = anchors.size()
	start_pos = COURSE[0].pad + Vector3(0, 1.0, 3.0)
	start_yaw = 0.0                     # facing -Z, down the course


const BLD := "res://assets/models/kenney/buildings/%s.glb"
## Kit footprints (width x height x depth, in kit units; base at y = 0, centred).
const BLD_SIZE := {
	"building-sample-house-a": Vector3(1.095643, 1.14375, 2.0),
	"building-sample-house-b": Vector3(1.091285, 1.98125, 2.2),
	"building-sample-house-c": Vector3(2.0, 1.98125, 2.2),
	"building-sample-tower-a": Vector3(1.1, 2.5, 1.25),
	"building-sample-tower-b": Vector3(1.1, 1.8875, 1.25),
}
const BLD_SCALE := 9.0             # kit units to metres: grand, two-storey-plus houses, doors about 3 m

var buildings: Array = []


## A Modular Buildings house: solid (you can stand on it) but not grapple-able.
## Returns the body; its "roof" meta is the top-centre point (for a roof anchor).
func _building(model: String, pos: Vector3, yaw_deg: float) -> StaticBody3D:
	var sz: Vector3 = BLD_SIZE[model] * BLD_SCALE
	var body := StaticBody3D.new()
	body.collision_layer = Player.LAYER_LAND
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = yaw_deg
	var shape := BoxShape3D.new()
	shape.size = sz
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = sz.y * 0.5
	body.add_child(col)
	add_child(body)
	var sc = load(BLD % model)
	if sc:
		var n: Node3D = sc.instantiate()
		n.scale = Vector3.ONE * BLD_SCALE
		body.add_child(n)
		_tone_kit(n)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.position.y = sz.y * 0.5
		mi.material_override = Mats.lit(Color(0.8, 0.7, 0.55))
		body.add_child(mi)
	body.set_meta("roof", pos + Vector3(0, sz.y, 0))
	buildings.append(body)
	return body


func _anchor(at: Vector3) -> Node3D:
	var a := SwingAnchor.new()
	a.position = at
	add_child(a)
	anchors.append(a)
	return a


## A flat strip of road laid on the grass (looks only).
func _road(from: Vector3, to: Vector3, width: float) -> void:
	var d := to - from
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.06, d.length())
	mi.mesh = bm
	mi.material_override = _road_mat
	mi.position = (from + to) * 0.5 + Vector3(0, 0.03, 0)
	mi.rotation.y = atan2(d.x, d.z)
	add_child(mi)


var _road_mat: StandardMaterial3D


## Hamlet: a floating island (about 130 m across) with a village square and well,
## a lane east to west, a road north to the chapel, six houses and the inn.
## North is -Z. Everything you can stand on is LAND (not grapple-able); the
## anchors on rooftops, the bell tower, the square's signpost and a tall tree
## are the only grapple points. A house in the north-east burnt from the inside.
func _build_hamlet() -> void:
	var isl = _island(Vector3.ZERO, 64.0, 1871)
	isl.collision_layer = Player.LAYER_LAND       # the ground can't be grappled here

	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.48, 0.40, 0.31)
	_road_mat.roughness = 1.0
	_road(Vector3(0, 0, 58), Vector3(0, 0, 10), 7.0)           # south road, arrival to the square
	_road(Vector3(0, 0, -10), Vector3(0, 0, -36), 7.0)         # north road to the chapel
	_road(Vector3(-54, 0, 0), Vector3(-10, 0, 0), 5.5)         # west lane
	_road(Vector3(10, 0, 0), Vector3(54, 0, 0), 5.5)           # east lane
	# the square: a round paved patch
	var sq := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 12.0
	cm.bottom_radius = 12.0
	cm.height = 0.06
	cm.radial_segments = 32
	sq.mesh = cm
	sq.material_override = _road_mat
	sq.position.y = 0.035
	add_child(sq)

	# the well, in the middle of the square
	var well := StaticBody3D.new()
	well.collision_layer = Player.LAYER_LAND
	well.position = Vector3(0, 0, 2)
	var ws := CylinderShape3D.new()
	ws.radius = 1.5
	ws.height = 1.1
	var wc := CollisionShape3D.new()
	wc.shape = ws
	wc.position.y = 0.55
	well.add_child(wc)
	var wm := MeshInstance3D.new()
	var wcm := CylinderMesh.new()
	wcm.top_radius = 1.5
	wcm.bottom_radius = 1.6
	wcm.height = 1.1
	wm.mesh = wcm
	wm.position.y = 0.55
	wm.material_override = Mats.lit(Color(0.55, 0.55, 0.53))
	well.add_child(wm)
	var water := MeshInstance3D.new()
	water.mesh = _disc(1.15)
	water.position.y = 1.0
	water.material_override = Mats.lit(Color(0.18, 0.3, 0.45))
	well.add_child(water)
	add_child(well)

	# buildings: the kit puts each door on the model's +X side, so the yaw below
	# turns that side to face the road (-90 = door south, 90 = north, 0 = east, 180 = west)
	var chapel := _building("building-sample-tower-a", Vector3(0, 0, -46), -90.0)
	var h1 := _building("building-sample-house-b", Vector3(-30, 0, -14), -90.0)
	var crime := _building("building-sample-house-c", Vector3(30, 0, -19), -90.0)
	var h3 := _building("building-sample-house-a", Vector3(-42, 0, 14), 90.0)
	var inn := _building("building-sample-tower-b", Vector3(44, 0, 15), 90.0)
	var h4 := _building("building-sample-house-b", Vector3(-17, 0, 30), 0.0)
	var smithy := _building("building-sample-house-a", Vector3(17, 0, 30), 180.0)
	crime.add_to_group("crime_scene")
	inn.set_meta("name", "inn")
	smithy.set_meta("name", "smithy")

	# grapple anchors: one above each roof, the bell tower, the signpost, a tall tree
	for b in [chapel, h1, crime, h3, inn, h4, smithy]:
		_anchor(b.get_meta("roof") + Vector3(0, 2.5, 0))
	var post := _box(Vector3(0.35, 11.0, 0.35), Vector3(6, 5.5, -12), Mats.lit(Color(0.42, 0.3, 0.2)))
	post.collision_layer = Player.LAYER_LAND
	_kit("sign", Vector3(6, 2.2, -11.8), 2.5, 0.0)
	_anchor(Vector3(6, 12.0, -12))      # signpost: also the link up to the bell tower
	_kit("tree", Vector3(-40, 0, 44), 9.0, 0.6)
	_anchor(Vector3(-37, 15.0, 44))

	# trees, barrels and fences for life
	for t in [[-56, -6], [52, -32], [48, 40], [-12, -52], [14, -54], [-52, 32], [56, 2]]:
		_kit("tree-pine" if (t[0] + t[1]) % 2 == 0 else "tree", Vector3(t[0], 0, t[1]), 4.0, t[0] * 0.1)
	for b in [[40, 8], [41, 9.5], [9, 22], [-9, 24]]:
		_kit("barrel", Vector3(b[0], 0, b[1]), 2.4, b[1])
	for i in 6:
		_kit("fence-low-straight", Vector3(22 + i * 3.0, 0, -38), 3.0, 0.0)     # the burnt house's back yard
		_kit("fence-low-straight", Vector3(22 + i * 3.0, 0, -6.0), 3.0, 0.0)

	# people
	var keeper := Npc.new()
	keeper.npc_id = "hamlet_innkeeper"
	keeper.display_name = "Innkeeper"
	keeper.position = Vector3(38, 0, 5)
	add_child(keeper)
	keeper.look_at(Vector3(0, 0, 4), Vector3.UP, true)
	var neighbour := Npc.new()
	neighbour.npc_id = "hamlet_neighbour"
	neighbour.display_name = "Neighbour"
	neighbour.position = Vector3(-5, 0, 6)
	add_child(neighbour)
	neighbour.look_at(Vector3(0, 0, 30), Vector3.UP, true)

	# the crime: fire, from the inside
	var char_mat := Mats.lit(Color(0.12, 0.10, 0.09))
	var wood := Mats.lit(Color(0.55, 0.40, 0.25))
	var door := _evidence("ev_hamlet_door", "fire", "A door scorched from inside",
		"The front door of the Harrow house is blackened on its inner face only. The outside paint isn't even blistered.", Vector3(26, 0, -8.5))
	door.part(Vector3(1.2, 2.2, 0.15), Vector3(0, 1.1, 0), wood)
	door.part(Vector3(1.0, 1.6, 0.02), Vector3(0, 1.1, -0.09), char_mat, Vector3.ZERO, false)
	var latch := _evidence("ev_hamlet_latch", "fire", "A latch melted shut",
		"The back gate's iron latch has run like wax and set again. Iron needs a forge to do that; there's no soot on the gate.", Vector3(34, 0, -37.5))
	latch.part(Vector3(0.25, 1.1, 0.25), Vector3(0, 0.55, 0), Mats.lit(Color(0.3, 0.3, 0.32)))
	latch.part(Vector3(0.35, 0.18, 0.35), Vector3(0, 0.9, 0), _glow(Color(1.0, 0.45, 0.15), 0.5), Vector3.ZERO, false)
	var ring := _evidence("ev_hamlet_ring", "fire", "A circle of ash in the yard",
		"In the back yard, a perfect ring of fine white ash on bare earth. Nothing was burnt there; there's nothing for the ash to have come from.", Vector3(28, 0, -33))
	var ash: MeshInstance3D = ring.part(Vector3(1.6, 0.02, 1.6), Vector3(0, 0.03, 0), Mats.lit(Color(0.85, 0.84, 0.8)), Vector3.ZERO, false)
	ash.mesh = _disc(0.8)

	start_pos = Vector3(0, 1.0, 54)
	start_yaw = 0.0                     # facing north, up the road into the hamlet


const FK := "res://assets/models/kenney/fantasy/%s.glb"
const STOREY := 3.5                # Retro Fantasy Kit modules are 1-unit cubes: one storey each
const STOREYS := 5
const CITY_R := 54.0               # buildings stop here; the ring promenade runs outside it

## The street plan (metres, north = -Z). Axis-aligned strips: [x0, z0, x1, z1].
const CITY_STREETS := [
	[-5, -60, 5, 60], [-60, -5, 60, 5],                         # the two boulevards, 10 m
	[-35, -60, -29, 60], [29, -60, 35, 60],                     # streets, 6 m
	[-60, -35, 60, -29], [-60, 29, 60, 35],
	[-45.5, -60, -42.5, 60], [42.5, -60, 45.5, 60],             # narrow streets, 3 m
	[-60, -45.5, 60, -42.5], [-60, 42.5, 60, 45.5],
	[-60, -17.25, -10, -14.75], [10, 14.75, 60, 17.25],         # alleys, 2.5 m
	[-17.25, -60, -14.75, -10], [14.75, 10, 17.25, 60],
	[-60, 14.75, -10, 17.25], [10, -17.25, 60, -14.75],
]
const CITY_DIAGONALS := [[Vector2(-47.5, 45), Vector2(-22.5, 20)], [Vector2(22.5, -20), Vector2(47.5, -45)]]
const PLAZA_R := 15.5

var city_cells := 0                # how many building footprints were laid (tests read it)


## Is this ground point open (street, alley, plaza, or outside the built-up area)?
func _city_open(x: float, z: float) -> bool:
	if Vector2(x, z).length() > CITY_R or Vector2(x, z).length() < PLAZA_R:
		return true
	for r in CITY_STREETS:
		if x > r[0] and x < r[2] and z > r[1] and z < r[3]:
			return true
	for d in CITY_DIAGONALS:
		var a: Vector2 = d[0]
		var b: Vector2 = d[1]
		var p := Vector2(x, z)
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if p.distance_to(a + (b - a) * t) < 1.4:
			return true
	return false


## City: a 130 m island paved in cobbles, packed with five-storey terraces built
## from Retro Fantasy Kit wall blocks (drawn in bulk: one MultiMesh per block
## type, one collision box per run of terrace). Tree-lined boulevards cross at a
## fountain plaza; streets, narrow streets and alleys cut the blocks; a ring
## promenade runs round the edge. Grapple anchors hang over the crossroads.
func _build_city() -> void:
	var isl := FloatingIsland.new()
	isl.radius = 64.0
	isl.island_seed = 77
	isl.wobble = 0.03
	isl.grass = false
	add_child(isl)
	islands.append(isl)
	isl.collision_layer = Player.LAYER_LAND
	var cob := StandardMaterial3D.new()
	cob.albedo_texture = load("res://assets/models/kenney/fantasy/Textures/cobblestone.png")
	cob.albedo_color = Color(0.82, 0.8, 0.76)
	cob.uv1_triplanar = true
	cob.uv1_world_triplanar = true
	cob.uv1_scale = Vector3.ONE * 0.4
	cob.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	cob.roughness = 1.0
	isl.top_mesh.material_override = cob

	# lay out the terraces block by block: each block (the land between two streets
	# each way) gets its own grid of cells sized to fill it exactly, wall to wall
	const BANDS := [[-54.0, -45.5], [-42.5, -35.0], [-29.0, -5.0], [5.0, 29.0], [35.0, 42.5], [45.5, 54.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1871
	var xf := {}                     # block model name -> Array[Transform3D]
	var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var h := STOREYS * STOREY + STOREY * 0.5
	city_cells = 0
	for bx in BANDS:
		for bz in BANDS:
			var w: float = bx[1] - bx[0]
			var d: float = bz[1] - bz[0]
			var nx := maxi(1, roundi(w / STOREY))
			var nz := maxi(1, roundi(d / STOREY))
			var cw := w / nx
			var cd := d / nz
			var built := {}
			for i in nx:
				for j in nz:
					var cx: float = bx[0] + (i + 0.5) * cw
					var cz: float = bz[0] + (j + 0.5) * cd
					var ok := true
					for o in [Vector2.ZERO, Vector2(0.4, 0.4), Vector2(-0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, -0.4)]:
						if _city_open(cx + o.x * cw, cz + o.y * cd):
							ok = false
							break
					if ok:
						built[Vector2i(i, j)] = Vector3(cx, 0, cz)
			city_cells += built.size()
			for c in built:
				var cell: Vector2i = c
				var pos: Vector3 = built[c]
				# which side faces the street? (the kit puts windows and doors on -Z)
				var face := Vector2i.ZERO
				for dd in dirs:
					if not built.has(cell + dd):
						face = dd
						break
				var yaw := atan2(-float(face.x), -float(face.y)) if face != Vector2i.ZERO else 0.0
				var local := Vector3(cw, STOREY, cd) if face.x == 0 else Vector3(cd, STOREY, cw)
				var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(local)
				var painted := (hash(Vector2i(floori(pos.x / 10.0), floori(pos.z / 10.0))) % 3) == 0
				for f in STOREYS:
					var block := "wall"
					if face != Vector2i.ZERO:
						var r := rng.randf()
						if f == 0:
							block = "wall-door" if r < 0.35 else ("wall-window" if r < 0.8 else "wall")
						else:
							block = ("wall-paint-window" if painted else "wall-window") if r < 0.75 else ("wall-paint" if painted else "wall-detail")
					elif f < STOREYS - 1:
						continue                     # hidden inside a block: only the top storey shows
					if not xf.has(block):
						xf[block] = []
					xf[block].append(Transform3D(basis, pos + Vector3(0, f * STOREY, 0)))
				if not xf.has("roof"):
					xf["roof"] = []
				xf["roof"].append(Transform3D(basis, pos + Vector3(0, STOREYS * STOREY, 0)))
			# collision: one box per east-west run of cells in this block
			for j in nz:
				var i := 0
				while i < nx:
					if not built.has(Vector2i(i, j)):
						i += 1
						continue
					var i0 := i
					while built.has(Vector2i(i, j)):
						i += 1
					var body := StaticBody3D.new()
					body.collision_layer = Player.LAYER_LAND
					body.collision_mask = 0
					body.position = Vector3(bx[0] + (i0 + i) * 0.5 * cw, h * 0.5, bz[0] + (j + 0.5) * cd)
					var bs := BoxShape3D.new()
					bs.size = Vector3((i - i0) * cw, h, cd)
					var col := CollisionShape3D.new()
					col.shape = bs
					body.add_child(col)
					add_child(body)
					buildings.append(body)
	for block in xf:
		_multimesh(FK % block, xf[block])

	# the fountain
	var basin := StaticBody3D.new()
	basin.collision_layer = Player.LAYER_LAND
	var bcs := CylinderShape3D.new()
	bcs.radius = 4.0
	bcs.height = 0.9
	var bcol := CollisionShape3D.new()
	bcol.shape = bcs
	bcol.position.y = 0.45
	basin.add_child(bcol)
	var bm := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 4.0
	bcm.bottom_radius = 4.2
	bcm.height = 0.9
	bcm.radial_segments = 24
	bm.mesh = bcm
	bm.position.y = 0.45
	bm.material_override = Mats.lit(Color(0.62, 0.6, 0.56))
	basin.add_child(bm)
	var wat := MeshInstance3D.new()
	wat.mesh = _disc(3.6)
	wat.position.y = 0.8
	wat.material_override = Mats.lit(Color(0.2, 0.38, 0.55))
	basin.add_child(wat)
	var spout := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.35
	sm.bottom_radius = 0.6
	sm.height = 2.6
	spout.mesh = sm
	spout.position.y = 1.3
	spout.material_override = Mats.lit(Color(0.62, 0.6, 0.56))
	basin.add_child(spout)
	add_child(basin)

	# street trees (about two storeys, well under the anchors)
	var trees: Array = []
	for z in [-50.0, -42.0, -26.0, -20.0, 20.0, 26.0, 40.0, 50.0]:
		trees.append(Vector3(-3.6, 0, z))
		trees.append(Vector3(3.6, 0, z))
		trees.append(Vector3(z, 0, -3.6))
		trees.append(Vector3(z, 0, 3.6))
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		trees.append(Vector3(cos(a), 0, sin(a)) * 11.0)
	for p in [Vector2(-32, -26), Vector2(32, -26), Vector2(-32, 26), Vector2(32, 26), Vector2(-26, -32), Vector2(26, -32), Vector2(-26, 32), Vector2(26, 32)]:
		trees.append(Vector3(p.x, 0, p.y))
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.3:
			continue                       # keep the south gate clear
		trees.append(Vector3(cos(a), 0, sin(a)) * 59.0)
	var tx: Array = []
	for t in trees:
		var tp: Vector3 = t
		tx.append(Transform3D(Basis(Vector3.UP, tp.x * 0.37 + tp.z).scaled(Vector3.ONE * rng.randf_range(3.6, 4.4)), tp))
	_multimesh(FK % "tree-large", tx)

	# grapple anchors over the crossroads, above the rooftops
	for p in [Vector2(-32, -32), Vector2(0, -32), Vector2(32, -32), Vector2(-32, 0), Vector2(32, 0),
			Vector2(-32, 32), Vector2(0, 32), Vector2(32, 32), Vector2(0, -52), Vector2(0, 52), Vector2(-52, 0), Vector2(52, 0)]:
		_anchor(Vector3(p.x, STOREYS * STOREY + 7.5, p.y))

	start_pos = Vector3(0, 1.0, 58)
	start_yaw = 0.0                     # through the south gate, facing up the boulevard


## Many copies of one Kenney model in a single draw call per surface.
func _multimesh(path: String, transforms: Array) -> MultiMeshInstance3D:
	var mesh := KenneyMesh.get_mesh(path)
	if mesh == null or transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	return mi


## Touched down: landing pads are checkpoints; the last one finishes the course.
func _on_landed(body: Node) -> void:
	if body == null or not body.has_meta("pad_index"):
		return
	var i: int = body.get_meta("pad_index")
	if i > checkpoint:
		checkpoint = i
		var top: Vector3 = COURSE[i].pad
		player.spawn = Transform3D(Basis(Vector3.UP, 0.0), top + Vector3(0, 1.0, 0))
		if i < pads.size() - 1:
			hud.toast("Pad %d of %d" % [i, pads.size() - 1], 1.5)
	if i == pads.size() - 1 and not finished:
		finished = true
		var rating := "PAR!" if player.swings <= par else "par is %d" % par
		hud.toast("Course complete: %d swings, %d falls  ·  %s" % [player.swings, falls, rating], 6.0)


## The Platform Test's running tally (read by the HUD each frame).
func course_text() -> String:
	if pads.is_empty():
		return ""
	return "SWINGS %d  ·  PAR %d      PAD %d / %d      FALLS %d" % [player.swings, par, checkpoint, pads.size() - 1, falls]


func _island(pos: Vector3, r: float, seed_: int) -> Node3D:
	var isl := FloatingIsland.new()
	isl.radius = r
	isl.island_seed = seed_
	isl.position = pos
	add_child(isl)
	islands.append(isl)
	return isl


## Start near the edge of `from`, facing `to`.
func _start_on(from: Node3D, to: Node3D) -> void:
	var d := (to.position - from.position)
	d.y = 0
	d = d.normalized()
	start_pos = from.position + d * (from.radius * 0.55) + Vector3(0, 1.0, 0)
	start_yaw = atan2(-d.x, -d.z)


## The test range: flat plane, one floating cube, an NPC and four clues.
func _build_range() -> void:
	# the plane: 400 x 400 m, top surface at y = 0
	_box(Vector3(400, 1, 400), Vector3(0, -0.5, 0), Mats.grid(Color(0.46, 0.56, 0.36), Color(0.42, 0.52, 0.33)))

	# one floating cube to swing from
	var cube := _box(Vector3(6, 6, 6), Vector3(0, 18, -24), Mats.grid(Color(0.92, 0.80, 0.45), Color(0.86, 0.72, 0.38), 1))
	cube.rotation_degrees.y = 20

	# a rectangle with an NPC label
	var npc := Npc.new()
	npc.npc_id = "test_npc"
	npc.display_name = "NPC"
	npc.position = Vector3(4, 0, 7)
	add_child(npc)
	npc.look_at(Vector3(start_pos.x, 0, start_pos.z), Vector3.UP, true)

	_build_evidence()


## Four practice clues, one per school of magic, in a row near the start.
func _build_evidence() -> void:
	var char_mat := Mats.lit(Color(0.12, 0.10, 0.09))
	var wood := Mats.lit(Color(0.55, 0.40, 0.25))
	var stone := Mats.lit(Color(0.62, 0.62, 0.60))

	# fire: a stone block with a perfect circle burnt into it, still warm
	var fire := _evidence("ev_fire_circle", "fire", "A ring burnt into stone",
		"A perfectly round scorch on a stone block. Stone doesn't burn, there's no fuel or oil smell, and the char is still warm to the touch.", Vector3(-9, 0, 9))
	fire.part(Vector3(1.2, 0.9, 1.2), Vector3(0, 0.45, 0), stone)
	var ring: MeshInstance3D = fire.part(Vector3(0.8, 0.02, 0.8), Vector3(0, 0.91, 0), char_mat, Vector3.ZERO, false)
	ring.mesh = _disc(0.42)
	var ember: MeshInstance3D = fire.part(Vector3(0.3, 0.03, 0.3), Vector3(0, 0.925, 0), _glow(Color(1.0, 0.45, 0.15)), Vector3.ZERO, false)
	ember.mesh = _disc(0.16)

	# nature: a cut-timber crate putting out fresh green shoots
	var nat := _evidence("ev_nature_crate", "nature", "A crate that has sprouted",
		"A shipping crate of cut, dried timber with green shoots and buds growing from its planks. Cut wood doesn't grow back.", Vector3(-3, 0, 9))
	nat.part(Vector3(1.1, 0.9, 1.1), Vector3(0, 0.45, 0), wood)
	var leaf := Mats.lit(Color(0.30, 0.62, 0.28))
	for i in 7:
		var a := i * 0.9
		nat.part(Vector3(0.06, 0.5 + (i % 3) * 0.2, 0.06), Vector3(cos(a) * 0.4, 1.1, sin(a) * 0.4), leaf, Vector3(sin(a) * 0.4, 0, cos(a) * 0.4), false)

	# ice: a post rimed with frost radiating from one point, on a warm day
	var ice := _evidence("ev_ice_post", "ice", "Frost on a summer post",
		"A wooden post coated in rime that spreads outward from one point like a star. It's a warm day, and nothing else nearby is cold.", Vector3(3, 0, 9))
	ice.part(Vector3(0.35, 1.8, 0.35), Vector3(0, 0.9, 0), wood)
	var frost := _glow(Color(0.75, 0.9, 1.0), 0.6)
	for i in 6:
		var a := i * TAU / 6.0
		ice.part(Vector3(0.05, 0.05, 0.6), Vector3(cos(a) * 0.2, 1.2 + sin(a) * 0.25, 0.2), frost, Vector3(0, 0, a), false)
	ice.part(Vector3(0.42, 0.25, 0.42), Vector3(0, 1.2, 0), frost, Vector3.ZERO, false)

	# water: a crate soaked to a tide line, with a puddle sitting on its lid
	var water := _evidence("ev_water_tideline", "water", "A tide line on a dry crate",
		"A crate with a level band of water staining around its sides and a puddle sitting on its lid, though the ground around it is bone dry.", Vector3(9, 0, 9))
	water.part(Vector3(1.1, 0.9, 1.1), Vector3(0, 0.45, 0), wood)
	water.part(Vector3(1.12, 0.06, 1.12), Vector3(0, 0.62, 0), Mats.lit(Color(0.32, 0.25, 0.18)), Vector3.ZERO, false)
	var pool: MeshInstance3D = water.part(Vector3(0.7, 0.02, 0.7), Vector3(0, 0.91, 0), _glow(Color(0.25, 0.45, 0.85), 0.35), Vector3.ZERO, false)
	pool.mesh = _disc(0.35)


func _evidence(id: String, school: String, title: String, note: String, pos: Vector3) -> Node:
	var ev := Evidence.new()
	ev.evidence_id = id
	ev.school = school
	ev.title = title
	ev.note = note
	ev.position = pos
	add_child(ev)
	return ev


func _disc(r: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.02
	m.radial_segments = 24
	return m


func _glow(c: Color, energy := 1.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Player.LAYER_WORLD
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	return body


# ---------------------------------------------------------------- dialogue
func _talk(npc: Node) -> void:
	if not Game.playing():
		return
	if npc.is_in_group("evidence"):
		_examine(npc)
		return
	_talking_to = npc
	player.halt()
	Game.set_ui_mode("dialogue")
	panel.open(DialogueDB.load_tree(npc.npc_id, npc.display_name))


func _examine(ev: Node) -> void:
	if ev.examine():
		hud.toast("Logged: %s.  Press L to open your logbook." % ev.title)
	else:
		hud.toast("Already in your logbook: %s" % ev.title, 2.0)


func open_logbook(page := "") -> void:
	if Game.ui_mode != "play":
		return
	Game.set_ui_mode("log")
	logbook.open(page)


func _play_test(data: Dictionary) -> void:
	editor.visible = false
	_talking_to = null
	Game.set_ui_mode("dialogue")
	panel.open(data)
	panel.set_meta("from_editor", true)


func _on_dialogue_closed() -> void:
	if panel.has_meta("from_editor"):
		panel.remove_meta("from_editor")
		open_editor()
		return
	_talking_to = null
	Game.set_ui_mode("play")


# ---------------------------------------------------------------- editor
func open_editor() -> void:
	var npcs := []
	for n in get_tree().get_nodes_in_group("npc"):
		npcs.append({"id": n.npc_id, "name": n.display_name})
	Game.set_ui_mode("editor")
	editor.open(npcs, editor.npc_id)


func close_editor() -> void:
	editor.visible = false
	Game.set_ui_mode("play")


# ---------------------------------------------------------------- menus
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("logbook") and Game.playing():
		open_logbook()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_editor"):
		if Game.ui_mode == "editor":
			close_editor()
		elif Game.ui_mode != "dialogue":
			open_editor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		match Game.ui_mode:
			"play":
				_set_paused(true)
			"pause":
				_set_paused(false)
			"editor":
				close_editor()
		get_viewport().set_input_as_handled()
	elif Game.playing() and event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# browsers only grant mouse capture on a click
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _set_paused(on: bool) -> void:
	Game.set_ui_mode("pause" if on else "play")


func _process(_dt: float) -> void:
	# In a browser, Esc releases the mouse before the game sees the key: treat that as pause.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if OS.has_feature("web") and Game.playing() and _had_capture and not captured:
		_set_paused(true)
	_had_capture = captured and Game.playing()
