extends Node
## Performance benchmark. Loads each level, lets it settle, then samples frames.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/bench.tscn
##   LEVELS=copper_kettle,city  to bench only some.
## Prints one line per level: load time, frame time, draw calls, objects, triangles,
## physics time, collision faces and shadow casters.

const SETTLE := 60
const SAMPLE := 120


func _ready() -> void:
	await get_tree().process_frame
	var ids: Array = []
	if OS.get_environment("LEVELS") != "":
		ids = Array(OS.get_environment("LEVELS").split(","))
	else:
		for l in Levels.LIST:
			ids.append(l.id)
	print("BENCH level                load_ms  frame_ms  p95_ms  draws  objs  tris_k  phys_ms  coll_faces_k  shapes  meshes  shadow_casters")
	for id in ids:
		await _bench(id)
	get_tree().quit(0)


func _bench(id: String) -> void:
	Game.level = id
	var t0 := Time.get_ticks_usec()
	var w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(w)
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	for i in SETTLE:
		await get_tree().process_frame
	var frames: Array = []
	var draws := 0.0
	var objs := 0.0
	var prims := 0.0
	var phys := 0.0
	var last := Time.get_ticks_usec()
	for i in SAMPLE:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	frames.sort()
	var mean := 0.0
	for f in frames:
		mean += f
	mean /= frames.size()
	var faces := 0
	var shapes := 0
	for cs in w.find_children("*", "CollisionShape3D", true, false):
		shapes += 1
		var s = cs.shape
		if s is ConcavePolygonShape3D:
			faces += s.get_faces().size() / 3
	var meshes := 0
	var casters := 0
	for mi in w.find_children("*", "GeometryInstance3D", true, false):
		meshes += 1
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mi.visible:
			casters += 1
	print("BENCH %-20s %7.0f  %8.1f  %6.1f  %5d  %4d  %6.0f  %7.2f  %12.1f  %6d  %6d  %6d" % [id, load_ms, mean,
		frames[int(frames.size() * 0.95)], roundi(draws / SAMPLE), roundi(objs / SAMPLE), prims / SAMPLE / 1000.0,
		phys / SAMPLE, faces / 1000.0, shapes, meshes, casters])
	w.queue_free()
	for i in 3:
		await get_tree().process_frame
	Game.level = "range"
