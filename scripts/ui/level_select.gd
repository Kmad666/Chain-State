extends Control
## Level select: the first screen. A navy Federal Chain case folder listing the
## levels in scripts/world/levels.gd. Click one (or press its number) to play.

const NAVY := Color(0.09, 0.15, 0.29)
const NAVY_2 := Color(0.12, 0.20, 0.38)
const PAPER := Color(0.95, 0.96, 0.98)
const SOFT := Color(0.95, 0.96, 0.98, 0.62)
const STAMP := Color(0.94, 0.65, 0.60)

var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.set_ui_mode("menu")

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var folder := VBoxContainer.new()
	folder.add_theme_constant_override("separation", 0)
	center.add_child(folder)

	# folder tab
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ts := StyleBoxFlat.new()
	ts.bg_color = NAVY
	ts.corner_radius_top_left = 10
	ts.corner_radius_top_right = 10
	ts.content_margin_left = 20
	ts.content_margin_right = 20
	ts.content_margin_top = 8
	ts.content_margin_bottom = 6
	tab.add_theme_stylebox_override("panel", ts)
	folder.add_child(tab)
	tab.add_child(_label("FEDERAL CHAIN  ·  CASE FILE", 14, SOFT))

	# cover
	var cover := PanelContainer.new()
	cover.custom_minimum_size = Vector2(720, 0)
	var cs := StyleBoxFlat.new()
	cs.bg_color = NAVY
	cs.corner_radius_top_right = 12
	cs.corner_radius_bottom_left = 12
	cs.corner_radius_bottom_right = 12
	cs.set_content_margin_all(40)
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size = 24
	cover.add_theme_stylebox_override("panel", cs)
	folder.add_child(cover)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	cover.add_child(col)
	col.add_child(_label("FILE NO. FC-1871-001      STATUS  OPEN", 13, SOFT))
	col.add_child(_label("Chain State", 64, PAPER))
	col.add_child(_label("Select a level", 20, SOFT))
	var rule := ColorRect.new()
	rule.color = Color(PAPER, 0.25)
	rule.custom_minimum_size.y = 1
	col.add_child(rule)

	for i in Levels.LIST.size():
		var l: Dictionary = Levels.LIST[i]
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 64
		b.text = "%d   %s\n     %s" % [i + 1, l.name, l.blurb]
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", PAPER)
		b.add_theme_color_override("font_hover_color", STAMP)
		b.add_theme_color_override("font_focus_color", STAMP)
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(NAVY_2, 1.0)
		hover.set_corner_radius_all(6)
		hover.set_content_margin_all(10)
		var normal := StyleBoxEmpty.new()
		normal.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.pressed.connect(Game.play_level.bind(l.id))
		col.add_child(b)
		_buttons.append(b)

	var rule2 := ColorRect.new()
	rule2.color = Color(PAPER, 0.25)
	rule2.custom_minimum_size.y = 1
	col.add_child(rule2)
	col.add_child(_label("Click a level or press its number.   Esc in a level returns here through the pause menu.", 14, SOFT))
	if _buttons.size() > 0:
		_buttons[0].grab_focus.call_deferred()


func _label(t: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.physical_keycode - KEY_1
		if idx >= 0 and idx < Levels.LIST.size():
			Game.play_level(Levels.LIST[idx].id)
