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
var _health: Label
var _wraps: Label
var _flash: ColorRect
var _flash_a := 0.0
var _banner: Label
var _banner_t := 0.0


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

	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.1, 0.05, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	move_child(_flash, 0)

	_banner = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -170
	_banner.offset_bottom = -90
	_banner.add_theme_constant_override("outline_size", 12)

	_health = _label(30, HORIZONTAL_ALIGNMENT_LEFT)
	_health.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_health.offset_left = 22
	_health.offset_top = 16
	_health.offset_right = 300
	_health.offset_bottom = 60
	_health.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))

	_wraps = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_wraps.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_wraps.offset_left = -300
	_wraps.offset_right = 300
	_wraps.offset_top = 70
	_wraps.offset_bottom = 104
	_wraps.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

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


## Red flash when the player is hit (or another colour for other events).
func flash(c := Color(0.9, 0.1, 0.05), strength := 0.45) -> void:
	_flash.color = Color(c, 0.0)
	_flash_a = strength


## A big centred word that fades out (e.g. SUBDUED).
func banner(t: String, c: Color, secs := 1.6) -> void:
	_banner.text = t
	_banner.add_theme_color_override("font_color", c)
	_banner_t = secs


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
	_flash_a = maxf(_flash_a - _dt * 1.6, 0.0)
	_banner_t = maxf(_banner_t - _dt, 0.0)
	_banner.modulate.a = clampf(_banner_t * 1.5, 0.0, 1.0)
	_flash.color.a = _flash_a
	# stun: a countdown in place of the old hearts
	_health.text = "STUNNED  %.1f" % player.stunned if player.stunned > 0.0 else ""
	_health.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	var target = player.hook_node if player.attached else null
	if target and is_instance_valid(target) and target.is_in_group("enemy"):
		var w: float = target.wraps
		var pips := ""
		for i in target.WRAPS_NEEDED:
			pips += "◉ " if i < floori(w) else "○ "
		_wraps.text = "WRAP  %s" % pips
	else:
		_wraps.text = ""

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
	elif player.aim_enemy and is_instance_valid(player.aim_enemy) and player.aim_enemy.is_in_group("enemy"):
		var dist: float = player.cam.global_position.distance_to(player.aim_enemy.global_position)
		var close: bool = dist <= player.aim_enemy.subdue_range()
		col = Color(1.0, 0.35, 0.3, 0.95) if close else Color(1.0, 0.75, 0.5, 0.7)
		_info.text = ("%d m  ·  in range to wrap" if close else "%d m  ·  too far to wrap") % roundi(dist)
	elif player.aim_enemy and is_instance_valid(player.aim_enemy) and player.aim_enemy.is_in_group("ward"):
		col = Color(0.8, 0.6, 1.0, 0.95)
		_info.text = "ward  ·  free grapple, but don't touch it"
	elif player.aim_enemy and is_instance_valid(player.aim_enemy):
		col = GOLD if player.aim_enemy == player.highlight_target else Color(0.55, 0.85, 1.0, 0.95)
		_info.text = "%s  ·  magic, free grapple" % player.aim_enemy.get("grapple_name") if player.aim_enemy.get("grapple_name") else "magic, free grapple"
	elif player.attached:
		col = Color(0.75, 0.85, 1.0, 0.8)
		_info.text = "rope %d m" % roundi(player.rope_len)
	elif player.aim_valid and (player.is_on_floor() or player.air_left > 0):
		col = Color(0.45, 1.0, 0.6, 0.85)
		_info.text = "%d m" % roundi(player.aim_distance)
	_cross_col = col
	queue_redraw()          # the landing marker moves every frame

	var pips := ""
	for i in int(player.tune.air_grapples):
		pips += "● " if i < player.air_left else "○ "
	_speed.text = "%d km/h    %s   %s      L — logbook" % [roundi(player.velocity.length() * 3.6), pips,
		"DASH" if player.dash_cd == 0.0 else ""]


func _draw() -> void:
	var c := size * 0.5
	var r: float = maxf(10.0, player.reticle_px()) if player else 10.0
	var shade := Color(0, 0, 0, 0.35)
	var faint := Color(_cross_col, maxf(0.5, _cross_col.a * 0.8))
	draw_arc(c, r, 0, TAU, 72, shade, 4.5, true)          # dark under-stroke: readable on bright sky
	draw_arc(c, r, 0, TAU, 72, faint, 2.0, true)
	draw_circle(c, 3.0, shade)
	draw_circle(c, 2.0, _cross_col)
	# where the hook will land: a small diamond, with a tick from the centre if it's off-centre
	if player and player.aim_valid and not player.cam.is_position_behind(player.aim_point):
		var m: Vector2 = player.cam.unproject_position(player.aim_point)
		var k := 8.0
		var pts := PackedVector2Array([m + Vector2(0, -k), m + Vector2(k, 0), m + Vector2(0, k), m + Vector2(-k, 0), m + Vector2(0, -k)])
		draw_polyline(pts, shade, 4.5, true)
		draw_polyline(pts, Color(_cross_col, 1.0), 2.0, true)
		if m.distance_to(c) > 14.0:
			draw_line(c + (m - c).normalized() * 5.0, m - (m - c).normalized() * 10.0, faint, 1.5, true)

	if player:
		_draw_lock()


const GOLD := Color(1.0, 0.86, 0.3)


## Lock-on brackets and label around the highlighted grapple target; an arrow at
## the screen edge when it's off-screen.
func _draw_lock() -> void:
	var t: Node3D = player.highlight_target
	if t == null or not is_instance_valid(t):
		return
	var cam: Camera3D = player.cam
	var p := t.global_position
	var d: float = cam.global_position.distance_to(p)
	var label := "%s  %d m" % [str(t.get("grapple_name")) if t.get("grapple_name") else "grapple", roundi(d)]
	var font := get_theme_default_font()
	var shade := Color(0, 0, 0, 0.45)
	var margin := 48.0
	var on_screen := not cam.is_position_behind(p)
	var m := Vector2.ZERO
	if on_screen:
		m = cam.unproject_position(p)
		on_screen = Rect2(Vector2.ZERO, size).grow(-margin * 0.5).has_point(m)
	if on_screen:
		# corner brackets sized to the orb on screen
		var px_per_m := size.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5) * maxf(d, 0.1))
		var r := clampf(1.1 * px_per_m, 14.0, 90.0)
		var k := r * 0.45
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner: Vector2 = m + Vector2(sx * r, sy * r)
				var pts := PackedVector2Array([corner - Vector2(0, sy * k), corner, corner - Vector2(sx * k, 0)])
				draw_polyline(pts, shade, 5.0, true)
				draw_polyline(pts, GOLD, 2.5, true)
		var at := m + Vector2(r + 8.0, -r + 12.0)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, shade)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
		return
	# off-screen: an arrow on the edge pointing the way, with the label
	var local: Vector3 = cam.global_transform.affine_inverse() * p
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 0.001:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var c := size * 0.5
	var half := c - Vector2(margin, margin)
	var s := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var tip := c + dir * s
	var side := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array([tip, tip - dir * 34.0 + side * 10.0, tip - dir * 26.0, tip - dir * 34.0 - side * 10.0])
	draw_colored_polygon(tri, GOLD)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), shade, 2.0, true)
	var lsize := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var at2 := (tip - dir * (54.0 + absf(dir.x) * lsize.x * 0.5)) + Vector2(-lsize.x * 0.5, 5.0)
	at2.x = clampf(at2.x, 8.0, size.x - lsize.x - 8.0)
	at2.y = clampf(at2.y, 20.0, size.y - 8.0)
	draw_string_outline(font, at2, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, shade)
	draw_string(font, at2, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
