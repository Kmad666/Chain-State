class_name Mats
## Shared materials, cached so identical colours share one material.

static var _cache := {}


## Plain lit surface.
static func lit(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var key := "L%s%s" % [color, roughness]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_cache[key] = m
	return _cache[key]


## Polished metal (the silver chain and cuff).
static func metal(color: Color, roughness := 0.32) -> StandardMaterial3D:
	var key := "M%s%s" % [color, roughness]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.9
		m.roughness = roughness
		m.metallic_specular = 0.8
		_cache[key] = m
	return _cache[key]


## Mirror-polished metal (shaders/chrome.gdshader): the chain, arrowhead and cuff.
static func polished(color: Color) -> ShaderMaterial:
	var key := "P%s" % color
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/chrome.gdshader")
		m.set_shader_parameter("tint", color)
		_cache[key] = m
	return _cache[key]


## Worked steel (the chain): the polished shader made grey and a little satin,
## so it reads as steel under any sky instead of taking on the sky's colour.
static func steel() -> ShaderMaterial:
	var key := "P_steel"
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/chrome.gdshader")
		m.set_shader_parameter("tint", Color(0.80, 0.81, 0.83))
		m.set_shader_parameter("desat", 0.85)
		m.set_shader_parameter("lift", 0.16)
		m.set_shader_parameter("rough", 0.22)
		_cache[key] = m
	return _cache[key]


static var _marble_tex: Texture2D
static var _stone_bump: Texture2D


## Weathered marble for carved stone (the Roman pillars): soft grey veins through a
## warm white, laid on in world space so long pieces don't stretch it, and a fine
## pitting in the surface. The model's own vertex colours carry its baked shading
## (darker in the flutes and under the mouldings), multiplied in. `col` tints it.
static func marble(col: Color) -> StandardMaterial3D:
	var key := "S%s" % col
	if not _cache.has(key):
		if _marble_tex == null:
			var n := FastNoiseLite.new()
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.004
			n.fractal_octaves = 5
			n.domain_warp_enabled = true
			n.domain_warp_amplitude = 60.0
			n.domain_warp_frequency = 0.006
			var ramp := Gradient.new()
			ramp.offsets = PackedFloat32Array([0.0, 0.46, 0.5, 0.54, 1.0])
			ramp.colors = PackedColorArray([Color(0.95, 0.94, 0.91), Color(0.93, 0.92, 0.89),
				Color(0.70, 0.70, 0.70), Color(0.92, 0.91, 0.88), Color(0.97, 0.96, 0.93)])
			var t := NoiseTexture2D.new()
			t.width = 1024
			t.height = 1024
			t.seamless = true
			t.noise = n
			t.color_ramp = ramp
			_marble_tex = t
			var b := FastNoiseLite.new()
			b.noise_type = FastNoiseLite.TYPE_CELLULAR
			b.frequency = 0.05
			var bt := NoiseTexture2D.new()
			bt.width = 256
			bt.height = 256
			bt.seamless = true
			bt.as_normal_map = true
			bt.bump_strength = 2.0
			bt.noise = b
			_stone_bump = bt
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.albedo_texture = _marble_tex
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.62
		m.normal_enabled = true
		m.normal_texture = _stone_bump
		m.normal_scale = 0.25
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 2.5         # a vein pattern about 2.5 m across
		m.uv1_triplanar_sharpness = 3.0
		_cache[key] = m
	return _cache[key]


## Point every polished material's fake reflections at the current sky.
static func set_chrome_env(top: Color, horizon: Color, ground: Color, strength := 1.0) -> void:
	for k in _cache:
		var m = _cache[k]
		if m is ShaderMaterial and str(k).begins_with("P"):
			m.set_shader_parameter("env_top", top)
			m.set_shader_parameter("env_horizon", horizon)
			m.set_shader_parameter("env_ground", ground)
			m.set_shader_parameter("strength", strength)


## Unshaded colour (UI-ish world markers).
static func flat(color: Color) -> StandardMaterial3D:
	var key := "F%s" % color
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache[key] = m
	return _cache[key]


## Lit surface with a 1 m checker grid, so you can read speed and distance.
static func grid(a: Color, b: Color, cells_per_tile := 2) -> StandardMaterial3D:
	var key := "G%s%s%s" % [a, b, cells_per_tile]
	if not _cache.has(key):
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		var cell := n / cells_per_tile
		for y in n:
			for x in n:
				var on := ((x / cell) + (y / cell)) % 2 == 0
				var c := a if on else b
				if x % cell == 0 or y % cell == 0:
					c = c.darkened(0.18)   # thin line on every cell edge
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(cells_per_tile)   # one cell = 1 m
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = 0.9
		_cache[key] = m
	return _cache[key]
