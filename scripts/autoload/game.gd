extends Node
## Global game state (autoload "Game"): the input map, and whether the player
## currently has control or a menu / dialogue / editor has taken it.

signal ui_mode_changed(mode: String)

## "play", "pause", "dialogue", "editor", "log" or "menu"
var ui_mode := "play"
## Which level the world scene builds (see scripts/world/levels.gd)
var level := "range"

const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/level_select.tscn"


func play_level(id: String) -> void:
	level = id
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


func to_level_select() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	set_ui_mode("menu")
	get_tree().change_scene_to_file(MENU_SCENE)


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func set_ui_mode(mode: String) -> void:
	ui_mode = mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "play" else Input.MOUSE_MODE_VISIBLE
	get_tree().paused = mode == "pause" or mode == "log"
	ui_mode_changed.emit(mode)


func playing() -> bool:
	return ui_mode == "play"


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"dash": [KEY_SHIFT],
		"reel_in": [KEY_Q],
		"reel_out": [KEY_E, KEY_CTRL],
		"interact": [KEY_E, KEY_F],
		"restart": [KEY_R],
		"pause": [KEY_ESCAPE],
		"toggle_editor": [KEY_F2],
		"perf": [KEY_F3],
		"dev_fly": [KEY_F4, KEY_V],
		"logbook": [KEY_L, KEY_TAB, KEY_J],
	}
	var mouse := {
		"grapple": [MOUSE_BUTTON_LEFT],
		"reel_in": [MOUSE_BUTTON_RIGHT],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for b in mouse[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)
