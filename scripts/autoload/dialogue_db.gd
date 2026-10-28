extends Node
## Dialogue trees, one JSON file per NPC (autoload "DialogueDB").
##
## Format (dialogue/<npc_id>.json):
## {
##   "npc_id": "test_npc",
##   "name": "NPC",                       # shown as the speaker by default
##   "start": "start",                    # id of the first line
##   "nodes": {
##     "start": {
##       "speaker": "NPC",                # "" = use the NPC's name
##       "text": "test test test",
##       "pos": [x, y],                   # where the editor draws it
##       "choices": [ {"text": "Option A", "next": "a"}, ... ]
##     }
##   }
## }
## A choice whose "next" is "" (or points nowhere) ends the conversation.
## A line with no choices shows a single "[Leave]" choice.
##
## Where saves go:
##   - running from the Godot editor: straight into the project's dialogue/ folder,
##     so the file is committed with the game
##   - an exported build: user://dialogue/ (overrides the shipped file), plus the
##     editor can download / copy the JSON so it can be added to the project

const PROJECT_DIR := "res://dialogue/"
const USER_DIR := "user://dialogue/"

var _cache := {}


func has_tree(npc_id: String) -> bool:
	return _cache.has(npc_id) or FileAccess.file_exists(_user_path(npc_id)) \
		or FileAccess.file_exists(_project_path(npc_id))


## Returns a deep copy of the NPC's tree (a fresh starter tree if none exists).
func load_tree(npc_id: String, display_name := "NPC") -> Dictionary:
	if not _cache.has(npc_id):
		var data := {}
		for path in [_user_path(npc_id), _project_path(npc_id)]:
			if FileAccess.file_exists(path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
				if parsed is Dictionary and parsed.has("nodes"):
					data = parsed
					break
				push_warning("Dialogue file is not valid: %s" % path)
		if data.is_empty():
			data = starter_tree(npc_id, display_name)
		_cache[npc_id] = normalize(data, npc_id, display_name)
	return _cache[npc_id].duplicate(true)


## Saves the tree and returns the path written ("" on failure).
func save_tree(npc_id: String, data: Dictionary) -> String:
	data = normalize(data.duplicate(true), npc_id, str(data.get("name", "NPC")))
	_cache[npc_id] = data
	var text := to_json(data)
	var path := _project_path(npc_id) if OS.has_feature("editor") else _user_path(npc_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Couldn't save dialogue to %s (error %d)" % [path, FileAccess.get_open_error()])
		return ""
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)


## Drops a saved override so the shipped project file is used again.
func revert_tree(npc_id: String) -> void:
	_cache.erase(npc_id)
	if not OS.has_feature("editor") and FileAccess.file_exists(_user_path(npc_id)):
		DirAccess.remove_absolute(_user_path(npc_id))


func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ", false)


## Fills in missing fields so the rest of the game can trust the shape.
func normalize(data: Dictionary, npc_id: String, display_name: String) -> Dictionary:
	data["npc_id"] = npc_id
	if not data.has("name"):
		data["name"] = display_name
	if not data.get("nodes") is Dictionary:
		data["nodes"] = {}
	var nodes: Dictionary = data["nodes"]
	for id in nodes.keys():
		var n = nodes[id]
		if not n is Dictionary:
			n = {}
			nodes[id] = n
		n["speaker"] = str(n.get("speaker", ""))
		n["text"] = str(n.get("text", ""))
		if not n.get("pos") is Array or n["pos"].size() < 2:
			n["pos"] = [0, 0]
		var choices: Array = []
		if n.get("choices") is Array:
			for c in n["choices"]:
				if c is Dictionary:
					choices.append({"text": str(c.get("text", "")), "next": str(c.get("next", ""))})
		n["choices"] = choices
	if nodes.is_empty():
		nodes["start"] = {"speaker": "", "text": "...", "pos": [0, 0], "choices": []}
	if not nodes.has(str(data.get("start", ""))):
		data["start"] = nodes.keys()[0]
	return data


func starter_tree(npc_id: String, display_name: String) -> Dictionary:
	return {
		"npc_id": npc_id, "name": display_name, "start": "start",
		"nodes": {"start": {"speaker": "", "text": "...", "pos": [0, 0], "choices": [{"text": "[Leave]", "next": ""}]}},
	}


func _project_path(npc_id: String) -> String:
	return PROJECT_DIR + npc_id + ".json"


func _user_path(npc_id: String) -> String:
	return USER_DIR + npc_id + ".json"
