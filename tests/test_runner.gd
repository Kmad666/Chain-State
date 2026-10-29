extends Node
## Smoke tests. Run:  godot --headless res://tests/test_runner.tscn
## With a display (no --headless) it also saves screenshots to user://shots/.

const HookOrb := preload("res://scripts/combat/hook_orb.gd")

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
	check(Sfx.played.has("chain_throw"), "throwing the chain makes a sound")
	for i in 60:
		await get_tree().physics_frame
	check(p.attached, "hook flew and attached")
	var y0: float = p.global_position.y
	for i in 120:
		Input.action_press("reel_in")
		await get_tree().physics_frame
	Input.action_release("reel_in")
	check(p.global_position.y > y0 + 3.0, "reeling in (Q) lifts the player (%.1f -> %.1f)" % [y0, p.global_position.y])
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
	check(menu._buttons.any(func(b): return "Platform Test" in b.text), "the Platform Test is on the menu")
	check(menu.build_stamp().begins_with("BUILD "), "the menu shows a build number (%s)" % menu.build_stamp())
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
		check(w.islands[0].tufts > 0 and w.clouds and w.clouds.cloud_count() > 0,
			"%s: grass tufts on the islands (%d) and clouds drifting around (%d)" % [lv, w.islands[0].tufts, w.clouds.cloud_count() if w.clouds else 0])
		if lv == "level_1":
			# sounds: jump, land, hook bite
			Sfx.played.clear()
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")
			for i in 150:
				await get_tree().physics_frame
				if w.player.is_on_floor() and Sfx.played.has("land"):
					break
			check(Sfx.played.has("jump") and Sfx.played.has("land"), "a jump and a landing make their sounds")
			check(Sfx._streams.size() == 8 and Sfx._streams["jump"].size() == 4, "all the sound effects load (4 jump variations)")
		await shot("11_" + lv)
		w.player.head.rotation.x = deg_to_rad(-35)
		await shot("12_" + lv + "_down")
		w.queue_free()
		await get_tree().process_frame
	print("== Platform Test")
	Game.level = "platform_test"
	var pw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(pw)
	for i in 20:
		await get_tree().physics_frame
	var pp = pw.player
	var CO: Array = pw.COURSE
	check(pw.pads.size() == 6 and pw.anchors.size() == 5 and pw.par == 5, "6 landing pads, 5 swing anchors, par 5")
	check(pw.pads.all(func(b): return b.collision_layer == pp.LAYER_LAND), "landing pads are solid but on the no-grapple layer")
	check(pw.anchors.all(func(a): return a.is_in_group("grapple_target")), "anchors are labelled grapple targets")
	check(is_equal_approx(pp.tune.fov, 90.0), "field of view is 90")
	check(is_equal_approx(pp.top_speed(), pp.tune.walk_speed + 10.0) and is_equal_approx(pp.tune.air_speed, pp.tune.walk_speed),
		"top speed is walk speed + 10 (%.0f m/s), air steering matches walk speed" % pp.top_speed())
	_aim(pp, CO[1].anchor + Vector3(0, -6, 0))
	for i in 4:
		await get_tree().process_frame
	await shot("22_course_start")
	# aiming at a pad: nothing to grapple, and the HUD knows why
	pp.tune.lock_cone = 0.0
	_aim(pp, CO[0].pad + Vector3(4, -0.5, -4))
	for i in 3:
		await get_tree().process_frame
	check(pp.find_target().is_empty() and pp.aim_blocked, "aiming at a landing pad: can't grapple it")
	pp.tune.lock_cone = 30.0
	# Q / E: reel in and slack while hooked to an anchor
	pp.global_position = CO[1].anchor + Vector3(0, -8, 6)
	pp.velocity = Vector3.ZERO
	_aim(pp, CO[1].anchor)
	await get_tree().process_frame
	pp.try_grapple()
	for i in 40:
		await get_tree().physics_frame
	check(pp.attached and pp.hook_node == null, "hooked onto an anchor")
	var r0: float = pp.rope_len
	Input.action_press("reel_out")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("reel_out")
	var r1: float = pp.rope_len
	Input.action_press("reel_in")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("reel_in")
	check(r1 > r0 + 1.0 and pp.rope_len < r1 - 1.0, "E gives slack (%.1f -> %.1f m), Q reels in (-> %.1f m)" % [r0, r1, pp.rope_len])
	check(InputMap.action_get_events("reel_in").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_Q)
		and InputMap.action_get_events("reel_out").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_E), "Q is bound to reel in, E to slack")
	pp.release()
	# land below + Space: latch down
	for i in 20:
		await get_tree().physics_frame
	var sw0: int = pp.swings
	pp.global_position = CO[1].pad + Vector3(0, 22, 0)
	pp.velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame
	check(pp.land_below > 15.0, "in the air over a pad, the HUD reports land below (%.0f m)" % pp.land_below)
	check(pw.hud._below.text.begins_with("▼"), "...shown at the bottom of the screen")
	await shot("20_land_below")
	pp.ground_latch()
	var tl := 0
	while tl < 240 and not pp.is_on_floor():
		await get_tree().physics_frame
		tl += 1
	check(pp.is_on_floor() and tl < 150 and not pp.attached and pp.swings == sw0,
		"Space latches straight down and reels you in (%.1f s), without counting as a swing" % (tl / 120.0))
	pp.global_position = CO[1].pad + Vector3(30, 5, 0)
	await get_tree().process_frame
	await get_tree().physics_frame
	check(pp.land_below < 0.0 and pw.hud._below.text.begins_with("▽"), "over the void: no land below")

	# a bot runs the whole course, one swing per gap
	pp.respawn()
	pp.swings = 0
	pw.checkpoint = 0
	var release_at := [0.0, 0.0, 0.0, 0.0, 0.0]
	var max_v := 0.0
	for gi in range(CO.size() - 1):
		var from_b: Vector3 = CO[gi].pad
		var to_b: Vector3 = CO[gi + 1].pad
		var an_b: Vector3 = CO[gi + 1].anchor
		var dir_b := to_b - from_b
		dir_b.y = 0.0
		dir_b = dir_b.normalized()
		var half_b: float = (CO[gi].get("size", Vector3(10, 1.5, 10)) as Vector3).z * 0.5
		pp.global_position = from_b + dir_b * (half_b - 0.6) + Vector3(0, 1.0, 0)
		pp.velocity = dir_b * pp.tune.walk_speed + Vector3(0, pp.tune.jump, 0)
		var fired_b := false
		var let_go_b := false
		var latched_b := 0
		var tb := 0
		Input.action_press("move_forward")
		while tb < 120 * 8:
			tb += 1
			if not let_go_b:
				_aim(pp, an_b)
			else:
				var d2_b: Vector3 = to_b - pp.global_position
				pp.rotation = Vector3(0, atan2(-d2_b.x, -d2_b.z), 0)
			await get_tree().physics_frame
			if not fired_b and tb > 12:
				pp.try_grapple()
				fired_b = true
			if not pp.latching:
				max_v = maxf(max_v, pp.velocity.length() if pp.attached else Vector2(pp.velocity.x, pp.velocity.z).length())
			if pp.attached and not let_go_b and (pp.global_position - an_b).dot(dir_b) > release_at[gi] and pp.velocity.y > -2.0:
				pp.release()
				let_go_b = true
			# over the next pad after letting go: Space, latch down onto it
			if let_go_b and not pp.latching and pp.land_below >= 0.0:
				var flat_b: Vector3 = pp.global_position - to_b
				flat_b.y = 0.0
				var half_n: float = (CO[gi + 1].get("size", Vector3(10, 1.5, 10)) as Vector3).x * 0.5
				if flat_b.length() < half_n - 1.0:
					pp.ground_latch()
					latched_b += 1
			if pp.is_on_floor() and tb > 30:
				break
		Input.action_release("move_forward")
		for i in 5:
			await get_tree().physics_frame
		print("  info gap %d: checkpoint now %d, swings %d, latched down %d" % [gi, pw.checkpoint, pp.swings, latched_b])
	check(max_v <= pp.top_speed() + 0.5, "the bot never went faster than top speed (fastest %.1f m/s)" % max_v)
	check(pw.finished and pp.swings == pw.par, "the course can be crossed in exactly par: %d swings, one per gap" % pp.swings)
	await shot("21_platform_test")
	pw.queue_free()
	await get_tree().process_frame

	print("== Hamlet")
	Game.level = "hamlet"
	var hw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(hw)
	for i in 40:
		await get_tree().physics_frame
	var hp = hw.player
	check(hw.buildings.size() == 7 and hw.anchors.size() == 9, "hamlet: 7 buildings (chapel, inn, smithy, 4 houses) and 9 grapple anchors")
	check(hp.is_on_floor(), "hamlet: you arrive standing on the south road")
	check(hw.buildings.all(func(b): return b.collision_layer == hp.LAYER_LAND) and hw.islands[0].collision_layer == hp.LAYER_LAND,
		"hamlet: buildings and ground are solid but can't be grappled")
	var linked := true
	for a in hw.anchors:
		var near := false
		for b in hw.anchors:
			if a != b and a.global_position.distance_to(b.global_position) <= hp.tune.grapple_range:
				near = true
		linked = linked and near
	check(linked, "hamlet: every anchor has another within chain reach (a rooftop route)")
	check(get_tree().get_nodes_in_group("npc").size() == 2 and DialogueDB.load_tree("hamlet_innkeeper", "Innkeeper").start == "start",
		"hamlet: an innkeeper and a neighbour, with their own dialogue")
	check(get_tree().get_nodes_in_group("evidence").size() == 3, "hamlet: three fire clues at the burnt house")
	# nothing that has to stay reachable may sit inside a building (or the roads)
	var clear := true
	var space = hw.get_world_3d().direct_space_state
	var spots: Array = []
	for n in get_tree().get_nodes_in_group("evidence") + get_tree().get_nodes_in_group("npc"):
		spots.append(n.global_position + Vector3(0, 1.0, 0))
	for z in range(-34, 58, 4):
		spots.append(Vector3(0, 1.0, z) if absf(z) > 12 else Vector3(14, 1.0, z))
	for x in range(-52, 54, 4):
		spots.append(Vector3(x, 1.0, 0) if absf(x) > 12 else Vector3(x, 1.0, 14))
	for sp in spots:
		var q := PhysicsPointQueryParameters3D.new()
		q.position = sp
		q.collision_mask = hp.LAYER_LAND
		for h in space.intersect_point(q):
			if h.collider in hw.buildings:
				clear = false
				print("  blocked: ", sp)
	check(clear, "hamlet: no building covers a road, a clue or a person")
	await shot("23_hamlet_arrival")
	hp.global_position = Vector3(-6, 1, 14)
	_aim(hp, Vector3(30, 4, -17))
	for i in 4:
		await get_tree().process_frame
	await shot("24_hamlet_square")
	hp.global_position = Vector3(0, 40, 75)
	hp.velocity = Vector3.ZERO
	_aim(hp, Vector3(0, 0, -5))
	for i in 3:
		await get_tree().process_frame
	await shot("25_hamlet_overview")
	hp.global_position = Vector3(0, 1, 30)
	hp.velocity = Vector3.ZERO
	_aim(hp, Vector3(17, 2, 30))
	for i in 3:
		await get_tree().process_frame
	await shot("26_hamlet_smithy_door")
	hw.queue_free()
	await get_tree().process_frame

	print("== City")
	Game.level = "city"
	var cw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(cw)
	for i in 40:
		await get_tree().physics_frame
	var cp = cw.player
	check(cp.is_on_floor(), "city: you arrive standing at the south gate")
	check(cw.city_cells > 180, "city: packed with terraces (%d building plots)" % cw.city_cells)
	check(cw.anchors.size() == 12, "city: 12 grapple anchors over the crossroads")
	var cspace = cw.get_world_3d().direct_space_state
	var c_top := PhysicsRayQueryParameters3D.create(Vector3(-20, 60, -20), Vector3(-20, -5, -20), cp.LAYER_LAND)
	var c_th = cspace.intersect_ray(c_top)
	check(not c_th.is_empty() and c_th.position.y > 17.0, "city: the terraces stand five storeys (%.1f m)" % (c_th.position.y if not c_th.is_empty() else 0.0))
	var c_road := true
	for z in range(-50, 52, 4):
		var q := PhysicsPointQueryParameters3D.new()
		q.position = Vector3(0, 1, z)
		q.collision_mask = cp.LAYER_LAND
		for hh in cspace.intersect_point(q):
			if hh.collider in cw.buildings:
				c_road = false
	check(c_road, "city: the north-south boulevard runs clear end to end")
	var c_linked := true
	for a in cw.anchors:
		var c_near := false
		for b in cw.anchors:
			if a != b and a.global_position.distance_to(b.global_position) <= cp.tune.grapple_range:
				c_near = true
		c_linked = c_linked and c_near
	check(c_linked, "city: every anchor has another within chain reach")
	await shot("27_city_gate")
	cp.global_position = Vector3(0, 1, 22)
	_aim(cp, Vector3(0, 3, 0))
	for i in 3:
		await get_tree().process_frame
	await shot("28_city_boulevard")
	cp.global_position = Vector3(31, 1, 12)
	_aim(cp, Vector3(31, 8, -20))
	for i in 3:
		await get_tree().process_frame
	await shot("29_city_street")
	cp.global_position = Vector3(0, 70, 95)
	cp.velocity = Vector3.ZERO
	_aim(cp, Vector3(0, 0, -5))
	for i in 3:
		await get_tree().process_frame
	await shot("30_city_overview")
	cw.queue_free()
	await get_tree().process_frame

	print("== The Ascent")
	Game.level = "ascent"
	var aw2 = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(aw2)
	for i in 40:
		await get_tree().physics_frame
	var ap2 = aw2.player
	check(aw2.ascent.size() == 50 and aw2.ascent.all(func(a): return a.is_in_group("magic")), "ascent: 50 anchors, all free to grapple")
	check(ap2.is_on_floor(), "ascent: you start on the forest floor")
	var top_y: float = aw2.ascent[49].global_position.y
	check(top_y > 380.0, "ascent: the last anchor is %d m up" % roundi(top_y))
	var max_gap := 0.0
	for k in 49:
		max_gap = maxf(max_gap, aw2.ascent[k].global_position.distance_to(aw2.ascent[k + 1].global_position))
	check(max_gap < ap2.tune.grapple_range - 6.0, "ascent: each anchor is within easy reach of the last (widest %.1f m)" % max_gap)
	await shot("31_ascent_start")
	# the bot climbs: hook, let the rope pull you up, then aim at the next and swap
	_aim(ap2, aw2.ascent[0].global_position)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 10:
		await get_tree().physics_frame
	ap2.try_grapple()
	var k2 := 0
	var t2 := 0
	var held := 0
	var vmax := 0.0
	var climbed := true
	while k2 < 49 and t2 < 120 * 200:
		t2 += 1
		await get_tree().physics_frame
		if not ap2.latching:
			vmax = maxf(vmax, ap2.velocity.length() if ap2.attached else Vector2(ap2.velocity.x, ap2.velocity.z).length())
		if ap2.attached and ap2.anchor.distance_to(aw2.ascent[k2].global_position) < 2.0:
			held += 1
			var d2: float = ap2.global_position.distance_to(aw2.ascent[k2].global_position)
			if held > 50 and (d2 < 9.0 or held > 300):
				_aim(ap2, aw2.ascent[k2 + 1].global_position)
				ap2.release()
				await get_tree().physics_frame
				_aim(ap2, aw2.ascent[k2 + 1].global_position)
				ap2.try_grapple()
				k2 += 1
				held = 0
		elif not ap2.attached and ap2.hook_state == 0:
			_aim(ap2, aw2.ascent[k2].global_position)
			ap2.try_grapple()
		if ap2.global_position.y < aw2.ascent[k2].global_position.y - 80.0:
			climbed = false
			break
	for i in 120:
		await get_tree().physics_frame
	check(climbed and aw2.ascent_reached == 49, "ascent: the bot chains all 50 anchors to the top (%d reached, %.0f s, %d m up)" % [aw2.ascent_reached + 1, aw2.ascent_time, roundi(ap2.global_position.y)])
	check(vmax <= ap2.top_speed() + 0.5, "ascent: the whole climb stays within top speed (fastest %.1f m/s)" % vmax)
	await shot("32_ascent_high")
	# drop onto the finish: Space latches down onto it
	ap2.release()
	ap2.global_position = aw2.ascent_finish.global_position + Vector3(0, 12, 0)
	ap2.velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame
	ap2.ground_latch()
	for i in 240:
		await get_tree().physics_frame
		if aw2.finished:
			break
	check(aw2.finished and not aw2.ascent_running, "ascent: landing on the gold platform finishes the run")
	_aim(ap2, Vector3(0, 0, 0))
	for i in 3:
		await get_tree().process_frame
	await shot("33_ascent_view_down")
	aw2.queue_free()
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
	check(Sfx.played.has("cast"), "his volleys make a casting sound, out where he is")
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
	ep.hook_offset = Vector3.ZERO
	ep.hook_state = 2
	ep.anchor = s.global_position
	ep.rope_len = 8.0
	ep.velocity = Vector3(0, 0, 6)
	ep.rotation.y += 1.4                     # looking away: the auto-wrap should swing the view round
	await get_tree().physics_frame
	ep.interact()
	check(ep.auto_wrap, "E on a hooked caster starts the auto-wrap")
	var frames := 0
	var t_wrap := Time.get_ticks_msec()
	while frames < 120 * 14 and not s.ready_to_arrest:
		await get_tree().physics_frame
		frames += 1
	var to_s: Vector3 = s.global_position - ep.cam.global_position
	var look_err: float = rad_to_deg((-ep.cam.global_basis.z).angle_to(to_s))
	check(s.ready_to_arrest and not s.is_subdued and ep.attached,
		"three automatic laps bind him (%.1f s of game time), and he waits for the arrest" % (frames / 120.0))
	check(look_err < 12.0, "the camera keeps him in the reticle while wrapping (%.1f deg off)" % look_err)
	await shot("14_bound")
	var v_before: float = ep.velocity.length()
	ep.interact()
	check(s.is_subdued, "E again: ARREST")
	check(not ep.attached and not ep.auto_wrap, "the chain comes free")
	check(ep.velocity.length() >= v_before * 0.95 and v_before > 8.0, "you keep your momentum (%.1f -> %.1f m/s)" % [v_before, ep.velocity.length()])
	check(is_equal_approx(Engine.time_scale, 1.0), "no slow motion or freeze on the arrest")
	var h = ew.hud
	check(h._flash_a == 0.0 and h._banner.text == "", "no screen flash and no banner on the arrest: just a line of text")
	var y_arrest: float = s.global_position.y
	for i in 240:
		await get_tree().physics_frame
	check(s._landed and s.global_position.y < y_arrest - 0.5 and s._coils.size() == 3,
		"he drops to the ground and lies there with the chain round him (fell %.1f m)" % (y_arrest - s.global_position.y))
	check(not s._core.visible, "his casting glow goes out")
	check(not ew.find_children("*", "MeshInstance3D", true, false).any(func(m): return m.mesh is SphereMesh and (m.mesh as SphereMesh).radius == 1.0 and m.material_override and m.material_override.transparency != 0 and m.get_parent().get_parent() == ew),
		"no effect is spawned on the arrest (effects come later)")
	for i in 30:
		await get_tree().process_frame
	await shot("14_arrested")
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
	check(tr.red_count() == 40 and tr.blue_orbs().size() == 10, "her tree: 40 red orbs, 10 blue")
	var min_gap := INF
	for i in tr._red_local.size():
		for j in range(i + 1, tr._red_local.size()):
			min_gap = minf(min_gap, tr._red_local[i].distance_to(tr._red_local[j]))
	check(tr.RED_SIZE >= 1.8 and min_gap >= tr.SPACING, "the red orbs are big (r %.1f m) and never clump (closest pair %.1f m)" % [tr.RED_SIZE, min_gap])
	check(wd.radius >= 17.0 and wd.global_position.y - wd.radius > tr.global_position.y + tr.height, "her ward is twice the size and still clears the tree")
	check(wd.rim_edges >= 3, "the opening is traced in gold (%d edges)" % wd.rim_edges)
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
	ap.tune.lock_cone = 0.0
	ap.lock_target = null
	check(ap.find_target().is_empty() or ap.find_target().collider != blue2, "with the reticle and lock-on at 0, the same near miss misses")
	ap.tune.aim_assist = keep
	ap.tune.lock_cone = 30.0

	# aim assist on surfaces: dead centre on open sky, but the ward's edge is inside the circle
	ap.global_position = wd.global_position + Vector3(-24, 0, -24)
	var to_w: Vector3 = (wd.global_position - ap.global_position).normalized()
	var edge_ang: float = asin(wd.radius / ap.global_position.distance_to(wd.global_position))
	var dir: Vector3 = to_w.rotated(Vector3.UP, edge_ang + deg_to_rad(1.5))
	_aim(ap, ap.cam.global_position + dir * 10.0 + Vector3(0, 0, 0))
	await get_tree().physics_frame
	var centre_hit: Dictionary = ap._ray(1 | 4, ap.tune.grapple_range)
	ft = ap.find_target()
	check(centre_hit.is_empty() and not ft.is_empty() and ft.collider == wd, "aim assist: just past the ward's edge still finds the ward")

	# auto-aim lock-on: away from the tree, one test orb up and off to the side
	var lo := HookOrb.new()
	lo.orbiting = true
	lo.harmless = true
	aw.add_child(lo)
	var spot := Vector3(-60, 20, -60)
	lo.global_position = spot + Vector3(9, 7.6, -20)
	ap.global_position = spot
	ap.velocity = Vector3.ZERO
	ap.rotation = Vector3.ZERO
	ap.head.rotation.x = deg_to_rad(4.0)
	ap.lock_target = null
	await get_tree().process_frame
	await get_tree().process_frame
	ft = ap.find_target()
	var lo_px: float = ap.cam.unproject_position(lo.global_position).distance_to(ap.get_viewport().get_visible_rect().size * 0.5)
	check(lo.is_in_group("grapple_target"), "blue orbs carry the grapple-target label")
	check(ap.lock_target == lo and not ft.is_empty() and ft.collider == lo and lo_px > ap.reticle_px(),
		"auto-aim locks onto a blue orb %d px off-centre, well outside the reticle" % roundi(lo_px))
	check(lo.highlighted and ap.highlight_target == lo, "the locked orb lights up")
	await shot("18_lock_on")
	ap.global_position = spot
	ap.rotation.y = deg_to_rad(110.0)          # turn away: the orb is now off-screen
	await get_tree().process_frame
	await get_tree().process_frame
	ft = ap.find_target()
	check(ap.cam.is_position_behind(lo.global_position) or not Rect2(Vector2.ZERO, ap.get_viewport().get_visible_rect().size).has_point(ap.cam.unproject_position(lo.global_position)),
		"(the orb is off-screen)")
	check(ap.lock_target == lo and not ft.is_empty() and ft.collider == lo and lo.highlighted, "the lock holds with the orb out of sight")
	await shot("19_lock_offscreen")
	ap.try_grapple()
	for i in 40:
		await get_tree().physics_frame
	check(ap.attached and ap.hook_node == lo, "...and the chain still catches it")
	check(not lo.highlighted, "the orb you hang from stops glowing (auto-aim moves on)")
	ap.release()
	for i in 70:
		await get_tree().physics_frame
	ap.global_position = spot
	ap.velocity = Vector3.ZERO
	ap.rotation = Vector3.ZERO
	ap.head.rotation.x = deg_to_rad(4.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ap.lock_target == lo, "(re-locked)")
	ap.global_position = Vector3(-46, 9, -30)   # stand by the small island, look down at it
	ap.rotation = Vector3(0, PI, 0)
	ap.head.rotation.x = deg_to_rad(-60.0)
	await get_tree().process_frame
	await get_tree().process_frame
	ft = ap.find_target()
	check(not ft.is_empty() and ft.collider != lo and not lo.highlighted,
		"aiming dead at a surface beats a lock outside the reticle")
	ap.global_position = spot
	ap.rotation = Vector3.ZERO
	ap.head.rotation.x = deg_to_rad(4.0)
	var keep_cone: float = ap.tune.lock_cone
	ap.tune.lock_cone = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	check(ap.lock_target == null and not lo.highlighted, "lock cone 0 turns auto-aim off")
	ap.tune.lock_cone = keep_cone
	lo.queue_free()

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
	check(Sfx.played.has("hurt"), "being stunned makes a sound")
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
	ap.global_position = wd.global_position + wd.open_dir.normalized() * (wd.radius + 16.0)
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
		witch._track_wrap(wc + Vector3(cos(a3) * (wd.radius + 2.0), 0, sin(a3) * (wd.radius + 2.0)))
	check(witch.wraps < 0.1, "laps outside the ward don't count")
	for k in 3 * 24 + 6:
		var a3 := TAU * k / 24.0
		witch._track_wrap(wc + Vector3(cos(a3) * 4.0, -1.0, sin(a3) * 4.0))
		if witch.is_subdued:
			break
	check(witch.ready_to_arrest and not witch.is_subdued, "three laps inside the ward bind her (swinging round by hand works too)")
	ap.interact()
	check(witch.is_subdued, "...and E arrests her")
	var lights_added := 0
	for _l in aw.find_children("*", "OmniLight3D", true, false):
		lights_added += 1
	check(lights_added == 0, "the arrest adds no light")
	check(not Sfx.played.has("break") and not Sfx.played.has("subdue"), "the arrest plays no sound effect")
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
