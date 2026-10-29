extends Label
## F3: a small performance readout in the top-right corner.
##   FPS, the slowest frame in the last 5 seconds, and the last hitch (any frame
##   over HITCH_MS), with how long ago it was and what had just happened.
## Hitches are also printed to the console ("[perf] ..."), visible in a browser's
## developer console on the web build.

const HITCH_MS := 100.0
const WINDOW := 5.0

var _last_us := 0
var _times: Array = []            # [ms, at_seconds]
var _hitch_ms := 0.0
var _hitch_at := -1.0
var _hitch_what := ""
var _recent := ""                 # the latest notice/toast, so a hitch says what caused it
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -520
	offset_right = -16
	offset_top = 12
	offset_bottom = 90
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(0.85, 1.0, 0.8))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_last_us = Time.get_ticks_usec()


func note(what: String) -> void:
	_recent = what


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("perf"):
		visible = not visible


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_clock += ms / 1000.0
	_times.append([ms, _clock])
	while not _times.is_empty() and _clock - _times[0][1] > WINDOW:
		_times.pop_front()
	if ms > HITCH_MS and _clock > 1.0:
		_hitch_ms = ms
		_hitch_at = _clock
		_hitch_what = _recent
		print("[perf] hitch %d ms (after: %s)" % [roundi(ms), _recent if _recent != "" else "-"])
	if not visible:
		return
	var worst := 0.0
	for t in _times:
		worst = maxf(worst, t[0])
	var txt := "FPS %d   ·   worst frame %d ms (last %d s)" % [Engine.get_frames_per_second(), roundi(worst), int(WINDOW)]
	if _hitch_at >= 0.0:
		txt += "\nlast hitch %d ms, %d s ago%s" % [roundi(_hitch_ms), int(_clock - _hitch_at),
			("  ·  after \"%s\"" % _hitch_what) if _hitch_what != "" else ""]
	else:
		txt += "\nno hitches over %d ms" % int(HITCH_MS)
	text = txt
	_recent = _recent if _clock - (_hitch_at if _hitch_at >= 0 else 0.0) < 30.0 else ""
