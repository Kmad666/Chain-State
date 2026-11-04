@tool
extends EditorPlugin
## Unattended lightmap baking (tools/bake.sh). Does nothing unless the editor was
## started with BAKE_SCENE set: then it opens that scene, presses the editor's own
## Bake Lightmaps button, answers the save dialog with <scene>.lmbake, waits for the
## bake, saves the scene and quits.
##
## Baking needs the Vulkan renderer (the game itself runs on Compatibility, which
## renders the baked lightmaps fine): bake.sh starts the editor with forward_plus.


func _enter_tree() -> void:
	var scene := OS.get_environment("BAKE_SCENE")
	if scene != "":
		_run.call_deferred(scene)


func _find_button(n: Node) -> Button:
	if n is Button and "Bake Lightmaps" in (n as Button).text:
		return n
	for c in n.get_children():
		var b := _find_button(c)
		if b:
			return b
	return null


func _run(scene: String) -> void:
	for i in 30:
		await get_tree().process_frame
	EditorInterface.open_scene_from_path(scene)
	for i in 30:
		await get_tree().process_frame
	EditorInterface.set_main_screen_editor("3D")
	var root := EditorInterface.get_edited_scene_root()
	var lms := root.find_children("*", "LightmapGI", true, false)
	if lms.is_empty():
		printerr("[autobake] no LightmapGI in ", scene)
		get_tree().quit(1)
		return
	var lm := lms[0] as LightmapGI
	EditorInterface.edit_node(lm)
	for i in 10:
		await get_tree().process_frame
	var b := _find_button(EditorInterface.get_base_control())
	if b == null:
		printerr("[autobake] no Bake Lightmaps button")
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	print("[autobake] baking ", scene)
	b.pressed.emit()
	for i in 20:
		await get_tree().process_frame
	for d in EditorInterface.get_base_control().get_window().find_children("*", "EditorFileDialog", true, false):
		if (d as Window).visible and "lightmap" in (d as Window).title.to_lower():
			d.hide()
			d.file_selected.emit(scene.get_basename() + ".lmbake")
	while lm.light_data == null and Time.get_ticks_msec() - t0 < 4 * 3600 * 1000:
		await get_tree().create_timer(2.0).timeout
	if lm.light_data == null:
		printerr("[autobake] bake timed out")
		get_tree().quit(1)
		return
	print("[autobake] baked in %.0f s: %s" % [(Time.get_ticks_msec() - t0) / 1000.0, lm.light_data.resource_path])
	EditorInterface.save_scene()
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(0)
