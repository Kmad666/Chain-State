extends StaticBody3D
## A talk-able character. Placeholder body: a tall rectangle with a floating
## name label. Its dialogue tree is dialogue/<npc_id>.json (see DialogueDB).
##
## Collision layer 2 = NPC: solid to walk into and talk-able, but the grapple
## can't hook it.

@export var npc_id := "test_npc"
@export var display_name := "NPC"
@export var body_size := Vector3(0.8, 2.0, 0.4)
@export var color := Color(0.85, 0.42, 0.30)

var _label: Label3D
var _body: MeshInstance3D
var _highlight := false


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 2
	collision_mask = 0

	var shape := BoxShape3D.new()
	shape.size = body_size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = body_size.y * 0.5
	add_child(col)

	var mesh := BoxMesh.new()
	mesh.size = body_size
	_body = MeshInstance3D.new()
	_body.mesh = mesh
	_body.position.y = body_size.y * 0.5
	_body.material_override = Mats.lit(color)
	add_child(_body)

	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = body_size.y + 0.35
	_label.font_size = 48
	_label.pixel_size = 0.004
	_label.outline_size = 12
	_label.modulate = Color(1, 0.95, 0.85)
	_label.no_depth_test = false
	add_child(_label)


## The HUD lights the NPC up while it's under the crosshair.
func set_highlight(on: bool) -> void:
	if on == _highlight:
		return
	_highlight = on
	_body.material_override = Mats.lit(color.lightened(0.25) if on else color)
	_label.modulate = Color(1, 0.85, 0.4) if on else Color(1, 0.95, 0.85)
