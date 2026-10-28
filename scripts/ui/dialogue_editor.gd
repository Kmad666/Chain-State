extends Control
## In-game dialogue tree editor (F2). Pick an NPC, then build its conversation
## as a graph: each box is one line the NPC says, each choice in the box has a
## socket on the right, and you drag from a socket to another box's left socket
## to say where that choice leads. A choice with no link ends the conversation.
##
##   + Line          add a box (or drag a choice socket into empty space)
##   Set start       make the selected box the opening line
##   Delete / Del    remove the selected boxes
##   Save / Ctrl+S   write dialogue/<npc_id>.json (see DialogueDB for where)
##   Play test       try the conversation as it is right now, saved or not
##
## Edits to each NPC are kept while you switch between NPCs, until you Save or Revert.

signal play_test_requested(data: Dictionary)
signal close_requested

const IN_COLOR := Color(0.55, 0.75, 1.0)
const OUT_COLOR := Color(0.95, 0.55, 0.3)
const START_TINT := Color(1.0, 0.85, 0.5)

var npc_id := ""
var data := {}
var _working := {}       # npc_id -> edited tree not yet saved
var _dirty := {}         # npc_id -> true
var _npcs: Array = []    # [{id, name}]

var _graph: GraphEdit
var _npc_pick: OptionButton
var _name_edit: LineEdit
var _status: Label
var _save_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.11, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 8
	col.offset_bottom = -6
	add_child(col)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	var title := Label.new()
	title.text = "DIALOGUE EDITOR"
	title.add_theme_color_override("font_color", OUT_COLOR)
	bar.add_child(title)
	bar.add_child(VSeparator.new())
	bar.add_child(_lbl("NPC"))
	_npc_pick = OptionButton.new()
	_npc_pick.custom_minimum_size.x = 160
	_npc_pick.item_selected.connect(func(i): _select_npc(_npcs[i].id))
	bar.add_child(_npc_pick)
	bar.add_child(_lbl("Name"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 140
	_name_edit.text_changed.connect(func(t): data["name"] = t; _mark_dirty(); _refresh_speaker_placeholders())
	bar.add_child(_name_edit)
	bar.add_child(VSeparator.new())
	_btn(bar, "+ Line", _add_line_at_center)
	_btn(bar, "Set start", _set_start)
	_btn(bar, "Delete", func(): _delete_nodes(_selected_ids()))
	bar.add_child(VSeparator.new())
	_save_btn = _btn(bar, "Save", save)
	_btn(bar, "Revert", _revert)
	_btn(bar, "Play test", func(): play_test_requested.emit(_synced().duplicate(true)))
	_btn(bar, "Copy JSON", _copy_json)
	_btn(bar, "Download" if OS.has_feature("web") else "Open folder", _export)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_btn(bar, "Close  [F2]", func(): close_requested.emit())

	_graph = GraphEdit.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = true
	_graph.minimap_enabled = true
	_graph.show_arrange_button = false
	_graph.connection_request.connect(_on_connect)
	_graph.disconnection_request.connect(_on_disconnect)
	_graph.connection_to_empty.connect(_on_connect_to_empty)
	_graph.delete_nodes_request.connect(func(names): _delete_nodes(names.map(func(n): return str(n))))
	_graph.end_node_move.connect(func(): _sync_positions(); _mark_dirty())
	col.add_child(_graph)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	col.add_child(_status)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _btn(parent: Node, t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- open / NPCs
## Opens the editor on `focus_id` (or the first NPC). `npcs` = [{id, name}].
func open(npcs: Array, focus_id := "") -> void:
	_npcs = npcs.duplicate()
	# also list dialogue files that exist for NPCs not in this scene
	var dir := DirAccess.open(DialogueDB.PROJECT_DIR)
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				var id := f.get_basename()
				if not _npcs.any(func(n): return n.id == id):
					_npcs.append({"id": id, "name": id})
	_npc_pick.clear()
	for n in _npcs:
		_npc_pick.add_item("%s  (%s)" % [n.name, n.id])
	visible = true
	if _npcs.is_empty():
		_status.text = "No NPCs in this scene."
		return
	var idx := 0
	for i in _npcs.size():
		if _npcs[i].id == focus_id:
			idx = i
	_npc_pick.select(idx)
	_select_npc(_npcs[idx].id)


func _select_npc(id: String) -> void:
	if npc_id != "" and not data.is_empty():
		_working[npc_id] = _synced()
	npc_id = id
	var display := id
	for n in _npcs:
		if n.id == id:
			display = n.name
	data = _working[id] if _working.has(id) else DialogueDB.load_tree(id, display)
	_name_edit.text = str(data.get("name", display))
	_rebuild()
	_frame_all.call_deferred()
	_update_status("Editing %s." % id)


## Scroll so every box is in view (zooming out if needed).
func _frame_all() -> void:
	var r := Rect2()
	var first := true
	for gn in _graph.get_children():
		if gn is GraphNode:
			var b := Rect2(gn.position_offset, gn.size)
			r = b if first else r.merge(b)
			first = false
	if first:
		return
	r = r.grow(40)
	var z := clampf(minf(_graph.size.x / r.size.x, _graph.size.y / r.size.y), 0.5, 1.0)
	_graph.zoom = z
	_graph.scroll_offset = r.position * z


# ---------------------------------------------------------------- graph build
func _rebuild() -> void:
	_graph.clear_connections()
	for c in _graph.get_children():
		if c is GraphNode:
			_graph.remove_child(c)
			c.queue_free()
	var nodes: Dictionary = data.nodes
	for id in nodes:
		_graph.add_child(_make_node(id, nodes[id]))
	for id in nodes:
		var choices: Array = nodes[id].choices
		for i in choices.size():
			var next := str(choices[i].next)
			if next != "" and nodes.has(next):
				_graph.connect_node(id, i, next, 0)
	_refresh_save_label()


func _make_node(id: String, n: Dictionary) -> GraphNode:
	var gn := GraphNode.new()
	gn.name = id
	var is_start: bool = data.start == id
	gn.title = ("★ START   " if is_start else "") + id
	if is_start:
		gn.self_modulate = START_TINT
	gn.position_offset = Vector2(float(n.pos[0]), float(n.pos[1]))
	gn.custom_minimum_size.x = 340

	# row 0: speaker (the left socket = "lines that lead here")
	var row := HBoxContainer.new()
	row.add_child(_lbl("Speaker"))
	var sp := LineEdit.new()
	sp.text = n.speaker
	sp.placeholder_text = str(data.get("name", "NPC"))
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.set_meta("speaker", true)
	sp.text_changed.connect(func(t): n.speaker = t; _mark_dirty())
	row.add_child(sp)
	gn.add_child(row)

	# row 1: what they say
	var te := TextEdit.new()
	te.text = n.text
	te.placeholder_text = "What they say…"
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(320, 96)
	te.text_changed.connect(func(): n.text = te.text; _mark_dirty())
	gn.add_child(te)

	# rows 2..: choices, each with a right socket
	var choices: Array = n.choices
	for i in choices.size():
		var c: Dictionary = choices[i]
		var cr := HBoxContainer.new()
		var num := _lbl("%d." % (i + 1))
		num.add_theme_color_override("font_color", OUT_COLOR)
		cr.add_child(num)
		var ce := LineEdit.new()
		ce.text = c.text
		ce.placeholder_text = "Choice text"
		ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ce.text_changed.connect(func(t): c.text = t; _mark_dirty())
		cr.add_child(ce)
		var up := Button.new()
		up.text = "↑"
		up.tooltip_text = "Move choice up"
		up.disabled = i == 0
		up.pressed.connect(func(): _move_choice(id, i, -1))
		cr.add_child(up)
		var x := Button.new()
		x.text = "✕"
		x.tooltip_text = "Remove choice"
		x.pressed.connect(func(): _sync_positions(); choices.remove_at(i); _mark_dirty(); _rebuild())
		cr.add_child(x)
		gn.add_child(cr)

	var add := Button.new()
	add.text = "+ Choice"
	add.pressed.connect(func(): _sync_positions(); choices.append({"text": "", "next": ""}); _mark_dirty(); _rebuild())
	gn.add_child(add)
	if choices.is_empty():
		var hint := _lbl("No choices: the player gets [Leave].")
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		hint.add_theme_font_size_override("font_size", 12)
		gn.add_child(hint)

	gn.set_slot(0, true, 0, IN_COLOR, false, 0, Color.WHITE)
	for i in choices.size():
		gn.set_slot(2 + i, false, 0, Color.WHITE, true, 0, OUT_COLOR)
	return gn


func _move_choice(id: String, i: int, d: int) -> void:
	var choices: Array = data.nodes[id].choices
	var j := i + d
	if j < 0 or j >= choices.size():
		return
	_sync_positions()
	var t = choices[i]
	choices[i] = choices[j]
	choices[j] = t
	_mark_dirty()
	_rebuild()


func _refresh_speaker_placeholders() -> void:
	for gn in _graph.get_children():
		if gn is GraphNode:
			for le in gn.find_children("*", "LineEdit", true, false):
				if le.has_meta("speaker"):
					le.placeholder_text = str(data.get("name", "NPC"))


# ---------------------------------------------------------------- graph edits
func _on_connect(from: StringName, from_port: int, to: StringName, _to_port: int) -> void:
	# a choice leads to exactly one line: drop its old link first
	for c in _graph.get_connection_list():
		if c.from_node == from and c.from_port == from_port:
			_graph.disconnect_node(c.from_node, c.from_port, c.to_node, c.to_port)
	_graph.connect_node(from, from_port, to, 0)
	data.nodes[str(from)].choices[from_port].next = str(to)
	_mark_dirty()


func _on_disconnect(from: StringName, from_port: int, to: StringName, to_port: int) -> void:
	_graph.disconnect_node(from, from_port, to, to_port)
	var choices: Array = data.nodes[str(from)].choices
	if from_port < choices.size():
		choices[from_port].next = ""
	_mark_dirty()


## Dragging a choice into empty space makes a new line there, already linked.
func _on_connect_to_empty(from: StringName, from_port: int, release_pos: Vector2) -> void:
	var pos := (release_pos + _graph.scroll_offset) / _graph.zoom
	var id := _new_line(pos)
	data.nodes[str(from)].choices[from_port].next = id
	_sync_positions()
	_rebuild()


func _add_line_at_center() -> void:
	var pos := (_graph.scroll_offset + _graph.size * 0.5) / _graph.zoom - Vector2(170, 80)
	_sync_positions()
	var id := _new_line(pos)
	_rebuild()
	_select_only(id)


func _new_line(pos: Vector2) -> String:
	var i: int = data.nodes.size() + 1
	while data.nodes.has("line_%d" % i):
		i += 1
	var id := "line_%d" % i
	data.nodes[id] = {"speaker": "", "text": "", "pos": [pos.x, pos.y], "choices": []}
	_mark_dirty()
	return id


func _delete_nodes(ids: Array) -> void:
	if ids.is_empty():
		_update_status("Select a box first (click its title).")
		return
	_sync_positions()
	for id in ids:
		data.nodes.erase(id)
	for n in data.nodes.values():
		for c in n.choices:
			if ids.has(c.next):
				c.next = ""
	if data.nodes.is_empty():
		data.nodes["start"] = {"speaker": "", "text": "", "pos": [0, 0], "choices": []}
	if not data.nodes.has(data.start):
		data.start = data.nodes.keys()[0]
	_mark_dirty()
	_rebuild()


func _set_start() -> void:
	var sel := _selected_ids()
	if sel.size() != 1:
		_update_status("Select one box to make it the opening line.")
		return
	_sync_positions()
	data.start = sel[0]
	_mark_dirty()
	_rebuild()


func _selected_ids() -> Array:
	var out := []
	for gn in _graph.get_children():
		if gn is GraphNode and gn.selected:
			out.append(str(gn.name))
	return out


func _select_only(id: String) -> void:
	for gn in _graph.get_children():
		if gn is GraphNode:
			gn.selected = str(gn.name) == id


func _sync_positions() -> void:
	for gn in _graph.get_children():
		if gn is GraphNode and data.nodes.has(str(gn.name)):
			data.nodes[str(gn.name)].pos = [roundf(gn.position_offset.x), roundf(gn.position_offset.y)]


## The tree as it stands, with box positions written back in.
func _synced() -> Dictionary:
	_sync_positions()
	return data


# ---------------------------------------------------------------- save / export
func save() -> void:
	var path := DialogueDB.save_tree(npc_id, _synced())
	if path == "":
		_update_status("Couldn't save. See the output log for the error.")
		return
	_working.erase(npc_id)
	_dirty.erase(npc_id)
	data = DialogueDB.load_tree(npc_id)
	_rebuild()
	var where := "project file" if OS.has_feature("editor") else "this computer (Download/Copy JSON to add it to the project)"
	_update_status("Saved %s to %s:  %s" % [npc_id, where, path])


func _revert() -> void:
	DialogueDB.revert_tree(npc_id)
	_working.erase(npc_id)
	_dirty.erase(npc_id)
	data = DialogueDB.load_tree(npc_id, str(data.get("name", npc_id)))
	_name_edit.text = str(data.name)
	_rebuild()
	_update_status("Reverted %s to the last saved version." % npc_id)


func _copy_json() -> void:
	DisplayServer.clipboard_set(DialogueDB.to_json(_synced()))
	_update_status("Copied %s's dialogue JSON to the clipboard." % npc_id)


func _export() -> void:
	var text := DialogueDB.to_json(_synced())
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), npc_id + ".json", "application/json")
		_update_status("Downloaded %s.json. Put it in the project's dialogue/ folder." % npc_id)
	else:
		var dir := DialogueDB.PROJECT_DIR if OS.has_feature("editor") else DialogueDB.USER_DIR
		DirAccess.make_dir_recursive_absolute(dir)
		OS.shell_open(ProjectSettings.globalize_path(dir))


func _mark_dirty() -> void:
	_dirty[npc_id] = true
	_refresh_save_label()


func _refresh_save_label() -> void:
	_save_btn.text = "Save *" if _dirty.has(npc_id) else "Save"


func _update_status(t: String) -> void:
	var dead := 0
	for n in data.get("nodes", {}).values():
		for c in n.choices:
			if c.next != "" and not data.nodes.has(c.next):
				dead += 1
	_status.text = t + ("   ⚠ %d choice(s) point to a missing line." % dead if dead else "") \
		+ "   ·   Drag from an orange socket to a blue one to link. Drop in empty space to make a new line."


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.physical_keycode == KEY_S:
		save()
		get_viewport().set_input_as_handled()
