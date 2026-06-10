extends RefCounted
## Tiny procedurally generated pixel textures + material helpers.
## Placeholder art with the right texture *language* (nearest-filtered, chunky)
## so painted textures can drop in later without touching geometry code.

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static var _font: FontFile

## Press Start 2P (OFL) configured for crisp integer-pixel rendering.
static func pixel_font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.generate_mipmaps = false
	return _font

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

## Painted Riviera facade: cornice, window grid with lit/unlit glass, striped
## awnings over windows, balcony railings, ground-floor storefront with door.
## One texture stretches the full building height (no vertical tiling, so the
## storefront stays at street level).
static func facade(rng: RandomNumberGenerator, base: Color, awnings: Array, balconies: bool) -> ImageTexture:
	var w := 24
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, base.darkened(0.05 * float((y / 6) % 2)))
	for x in w:
		img.set_pixel(x, 0, base.darkened(0.3))
		img.set_pixel(x, 1, base.lightened(0.15))
	var wy := 4
	while wy + 5 < h - 6:
		var row_balcony := balconies and rng.randf() < 0.4
		var wx := 2
		while wx + 3 <= w - 2:
			var lit := rng.randf() < 0.2
			var glass := Color(0.95, 0.85, 0.45) if lit else Color(0.16, 0.2, 0.3)
			for yy in range(wy, wy + 4):
				for xx in range(wx, wx + 3):
					img.set_pixel(xx, yy, glass.darkened(0.18 if yy == wy else 0.0))
			img.set_pixel(wx - 1, wy + 1, base.darkened(0.3))
			img.set_pixel(wx + 3, wy + 1, base.darkened(0.3))
			if not awnings.is_empty() and rng.randf() < 0.4:
				var ac: Color = awnings[rng.randi() % awnings.size()]
				for xx in range(wx - 1, wx + 4):
					img.set_pixel(clampi(xx, 0, w - 1), wy - 1, ac if xx % 2 == 0 else Color(0.93, 0.92, 0.88))
			wx += 5
		if row_balcony:
			for x in range(1, w - 1):
				img.set_pixel(x, wy + 5, base.darkened(0.4))
				if x % 2 == 0:
					img.set_pixel(x, wy + 4, Color(0.15, 0.15, 0.17))
		wy += 6
	# ground-floor storefront
	for y in range(h - 6, h - 1):
		for x in range(1, w - 1):
			img.set_pixel(x, y, Color(0.13, 0.15, 0.2).lightened(0.05 * float(y % 2)))
	for y in range(h - 5, h):
		img.set_pixel(11, y, Color(0.35, 0.22, 0.12))
		img.set_pixel(12, y, Color(0.3, 0.18, 0.1))
	if not awnings.is_empty() and rng.randf() < 0.65:
		var ac2: Color = awnings[rng.randi() % awnings.size()]
		for x in w:
			img.set_pixel(x, h - 7, ac2 if (x / 2) % 2 == 0 else Color(0.93, 0.92, 0.88))
	for x in w:
		img.set_pixel(x, h - 1, base.darkened(0.45))
	return _tex(img)

static func awning(c: Color) -> ImageTexture:
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 8:
			img.set_pixel(x, y, c if (x / 2) % 2 == 0 else Color(0.93, 0.92, 0.88))
	return _tex(img)

static func crowd(rng: RandomNumberGenerator) -> ImageTexture:
	return crowd_frames(rng)[0]

## Two-frame crowd: half the heads bob up one pixel on alternate frames.
static func crowd_frames(rng: RandomNumberGenerator) -> Array:
	var palette := [
		Color(0.9, 0.3, 0.25), Color(0.3, 0.5, 0.9), Color(0.95, 0.8, 0.3),
		Color(0.4, 0.8, 0.5), Color(0.92, 0.92, 0.92), Color(0.85, 0.5, 0.8),
	]
	var w := 32
	var h := 8
	var heads: Array = []
	for y in range(0, h - 1, 2):
		for x in w:
			if rng.randf() < 0.8:
				heads.append([x, y, palette[rng.randi() % palette.size()], rng.randi() % 2 == 0])
	var frames: Array = []
	for f in 2:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.1, 0.1, 0.13))
		for hd in heads:
			var x: int = hd[0]
			var y: int = hd[1]
			if hd[3] == (f == 1):
				y = maxi(y - 1, 0)
			img.set_pixel(x, y, hd[2])
			if y + 1 < h:
				img.set_pixel(x, y + 1, (hd[2] as Color).darkened(0.45))
		frames.append(_tex(img))
	return frames

static func ground(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var v := 0.4 + rng.randf() * 0.045
			img.set_pixel(x, y, Color(v, v * 0.92, v * 0.78))
	return _tex(img)

static func water_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_disabled;
uniform vec3 deep : source_color = vec3(0.03, 0.17, 0.44);
uniform vec3 lite : source_color = vec3(0.28, 0.6, 0.92);
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 g = floor(wpos / 6.0);
	float w1 = sin(g.x * 0.35 + TIME * 1.6 + sin(g.y * 0.5));
	float w2 = sin(g.y * 0.55 - TIME * 1.1 + g.x * 0.2);
	float band = step(1.25, w1 + w2);
	float swell = step(0.6, sin(g.x * 0.13 - TIME * 0.5 + g.y * 0.21));
	vec3 col = mix(deep, deep * 1.35, swell * 0.8);
	col = mix(col, lite, band * 0.85);
	// sun glints
	float sp = step(0.992, fract(sin(dot(g, vec2(12.9898, 78.233)) + floor(TIME * 2.0)) * 43758.5453));
	col = mix(col, vec3(0.95, 0.98, 1.0), sp);
	ALBEDO = col;
	ROUGHNESS = 0.35;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
