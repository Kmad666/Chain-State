class_name GrappleTower
extends Node3D
## A tall round stone tower (Retro Fantasy Kit pieces) with grapple hooks sticking
## out of it: a reusable traversal landmark. Drop one into any level:
##
##   var t := preload("res://scripts/world/grapple_tower.gd").new()
##   t.position = Vector3(0, 0, 0)       # the base sits at the node's origin
##   add_child(t)                        # builds itself; see t.hooks and t.top_point()
##
## - The shaft is `sections` blocks of `unit` metres (8 m by default: 16 x 8 = 128 m).
## - Every `ledge_every` sections a wider stone ring sticks out: a rest ledge.
## - From every section a wooden beam juts out, a quarter-turn round from the last,
##   with a grapple crate at its tip. A quarter-turn keeps each crate in clear sight
##   of the next (half-turns would hide them behind the tower).
## - The crown is a walkable battlemented platform. The last hook stands on a post
##   above it, so you can swing up and latch down onto the top.
## - Stone and beams are solid but can't be grappled (Player.LAYER_LAND); only the
##   crates can. With free_hooks (default) the crates cost no air grapples.

const SwingAnchor := preload("res://scripts/world/swing_anchor.gd")
const FK := "res://assets/models/kenney/fantasy/%s.glb"
const LAYER_LAND := 8

@export var sections := 16
@export var unit := 8.0               # metres per kit block: the shaft is unit wide
@export var ledge_every := 4
@export var hook_reach := 5.0         # how far the beams stick out past the wall
@export var free_hooks := true
@export var start_angle := 0.0        # where the first hook points (radians, 0 = +X)

var hooks: Array = []                 # the grapple crates, bottom to top
var ledges: Array = []                # the rest-ledge bodies (and the crown, last)


func _ready() -> void:
	_build()


func shaft_radius() -> float:
	return unit * 0.5


## The walkable top of the crown.
func top_point() -> Vector3:
	return global_position + Vector3(0, sections * unit + 0.4 * unit * 1.25, 0)


func _build() -> void:
	var r := shaft_radius()
	var h := sections * unit
	# the shaft: base block, then plain and painted blocks (a painted band every 3)
	_piece("tower-base", Vector3.ZERO, unit)
	for i in range(1, sections):
		_piece("tower-paint" if i % 3 == 0 else "tower", Vector3(0, i * unit, 0), unit)
	_solid(CylinderShape3D.new(), r, h, Vector3(0, h * 0.5, 0))

	# rest ledges: the wide stone ring, every few sections
	for i in range(ledge_every, sections, ledge_every):
		var y := i * unit
		_piece("tower-edge", Vector3(0, y - 0.4 * unit * 1.25, 0), unit * 1.25)
		ledges.append(_solid(CylinderShape3D.new(), 0.6 * unit * 1.25, 0.4 * unit * 1.25, Vector3(0, y - 0.2 * unit * 1.25, 0)))

	# the crown: a wide floor with battlements round it
	var crown_y := h
	_piece("tower-edge", Vector3(0, crown_y, 0), unit * 1.25)
	_piece("tower-top", Vector3(0, crown_y + 0.4 * unit * 1.25, 0), unit * 1.25)
	ledges.append(_solid(CylinderShape3D.new(), 0.6 * unit * 1.25, 0.4 * unit * 1.25, Vector3(0, crown_y + 0.2 * unit * 1.25, 0)))

	# hooks: a beam out of every section, each a quarter-turn round from the last
	for i in range(1, sections):
		var a := start_angle + (i - 1) * PI * 0.5
		var y := i * unit + unit * 0.55
		_hook(a, y, r)
	# the last hook stands on a post above the crown, out over its edge
	var top := crown_y + 0.4 * unit * 1.25
	var post_h := unit * 1.2
	var sc = load(FK % "column-wood")
	if sc:
		var n: Node3D = sc.instantiate()
		n.scale = Vector3(unit * 0.25, post_h, unit * 0.25)
		n.position = Vector3(0, top, 0)
		add_child(n)
	var a_top := start_angle + (sections - 1) * PI * 0.5
	_hook(a_top, top + post_h, 0.0, unit * 0.6)


## A wooden beam jutting from the wall at angle a, height y, with a crate at its tip.
func _hook(a: float, y: float, from_r: float, reach := -1.0) -> void:
	var length := hook_reach if reach < 0.0 else reach
	var out := Vector3(cos(a), 0, sin(a))
	var sc = load(FK % "overhang")
	if sc:
		var beam: Node3D = sc.instantiate()
		# the kit's plank runs along X: point it outward, thick enough to read from afar
		beam.basis = Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(length + 0.6, unit * 0.35, unit * 0.18))
		beam.position = out * (from_r + length * 0.5 - 0.3) + Vector3(0, y, 0)
		add_child(beam)
	var crate := SwingAnchor.new()
	crate.free = free_hooks
	crate.position = out * (from_r + length + 0.4) + Vector3(0, y + 1.2, 0)
	add_child(crate)
	hooks.append(crate)


func _piece(model: String, at: Vector3, scale_by: float) -> Node3D:
	var sc = load(FK % model)
	if sc == null:
		return null
	var n: Node3D = sc.instantiate()
	n.position = at
	n.scale = Vector3.ONE * scale_by
	add_child(n)
	return n


func _solid(shape: CylinderShape3D, radius: float, height: float, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_LAND
	body.collision_mask = 0
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.position = at
	add_child(body)
	return body
