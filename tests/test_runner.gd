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
	if OS.get_environment("ONLY") in ["nation", "spire", "tree", "citadel", "keep"]:     # quick runs
		if OS.get_environment("ONLY") == "nation":
			await _test_nation()
		elif OS.get_environment("ONLY") == "keep":
			await _test_keep()
		elif OS.get_environment("ONLY") == "citadel":
			await _test_citadel()
		elif OS.get_environment("ONLY") == "tree":
			await _test_cloud_tree()
		else:
			await _test_spire()
		print("== %s" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
		get_tree().quit(1 if fails else 0)
		return
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
	await get_tree().process_frame
	check(menu.scroll != null and menu._buttons.all(func(b): return menu.scroll.is_ancestor_of(b)), "the level list sits in a scroll box")
	var last: Button = menu._buttons[menu._buttons.size() - 1]
	last.grab_focus()
	for i in 4:
		await get_tree().process_frame
	check(menu.scroll.get_v_scroll_bar().max_value <= menu.scroll.size.y + 1.0 or menu.scroll.scroll_vertical > 0,
		"the list scrolls to the last level (%d px down)" % menu.scroll.scroll_vertical)
	await shot("10b_level_select_scrolled")
	menu.scroll.scroll_vertical = 0
	await get_tree().process_frame
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
	# the apprentices: weaker flyers that shoot big fast orbs straight at you
	var apps: Array = aw2.sentries.filter(func(x): return x.kind == "apprentice")
	check(apps.size() == 5 and apps.all(func(x): return x.wraps_needed == 1 and x.title == "apprentice"),
		"ascent: five apprentices along the climb, one wrap each")
	var app = apps[0]
	# patrol: a wide circle round its post, unaware of you on the ground far below
	var pa: Vector3 = app.global_position
	for i in 120:
		await get_tree().physics_frame
	check(not app.chasing and app.global_position.distance_to(pa) > 4.0 and app.global_position.distance_to(app.home) > 20.0,
		"an apprentice patrols a wide circle (%d m round its post)" % roundi(app.global_position.distance_to(app.home)))
	# spotted: it chases you, with a "!"
	ap2.invuln = 999.0
	ap2.global_position = app.global_position + Vector3(0, -2, 30)
	ap2.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var d_start: float = app.global_position.distance_to(ap2.global_position)
	for i in 120:
		ap2.velocity = Vector3.ZERO
		await get_tree().physics_frame
	var d_now: float = app.global_position.distance_to(ap2.global_position)
	check(app.chasing and app._alert.visible and d_now < d_start - 5.0, "it spots you (!) and chases (%d m -> %d m)" % [roundi(d_start), roundi(d_now)])
	ap2.global_position = app.global_position + Vector3(0, 0, 90)
	for i in 5:
		await get_tree().physics_frame
	check(not app.chasing and not app._alert.visible, "get far enough away and it gives up")
	ap2.global_position = app.global_position + Vector3(0, -2, 22)
	ap2.velocity = Vector3.ZERO
	ap2.invuln = 0.0
	var got_shot := false
	var shot_ok := false
	for i in 120 * 5:
		ap2.global_position = app.global_position + Vector3(0, -2, 22)     # hold still in the air
		ap2.velocity = Vector3.ZERO
		await get_tree().physics_frame
		var f = aw2.bullets
		for b in f._pos.size():
			var v: Vector3 = f._vel[b]
			var to_p: Vector3 = (ap2.global_position - f._pos[b]).normalized()
			if v.length() > 20.0 and f._rad[b] > 1.0 and v.normalized().dot(to_p) > 0.9:
				shot_ok = true
		if ap2.stunned > 0.0:
			got_shot = true
			break
	check(shot_ok, "an apprentice fires large, fast orbs aimed at you")
	check(got_shot, "...and one hits if you hang about")
	ap2.global_position = app.global_position + Vector3(2, -1, 9)
	_aim(ap2, app.global_position)
	await shot("34_apprentice")
	ap2.stunned = 0.0
	ap2.invuln = 999.0
	ap2.global_position = app.global_position + Vector3(8, -1, 0)
	ap2.velocity = Vector3.ZERO
	check(_hook_on(ap2, app), "hooking an apprentice holds")
	var side0: Vector3 = app.global_position
	var max_side := 0.0
	for i in 90:
		ap2.global_position = app.global_position + Vector3(8, -1, 0)    # hold the chain taut
		ap2.velocity = Vector3.ZERO
		await get_tree().physics_frame
		max_side = maxf(max_side, absf(app.global_position.z - side0.z))
	check(max_side > 2.0, "hooked, it zigzags side to side (%.1f m)" % max_side)
	var wc3: Vector3 = app.global_position
	for k in 26:
		app._track_wrap(wc3 + Vector3(cos(TAU * k / 24.0) * 8.0, -1.0, sin(TAU * k / 24.0) * 8.0))
	check(app.ready_to_arrest and ap2.attached, "one lap binds an apprentice (no throw-back)")
	ap2.interact()
	check(app.is_subdued and not ap2.attached, "E arrests it, and the chain comes free")
	ap2.respawn()
	aw2.bullets.clear()
	for i in 10:
		await get_tree().physics_frame
	for x in apps:
		if is_instance_valid(x):
			x.queue_free()                   # tested above; out of the bot's way for the climb
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

	print("== Tower")
	Game.level = "tower"
	var tw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(tw)
	for i in 30:
		await get_tree().physics_frame
	var tp = tw.player
	var T = tw.tower
	check(T.top_point().y > 120.0 and T.hooks.size() == T.sections, "tower: %d m tall with %d hooks" % [roundi(T.top_point().y), T.hooks.size()])
	var tspace = tw.get_world_3d().direct_space_state
	var clear_lines := true
	for k in T.hooks.size() - 1:
		var q := PhysicsRayQueryParameters3D.create(T.hooks[k].global_position, T.hooks[k + 1].global_position, tp.LAYER_LAND | tp.LAYER_WORLD)
		q.exclude = [T.hooks[k].get_rid(), T.hooks[k + 1].get_rid()]
		if not tspace.intersect_ray(q).is_empty() or T.hooks[k].global_position.distance_to(T.hooks[k + 1].global_position) > tp.tune.grapple_range - 6.0:
			clear_lines = false
	check(clear_lines, "tower: each hook is in clear sight and easy reach of the next")
	await shot("35_tower_base")
	tp.invuln = 999.0
	_aim(tp, T.hooks[0].global_position)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 10:
		await get_tree().physics_frame
	tp.try_grapple()
	var kt := 0
	var tt := 0
	var held_t := 0
	while kt < T.hooks.size() - 1 and tt < 120 * 90:
		tt += 1
		await get_tree().physics_frame
		if tp.attached and tp.anchor.distance_to(T.hooks[kt].global_position) < 2.0:
			held_t += 1
			if held_t > 50 and (tp.global_position.distance_to(T.hooks[kt].global_position) < 9.0 or held_t > 300):
				_aim(tp, T.hooks[kt + 1].global_position)
				tp.release()
				await get_tree().physics_frame
				_aim(tp, T.hooks[kt + 1].global_position)
				tp.try_grapple()
				kt += 1
				held_t = 0
		elif not tp.attached and tp.hook_state == 0:
			_aim(tp, T.hooks[kt].global_position)
			tp.try_grapple()
	for i in 90:
		await get_tree().physics_frame
	var at_top: bool = tp.attached and tp.anchor.distance_to(T.hooks[-1].global_position) < 2.0
	check(at_top, "tower: the bot climbs hook to hook to the top post (%.0f s)" % (tt / 120.0))
	await shot("36_tower_high")
	# let go above the crown and latch down onto it
	tp.release()
	tp.global_position = T.top_point() + Vector3(0, 6, 0)
	tp.velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame
	tp.ground_latch()
	for i in 240:
		await get_tree().physics_frame
		if tp.is_on_floor():
			break
	check(tp.is_on_floor() and tp.global_position.y > T.top_point().y - 1.0, "tower: you can stand on the crown (%d m up)" % roundi(tp.global_position.y))
	_aim(tp, Vector3(0, 0, 60))
	for i in 3:
		await get_tree().process_frame
	await shot("37_tower_crown")
	tw.queue_free()
	await get_tree().process_frame

	print("== Cherub")
	Game.level = "cherub_test"
	var chw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(chw)
	for i in 30:
		await get_tree().physics_frame
	var chp = chw.player
	var cb = chw.cherub
	chp.invuln = 999.0
	check(cb.state == "idle", "cherub: asleep until you come near")
	await shot("38_cherub_far")
	chp.global_position = Vector3(0, 1, 0)        # walk in toward it
	for i in 120 * 4:
		await get_tree().physics_frame
	check(cb.state == "fight", "cherub: it wakes, stares you down and casts its cone")
	var to_p: Vector3 = (chp.global_position - cb.global_position).normalized()
	check(cb.axis.dot(to_p) > 0.95, "cherub: the cone points at you")
	var bl: float = cb.CONE_LENGTH * tan(deg_to_rad(cb.CONE_HALF))
	check(bl > 120.0, "cherub: the cone is island-sized (%d m across at its mouth)" % roundi(bl * 2.0))
	check(cb.is_trapped(chp.global_position), "cherub: you're inside it")
	# try to leave: the wall pushes you back in
	var side: Vector3 = cb.axis.cross(Vector3.UP).normalized()
	chp.global_position += side * 150.0
	chp.velocity = side * 15.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(cb.is_trapped(chp.global_position + side * -0.3) and chp.velocity.dot(side) <= 0.01, "cherub: you can't leave the cone (its wall stops you)")
	chp.global_position = Vector3(0, 1, 0)
	for i in 120 * 6:
		await get_tree().physics_frame
	var nb: int = chw.bullets.count()
	check(nb > 40 and nb < 600, "cherub: a bullet-hell barrage down the cone (%d orbs in flight)" % nb)
	check(cb.sages.size() >= 1 and cb.sages.size() <= cb.MAX_SAGES, "cherub: it releases sages (%d out, at most %d)" % [cb.sages.size(), cb.MAX_SAGES])
	await shot("39_cherub_fight")
	chp.global_position = Vector3(25, 1, 25)
	_aim(chp, cb.global_position + Vector3(-40, -30, 40))
	for i in 3:
		await get_tree().process_frame
	await shot("41_cherub_cone_wall")
	chp.global_position = Vector3(0, 1, 0)
	var sg = cb.sages[0]
	for i in 120 * 2:
		await get_tree().physics_frame              # let it reach its hover spot
	check(sg.is_in_group("grapple_target") and sg.wraps_needed == 1 and chp.is_magic(sg), "sage: grapple-able (free), one lap to bind")
	_aim(chp, sg.global_position)
	await shot("40_sage")
	chp.global_position = sg.global_position + Vector3(8, -1, 0)
	check(_hook_on(chp, sg), "sage: hook it")
	var wc4: Vector3 = sg.global_position
	for k in 26:
		sg._track_wrap(wc4 + Vector3(cos(TAU * k / 24.0) * 8.0, -1.0, sin(TAU * k / 24.0) * 8.0))
	check(sg.ready_to_arrest, "sage: one lap binds it")
	chp.interact()
	check(sg.is_subdued and cb.arrested == 1, "sage: E arrests it (1 of %d)" % cb.SAGES_TO_WIN)
	# arrest four more (as they come) and the Cherub is spent
	var guard := 0
	while cb.arrested < cb.SAGES_TO_WIN and guard < 120 * 60:
		guard += 1
		await get_tree().physics_frame
		for x in cb.sages:
			if is_instance_valid(x) and not x.is_subdued and x._hooked_by == null and cb.arrested < cb.SAGES_TO_WIN:
				chp.global_position = x.global_position + Vector3(8, -1, 0)
				if _hook_on(chp, x):
					var c5: Vector3 = x.global_position
					for k in 26:
						x._track_wrap(c5 + Vector3(cos(TAU * k / 24.0) * 8.0, -1.0, sin(TAU * k / 24.0) * 8.0))
					chp.interact()
				break
	for i in 30:
		await get_tree().physics_frame
	check(cb.state == "spent" and chw.bullets.count() == 0, "cherub: five sages arrested and it's spent: the barrage stops")
	check(not cb.is_trapped(chp.global_position), "cherub: the cone lets you go")
	chw.queue_free()
	await get_tree().process_frame

	await _test_nation()
	await _test_spire()
	await _test_cloud_tree()
	await _test_citadel()
	await _test_keep()

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
	# awareness: he spotted you earlier ("!" over his head); get far enough away and he gives up
	ep.global_position = s.global_position + Vector3(0, -1, 25)
	await get_tree().physics_frame
	check(s.chasing and s._alert.visible, "spotted: the wizard follows you, with a ! over his head")
	ep.global_position = s.global_position + Vector3(0, 0, 80)
	for i in 5:
		await get_tree().physics_frame
	check(not s.chasing and not s._alert.visible, "get far enough away and he gives up the chase")
	ep.global_position = s.global_position + Vector3(8, -1, 0)
	check(_hook_on(ep, s), "hooking from close range holds")
	ep.velocity = Vector3(0, 0, 6)
	ep.rotation.y += 1.4                     # looking away: the lock should swing the view round
	var p0: Vector3 = ep.global_position
	await get_tree().physics_frame
	ep.interact()
	check(ep.wrap_lock, "E on a hooked caster locks your view on it")
	for i in 60:
		await get_tree().physics_frame
	var to_s: Vector3 = s.global_position - ep.cam.global_position
	var look_err: float = rad_to_deg((-ep.cam.global_basis.z).angle_to(to_s))
	check(look_err < 12.0, "the camera keeps him in the reticle (%.1f deg off)" % look_err)
	check(s._laps == 0, "...but it doesn't fly you round him: you do the swinging")
	# lap one, for real: locked on, hold D and swing round him
	var lap_frames := 0
	Input.action_press("move_right")
	while lap_frames < 120 * 12 and s._laps < 1:
		await get_tree().physics_frame
		lap_frames += 1
	Input.action_release("move_right")
	print("  info lap by holding D: %.1f s" % (lap_frames / 120.0))
	check(s._laps == 1, "locked on, holding D swings you right round him (%.1f s)" % (lap_frames / 120.0))
	var wc2: Vector3 = s.global_position
	var away: Vector3 = ep.global_position - s.global_position
	away.y = 0.0
	check(s._laps == 1 and not ep.attached and s._coils.size() == 1, "wrap 1 of 3: the wizard burns the chain (the coil stays on him)")
	check(ep.velocity.dot(away.normalized()) > 8.0 and ep.velocity.y > 4.0, "...and throws you back (%.1f m/s away)" % ep.velocity.dot(away.normalized()))
	await shot("14_thrown")
	# lap two: hook him again
	ep.global_position = s.global_position + Vector3(8, -1, 0)
	check(_hook_on(ep, s), "hook him again for the next lap")
	wc2 = s.global_position
	for k in 26:
		s._track_wrap(wc2 + Vector3(cos(TAU * k / 24.0) * 8.0, -1.0, sin(TAU * k / 24.0) * 8.0))
	check(s._laps == 2 and not ep.attached, "wrap 2 of 3: thrown back again")
	# lap three: bound
	ep.global_position = s.global_position + Vector3(8, -1, 0)
	_hook_on(ep, s)
	wc2 = s.global_position
	for k in 26:
		s._track_wrap(wc2 + Vector3(cos(TAU * k / 24.0) * 8.0, -1.0, sin(TAU * k / 24.0) * 8.0))
	check(s.ready_to_arrest and not s.is_subdued and ep.attached, "wrap 3 of 3: bound, and he waits for the arrest")
	await shot("14_bound")
	ep.velocity = Vector3(10, 2, 0)
	var v_before: float = ep.velocity.length()
	ep.interact()
	check(s.is_subdued, "E again: ARREST")
	check(not ep.attached and not ep.wrap_lock, "the chain comes free")
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


## Put the player on the chain, hooked to a caster (as if the hook had just bitten).
func _hook_on(pl: Node, en: Node) -> bool:
	if not en.on_hooked(pl):
		return false
	pl.attached = true
	pl.hook_node = en
	pl.hook_offset = Vector3.ZERO
	pl.hook_state = 2
	pl.anchor = en.global_position
	pl.rope_len = pl.global_position.distance_to(en.global_position)
	return true


func _test_nation() -> void:
	print("== Nation (draft) and dev fly")
	Game.level = "nation"
	var nw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(nw)
	for i in 60:
		await get_tree().physics_frame
	var np = nw.player
	check(nw.islands.size() == 6 + 15 + 12, "nation: 6 state islands, 15 satellites, 12 ordinary islands (%d)" % nw.islands.size())
	check(nw.islands[0].radius * 2.0 >= 1000.0, "nation: Delos is the 1 km hero island")
	var far_ok := true
	for i in range(1, 6):
		var d: float = Vector2(nw.islands[i].position.x, nw.islands[i].position.z).length()
		far_ok = far_ok and d > 1400.0 and d < 3200.0
	check(far_ok, "nation: the state capitals sit 1.4-3.2 km from Delos, clustered from the 1:50 map")
	var clear := true
	for a in nw.islands.size():
		for b in range(a + 1, nw.islands.size()):
			var ia = nw.islands[a]
			var ib = nw.islands[b]
			var gap: float = Vector2(ia.position.x - ib.position.x, ia.position.z - ib.position.z).length() - ia.radius - ib.radius
			clear = clear and gap >= 60.0
	check(clear, "nation: no two islands overlap (at least 60 m of air between rims)")
	check(nw.nation.spire != null and Vector2(nw.nation.spire.position.x, nw.nation.spire.position.z).length() > 600.0,
		"nation: Spire Town stands among the islands, clear of Delos")
	check(nw.nation.rails.size() == nw.islands.size(), "nation: a railway across every island (%d)" % nw.nation.rails.size())
	var on_isle := true
	for k in nw.nation.rails.size():
		var ln: Dictionary = nw.nation.rails[k]
		for e in [-1.0, 1.0]:
			var tip: Vector3 = ln.o + ln.dir * ln.half * e
			var q := PhysicsRayQueryParameters3D.create(tip + Vector3(0, 5, 0), tip + Vector3(0, -5, 0), 1)
			on_isle = on_isle and not nw.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	check(on_isle, "nation: every line ends on its island, not in the air")
	var ord_ok := true
	for i in range(21, 33):
		ord_ok = ord_ok and nw.islands[i].radius >= 50.0 and nw.islands[i].radius <= 200.0
	check(ord_ok, "nation: ordinary islands are 100-400 m across")
	check(np.is_on_floor() and nw.nation.where(np.global_position) == "over DELOS", "nation: you start standing on Delos's station platform")
	var nat = nw.nation
	check(nw.env.fog_mode == Environment.FOG_MODE_DEPTH and nw.env.fog_depth_end == nat.fog_end and nw.env.fog_height_density > 0.0,
		"fog: depth haze solid by %.1f km, and a cloud sea under the islands" % (nat.fog_end / 1000.0))
	check(nat.cloud_floor != null and nat.cloud_floor.global_position.y < -200.0, "fog: a cloud floor far below for the sea to settle on")
	check(np.cam.far > nat.fog_end and np.cam.far <= nat.fog_end + 250.0, "fog: the camera stops drawing just past the haze (%d m)" % roundi(np.cam.far))
	var culled: bool = nat.detail_nodes.size() > nw.islands.size() * 3
	for gi in nat.detail_nodes:
		culled = culled and gi.visibility_range_end > 0.0 and gi.visibility_range_end < nat.fog_end
	check(culled, "fog: every island's detail is its own batch (%d) and switches off inside the haze" % nat.detail_nodes.size())
	var max_extent := 0.0
	for gi in nat.detail_nodes:
		max_extent = maxf(max_extent, gi.get_aabb().size.length())
	check(max_extent < 1400.0, "fog: no detail batch spans more than one island (largest %d m)" % roundi(max_extent))
	await shot("39_nation_start")
	np.set_flying(true)
	check(np.flying and np.collision_mask == 0, "fly: F4 / V turns on noclip flight")
	check(nw.course_text().begins_with("DEV FLY"), "fly: the HUD shows speed, altitude and where you are")
	var fe0: float = nat.fog_end
	nat.tune_fog(KEY_BRACKETRIGHT)
	check(nat.fog_end == fe0 + 250.0 and np.cam.far > nat.fog_end, "fog: ] pushes the haze out (and the far plane with it)")
	nat.tune_fog(KEY_BRACKETLEFT)
	var sd0: float = nat.sea_density
	nat.tune_fog(KEY_EQUAL)
	check(nw.env.fog_height_density > sd0, "fog: = thickens the cloud sea")
	nat.tune_fog(KEY_MINUS)
	var fy0: float = np.global_position.y
	Input.action_press("jump")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("jump")
	check(np.global_position.y > fy0 + 30.0, "fly: Space rises (%d m in a second)" % roundi(np.global_position.y - fy0))
	var fz0: Vector3 = np.global_position * Vector3(1, 0, 1)
	Input.action_press("move_forward")
	Input.action_press("dash")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("dash")
	var flown: float = (np.global_position * Vector3(1, 0, 1)).distance_to(fz0)
	check(flown > 150.0, "fly: Shift flies five times faster (%d m in a second)" % roundi(flown))
	# up high over Delos, looking north-east toward Gordia
	np.velocity = Vector3.ZERO
	np.global_position = Vector3(0, 600, 900)
	np.look_at(nw.islands[1].position + Vector3(0, -400, 0) * 0.0, Vector3.UP)
	np.rotation.x = 0.0
	np.rotation.z = 0.0
	np.head.rotation.x = deg_to_rad(-14)
	for i in 10:
		await get_tree().physics_frame
	await shot("40_nation_over_delos")
	np.global_position = Vector3(-900, 1500, 3400)
	np.look_at(Vector3(400, 0, -300), Vector3.UP)
	np.rotation.x = 0.0
	np.rotation.z = 0.0
	np.head.rotation.x = deg_to_rad(-24)
	for i in 10:
		await get_tree().physics_frame
	await shot("41_nation_overview")
	var ln0: Dictionary = nw.nation.rails[0]
	np.global_position = ln0.o + ln0.dir * 60.0 + ln0.dir.cross(Vector3.UP).normalized() * 9.0 + Vector3(0, 6, 0)
	np.look_at(ln0.o - ln0.dir * 40.0, Vector3.UP)
	np.rotation.x = 0.0
	np.rotation.z = 0.0
	np.head.rotation.x = deg_to_rad(-12)
	for i in 10:
		await get_tree().physics_frame
	await shot("42_nation_station")
	var spn: Vector3 = nw.nation.spire.position
	var away: Vector3 = Vector3(spn.x, 0, spn.z).normalized()
	np.global_position = spn + away * 330.0 + Vector3(0, 120, 0)
	np.look_at(spn + Vector3(0, 110, 0), Vector3.UP)
	np.rotation.x = 0.0
	np.rotation.z = 0.0
	np.head.rotation.x = 0.0
	for i in 10:
		await get_tree().physics_frame
	await shot("46_nation_spire")
	np.set_flying(false)
	check(not np.flying and np.collision_mask != 0, "fly: F4 again lands you with collision back on")
	nw.queue_free()
	await get_tree().process_frame



func _test_spire() -> void:
	print("== Spire Town")
	Game.level = "spire_town"
	var sw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(sw)
	for i in 60:
		await get_tree().physics_frame
	var sp = sw.player
	var town = sw.spire
	check(town != null and sp.is_on_floor(), "spire: you start standing on the landing island")
	check(town.top_point().y > 230.0, "spire: the main tower's finial is the top of the town (%d m)" % roundi(town.top_point().y))
	check(town.shelves.size() >= 30, "spire: houses cling to both pillars (%d)" % town.shelves.size())
	check(sw.env.fog_height_density > 0.0 and sw.sky_id == "alien", "spire: lavender sky and a cloud sea below")
	var space = sw.get_world_3d().direct_space_state
	var hits := 0
	for probe in [Vector3(0, 70, 0), Vector3(-55, 200, 0), Vector3(50, 220, 0), Vector3(10, 180, 0)]:
		var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3(0, -60, 0), 1)
		if not space.intersect_ray(q).is_empty():
			hits += 1
	check(hits == 4, "spire: solid viaduct, palace, east tower and plank bridge (%d / 4)" % hits)
	# the east pillar's spiral walkway is a ramp you can walk up
	var a0 := PI + 0.4
	var r0: float = town.radius_at(town.EAST_LEVELS, 60.0) + 2.6
	sp.global_position = Vector3(town.EAST.x + cos(a0) * r0, 58.0, town.EAST.y + sin(a0) * r0)
	sp.velocity = Vector3.ZERO
	for i in 150:
		await get_tree().physics_frame
	var y_start: float = sp.global_position.y
	check(sp.is_on_floor(), "spire: you can stand on the spiral walkway")
	for i in 480:
		var a: float = atan2(sp.global_position.z - town.EAST.y, sp.global_position.x - town.EAST.x)
		var tangent := Vector3(-sin(a), 0, cos(a))
		sp.look_at(sp.global_position + tangent, Vector3.UP)
		sp.rotation.x = 0.0
		sp.rotation.z = 0.0
		Input.action_press("move_forward")
		await get_tree().physics_frame
	Input.action_release("move_forward")
	check(sp.global_position.y > y_start + 3.0, "spire: walking the spiral climbs (%.1f m in 4 s)" % (sp.global_position.y - y_start))
	# land somewhere high: a checkpoint
	sp.global_position = Vector3(town.WEST.x + 6.0, 156.0, town.WEST.y + 20.0)
	sp.velocity = Vector3.ZERO
	for i in 150:
		await get_tree().physics_frame
	check(sw.spire_best > 140.0 and sp.spawn.origin.y > 140.0, "spire: the highest place you've stood is your checkpoint")
	# the view from the landing island, like the painting
	sp.global_position = Vector3(2, 20, 240)
	sp.look_at(Vector3(-2, 130, 0), Vector3.UP)
	var pitch: float = sp.rotation.x
	sp.rotation.x = 0.0
	sp.rotation.z = 0.0
	sp.set_flying(true)
	sp.head.rotation.x = pitch
	for i in 10:
		await get_tree().physics_frame
	await shot("43_spire_town")
	sp.global_position = Vector3(-20, 130, 75)
	sp.look_at(Vector3(10, 120, 0), Vector3.UP)
	sp.rotation.x = 0.0
	sp.rotation.z = 0.0
	sp.head.rotation.x = deg_to_rad(4)
	for i in 10:
		await get_tree().physics_frame
	await shot("44_spire_close")
	sp.global_position = Vector3(-70, 175, 60)
	sp.look_at(Vector3(20, 160, 0), Vector3.UP)
	sp.rotation.x = 0.0
	sp.rotation.z = 0.0
	sp.head.rotation.x = deg_to_rad(-6)
	for i in 10:
		await get_tree().physics_frame
	await shot("45_spire_crown")
	sw.queue_free()
	await get_tree().process_frame


func _test_cloud_tree() -> void:
	print("== The Cloud Tree")
	Game.level = "cloud_tree"
	var tw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(tw)
	for i in 60:
		await get_tree().physics_frame
	var tp = tw.player
	var tree_n = tw.cloud_tree
	check(tree_n != null and tp.is_on_floor(), "cloud tree: you start on the meadow")
	check(tree_n.branches >= 30, "cloud tree: trunk, limbs and forks (%d pieces of wood)" % tree_n.branches)
	check(tree_n.puffs.size() >= 20, "cloud tree: a crown of cloud (%d solid puffs)" % tree_n.puffs.size())
	check(tree_n.top_point().y > 250.0, "cloud tree: it towers %d m over the meadow" % roundi(tree_n.top_point().y))
	var space = tw.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 60, 40), Vector3(0, 60, -40), 1)
	var hit: Dictionary = space.intersect_ray(q)
	check(not hit.is_empty() and not tp.is_magic(hit.collider), "cloud tree: the trunk is solid wood (costs a grapple)")
	var puff: Array = tree_n.puffs[tree_n.puffs.size() / 2]
	q = PhysicsRayQueryParameters3D.create(puff[0] + Vector3(0, 40, 0), puff[0], 1)
	hit = space.intersect_ray(q)
	check(not hit.is_empty() and tp.is_magic(hit.collider), "cloud tree: the clouds are solid magic (free to grapple)")
	# land on a high cloud: it's your checkpoint
	var high: Array = tree_n.puffs[0]
	for pf in tree_n.puffs:
		if pf[0].y > high[0].y:
			high = pf
	tp.global_position = high[0] + Vector3(0, high[1] * 0.45 + 3.0, 0)
	tp.velocity = Vector3.ZERO
	for i in 150:
		await get_tree().physics_frame
	check(tp.is_on_floor() and tw.spire_best > 200.0, "cloud tree: you can stand on the clouds, and the highest is your checkpoint (%d m)" % roundi(tw.spire_best))
	# the painting's view: from the meadow, looking up at the whole tree
	tp.set_flying(true)
	tp.global_position = Vector3(30, 3, 215)
	tp.look_at(Vector3(0, 3, 0), Vector3.UP)
	tp.rotation.x = 0.0
	tp.rotation.z = 0.0
	tp.head.rotation.x = deg_to_rad(40)
	for i in 10:
		await get_tree().physics_frame
	await shot("47_cloud_tree")
	tp.global_position = Vector3(-60, 190, 120)
	tp.look_at(Vector3(0, 210, 0), Vector3.UP)
	tp.rotation.x = 0.0
	tp.rotation.z = 0.0
	tp.head.rotation.x = deg_to_rad(5)
	for i in 10:
		await get_tree().physics_frame
	await shot("48_cloud_tree_crown")
	tw.queue_free()
	await get_tree().process_frame


func _test_citadel() -> void:
	print("== The White Citadel")
	Game.level = "white_citadel"
	var cw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(cw)
	for i in 60:
		await get_tree().physics_frame
	var cp = cw.player
	var cit = cw.citadel
	check(cit != null and cp.is_on_floor(), "citadel: you start on the jetty")
	check(cit.top_point().y > 180.0, "citadel: the clock tower's crown-spire tops the city (%d m)" % roundi(cit.top_point().y))
	check(cit.stairs.size() == 2, "citadel: two grand stairs climb out of the lake")
	# walk up a grand stair from the water to the plinth
	var st: Array = cit.stairs[1]
	var foot: Vector3 = cit.global_position + st[0] + Vector3(0, 1.5, -2)
	cp.global_position = foot
	cp.velocity = Vector3.ZERO
	cp.rotation = Vector3.ZERO                   # facing -z: up the stair
	cp.head.rotation.x = 0.0
	for i in 60:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for i in 900:
		await get_tree().physics_frame
		if cp.global_position.y > 14.0:
			break
	Input.action_release("move_forward")
	check(cp.global_position.y > 14.0, "citadel: you can walk up the grand stair to the plinth (%d m)" % roundi(cp.global_position.y))
	var space = cw.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(48, 200, -34), Vector3(48, 100, -34), 1)
	check(not space.intersect_ray(q).is_empty(), "citadel: the sky bridge is solid")
	cp.set_flying(true)
	cp.global_position = Vector3(10, 30, 330)
	cp.look_at(Vector3(5, 30, 0), Vector3.UP)
	cp.rotation.x = 0.0
	cp.rotation.z = 0.0
	cp.head.rotation.x = deg_to_rad(16)
	for i in 10:
		await get_tree().physics_frame
	await shot("49_white_citadel")
	cp.global_position = Vector3(-70, 110, 120)
	cp.look_at(Vector3(20, 120, -20), Vector3.UP)
	cp.rotation.x = 0.0
	cp.rotation.z = 0.0
	cp.head.rotation.x = deg_to_rad(4)
	for i in 10:
		await get_tree().physics_frame
	await shot("50_white_citadel_close")
	cw.queue_free()
	await get_tree().process_frame


func _test_keep() -> void:
	print("== The Keep Isles")
	Game.level = "keep_isles"
	var kw = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(kw)
	for i in 60:
		await get_tree().physics_frame
	var kp = kw.player
	var kk = kw.keep
	check(kk != null and kp.is_on_floor(), "keep: you start on the left isle")
	check(kk.isles.size() == 3 and kk.bridges.size() == 2, "keep: three little isles, two joined by plank bridges")
	check(kk.top_point().y > 160.0, "keep: the tower's banner tops the keep (%d m)" % roundi(kk.top_point().y))
	var space = kw.get_world_3d().direct_space_state
	var probe := Vector3(-50, 120, 40)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, probe + Vector3(0, -140, 0), 1))
	var want: float = kk.hill_y(-50.0, 40.0)
	check(not hit.is_empty() and absf(hit.position.y - want) < 4.0, "keep: the hill is a solid dome you can walk on (%.0f m, expected %.0f)" % [hit.get("position", Vector3.ZERO).y, want])
	# walk the left bridge to the hillside town
	var br: Array = kk.bridges[0]
	var a: Vector3 = br[0]
	var b: Vector3 = br[1]
	kp.global_position = a + Vector3(0, 1.5, 0) + (b - a).normalized() * 2.0
	kp.velocity = Vector3.ZERO
	kp.look_at(kp.global_position + Vector3(b.x - a.x, 0, b.z - a.z), Vector3.UP)
	kp.rotation.x = 0.0
	kp.rotation.z = 0.0
	for i in 60:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for i in 1500:
		await get_tree().physics_frame
		if Vector2(kp.global_position.x - b.x, kp.global_position.z - b.z).length() < 6.0:
			break
	Input.action_release("move_forward")
	check(Vector2(kp.global_position.x - b.x, kp.global_position.z - b.z).length() < 8.0 and kp.global_position.y > a.y,
		"keep: you can walk the plank bridge up to the hillside town")
	kp.set_flying(true)
	kp.global_position = Vector3(10, 60, 380)
	kp.look_at(Vector3(0, 55, 0), Vector3.UP)
	kp.rotation.x = 0.0
	kp.rotation.z = 0.0
	kp.head.rotation.x = deg_to_rad(6)
	for i in 10:
		await get_tree().physics_frame
	await shot("51_keep_isles")
	kp.global_position = Vector3(-130, 95, 110)
	kp.look_at(Vector3(0, 110, 0), Vector3.UP)
	kp.rotation.x = 0.0
	kp.rotation.z = 0.0
	kp.head.rotation.x = deg_to_rad(3)
	for i in 10:
		await get_tree().physics_frame
	await shot("52_keep_close")
	kw.queue_free()
	await get_tree().process_frame
