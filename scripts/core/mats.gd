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
