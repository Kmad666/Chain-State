extends Node3D
## Drifting clouds around a level: Kenney's soft cloud model, scattered in a wide
## band among and below the islands, sliding slowly with the wind and wrapping
## round. Decoration only: no collision, the grapple passes straight through.

@export var count := 26
@export var centre := Vector3.ZERO
@export var spread := 150.0          # half-width of the band, metres
@export var wind := Vector3(1.6, 0, 0.4)
@export var cloud_seed := 7
@export var y_low := -45.0           # cloud heights, relative to the centre
@export var y_high := 18.0

var _mm: MultiMesh
var _pos := PackedVector3Array()
var _scale := PackedFloat32Array()
var _yaw := PackedFloat32Array()


func _ready() -> void:
	var mesh := KenneyMesh.get_mesh("res://assets/models/kenney/cloud.glb")
	if mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = cloud_seed
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(spread * 0.25, spread)
		_pos.append(centre + Vector3(cos(a) * r, rng.randf_range(y_low, y_high), sin(a) * r))
		_scale.append(rng.randf_range(5.0, 13.0))
		_yaw.append(rng.randf() * TAU)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(centre - Vector3.ONE * (spread + 80.0), Vector3.ONE * (spread + 80.0) * 2.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	add_child(mi)
	_place()


func _process(dt: float) -> void:
	if _mm == null:
		return
	for i in _pos.size():
		var p := _pos[i] + wind * dt
		var off := p - centre
		if absf(off.x) > spread:
			p.x -= signf(off.x) * spread * 2.0
		if absf(off.z) > spread:
			p.z -= signf(off.z) * spread * 2.0
		_pos[i] = p
	_place()


func _place() -> void:
	for i in _pos.size():
		var b := Basis(Vector3.UP, _yaw[i]).scaled(Vector3(1.4, 0.8, 1.0) * _scale[i])
		_mm.set_instance_transform(i, Transform3D(b, _pos[i]))


func cloud_count() -> int:
	return _pos.size()
