extends Control
## Disco Elysium-style conversation column: a tall dark panel on the right side
## of the screen. The conversation scrolls upward as a log (speaker in caps, then
## the line), and the numbered choices sit at the bottom of the log.
##
## Click a choice or press its number. Esc leaves the conversation. Choices
## you've already picked in this conversation are greyed, like in DE.

signal closed

const BG := Color(0.07, 0.065, 0.06, 0.94)
const TEXT := Color(0.86, 0.83, 0.76)
const SPEAKER := Color(0.82, 0.38, 0.24)
const YOU := Color(0.55, 0.53, 0.50)
const CHOICE := Color(0.90, 0.48, 0.28)
const CHOICE_HOVER := Color(1.0, 0.80, 0.55)
const CHOICE_SEEN := Color(0.58, 0.46, 0.38)
const FONT_SIZE := 24

var tree := {}
var npc_name := "NPC"
var current := ""
var _seen := {}
var _panel: PanelContainer
var _scroll: ScrollContainer
var _log: VBoxContainer
var _choices: VBoxContainer
var _title: Label
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = Color(0.32, 0.24, 0.18)
	sb.border_width_left = 2
	sb.content_margin_left = 34
	sb.content_margin_right = 30
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	resized.connect(_layout)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", YOU)
	col.add_child(_title)
	col.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 22)
	_scroll.add_child(inner)
	# push the log to the bottom while it's short, so new lines appear near the choices
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 18)
	inner.add_child(_log)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	inner.add_child(_choices)
	inner.custom_minimum_size.y = 0
	_scroll.resized.connect(func(): inner.custom_minimum_size.y = _scroll.size.y)

	var hint := Label.new()
	hint.text = "1–9 or click to choose   ·   Esc to leave"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", YOU)
	col.add_child(hint)
	_layout()


func _layout() -> void:
	var w := clampf(size.x * 0.34, 460.0, 720.0)
	_panel.offset_left = -w
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0


## Start a conversation. `data` is a DialogueDB tree.
func open(data: Dictionary) -> void:
	tree = data
	npc_name = str(data.get("name", "NPC"))
	_title.text = npc_name.to_upper()
	_seen.clear()
	for c in _log.get_children():
		c.queue_free()
	visible = true
	_panel.modulate.a = 0.0
	_panel.position.x += 60
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "position:x", _panel.position.x - 60, 0.25)
	_show(str(data.get("start", "")))


func close() -> void:
	if not visible:
		return
	visible = false
	_clear_choices()
	closed.emit()


func _show(id: String) -> void:
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(id):
		close()
		return
	current = id
	var n: Dictionary = nodes[id]
	var speaker := str(n.get("speaker", ""))
	if speaker == "":
		speaker = npc_name
	_add_line(speaker, str(n.get("text", "")), SPEAKER, TEXT)

	_clear_choices()
	var choices: Array = n.get("choices", [])
	if choices.is_empty():
		choices = [{"text": "[Leave]", "next": ""}]
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, c.get("text", "")]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", FONT_SIZE)
		var col := CHOICE_SEEN if _seen.has("%s:%d" % [id, i]) else CHOICE
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", CHOICE_HOVER)
		b.add_theme_color_override("font_pressed_color", CHOICE_HOVER)
		b.pressed.connect(_pick.bind(i))
		_choices.add_child(b)
		_choice_buttons.append(b)
	_scroll_to_end()


func _pick(i: int) -> void:
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(current):
		close()
		return
	var choices: Array = nodes[current].get("choices", [])
	var choice: Dictionary = choices[i] if i < choices.size() else {"text": "[Leave]", "next": ""}
	_seen["%s:%d" % [current, i]] = true
	_add_line("YOU", str(choice.get("text", "")), YOU, YOU)
	var next := str(choice.get("next", ""))
	if next == "" or not nodes.has(next):
		close()
	else:
		_show(next)


func _add_line(speaker: String, text: String, speaker_col: Color, text_col: Color) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	r.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	r.add_theme_color_override("default_color", text_col)
	r.text = "[b][color=#%s]%s[/color][/b] — %s" % [speaker_col.to_html(false), _esc(speaker.to_upper()), _esc(text)]
	_log.add_child(r)


## RichTextLabel reads [square brackets] as tags; "[lb]" prints a literal "[".
static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _clear_choices() -> void:
	for b in _choice_buttons:
		b.queue_free()
	_choice_buttons.clear()


func _scroll_to_end() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		var k: int = event.physical_keycode
		var idx := -1
		if k >= KEY_1 and k <= KEY_9:
			idx = k - KEY_1
		elif k >= KEY_KP_1 and k <= KEY_KP_9:
			idx = k - KEY_KP_1
		if idx >= 0 and idx < _choice_buttons.size():
			_pick(idx)
			get_viewport().set_input_as_handled()
