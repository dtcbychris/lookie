extends RefCounted
## Tiny procedurally generated pixel textures + material helpers.
## Placeholder art with the right texture *language* (nearest-filtered, chunky)
## so painted textures can drop in later without touching geometry code.

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static func tex_mat(tex: Texture2D, tint := Color.WHITE, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.9
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = emission
	return m

static func flat_mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static func asphalt() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var v := 0.05 + rng.randf() * 0.02
			if rng.randf() < 0.04:
				v += 0.035
			img.set_pixel(x, y, Color(v, v, v * 1.12))
	return _tex(img)

static func checker() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var on := (x / 2 + y / 2) % 2 == 0
			img.set_pixel(x, y, Color(0.92, 0.92, 0.92) if on else Color(0.06, 0.06, 0.07))
	return _tex(img)

static func curb() -> ImageTexture:
	# stripes across v (texture tiles along track length)
	var img := Image.create(4, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 4:
			img.set_pixel(x, y, Color(0.85, 0.12, 0.1) if y < 4 else Color(0.93, 0.9, 0.86))
	return _tex(img)

static func barrier() -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 16:
			var c := Color(0.88, 0.87, 0.84)
			if y >= 3 and y <= 4:
				c = Color(0.8, 0.15, 0.12)
			if x % 8 == 0:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return _tex(img)

static func facade(rng: RandomNumberGenerator, base: Color) -> ImageTexture:
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 12:
			img.set_pixel(x, y, base.darkened(0.06 * float(y % 2)))
	for wy in range(1, 14, 3):
		for wx in range(1, 11, 3):
			var lit := rng.randf() < 0.28
			var c := Color(0.95, 0.85, 0.45) if lit else Color(0.12, 0.14, 0.2)
			img.set_pixel(wx, wy, c)
			img.set_pixel(wx + 1, wy, c)
			img.set_pixel(wx, wy + 1, c.darkened(0.2))
			img.set_pixel(wx + 1, wy + 1, c.darkened(0.2))
	# ground-floor door band
	for x in 12:
		img.set_pixel(x, 15, base.darkened(0.35))
	return _tex(img)

static func crowd(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	var palette := [
		Color(0.9, 0.3, 0.25), Color(0.3, 0.5, 0.9), Color(0.95, 0.8, 0.3),
		Color(0.4, 0.8, 0.5), Color(0.92, 0.92, 0.92), Color(0.85, 0.5, 0.8),
	]
	for y in 8:
		for x in 32:
			if y % 2 == 0 and rng.randf() < 0.85:
				img.set_pixel(x, y, palette[rng.randi() % palette.size()].darkened(rng.randf() * 0.25))
			else:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.13))
	return _tex(img)

static func ground(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var v := 0.41 + rng.randf() * 0.045
			img.set_pixel(x, y, Color(v, v * 0.95, v * 0.86))
	return _tex(img)

static func water_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_disabled;
uniform vec3 deep : source_color = vec3(0.04, 0.22, 0.5);
uniform vec3 lite : source_color = vec3(0.35, 0.68, 0.95);
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 g = floor(wpos / 6.0);
	float w1 = sin(g.x * 0.35 + TIME * 1.6 + sin(g.y * 0.5));
	float w2 = sin(g.y * 0.55 - TIME * 1.1 + g.x * 0.2);
	float band = step(1.25, w1 + w2);
	float swell = step(0.6, sin(g.x * 0.13 - TIME * 0.5 + g.y * 0.21));
	vec3 col = mix(deep, deep * 1.3, swell * 0.8);
	col = mix(col, lite, band * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.35;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
