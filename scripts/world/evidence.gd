extends StaticBody3D
## Something at a scene the Agent can examine (look at it and press E).
## Examining it logs `entry` in the Logbook. Collision layer 2, like NPCs:
## solid and examinable, but the grapple can't hook it.

@export var evidence_id := ""
@export var school := ""          # fire, nature, ice, water (matches data/magic_schools.json)
@export var title := ""
@export_multiline var note := ""
@export var where := "Test range"

var display_name := "Evidence"
var _label: Label3D
var _highlight := false
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("evidence")
	collision_layer = 2
	collision_mask = 0
	display_name = title
	_label = Label3D.new()
	_label.text = "?"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.pixel_size = 0.004
	_label.outline_size = 14
	_label.modulate = Color(1, 0.95, 0.8)
	_label.position.y = 1.6
	add_child(_label)
	Logbook.evidence_added.connect(func(e): if e.id == evidence_id: _mark_logged())
	if Logbook.has_evidence(evidence_id):
		_mark_logged()


## Adds a box (visual + collision) as part of this prop.
func part(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, solid := true) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	_meshes.append(mi)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = pos
		col.rotation = rot
		add_child(col)
	return mi


func examine() -> bool:
	return Logbook.add_evidence({"id": evidence_id, "school": school, "title": title, "note": note, "where": where})


func set_highlight(on: bool) -> void:
	if on == _highlight:
		return
	_highlight = on
	_label.modulate = Color(1, 0.8, 0.35) if on else (Color(0.7, 0.75, 0.7) if Logbook.has_evidence(evidence_id) else Color(1, 0.95, 0.8))


func _mark_logged() -> void:
	_label.text = "✓"
	_label.modulate = Color(0.7, 0.75, 0.7)
