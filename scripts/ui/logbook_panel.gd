extends Control
## The logbook screen (L / Tab / J). A Federal Chain case book: navy cover, cream
## pages. Left: the index. Right: the selected page.
##   Field guide  - general notes, then one page per school of magic
##   Case evidence - everything the Agent has examined so far

signal closed

const NAVY := Color(0.09, 0.15, 0.29)
const PAPER := Color(0.95, 0.92, 0.85)
const INK := Color(0.16, 0.13, 0.10)
const INK_SOFT := Color(0.40, 0.34, 0.27)

var _index: VBoxContainer
var _page: RichTextLabel
var _evidence_btn: Button
var _buttons := {}
var _current := "general"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# the cover: navy, with the pages inset
	var cover := PanelContainer.new()
	cover.custom_minimum_size = Vector2(1100, 720)
	var cs := StyleBoxFlat.new()
	cs.bg_color = NAVY
	cs.set_corner_radius_all(10)
	cs.set_content_margin_all(18)
	cs.shadow_color = Color(0, 0, 0, 0.45)
	cs.shadow_size = 18
	cover.add_theme_stylebox_override("panel", cs)
	center.add_child(cover)
	resized.connect(func():
		cover.custom_minimum_size = Vector2(clampf(size.x * 0.82, 760, 1300), clampf(size.y * 0.84, 520, 900)))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	cover.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "FEDERAL CHAIN  ·  AGENT'S LOGBOOK"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98))
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var hint := Label.new()
	hint.text = "L / Tab / Esc to close"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98, 0.6))
	head.add_child(hint)

	var pages := PanelContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = PAPER
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(0)
	pages.add_theme_stylebox_override("panel", ps)
	col.add_child(pages)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	pages.add_child(row)

	# index (left page)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 260
	var ls := StyleBoxFlat.new()
	ls.bg_color = PAPER.darkened(0.05)
	ls.border_color = INK_SOFT.lerp(PAPER, 0.6)
	ls.border_width_right = 2
	ls.set_content_margin_all(18)
	left.add_theme_stylebox_override("panel", ls)
	row.add_child(left)
	_index = VBoxContainer.new()
	_index.add_theme_constant_override("separation", 4)
	left.add_child(_index)

	_section("FIELD GUIDE")
	_tab("general", "How to read a scene", INK)
	for s in Logbook.schools:
		_tab(s.id, "%s magic" % s.name, ink_of(s.color))
	_index.add_child(_gap(14))
	_section("CASE EVIDENCE")
	_evidence_btn = _tab("evidence", "Evidence logged (0)", INK)

	# page (right)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	row.add_child(margin)
	_page = RichTextLabel.new()
	_page.bbcode_enabled = true
	_page.scroll_active = true
	_page.selection_enabled = false
	_page.add_theme_color_override("default_color", INK)
	_page.add_theme_font_size_override("normal_font_size", 19)
	_page.add_theme_font_size_override("bold_font_size", 19)
	margin.add_child(_page)

	Logbook.evidence_added.connect(func(_e):
		_refresh_count()
		if visible and _current == "evidence":
			show_page("evidence"))
	show_page("general")


func _section(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", INK_SOFT)
	_index.add_child(l)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _tab(id: String, text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", col)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(col, 0.14)
	pressed.set_corner_radius_all(4)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.pressed.connect(func(): show_page(id))
	_index.add_child(b)
	_buttons[id] = b
	return b


func _refresh_count() -> void:
	_evidence_btn.text = "Evidence logged (%d)" % Logbook.evidence.size()


## A school's colour, darkened enough to read on the cream page.
static func ink_of(hex: String) -> Color:
	var c := Color.html(hex)
	return c.darkened(0.5 if c.get_luminance() > 0.55 else 0.25)


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func show_page(id: String) -> void:
	_current = id
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == id)
	var t := ""
	if id == "general":
		t += "[font_size=34]How to read a scene[/font_size]\n\n"
		t += "Magic crimes leave traces that ordinary crimes don't. Each school of magic has its own signs. Learn them, and the scene tells you what kind of practitioner was there.\n\n"
		for g in Logbook.general:
			t += "•  %s\n\n" % _esc(g)
		t += "[color=#%s]Pick a school on the left to see what it leaves behind.[/color]" % INK_SOFT.to_html(false)
	elif id == "evidence":
		t += "[font_size=34]Case evidence[/font_size]\n\n"
		if Logbook.evidence.is_empty():
			t += "[color=#%s]No evidence logged yet. When you find something suspicious, look at it and press E to examine it. It will be recorded here.[/color]" % INK_SOFT.to_html(false)
		for e in Logbook.evidence:
			var s := Logbook.school(str(e.get("school", "")))
			var tag := ""
			if not s.is_empty():
				tag = "  [color=#%s][b]%s magic[/b][/color]" % [ink_of(s.color).to_html(false), s.name.to_upper()]
			t += "[b][font_size=22]%s[/font_size][/b]%s\n" % [_esc(str(e.get("title", ""))), tag]
			if str(e.get("where", "")) != "":
				t += "[color=#%s][i]%s[/i][/color]\n" % [INK_SOFT.to_html(false), _esc(str(e.where))]
			t += "%s\n\n" % _esc(str(e.get("note", "")))
	else:
		var s := Logbook.school(id)
		t += "[font_size=34][color=%s]%s magic[/color][/font_size]\n\n" % ["#" + ink_of(s.color).to_html(false), _esc(s.name)]
		t += "%s\n\n" % _esc(s.summary)
		t += "[color=#%s][b]Under the residue lens:[/b] %s[/color]\n\n" % [INK_SOFT.to_html(false), _esc(s.lens)]
		t += "[font_size=24]What it leaves behind[/font_size]\n\n"
		for ev in s.evidence:
			t += "[b]%s[/b]\n%s\n\n" % [_esc(ev.sign), _esc(ev.means)]
		t += "[font_size=24]Easily mistaken for[/font_size]\n\n%s" % _esc(s.mistaken_for)
	_page.text = t
	_page.scroll_to_line(0)


func open(page := "") -> void:
	_refresh_count()
	show_page(page if page != "" else _current)
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("logbook") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
