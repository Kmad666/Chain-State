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
	Game.level = "range"

	print("== %s" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails else 0)


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % name)
