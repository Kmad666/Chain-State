extends StaticBody3D
## A swing anchor: a small placeholder cube the chain can bite. On the Platform
## Test these are the ONLY things you can grapple; the landing pads around them
## are solid but un-grappleable (Player.LAYER_LAND).
##
## Explicitly grapple-able: in the grapple_target group, so auto-aim can lock on
## and lights it gold.

const COLOR := Color(0.95, 0.55, 0.15)
const LIT := Color(1.0, 0.86, 0.3)

@export var size := 1.6
var grapple_name := "anchor"
var highlighted := false
var _mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1                  # Player.LAYER_WORLD: solid and grapple-able
	collision_mask = 0
	add_to_group("grapple_target")
	add_to_group("swing_anchor")
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR
	_mat.emission_enabled = true
	_mat.emission = COLOR * 0.35
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	add_child(mi)


func set_highlight(on: bool) -> void:
	highlighted = on
	if _mat:
		_mat.albedo_color = LIT if on else COLOR
		_mat.emission = (LIT if on else COLOR) * (0.8 if on else 0.35)
