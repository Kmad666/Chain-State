class_name ArmMesh
## The first-person arm as one mesh: a black suit sleeve over a white shirt cuff and
## a black leather glove, built from lofted cross-sections in the arm's own space
## (metres; -Z runs from the elbow to the fingertips, +Y is the back of the hand,
## -X the thumb side of this right hand, palm down).
##
## Two poses share one topology: the base mesh is a relaxed hand, fingers loosely
## curled, and the blend shape "fist" closes it round the chain. Every vertex is
## built twice from the same recipe, once per pose, so the shape morphs cleanly.
##
## Surfaces, in order: wool, lining, shirt, leather, buttons.

enum { WOOL, LINING, SHIRT, LEATHER, BUTTONS }
const SURFACES := 5
const SEG := 18                  # vertices round each ring

## Hand measurements (glove included): an adult man's hand, about 19 cm from the
## wrist crease to the middle fingertip and 8.8 cm across the knuckles.
const WRIST_Z := -0.218
const SLEEVE_END := -0.200
const CUFF_END := -0.212

## Fingers, index to little: knuckle (MCP) position, phalanx lengths
## (proximal, middle, distal), base radius, and the sideways splay in each pose.
const FINGERS := [
	{"mcp": Vector3(-0.0305, 0.0010, -0.3125), "len": [0.044, 0.026, 0.021], "r": 0.0099, "splay": [-0.10, -0.03]},
	{"mcp": Vector3(-0.0100, 0.0030, -0.3165), "len": [0.044, 0.027, 0.020], "r": 0.0102, "splay": [-0.02, 0.0]},
	{"mcp": Vector3(0.0110, 0.0015, -0.3125), "len": [0.041, 0.026, 0.019], "r": 0.0096, "splay": [0.05, 0.02]},
	{"mcp": Vector3(0.0300, -0.0020, -0.3015), "len": [0.032, 0.019, 0.017], "r": 0.0086, "splay": [0.12, 0.05]},
]
## Joint bends (MCP, PIP, DIP), degrees: a hand at rest curls a little more toward
## the little finger; a fist folds the fingers flat against the palm.
const RELAXED := [[16.0, 30.0, 16.0], [20.0, 34.0, 18.0], [24.0, 40.0, 20.0], [28.0, 46.0, 22.0]]
const FIST := [[84.0, 110.0, 74.0], [86.0, 110.0, 74.0], [88.0, 110.0, 74.0], [90.0, 110.0, 76.0]]

## Thumb joints (CMC, MCP, IP, tip) in each pose, and its radii along the way:
## a fat base (the thenar muscle) narrowing to the tip.
const THUMB_RELAXED := [Vector3(-0.024, -0.009, -0.226), Vector3(-0.045, -0.022, -0.260),
	Vector3(-0.050, -0.032, -0.289), Vector3(-0.046, -0.038, -0.314)]
const THUMB_FIST := [Vector3(-0.024, -0.009, -0.226), Vector3(-0.050, -0.032, -0.282),
	Vector3(-0.040, -0.050, -0.318), Vector3(-0.012, -0.052, -0.332)]
const THUMB_R := [0.0175, 0.0128, 0.0117, 0.0106]

## Where the chain leaves the hand in each pose (between thumb and index).
const CHAIN_RELAXED := Vector3(-0.024, -0.030, -0.330)
const CHAIN_FIST := Vector3(-0.022, -0.036, -0.326)


class Surf:
	var v := [PackedVector3Array(), PackedVector3Array()]     # base pose, fist pose
	var idx := PackedInt32Array()


var surfs: Array = []
var inside := false              # the next loft is seen from within (the lining)
var folds := 0.0                 # cloth drape on the next loft: fold depth in metres at its start


static func build() -> ArrayMesh:
	var b := ArmMesh.new()
	return b._build()


func _build() -> ArrayMesh:
	for i in SURFACES:
		surfs.append(Surf.new())
	_sleeve()
	_shirt()
	_glove()
	for f in 4:
		_finger(f)
	_thumb()
	_buttons()
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED     # the fist is a whole pose, not an offset
	mesh.add_blend_shape("fist")
	for s in surfs:
		var base := _arrays(s, 0)
		var fist := _arrays(s, 1)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base, [fist])
	return mesh


# ------------------------------------------------------------------ parts

## The sleeve: wool tapering from the elbow to the cuff, hanging a touch low, its
## open end turned in to a dark lining.
func _sleeve() -> void:
	var rows := []
	for i in 25:
		var t := i / 24.0
		var z := lerpf(0.30, SLEEVE_END, t)
		var rx := lerpf(0.066, 0.0450, t)
		var ry := lerpf(0.061, 0.0420, t)
		# the cloth hangs: the sleeve's underside sags a little more toward the cuff
		rows.append([Vector3(0.0, -0.004 * t, z), rx, ry, ry * (1.0 + 0.06 * t), 2.0])
	folds = 0.0035
	_loft(WOOL, rows, rows, Vector3.UP, true, false)
	folds = 0.0
	# the turned-in edge, then the lining back inside
	var end: Array = rows[-1]
	var lip := [
		[end[0], end[1], end[2], end[3], 2.0],
		[end[0] + Vector3(0, 0, 0.0015), end[1] * 0.965, end[2] * 0.965, end[3] * 0.965, 2.0],
	]
	_loft(WOOL, lip, lip, Vector3.UP, false, false)
	var lining := [
		[end[0] + Vector3(0, 0, 0.0015), end[1] * 0.965, end[2] * 0.965, end[3] * 0.965, 2.0],
		[end[0] + Vector3(0, 0, 0.05), end[1] * 0.965, end[2] * 0.965, end[3] * 0.965, 2.0],
	]
	inside = true
	_loft(LINING, lining, lining, Vector3.UP, false, false)
	inside = false


## The shirt cuff: a centimetre of white past the sleeve, closed round the glove.
func _shirt() -> void:
	var rows := []
	for z in [-0.17, CUFF_END]:
		rows.append([Vector3(0.0, -0.005, z), 0.0395, 0.0355, 0.0365, 2.4])
	rows.append([Vector3(0.0, -0.005, CUFF_END - 0.0012), 0.0378, 0.0338, 0.0348, 2.4])
	rows.append([Vector3(0.0, -0.005, CUFF_END + 0.004), 0.034, 0.029, 0.030, 2.4])
	_loft(SHIRT, rows, rows, Vector3.UP, false, false)


## The glove from inside the cuff to the knuckles: round at the wrist, spreading
## into a broad, flat hand; the palm side fuller at the heel than the back.
## Rows: centre, half-width, half-height above and below, squareness.
func _glove() -> void:
	var rows := [
		[Vector3(0.0, -0.004, -0.160), 0.0315, 0.0250, 0.0250, 2.0],
		[Vector3(0.0, -0.003, -0.205), 0.0290, 0.0215, 0.0215, 2.1],
		[Vector3(0.0, -0.002, WRIST_Z), 0.0292, 0.0200, 0.0215, 2.2],
		[Vector3(-0.001, -0.001, -0.236), 0.0360, 0.0175, 0.0225, 2.5],
		[Vector3(-0.002, 0.000, -0.258), 0.0420, 0.0160, 0.0205, 2.7],
		[Vector3(-0.001, 0.001, -0.282), 0.0445, 0.0150, 0.0175, 2.8],
		[Vector3(0.000, 0.001, -0.300), 0.0450, 0.0140, 0.0150, 2.8],
		[Vector3(0.000, 0.001, -0.310), 0.0425, 0.0120, 0.0125, 2.6],
	]
	# clenched, the palm's muscles bunch and its heel fills out under the fingers
	var fist := []
	for r in rows:
		var q: Array = r.duplicate()
		var z: float = (r[0] as Vector3).z
		var bunch := smoothstep(-0.225, -0.26, z)
		q[3] = r[3] * (1.0 + 0.32 * bunch)
		q[1] = r[1] * (1.0 - 0.04 * bunch)
		fist.append(q)
	_loft(LEATHER, rows, fist, Vector3.UP, false, true)


## One finger: a single tube from inside the palm through its three joints to a
## rounded tip, bending smoothly at each joint so the knuckles form by themselves.
func _finger(f: int) -> void:
	var d: Dictionary = FINGERS[f]
	var lens: Array = d.len
	var total: float = lens[0] + lens[1] + lens[2]
	var back := 0.016                     # the tube starts this far inside the palm
	var joints := [0.0, lens[0], lens[0] + lens[1]]
	var n := 30
	var poses := []
	for pose in 2:
		var bends: Array = RELAXED[f] if pose == 0 else FIST[f]
		var splay: float = d.splay[pose]
		var fwd := Basis(Vector3.UP, -splay) * Vector3.FORWARD
		var side := Basis(Vector3.UP, -splay) * Vector3.RIGHT      # the axis the finger curls about
		var rows := []
		var p: Vector3 = d.mcp - fwd * back
		var step := (total + back) / float(n - 1)
		for i in n:
			var s := -back + i * step
			var ang := 0.0
			var w: float = 0.011 + d.r * 0.4                                   # how long each bend is
			for j in 3:
				ang += deg_to_rad(bends[j]) * smoothstep(joints[j] - w * 0.5, joints[j] + w * 0.5, s)
			var rot := Basis(side, -ang)
			var dir := rot * fwd
			var up := rot * Vector3.UP
			if i > 0:
				p += dir * step
			# radius: a little fuller over each joint, narrower mid-bone, tapering to the tip
			var r: float = d.r * lerpf(1.0, 0.86, clampf(s / total, 0.0, 1.0))
			for j in 3:
				r *= 1.0 + 0.07 * exp(-pow((s - joints[j]) / 0.006, 2.0))
			if s < 0.0:
				r *= lerpf(1.0, 0.92, -s / back)
			# flatter over the back, fuller over the pad, flattest toward the tip
			var tipward := smoothstep(total * 0.7, total, s)
			rows.append([p, r * 1.07, r * lerpf(0.86, 0.74, tipward), r * 1.0, lerpf(2.2, 2.5, tipward), up])
		poses.append(rows)
	_loft_up(LEATHER, poses[0], poses[1], false, true)


## The thumb: thick at its base where the thenar muscle fills the palm, along a
## smooth curve through its joints.
func _thumb() -> void:
	var poses := []
	for pose in 2:
		var pts: Array = THUMB_RELAXED if pose == 0 else THUMB_FIST
		var rows := []
		var per := 8
		for seg in 3:
			var a: Vector3 = pts[seg]
			var b: Vector3 = pts[seg + 1]
			var pre: Vector3 = pts[seg - 1] if seg > 0 else a - (b - a)
			var post: Vector3 = pts[seg + 2] if seg < 2 else b + (b - a)
			for k in per:
				if seg > 0 and k == 0:
					continue
				var t := k / float(per - 1)
				var p := a.cubic_interpolate(b, pre, post, t)
				var r := lerpf(THUMB_R[seg], THUMB_R[seg + 1], t)
				# the thumbnail side faces out and a little up
				var dir := (b - a).normalized()
				var up := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.95 else Vector3.RIGHT).normalized()
				if up.y < 0.0:
					up = -up
				up = (up + Vector3(-0.6, 0.4, 0)).normalized()
				up = (up - dir * up.dot(dir)).normalized()
				rows.append([p, r * 1.04, r * 0.92, r * 1.0, 2.1, up])
		poses.append(rows)
	_loft_up(LEATHER, poses[0], poses[1], true, true)


## Four horn buttons on the outer side of the cuff.
func _buttons() -> void:
	for k in 4:
		var z := -0.188 + k * 0.0135
		var t := inverse_lerp(0.30, SLEEVE_END, z)
		var rx := lerpf(0.066, 0.0450, t)
		var ry := lerpf(0.061, 0.0420, t)
		var a := deg_to_rad(-28.0)
		var c := Vector3(cos(a) * rx, -0.004 * t + sin(a) * ry, z)
		var normal := Vector3(cos(a) / rx, sin(a) / ry, 0).normalized()
		var rows := []
		for h in [[-0.0005, 0.0050], [0.0012, 0.0052], [0.0022, 0.0042]]:
			rows.append([c + normal * h[0], h[1], h[1], h[1], 2.0])
		var up := Vector3.FORWARD
		var rr := []
		for r in rows:
			rr.append(r + [up])
		_loft_up(BUTTONS, rr, rr, false, true)


# ------------------------------------------------------------------ lofting

## A loft along -Z-ish rows whose ring "up" is a fixed direction.
func _loft(surf: int, a: Array, b: Array, up: Vector3, cap_start: bool, cap_end: bool) -> void:
	var aa := []
	var bb := []
	for r in a:
		aa.append(r + [up])
	for r in b:
		bb.append(r + [up])
	_loft_up(surf, aa, bb, cap_start, cap_end)


## Rings through rows [centre, half-width, half-height up, half-height down,
## squareness, up direction], once per pose, joined into one tube.
func _loft_up(surf: int, pose_a: Array, pose_b: Array, cap_start: bool, cap_end: bool) -> void:
	var s: Surf = surfs[surf]
	var start: int = s.v[0].size()
	var rings := 0
	for pose in 2:
		var rows: Array = pose_a if pose == 0 else pose_b
		var all := rows.duplicate()
		if cap_end:
			all.append_array(_cap(rows, rows.size() - 1, 1.0))
		if cap_start:
			var head := _cap(rows, 0, -1.0)
			head.reverse()
			all = head + all
		rings = all.size()
		for i in all.size():
			var r: Array = all[i]
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, all.size() - 1)
			var t: Vector3 = (all[i1][0] - all[i0][0])
			t = t.normalized() if t.length() > 1e-6 else Vector3.FORWARD
			var up: Vector3 = r[5]
			up = (up - t * up.dot(t)).normalized()
			var side := t.cross(up).normalized()
			for k in SEG:
				var ang := TAU * k / SEG
				var c := cos(ang)
				var sn := sin(ang)
				var n: float = r[4]
				var x: float = signf(c) * pow(absf(c), 2.0 / n) * r[1]
				var y: float = signf(sn) * pow(absf(sn), 2.0 / n) * (r[2] if sn > 0.0 else r[3])
				var off := side * x + up * y
				if folds > 0.0:
					off += off.normalized() * _fold(ang, (r[0] as Vector3).z, i / float(all.size() - 1))
				s.v[pose].append(r[0] + off)
	# faces, wound so they face outward (checked on the first quad)
	# (tested on a ring halfway along: the rings of a domed cap are too small to trust)
	var flip := false
	var mid: int = start + mini(rings / 2, rings - 2) * SEG
	var p00: Vector3 = s.v[0][mid]
	var p01: Vector3 = s.v[0][mid + 1]
	var p10: Vector3 = s.v[0][mid + SEG]
	var centre := Vector3.ZERO
	for k in SEG:
		centre += s.v[0][mid + k]
	centre /= SEG
	if (p10 - p00).cross(p01 - p00).dot(p00 - centre) > 0.0:
		flip = true
	if inside:
		flip = not flip
	for i in rings - 1:
		for k in SEG:
			var a: int = start + i * SEG + k
			var b: int = start + i * SEG + (k + 1) % SEG
			var c: int = start + (i + 1) * SEG + k
			var d: int = start + (i + 1) * SEG + (k + 1) % SEG
			if flip:
				s.idx.append_array([a, b, c, b, d, c])
			else:
				s.idx.append_array([a, c, b, b, c, d])


## Wool drape: long soft folds running down the sleeve, deeper at the elbow, with
## a few shallow rings where the sleeve gathers above the cuff.
func _fold(ang: float, z: float, along: float) -> float:
	var deep := folds * lerpf(1.0, 0.3, along)
	var f := deep * (0.55 * sin(3.0 * ang + z * 9.0) + 0.3 * sin(5.0 * ang - z * 14.0 + 1.3) + 0.15 * sin(8.0 * ang + 2.1))
	var gather := smoothstep(-0.09, -0.15, z) * smoothstep(-0.205, -0.185, z)
	f += folds * 0.35 * gather * sin(z * 260.0) * (0.6 + 0.4 * sin(2.0 * ang))
	return f


## Rings closing a tube end in a dome (dir 1 = past the last row, -1 = before the first).
func _cap(rows: Array, at: int, dir: float) -> Array:
	var r: Array = rows[at]
	var nb: Array = rows[at - 1] if dir > 0.0 else rows[1]
	var t: Vector3 = ((r[0] - nb[0]) as Vector3).normalized()
	var depth := minf(r[1], minf(r[2], r[3])) * 0.9
	var out := []
	for k in [1, 2, 3, 4]:
		var phi: float = k / 4.0 * PI * 0.5
		var shrink := cos(phi) if k < 4 else 0.02
		var row := r.duplicate()
		row[0] = r[0] + t * depth * sin(phi)
		row[1] = r[1] * shrink
		row[2] = r[2] * shrink
		row[3] = r[3] * shrink
		out.append(row)
	return out


# ------------------------------------------------------------------ arrays

func _arrays(s: Surf, pose: int) -> Array:
	var v: PackedVector3Array = s.v[pose]
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	var idx := s.idx
	for i in range(0, idx.size(), 3):
		var a := v[idx[i]]
		var b := v[idx[i + 1]]
		var c := v[idx[i + 2]]
		var fn := (c - a).cross(b - a)            # Godot fronts are clockwise
		nrm[idx[i]] += fn
		nrm[idx[i + 1]] += fn
		nrm[idx[i + 2]] += fn
	var tan := PackedFloat32Array()
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 0.0 else Vector3.UP
		var tg := nrm[i].cross(Vector3.FORWARD if absf(nrm[i].z) < 0.95 else Vector3.RIGHT).normalized()
		tan.append_array([tg.x, tg.y, tg.z, 1.0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TANGENT] = tan
	if pose == 0:
		arr[Mesh.ARRAY_INDEX] = idx
	return arr
