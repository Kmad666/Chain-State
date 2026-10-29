extends StaticBody3D
## A swing anchor: a metal-framed crate (Kenney Platformer Kit) the chain can bite. On the Platform
## Test these are the ONLY things you can grapple; the landing pads around them
## are solid but un-grappleable (Player.LAYER_LAND).
##
## Explicitly grapple-able: in the grapple_target group, so auto-aim can lock on
## and lights it gold.

const COLOR := Color(0.95, 0.55, 0.15)
const LIT := Color(1.0, 0.86, 0.3)

@export var size := 1.6
var grapple_name := "anchor"
@export var free := false            # true: grapples on it cost no air grapple (long chains)
var highlighted := false
var _meshes: Array = []
var _glow: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1                  # Player.LAYER_WORLD: solid and grapple-able
	collision_mask = 0
	add_to_group("grapple_target")
	add_to_group("swing_anchor")
	if free:
		add_to_group("magic")            # Player.is_magic(): free, like the blue orbs
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	# the kit's metal-framed strong crate; a plain orange box if the kit is missing
	var sc = load("res://assets/models/kenney/platformer/crate-strong.glb")
	if sc:
		var crate: Node3D = sc.instantiate()
		crate.scale = Vector3.ONE * (size / 0.6)
		crate.position.y = -size * 0.5
		add_child(crate)
		_meshes = crate.find_children("*", "MeshInstance3D", true, false)
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = COLOR
		mi.material_override = m
		add_child(mi)
		_meshes = [mi]
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(LIT, 0.55)


func set_highlight(on: bool) -> void:
	highlighted = on
	for m in _meshes:
		m.material_overlay = _glow if on else null    # a gold wash over the crate while it's the target
