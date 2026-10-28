extends Node
## Smoke tests. Run:  godot --headless res://tests/test_runner.tscn
## With a display (no --headless) it also saves screenshots to user://shots/.

var fails := 0
var range_scene: Node


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	await get_tree().process_frame
	print("== DialogueDB")
	var t := DialogueDB.load_tree("test_npc", "NPC")
	check(t.start == "start", "test tree starts at 'start'")
	check(t.nodes.start.text == "test test test", "opening line is 'test test test'")
	check(t.nodes.start.choices.size() == 4, "start offers A, B, C and Leave")
	check(t.nodes.a.choices[0].next == "b" and t.nodes.b.choices[0].next == "a", "A and B loop to each other")

	print("== Test range")
	range_scene = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(range_scene)
	for i in 60:
		await get_tree().physics_frame
	var p = range_scene.player
	check(p.is_on_floor(), "player stands on the plane")
	await shot("01_spawn")
	print("== Skies")
	for id in range_scene.SKIES:
		range_scene.set_sky(id)
		check(range_scene.env.sky.sky_material is PanoramaSkyMaterial and range_scene.env.sky.sky_material.panorama != null, "%s sky loads" % id)
		await shot("sky_" + id)
	range_scene.set_sky("day")
	print("== Sun glare")
	var g = range_scene.glare
	p.global_position = Vector3(0, 1, 30)
	p.look_at(p.global_position + Vector3(g.sun_dir.x, 0, g.sun_dir.z), Vector3.UP)
	p.rotation = Vector3(0, p.rotation.y, 0)
	p.head.rotation.x = asin(clampf(g.sun_dir.y, -1, 1))
	for i in 40:
		await get_tree().process_frame
	check(g._vis > 0.6, "glare shows when looking at the sun (%.2f)" % g._vis)
	await shot("09_sun_glare")
	p.head.rotation.x = -0.6
	for i in 40:
		await get_tree().process_frame
	check(g._vis < 0.1, "glare fades when looking away (%.2f)" % g._vis)
	p.head.rotation.x = 0.0

	print("== Grapple")
	p.global_position = Vector3(0, 1, -10)
	p.rotation = Vector3.ZERO
	p.head.rotation.x = deg_to_rad(40)   # look up at the cube
	for i in 6:
		await get_tree().physics_frame
		await get_tree().process_frame
	check(p.aim_valid, "crosshair finds the cube")
	p.try_grapple()
	for i in 60:
		await get_tree().physics_frame
	check(p.attached, "hook flew and attached")
	var y0: float = p.global_position.y
	for i in 120:
		Input.action_press("jump")
		await get_tree().physics_frame
	Input.action_release("jump")
	check(p.global_position.y > y0 + 3.0, "reeling in lifts the player (%.1f -> %.1f)" % [y0, p.global_position.y])
	check(p.global_position.distance_to(p.anchor) <= p.rope_len + 0.6, "rope constraint holds")
	await shot("02_hooked")
	p.release()
	check(not p.attached, "release lets go")
	for i in 240:
		await get_tree().physics_frame
	check(p.hook_state == 0, "chain wound back up")

	print("== Dialogue")
	p.global_position = Vector3(4, 1, 10)
	for i in 30:
		await get_tree().physics_frame
	var npc = get_tree().get_nodes_in_group("npc")[0]
	range_scene._talk(npc)
	var panel = range_scene.panel
	check(panel.visible and Game.ui_mode == "dialogue", "talking opens the panel")
	check(panel._choice_buttons.size() == 4, "4 choices shown")
	await shot("03_dialogue")
	panel._pick(0)
	check(panel.current == "a", "option A -> line a")
	panel._pick(1)
	check(panel.current == "c", "from A, option C -> line c")
	panel._pick(0)
	check(panel.current == "a", "from C, option A loops back to a")
	panel._pick(2)
	check(panel.current == "start", "back to the start")
	await shot("04_dialogue_log")
	panel._pick(3)
	check(not panel.visible and Game.ui_mode == "play", "[Leave] closes and returns control")

	print("== Logbook")
	check(Logbook.schools.size() == 4, "field guide has fire, nature, ice and water")
	check(Logbook.schools.all(func(sc): return sc.evidence.size() >= 5 and sc.mistaken_for != ""), "every school lists 5+ signs and a common misreading")
	var evs := get_tree().get_nodes_in_group("evidence")
	check(evs.size() == 4, "four practice clues in the range")
	var ev = evs[0]
	p.global_position = ev.global_position + Vector3(0, 1.0, 2.6)
	p.look_at(ev.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	p.rotation = Vector3(0, p.rotation.y, 0)
	p.head.rotation.x = deg_to_rad(-22)
	for i in 6:
		await get_tree().physics_frame
		await get_tree().process_frame
	check(p.look_npc == ev, "crosshair picks up the clue")
	range_scene._talk(ev)
	check(Logbook.has_evidence(ev.evidence_id), "examining logs the clue")
	check(not ev.examine(), "examining twice doesn't duplicate it")
	await shot("06_examine")
	range_scene.open_logbook("fire")
	await get_tree().process_frame
	check(range_scene.logbook.visible and Game.ui_mode == "log" and get_tree().paused, "L opens the logbook and pauses the game")
	await shot("07_logbook_fire")
	range_scene.logbook.show_page("evidence")
	await shot("08_logbook_evidence")
	range_scene.logbook.close()
	check(Game.ui_mode == "play" and not get_tree().paused, "closing the logbook resumes play")

	print("== Editor")
	range_scene.open_editor()
	var ed = range_scene.editor
	await get_tree().process_frame
	check(ed.visible and ed.npc_id == "test_npc", "editor opens on the NPC")
	var before: int = ed.data.nodes.size()
	ed._add_line_at_center()
	var new_id := ""
	for k in ed.data.nodes:
		if str(k).begins_with("line_"):
			new_id = k
	check(ed.data.nodes.size() == before + 1 and new_id != "", "+ Line adds a box")
	ed.data.nodes[new_id].text = "a brand new line"
	ed._on_connect("c", 1, new_id, 0)
	check(ed.data.nodes.c.choices[1].next == new_id, "linking a choice sets its target")
	await get_tree().process_frame
	ed._frame_all()
	await shot("05_editor")
	var path := ProjectSettings.globalize_path("res://dialogue/test_npc.json") if OS.has_feature("editor") \
		else ProjectSettings.globalize_path("user://dialogue/test_npc.json")
	var shipped := FileAccess.get_file_as_string("res://dialogue/test_npc.json")
	ed.save()
	var saved := DialogueDB.load_tree("test_npc")
	check(saved.nodes.has(new_id) and saved.nodes.c.choices[1].next == new_id, "save + reload keeps the new line and link")
	ed._delete_nodes([new_id])
	check(ed.data.nodes.c.choices[1].next == "", "deleting a box clears links to it")
	# put the shipped file back exactly as it was
	if OS.has_feature("editor"):
		var f := FileAccess.open("res://dialogue/test_npc.json", FileAccess.WRITE)
		f.store_string(shipped)
		f.close()
	ed._revert()
	check(not DialogueDB.load_tree("test_npc").nodes.has(new_id), "revert drops the test line")
	ed._add_line_at_center()
	ed._revert()
	check(ed.data.nodes.size() == before, "revert discards unsaved edits")
	range_scene.close_editor()

	print("== Level select")
	range_scene.queue_free()
	await get_tree().process_frame
	var menu = load("res://scenes/level_select.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	check(menu._buttons.size() == Levels.LIST.size(), "menu lists every level")
	await shot("10_level_select")
	menu.queue_free()
	await get_tree().process_frame

	for lv in ["level_1", "level_2"]:
		print("== " + lv)
		Game.level = lv
		var w = load("res://scenes/world.tscn").instantiate()
		get_tree().root.add_child(w)
		for i in 60:
			await get_tree().physics_frame
		check(w.islands.size() == 2, "%s has two islands" % lv)
		check(w.player.is_on_floor(), "%s: player starts standing on an island" % lv)
		var far = w.islands[1]
		var space = w.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(w.player.cam.global_position, far.global_position + Vector3(0, -2, 0))
		q.exclude = [w.player.get_rid()]
		var hit = space.intersect_ray(q)
		check(not hit.is_empty() and hit.collider == far, "%s: the far island is solid and grapple-able" % lv)
		await shot("11_" + lv)
		w.player.head.rotation.x = deg_to_rad(-35)
		await shot("12_" + lv + "_down")
		w.queue_free()
		await get_tree().process_frame
	print("== Enemy test (ground)")
	Game.level = "enemy_test"
	var ew = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(ew)
	for i in 30:
		await get_tree().physics_frame
	var ep = ew.player
	ep.invuln = 999.0
	var s = ew.sentries[0]
	check(ew.sentries.size() == 1 and s.kind == "ground" and s.title == "wizard", "one ground Sentry, a wizard on a broom")
	ep.global_position = s.global_position + Vector3(0, 0, 60)
	for i in 240:
		await get_tree().physics_frame
	check(ew.bullets.count() == 0 and not s.engaged, "out of range: it holds fire")
	ep.global_position = s.global_position + Vector3(0, -1, 25)
	for i in 420:
		await get_tree().physics_frame
	var n: int = ew.bullets.count()
	check(s.engaged and n > 0 and n <= 15, "in range: it fires a few large orbs (%d in the air)" % n)
	var flat := true
	for v in ew.bullets._vel:
		flat = flat and absf(v.y) < 0.001
	check(flat, "its orbs fly level, parallel to the ground")
	_aim(ep, s.global_position)
	await shot("13_enemy_ground")
	ep.global_position = s.global_position + Vector3(4, -0.2, -5.5)
	_aim(ep, s.global_position + Vector3(0, 0.8, 0))
	await shot("16_wizard_close")
	ep.invuln = 0.0
	ep.global_position = s.global_position + Vector3(0, 6, 12)
	ep.attached = true
	ep.hook_node = null
	ep.velocity = Vector3(12, 3, 0)
	ep.hit(Vector3.FORWARD)
	check(ep.stunned > 2.9 and not ep.attached, "a hit stuns: the chain drops")
	check(absf(ep.velocity.x) < 2.0 and ep.velocity.y <= 0.0, "stunned, you drop straight down")
	ep.try_grapple()
	check(ep.hook_state == 0 or ep.hook_state == 3, "no grappling while stunned")
	for i in int(3.2 * 120):
		await get_tree().physics_frame
	check(ep.stunned == 0.0, "control returns after 3 seconds")
	ep.invuln = 999.0

	ep.global_position = s.global_position + Vector3(30, 0, 0)
	check(not s.on_hooked(ep), "hooking from too far: it shakes the chain off")
	ep.global_position = s.global_position + Vector3(8, -1, 0)
	check(s.on_hooked(ep), "hooking from close range holds")
	ep.attached = true
	ep.hook_node = s
	ep.rope_len = 8.0
	ep.velocity = Vector3(0, 0, 25)
	var c: Vector3 = s.global_position
	var rope_before: float = ep.rope_len
	for k in 3 * 24 + 6:
		var a2 := TAU * k / 24.0
		s._track_wrap(c + Vector3(cos(a2) * 8.0, -1.0, sin(a2) * 8.0))
		if k == 30:
			check(is_equal_approx(ep.rope_len, rope_before), "wrapping no longer reels you in")
		if s.is_subdued:
			break
	check(s.is_subdued, "three laps around it subdue the Sentry")
	check(not ep.attached, "the chain snaps once it's bound")
	check(ep.velocity.length() <= 9.01, "your speed is capped when the chain snaps (%.1f m/s)" % ep.velocity.length())
	check(Engine.time_scale < 1.0, "a moment of slow motion marks the snap")
	check(get_tree().get_nodes_in_group("enemy").size() >= 1 and ew.get_children().any(func(x): return x.get_script() == preload("res://scripts/combat/magic_burst.gd")), "a purple magic burst goes off")
	ep.global_position = s.global_position + Vector3(0, 0.5, 9)
	_aim(ep, s.global_position)
	await shot("14_snap")
	for i in 90:
		await get_tree().process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "time returns to normal")
	ew.queue_free()
	await get_tree().process_frame

	print("== Enemy test (air): the witch's tree")
	Game.level = "enemy_test_air"
	var aw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(aw)
	for i in 30:
		await get_tree().physics_frame
	var ap = aw.player
	var witch = aw.sentries[0]
	var tr = aw.tree
	var wd = aw.ward
	check(aw.sentries.size() == 1 and witch.kind == "air" and witch.title == "witch", "one witch")
	check(tr.red_count() == 80 and tr.blue_orbs().size() == 10, "her tree: 80 red orbs, 10 blue")
	var b0: Vector3 = tr.blue_orbs()[0].global_position
	for i in 60:
		await get_tree().physics_frame
	check(tr.blue_orbs()[0].global_position.distance_to(b0) > 0.05, "the tree slowly turns")
	check(wd.is_inside(witch.global_position), "the witch hovers inside her ward")

	# free magic grapples vs limited ordinary ones
	ap.invuln = 999.0
	var blue = tr.blue_orbs()[3]
	ap.global_position = blue.global_position + Vector3(0, -4, 6)
	_aim(ap, blue.global_position)
	ap.air_left = 0
	await get_tree().physics_frame
	ap.try_grapple()
	check(ap.hook_state == 1, "out of air grapples, you can still hook a blue orb (magic is free)")
	for i in 30:
		await get_tree().physics_frame
	check(ap.attached and ap.hook_node == blue and blue.orbiting, "the hooked blue orb keeps riding the tree")
	ap.release()
	for i in 20:
		await get_tree().physics_frame

	# aim assist: a near miss on a blue orb still catches it
	var blue2 = tr.blue_orbs()[4]
	ap.global_position = blue2.global_position + Vector3(0, -3, 10)
	_aim(ap, blue2.global_position)
	await get_tree().physics_frame
	var aimed: Vector3 = blue2.global_position
	_aim(ap, aimed + (ap.cam.global_basis.x * 0.6))
	await get_tree().physics_frame
	var off_px: float = ap.cam.unproject_position(blue2.global_position).distance_to(ap.get_viewport().get_visible_rect().size * 0.5)
	var ft: Dictionary = ap.find_target()
	check(off_px > 4.0 and off_px < ap.reticle_px() and not ft.is_empty() and ft.collider == blue2,
		"aim assist: a blue orb %d px off-centre (inside the %d px reticle) is the target" % [roundi(off_px), roundi(ap.reticle_px())])
	await shot("17_aim_assist")
	ap.try_grapple()
	for i in 30:
		await get_tree().physics_frame
	check(ap.attached and ap.hook_node == blue2, "...and the chain catches it")
	ap.release()
	for i in 20:
		await get_tree().physics_frame
	var keep: float = ap.tune.aim_assist
	ap.tune.aim_assist = 0.0
	check(ap.find_target().is_empty() or ap.find_target().collider != blue2, "with the reticle at 0, the same near miss misses")
	ap.tune.aim_assist = keep

	# aim assist on surfaces: dead centre on open sky, but the ward's edge is inside the circle
	ap.global_position = wd.global_position + Vector3(-30, 0, -30)
	var to_w: Vector3 = (wd.global_position - ap.global_position).normalized()
	var edge_ang: float = asin(wd.radius / ap.global_position.distance_to(wd.global_position))
	var dir: Vector3 = to_w.rotated(Vector3.UP, edge_ang + deg_to_rad(1.5))
	_aim(ap, ap.cam.global_position + dir * 10.0 + Vector3(0, 0, 0))
	await get_tree().physics_frame
	var centre_hit: Dictionary = ap._ray(1 | 4, ap.tune.grapple_range)
	ft = ap.find_target()
	check(centre_hit.is_empty() and not ft.is_empty() and ft.collider == wd, "aim assist: just past the ward's edge still finds the ward")

	ap.air_left = 0
	ap.global_position = Vector3(0, 6, 20)
	_aim(ap, Vector3(0, -2, 0))
	await get_tree().physics_frame
	ap.try_grapple()
	check(ap.hook_state != 1, "out of air grapples, an ordinary surface can't be hooked")

	# touching a red orb stuns
	ap.invuln = 0.0
	var red_world: Vector3 = tr.global_position + Basis(Vector3.UP, tr._angle) * tr._red_local[10]
	ap.global_position = red_world
	await get_tree().physics_frame
	check(ap.stunned > 0.0, "touching a red orb stuns you")
	ap.stunned = 0.0
	ap.invuln = 0.0

	# the ward: touching its outside stuns; the opening is safe
	var outside: Vector3 = wd.global_position + Vector3(-1, 0, 0) * (wd.radius + 0.2)
	ap.global_position = outside
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(ap.stunned > 0.0, "touching the ward's shell stuns you")
	ap.stunned = 0.0
	ap.invuln = 0.0
	var hole: Vector3 = wd.global_position + wd.open_dir.normalized() * wd.radius
	ap.global_position = hole
	await get_tree().physics_frame
	check(ap.stunned == 0.0, "the opening is safe to fly through")
	ap.global_position = wd.global_position + Vector3(4, 0, 0)
	await get_tree().physics_frame
	check(wd.is_inside(ap.global_position) and ap.stunned == 0.0, "inside the ward you're safe")

	ap.invuln = 999.0
	ap.global_position = wd.global_position + Vector3(2, -5, 17)
	_aim(ap, wd.global_position)
	await shot("16_ward")
	# wraps only count inside
	ap.invuln = 999.0
	ap.global_position = wd.global_position + Vector3(0, 0, wd.radius + 6)
	check(witch.on_hooked(ap), "you can hook her through the opening from outside")
	ap.attached = true
	ap.hook_node = witch
	var wc: Vector3 = witch.global_position
	for k in 30:
		var a3 := TAU * k / 24.0
		witch._track_wrap(wc + Vector3(cos(a3) * 14.0, 0, sin(a3) * 14.0))
	check(witch.wraps < 0.1, "laps outside the ward don't count")
	for k in 3 * 24 + 6:
		var a3 := TAU * k / 24.0
		witch._track_wrap(wc + Vector3(cos(a3) * 4.0, -1.0, sin(a3) * 4.0))
		if witch.is_subdued:
			break
	check(witch.is_subdued, "three laps inside the ward subdue her")
	await get_tree().process_frame
	check(not is_instance_valid(wd) or wd.is_queued_for_deletion(), "her ward breaks with her")
	for i in 90:
		await get_tree().process_frame
	ap.global_position = Vector3(0, 8, 40)
	_aim(ap, tr.global_position + Vector3(0, 26, 0))
	await shot("15_witch_tree")
	aw.queue_free()
	await get_tree().process_frame
	Game.level = "range"

	print("== %s" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails else 0)


func _aim(pl: Node, target: Vector3) -> void:
	var d: Vector3 = target - pl.cam.global_position
	pl.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	pl.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % name)
