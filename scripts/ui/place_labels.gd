extends Control
## Island names drawn on the HUD over their 3D positions, so they stay crisp and
## readable through the haze at any distance (Label3D picks up the fog).

var camera: Camera3D
var places: Array = []             # {pos, title, sub, col, big, fade}
var _labels: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add(pos: Vector3, title: String, sub: String, col: Color, big: bool, fade := 0.0) -> void:
	places.append({"pos": pos, "title": title, "sub": sub, "col": col, "big": big, "fade": fade})
	var l := Label.new()
	l.text = "%s\n%s" % [title, sub]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22 if big else 14)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6 if big else 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_labels.append(l)


func _process(_dt: float) -> void:
	visible = Game.playing() and camera != null
	if not visible:
		return
	var eye := camera.global_position
	for i in places.size():
		var p: Dictionary = places[i]
		var l: Label = _labels[i]
		var d := eye.distance_to(p.pos)
		if camera.is_position_behind(p.pos) or (p.fade > 0.0 and d > p.fade):
			l.visible = false
			continue
		l.visible = true
		var s := camera.unproject_position(p.pos)
		l.reset_size()
		l.position = s - Vector2(l.size.x * 0.5, l.size.y)
