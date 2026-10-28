extends Control
## Crosshair, grapple readout, talk prompt and speedometer.

var player: Node

var _speed: Label
var _info: Label
var _prompt: Label
var _cross_col := Color(1, 1, 1, 0.6)
var _last_npc: Node = null
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prompt = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = 40
	_prompt.offset_bottom = 80
	_prompt.add_theme_color_override("font_color", Color(1, 0.85, 0.5))

	_info = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_info.offset_left = -200
	_info.offset_right = 200
	_info.offset_top = 18
	_info.offset_bottom = 44

	_toast = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -420
	_toast.offset_right = 420
	_toast.offset_top = 40
	_toast.offset_bottom = 80
	_toast.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))

	_speed = _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_speed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_speed.offset_left = 20
	_speed.offset_top = -64
	_speed.offset_right = 600
	_speed.offset_bottom = -16


func _label(sz: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## A short message near the top of the screen.
func toast(t: String, secs := 3.0) -> void:
	_toast.text = t
	_toast_t = secs


func _process(_dt: float) -> void:
	if player == null:
		return
	_toast_t = maxf(_toast_t - _dt, 0.0)
	_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	var playing := Game.playing()
	visible = playing

	var npc = player.look_npc
	if npc != _last_npc:
		if is_instance_valid(_last_npc):
			_last_npc.set_highlight(false)
		if npc:
			npc.set_highlight(true)
		_last_npc = npc

	var col := Color(1, 1, 1, 0.55)
	_info.text = ""
	_prompt.text = ""
	if npc:
		col = Color(1, 0.85, 0.4, 0.9)
		_prompt.text = ("[E]  Examine: %s" if npc.is_in_group("evidence") else "[E]  Talk to %s") % npc.display_name
	elif player.attached:
		col = Color(0.75, 0.85, 1.0, 0.8)
		_info.text = "rope %d m" % roundi(player.rope_len)
	elif player.aim_valid and (player.is_on_floor() or player.air_left > 0):
		col = Color(0.45, 1.0, 0.6, 0.85)
		_info.text = "%d m" % roundi(player.aim_distance)
	if col != _cross_col:
		_cross_col = col
		queue_redraw()

	var pips := ""
	for i in int(player.tune.air_grapples):
		pips += "● " if i < player.air_left else "○ "
	_speed.text = "%d km/h    %s   %s      L — logbook" % [roundi(player.velocity.length() * 3.6), pips,
		"DASH" if player.dash_cd == 0.0 else ""]


func _draw() -> void:
	var c := size * 0.5
	draw_arc(c, 10.0, 0, TAU, 32, _cross_col, 2.0, true)
	draw_circle(c, 2.0, _cross_col)
