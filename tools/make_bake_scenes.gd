extends SceneTree
## Builds the static scenes that tools/bake.sh lightmaps, under res://levels/baked/.
##   godot --headless --path . -s tools/make_bake_scenes.gd
## Each scene holds the level's static geometry, a sun matching the level's sky, the
## sky's light for the bounce, and a LightmapGI. The bake writes <name>.lmbake and
## <name>.exr next to it; the level loads the baked scene and lights only moving
## things (you, NPCs, the chain) in real time, with no real-time shadows.

const KETTLE_GLB := "res://assets/models/townhouse/copper_kettle.glb"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://levels/baked")
	_kettle()
	quit()


## The sky a level is baked under: its sun and the light from the dome.
static func sun_for(sky_id: String) -> DirectionalLight3D:
	var s: Dictionary = Skies.LIST[sky_id]
	var sun := DirectionalLight3D.new()
	sun.name = "BakeSun"
	var dir := Basis.from_euler(Vector3(deg_to_rad(s.elev), -s.u * TAU, 0)) * Vector3.FORWARD
	sun.basis = Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK)
	sun.light_color = s.light
	sun.light_energy = s.energy
	sun.light_bake_mode = Light3D.BAKE_STATIC
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.6          # a slightly soft sun: shadow edges blur a little with distance
	return sun


static func lightmap_for(sky_id: String, texel_scale := 1.0) -> LightmapGI:
	var s: Dictionary = Skies.LIST[sky_id]
	var lm := LightmapGI.new()
	lm.name = "LightmapGI"
	lm.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	lm.bounces = 3
	lm.texel_scale = texel_scale
	lm.use_denoiser = true
	lm.directional = false
	lm.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	lm.environment_custom_color = s.get("ambient_col", s.fog)
	lm.environment_custom_energy = s.ambient
	return lm


func _save(root: Node3D, path: String) -> void:
	for c in root.get_children():
		c.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print("saved ", path, " ", ResourceSaver.save(ps, path))
	root.free()


func _kettle() -> void:
	var root := Node3D.new()
	root.name = "CopperKettleBaked"
	var house: Node3D = (load(KETTLE_GLB) as PackedScene).instantiate()
	house.name = "House"
	root.add_child(house)
	root.add_child(sun_for(Skies.DEFAULT))
	root.add_child(lightmap_for(Skies.DEFAULT))
	_save(root, "res://levels/baked/copper_kettle.tscn")
