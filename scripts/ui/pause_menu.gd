extends Control
## Esc menu: controls, physics presets and live sliders for every feel value.
## Tuning is saved to user://tuning.json so it survives restarts.

signal editor_requested
signal sky_selected(id: String)

const SAVE_PATH := "user://tuning.json"

var player: Node
var _sliders := {}
var _preset_desc: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Game.ui_mode_changed.connect(func(mode): visible = mode == "pause")

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	center.add_child(row)

	# left: title, controls, presets
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 440
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	left.add_child(title)
	var help := Label.new()
	help.text = "Mouse — look\n" \
		+ "Hold Left Click — fire the silver chain at any surface\n" \
		+ "Release — let go     Space — jump / reel in while hooked\n" \
		+ "Right Click / wheel up — reel in     Q / Ctrl / wheel down — reel out\n" \
		+ "WASD — walk, steer in the air, push while swinging\n" \
		+ "Shift — dash where you look     R — back to start\n" \
		+ "E or Left Click on an NPC — talk     F2 — dialogue editor\n" \
		+ "Esc — pause"
	help.add_theme_font_size_override("font_size", 16)
	left.add_child(help)
	left.add_child(HSeparator.new())
	var pt := Label.new()
	pt.text = "PHYSICS PRESET"
	pt.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	left.add_child(pt)
	var pr := HBoxContainer.new()
	left.add_child(pr)
	for p in preload("res://scripts/player/player.gd").PRESETS:
		var b := Button.new()
		b.text = p.name
		b.pressed.connect(func(): _apply_preset(p))
		pr.add_child(b)
	_preset_desc = Label.new()
	_preset_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_desc.custom_minimum_size.x = 420
	left.add_child(_preset_desc)
	var st := Label.new()
	st.text = "SKY"
	st.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	left.add_child(st)
	var skies := HBoxContainer.new()
	left.add_child(skies)
	for id in ["day", "morning", "night", "space", "alien"]:
		var sb := Button.new()
		sb.text = id.capitalize()
		sb.pressed.connect(func(): sky_selected.emit(id))
		skies.add_child(sb)
	var br := HBoxContainer.new()
	left.add_child(br)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func(): Game.set_ui_mode("play"))
	br.add_child(resume)
	var reset := Button.new()
	reset.text = "Reset tuning"
	reset.pressed.connect(_reset_tuning)
	br.add_child(reset)
	var editor := Button.new()
	editor.text = "Dialogue editor (F2)"
	editor.pressed.connect(func(): editor_requested.emit())
	br.add_child(editor)

	# right: one slider per tuning value
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 420
	row.add_child(right)
	var tt := Label.new()
	tt.text = "FEEL TUNING"
	tt.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	right.add_child(tt)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	right.add_child(grid)
	for spec in preload("res://scripts/player/player.gd").TUNING:
		var l := Label.new()
		l.text = spec.label
		grid.add_child(l)
		var s := HSlider.new()
		s.min_value = spec.min
		s.max_value = spec.max
		s.step = spec.step
		s.custom_minimum_size.x = 200
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(s)
		var v := Label.new()
		v.custom_minimum_size.x = 56
		grid.add_child(v)
		var key: String = spec.key
		s.value_changed.connect(func(x):
			v.text = _fmt(x, spec.step)
			if player:
				player.tune[key] = x
				_save())
		_sliders[key] = [s, v, spec.step]


static func _fmt(x: float, step: float) -> String:
	return str(int(x)) if step >= 1.0 else ("%.2f" % x)


var _defaults := {}

## Call once the player exists: remembers defaults and loads saved tuning.
func bind(p: Node) -> void:
	player = p
	_defaults = p.tune.duplicate()
	if FileAccess.file_exists(SAVE_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if saved is Dictionary:
			p.apply_values(saved)
	_refresh()


func _refresh() -> void:
	for key in _sliders:
		var s: HSlider = _sliders[key][0]
		s.set_value_no_signal(player.tune[key])
		_sliders[key][1].text = _fmt(player.tune[key], _sliders[key][2])
	_preset_desc.text = ""


func _apply_preset(p: Dictionary) -> void:
	player.apply_values(p["values"])
	_refresh()
	_preset_desc.text = "%s: %s" % [p.name, p.desc]
	_save()


func _reset_tuning() -> void:
	player.apply_values(_defaults)
	_refresh()
	_save()


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(player.tune))
