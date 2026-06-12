extends SceneTree
## Texture authoring tool: writes the rich "authored" texture set into
## assets/textures/, where it overrides the simple runtime generators
## (see pixel_textures.gd named_tex). Run when art recipes change:
##   godot --headless --path pixelgp --script res://tests/author_textures.gd
## Any of these PNGs can later be replaced by hand-painted art.

const OUT := "res://assets/textures/%s.png"

var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/textures")
	_save("asphalt", _asphalt())
	_save("ground", _ground())
	_save("curb", _curb())
	_save("barrier", _barrier())
	var walls := {
		"oldtown": [Color(0.82, 0.62, 0.4), Color(0.8, 0.55, 0.42), Color(0.85, 0.7, 0.5), Color(0.78, 0.5, 0.34)],
		"harbor": [Color(0.9, 0.74, 0.72), Color(0.88, 0.84, 0.74), Color(0.72, 0.8, 0.84), Color(0.74, 0.85, 0.76)],
		"casino": [Color(0.92, 0.89, 0.8), Color(0.95, 0.92, 0.86), Color(0.88, 0.82, 0.66), Color(0.92, 0.89, 0.8)],
		"center": [Color(0.85, 0.78, 0.66), Color(0.75, 0.72, 0.62), Color(0.8, 0.76, 0.72), Color(0.7, 0.66, 0.6)],
		"wood": [Color(0.42, 0.3, 0.22), Color(0.5, 0.36, 0.26), Color(0.36, 0.26, 0.2), Color(0.55, 0.42, 0.3)],
		"garden": [Color(0.9, 0.88, 0.82), Color(0.85, 0.84, 0.78), Color(0.8, 0.78, 0.7), Color(0.88, 0.85, 0.76)],
	}
	var awnings := {
		"oldtown": [Color(0.25, 0.5, 0.3), Color(0.8, 0.45, 0.15)],
		"harbor": [Color(0.8, 0.2, 0.18), Color(0.15, 0.5, 0.6)],
		"casino": [Color(0.7, 0.5, 0.15), Color(0.45, 0.12, 0.2)],
		"center": [Color(0.3, 0.35, 0.5), Color(0.55, 0.25, 0.25)],
		"wood": [Color(0.75, 0.18, 0.15), Color(0.2, 0.25, 0.4)],
		"garden": [Color(0.65, 0.15, 0.15), Color(0.25, 0.4, 0.35)],
	}
	for district in walls.keys():
		for idx in 4:
			var fname := "facade_%s_%d" % [district, idx]
			rng.seed = hash(fname)
			_save(fname, _facade(district, walls[district][idx], awnings[district]))
	print("authored texture set written to assets/textures/")
	quit(0)

func _save(name: String, img: Image) -> void:
	img.save_png(OUT % name)
	print("  ", name)

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, c)

# --- surfaces -----------------------------------------------------------------

func _asphalt() -> Image:
	rng.seed = 101
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var v := 0.055 + rng.randf() * 0.01
			img.set_pixel(x, y, Color(v, v, v * 1.12))
	# repair patches
	for p in 4:
		var px := rng.randi() % 56
		var py := rng.randi() % 56
		var pw := 6 + rng.randi() % 14
		var ph := 6 + rng.randi() % 14
		var dv := (rng.randf() - 0.5) * 0.02
		for yy in range(py, mini(py + ph, 64)):
			for xx in range(px, mini(px + pw, 64)):
				var c := img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(c.r + dv, c.g + dv, c.b + dv))
	# cracks: dark random walks
	for cidx in 6:
		var cx := rng.randi() % 64
		var cy := rng.randi() % 64
		for s in 10 + rng.randi() % 16:
			img.set_pixel(cx % 64, cy % 64, Color(0.03, 0.03, 0.04))
			cx += rng.randi() % 3 - 1
			cy += 1
	# sparse light speckle
	for s in 20:
		var sx := rng.randi() % 64
		var sy := rng.randi() % 64
		var c2 := img.get_pixel(sx, sy)
		img.set_pixel(sx, sy, c2.lightened(0.5))
	# manhole cover
	var mx := 14
	var my := 44
	for yy in range(-4, 5):
		for xx in range(-4, 5):
			var d := sqrt(float(xx * xx + yy * yy))
			if d < 3.6:
				img.set_pixel(mx + xx, my + yy, Color(0.07, 0.07, 0.08) if int(d * 2.0) % 2 == 0 else Color(0.05, 0.05, 0.06))
			elif d < 4.4:
				img.set_pixel(mx + xx, my + yy, Color(0.03, 0.03, 0.04))
	return img

func _ground() -> Image:
	rng.seed = 102
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	# calm promenade paving: subtle grout, gentle tone variance (the original
	# high-contrast pave grid read as noise from the race camera)
	var grout := Color(0.37, 0.345, 0.3)
	for y in 48:
		for x in 48:
			if x % 8 == 0 or y % 8 == 0:
				img.set_pixel(x, y, grout)
			else:
				var v := 0.41 + rng.randf() * 0.028
				img.set_pixel(x, y, Color(v, v * 0.92, v * 0.78))
	for sy in 6:
		for sx in 6:
			if rng.randf() < 0.12:
				var ox := sx * 8 + 1
				var oy := sy * 8 + 1
				for yy in range(oy, oy + 7):
					for xx in range(ox, ox + 7):
						var c := img.get_pixel(xx, yy)
						img.set_pixel(xx, yy, Color(c.r * 0.96, c.g * 0.97, c.b * 1.02))
	return img

func _curb() -> Image:
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 8:
			var red := y < 8
			var c := Color(0.85, 0.12, 0.1) if red else Color(0.93, 0.9, 0.86)
			var band_y := y % 8
			if band_y == 0:
				c = c.lightened(0.18)  # bevel highlight
			elif band_y == 7:
				c = c.darkened(0.22)   # bevel shadow
			img.set_pixel(x, y, c)
	return img

func _barrier() -> Image:
	rng.seed = 103
	var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 32:
			var c := Color(0.88, 0.87, 0.84)
			if y >= 3 and y <= 4:
				c = Color(0.8, 0.15, 0.12)
			if y == 7:
				c = c.darkened(0.3)
			if y == 0:
				c = c.lightened(0.1)
			if x % 8 == 0:
				c = c.darkened(0.28)
			img.set_pixel(x, y, c)
	for bx in [4, 12, 20, 28]:
		img.set_pixel(bx, 1, Color(0.5, 0.5, 0.52))
		img.set_pixel(bx, 6, Color(0.5, 0.5, 0.52))
	return img

# --- facades (32x48, four floors + ground-floor storefront) --------------------

func _facade(district: String, base: Color, awning_colors: Array) -> Image:
	var w := 32
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, base.darkened(0.04 * float((y / 8) % 2)))
	# roof trim
	_rect(img, 0, 0, w, 1, base.darkened(0.35))
	_rect(img, 0, 1, w, 1, base.lightened(0.18))
	if district == "wood":
		# machiya timber framing: vertical posts and floor beams
		for x in range(0, w, 4):
			_rect(img, x, 2, 1, h - 4, base.darkened(0.3))
		for f in 4:
			_rect(img, 0, 2 + f * 8, w, 1, base.darkened(0.4))
	elif district == "garden":
		# white plaster with dark timber border frame
		_rect(img, 0, 2, 1, h - 2, Color(0.3, 0.24, 0.2))
		_rect(img, w - 1, 2, 1, h - 2, Color(0.3, 0.24, 0.2))
		for f in 4:
			_rect(img, 0, 10 + f * 8, w, 1, Color(0.3, 0.24, 0.2))
	# corner quoins (western quarters only)
	if district != "wood" and district != "garden":
		for y in range(2, h - 12, 3):
			var on := (y / 3) % 2 == 0
			if on:
				_rect(img, 0, y, 2, 3, base.lightened(0.12))
				_rect(img, w - 2, y, 2, 3, base.lightened(0.12))
	# four window floors
	for f in 4:
		var fy := 3 + f * 8
		for k in 5:
			var fx := 3 + k * 6
			_window(img, district, base, awning_colors, fx, fy)
		if district == "casino":
			_rect(img, 2, fy + 7, w - 4, 1, Color(0.78, 0.62, 0.3))
	# pilasters for the casino quarter
	if district == "casino":
		for k in 6:
			var px := 1 + k * 6
			_rect(img, px, 3, 1, 32, base.lightened(0.15))
	_storefront(img, district, base, awning_colors)
	return img

func _window(img: Image, district: String, base: Color, awning_colors: Array, x: int, y: int) -> void:
	var lit := rng.randf() < 0.18
	var glass := Color(0.95, 0.85, 0.45) if lit else Color(0.15, 0.19, 0.28)
	match district:
		"oldtown":
			_rect(img, x, y + 1, 4, 5, glass)
			img.set_pixel(x, y + 1, base)      # arched top corners
			img.set_pixel(x + 3, y + 1, base)
			_rect(img, x, y, 4, 1, base.darkened(0.25))  # stone lintel
			var shutter := Color(0.25, 0.42, 0.28) if rng.randf() < 0.6 else Color(0.4, 0.28, 0.18)
			_rect(img, x - 1, y + 1, 1, 5, shutter)
			_rect(img, x + 4, y + 1, 1, 5, shutter)
		"harbor":
			_rect(img, x, y, 4, 6, glass)
			# wrought-iron balcony
			for k in 6:
				if k % 2 == 0:
					img.set_pixel(clampi(x - 1 + k, 0, 31), y + 5, Color(0.12, 0.12, 0.14))
			_rect(img, x - 1, y + 6, 6, 1, Color(0.18, 0.18, 0.2))
			if not awning_colors.is_empty() and rng.randf() < 0.45:
				var ac: Color = awning_colors[rng.randi() % awning_colors.size()]
				_rect(img, x - 1, y - 1, 6, 1, ac)
				for k in 6:  # scalloped edge
					if k % 2 == 1:
						img.set_pixel(clampi(x - 1 + k, 0, 31), y, ac.darkened(0.15))
		"casino":
			_rect(img, x, y, 4, 7, Color(0.78, 0.62, 0.3))  # gold frame
			_rect(img, x + 1, y + 1, 2, 5, glass)
			img.set_pixel(x + 1, y + 1, glass.lightened(0.2))
		"wood":
			# wide shoji screens with a warm paper glow and lattice
			var paper := Color(0.95, 0.85, 0.6) if rng.randf() < 0.5 else Color(0.55, 0.48, 0.38)
			_rect(img, x - 1, y + 1, 6, 5, paper)
			for lx in range(x - 1, x + 5, 2):
				_rect(img, lx, y + 1, 1, 5, paper.darkened(0.35))
			_rect(img, x - 1, y + 3, 6, 1, paper.darkened(0.35))
		"garden":
			_rect(img, x, y + 1, 4, 5, Color(0.3, 0.24, 0.2))
			_rect(img, x + 1, y + 2, 2, 3, glass)
		_:
			_rect(img, x, y, 4, 6, base.darkened(0.3))
			_rect(img, x + 1, y + 1, 2, 4, glass)
			_rect(img, x, y + 6, 4, 1, base.lightened(0.2))  # sill

func _storefront(img: Image, district: String, base: Color, awning_colors: Array) -> void:
	var w := 32
	if district == "wood" or district == "garden":
		# noren curtain: hanging split flaps over the entrance
		var nc: Color = awning_colors[rng.randi() % awning_colors.size()]
		for x in w:
			img.set_pixel(x, 35, nc)
			if (x / 3) % 2 == 0:
				img.set_pixel(x, 36, nc.darkened(0.1))
	elif not awning_colors.is_empty():
		# scalloped awning band
		var ac: Color = awning_colors[rng.randi() % awning_colors.size()]
		for x in w:
			img.set_pixel(x, 35, ac if (x / 2) % 2 == 0 else Color(0.93, 0.92, 0.88))
			if x % 2 == 1:
				img.set_pixel(x, 36, ac.darkened(0.2))
	# sign band with pixel lettering
	var sign_bg := base.darkened(0.55)
	_rect(img, 1, 37, w - 2, 2, sign_bg)
	var lx := 3
	while lx < w - 3:
		img.set_pixel(lx, 37 if rng.randf() < 0.5 else 38, Color(0.92, 0.9, 0.85))
		lx += 2 + rng.randi() % 2
	# display glass with goods
	_rect(img, 1, 39, w - 2, 7, Color(0.12, 0.15, 0.2))
	var goods := [Color(0.85, 0.4, 0.3), Color(0.4, 0.7, 0.4), Color(0.9, 0.8, 0.4), Color(0.5, 0.6, 0.85)]
	for g in 6:
		var gx := 2 + rng.randi() % (w - 6)
		if gx > 12 and gx < 19:
			continue  # keep the door clear
		_rect(img, gx, 42 + rng.randi() % 2, 2, 2, goods[rng.randi() % goods.size()])
	# door
	_rect(img, 14, 40, 4, 8, Color(0.35, 0.22, 0.12))
	img.set_pixel(17, 44, Color(0.85, 0.7, 0.3))
	# pavement shadow
	_rect(img, 0, 47, w, 1, base.darkened(0.5))
