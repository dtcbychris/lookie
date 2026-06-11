extends Node3D
## Hand-placed set dressing: renders the "set_dressing" section of the track
## JSON through a small prop library. This is the curated composition layer on
## top of the RNG scenery — race-weekend furniture placed by an art director,
## not a dice roll. Tracks 2-9 get dressed the same way.
##
## Prop space: each prop gets a root at the world position, rotated so local
## +X points along "facing" (degrees: 0 = +x east, 90 = +z south).

const Pix = preload("res://scripts/pixel_textures.gd")

var track  # TrackData
var _sway: Array[Node3D] = []     # flags, animated
var _rotors: Array[Node3D] = []   # helicopter rotors
var _screens: Array = []          # {"mat": ..., "frames": [..]}
var _screen_frame := 0
var _rng := RandomNumberGenerator.new()

func build(p_track) -> void:
	track = p_track
	_rng.seed = 23
	for entry in track.set_dressing:
		var at: Array = entry["at"]
		var pos := Vector3(at[0] * track.WORLD_SCALE, 0, at[1] * track.WORLD_SCALE)
		var root := Node3D.new()
		root.position = pos
		root.rotation.y = -deg_to_rad(float(entry.get("facing", 0)))
		add_child(root)
		match entry["type"]:
			"flag_row":
				_flag_row(root, int(entry.get("count", 6)))
			"big_screen":
				_big_screen(root)
			"tv_crane":
				_tv_crane(root)
			"camera_tower":
				_camera_tower(root)
			"marshal_post":
				_marshal_post(root)
			"statue":
				_statue(root)
			"cafe_terrace":
				_cafe_terrace(root)
			"helipad":
				_helipad(root)
			"harbor_crane":
				_harbor_crane(root)
			_:
				push_warning("unknown set_dressing type: %s" % entry["type"])

func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _sway.size():
		_sway[i].rotation.x = sin(t * 3.0 + float(i) * 1.7) * 0.2
	for r in _rotors:
		r.rotation.y = t * 2.2
	var fi := 0 if fmod(t, 0.8) < 0.4 else 1
	if fi != _screen_frame:
		_screen_frame = fi
		for s in _screens:
			s["mat"].albedo_texture = s["frames"][fi]
			s["mat"].emission_texture = s["frames"][fi]

# --- helpers -------------------------------------------------------------------

func _part(root: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)
	return mi

func _cyl(root: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, segments := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segments
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi

# --- props ----------------------------------------------------------------------

## Row of sponsor/team flags along local +X.
func _flag_row(root: Node3D, count: int) -> void:
	var pole_mat := Pix.flat_mat(Color(0.8, 0.8, 0.82))
	var colors := [
		Color(0.89, 0.23, 0.18), Color(0.18, 0.44, 0.88), Color(0.88, 0.66, 0.18),
		Color(0.79, 0.8, 0.83), Color(0.5, 0.12, 0.55), Color(0.92, 0.92, 0.92),
	]
	for i in count:
		var pole := _part(root, Vector3(0.6, 11, 0.6), Vector3(float(i) * 16.0, 5.5, 0), pole_mat)
		var flag := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(5, 3)
		flag.mesh = qm
		var fm := Pix.flat_mat(colors[i % colors.size()], 0.2)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = fm
		flag.position = Vector3(2.8, 4.2, 0)
		pole.add_child(flag)
		_sway.append(flag)

## Jumbotron with an animated "broadcast" texture, facing local +X.
func _big_screen(root: Node3D) -> void:
	var dark := Pix.flat_mat(Color(0.16, 0.17, 0.2))
	for side in [-1.0, 1.0]:
		_part(root, Vector3(1.4, 13, 1.4), Vector3(0, 6.5, side * 7.0), dark)
	_part(root, Vector3(1.6, 10, 17), Vector3(0, 13, 0), dark)
	var frames: Array = _broadcast_frames()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = frames[0]
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.emission_enabled = true
	mat.emission_texture = frames[0]
	mat.emission_energy_multiplier = 0.9
	_screens.append({"mat": mat, "frames": frames})
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(15.5, 8.6)
	screen.mesh = qm
	screen.material_override = mat
	screen.position = Vector3(0.9, 13, 0)
	screen.rotation.y = PI / 2.0  # quad +Z -> local +X
	root.add_child(screen)

func _broadcast_frames() -> Array:
	var out: Array = []
	for f in 2:
		var img := Image.create(32, 18, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.07, 0.1, 0.2))
		for x in 32:  # white border
			img.set_pixel(x, 0, Color(0.85, 0.88, 0.92))
			img.set_pixel(x, 17, Color(0.85, 0.88, 0.92))
		# "live feed": car-colored blobs on track-gray band
		for y in range(6, 13):
			for x in range(1, 31):
				img.set_pixel(x, y, Color(0.22, 0.22, 0.26))
		var blob_x := 6 + f * 9
		img.set_pixel(blob_x, 9, Color(0.89, 0.23, 0.18))
		img.set_pixel(blob_x + 1, 9, Color(0.89, 0.23, 0.18))
		img.set_pixel(blob_x + 6, 10, Color(0.18, 0.44, 0.88))
		img.set_pixel(blob_x + 7, 10, Color(0.18, 0.44, 0.88))
		# ticker
		var tx := 2 + f * 2
		while tx < 30:
			img.set_pixel(tx, 15, Color(0.95, 0.8, 0.25))
			tx += 3
		out.append(ImageTexture.create_from_image(img))
	return out

## Broadcast crane: tall yellow mast towering over the skyline, boom reaching
## toward local +X with a camera — visible from anywhere like real TV cranes.
func _tv_crane(root: Node3D) -> void:
	var yellow := Pix.flat_mat(Color(0.85, 0.72, 0.18))
	var dark := Pix.flat_mat(Color(0.2, 0.21, 0.25))
	_part(root, Vector3(8, 2, 8), Vector3(0, 1, 0), dark)
	_part(root, Vector3(4.5, 3.5, 4.5), Vector3(0, 3.7, 0), Pix.flat_mat(Color(0.9, 0.9, 0.92)))
	_part(root, Vector3(2.4, 56, 2.4), Vector3(0, 30, 0), yellow)
	# lattice hint: thin cross braces up the mast
	for k in 5:
		_part(root, Vector3(3.2, 0.6, 0.6), Vector3(0, 10 + k * 10, 0), dark)
	var boom := _part(root, Vector3(30, 1.8, 1.8), Vector3(12, 60, 0), yellow)
	boom.rotation.z = -0.12
	_part(root, Vector3(5, 2.6, 3.4), Vector3(-5, 60.5, 0), dark)  # counterweight
	var cam := _part(root, Vector3(2.8, 2.2, 2.6), Vector3(26.5, 57.5, 0), dark)
	cam.add_child(_lens())
	_part(root, Vector3(0.25, 18, 0.25), Vector3(26.5, 48, 0), dark)  # camera cable

## Speed-trap / TV camera post aimed at local +X.
func _camera_tower(root: Node3D) -> void:
	var gray := Pix.flat_mat(Color(0.55, 0.57, 0.6))
	_part(root, Vector3(1.2, 11, 1.2), Vector3(0, 5.5, 0), gray)
	_part(root, Vector3(3.4, 0.6, 3.4), Vector3(0, 11.2, 0), gray)
	var cam := _part(root, Vector3(3, 1.8, 1.8), Vector3(0.6, 12.4, 0), Pix.flat_mat(Color(0.18, 0.19, 0.23)))
	cam.add_child(_lens())

func _lens() -> MeshInstance3D:
	var lens := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.7
	cm.height = 1.0
	cm.radial_segments = 8
	lens.mesh = cm
	lens.material_override = Pix.flat_mat(Color(0.3, 0.5, 0.85), 0.5)
	lens.rotation.z = -PI / 2.0
	lens.position = Vector3(1.9, 0, 0)
	return lens

## Marshal stand: two orange marshals and a waving yellow flag, facing +X.
func _marshal_post(root: Node3D) -> void:
	_part(root, Vector3(5, 1.4, 3.6), Vector3(0, 0.7, 0), Pix.flat_mat(Color(0.85, 0.85, 0.82)))
	var orange := Pix.flat_mat(Color(0.95, 0.45, 0.1))
	var skin := Pix.flat_mat(Color(0.85, 0.65, 0.5))
	for k in 2:
		var bx := -1.1 + float(k) * 2.2
		_part(root, Vector3(1.1, 2.2, 0.9), Vector3(bx, 2.5, 0), orange)
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		head.mesh = sm
		head.material_override = skin
		head.position = Vector3(bx, 4.1, 0)
		root.add_child(head)
	var pole := _part(root, Vector3(0.3, 3.4, 0.3), Vector3(1.9, 3.4, 0), Pix.flat_mat(Color(0.6, 0.6, 0.62)))
	var flag := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.4, 1.7)
	flag.mesh = qm
	var fm := Pix.flat_mat(Color(0.95, 0.85, 0.15), 0.3)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.material_override = fm
	flag.position = Vector3(1.3, 1.2, 0)
	pole.add_child(flag)
	_sway.append(flag)

## Old-town bronze statue on a stone plinth.
func _statue(root: Node3D) -> void:
	var stone := Pix.flat_mat(Color(0.75, 0.7, 0.6))
	var bronze := Pix.flat_mat(Color(0.42, 0.58, 0.48))
	_part(root, Vector3(6, 1.2, 6), Vector3(0, 0.6, 0), stone)
	_part(root, Vector3(4.4, 3.6, 4.4), Vector3(0, 3, 0), stone)
	_part(root, Vector3(1.5, 2.6, 1.2), Vector3(0, 6.1, 0), bronze)   # legs
	_part(root, Vector3(1.8, 2.4, 1.4), Vector3(0, 8.6, 0), bronze)   # torso
	var arm := _part(root, Vector3(0.6, 2.4, 0.6), Vector3(1.0, 10.2, 0), bronze)
	arm.rotation.z = -0.5
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	sm.radial_segments = 6
	sm.rings = 3
	head.mesh = sm
	head.material_override = bronze
	head.position = Vector3(0, 10.6, 0)
	root.add_child(head)

## Promenade cafe: umbrellas + round tables.
func _cafe_terrace(root: Node3D) -> void:
	var colors := [Color(0.85, 0.25, 0.2), Color(0.95, 0.9, 0.82), Color(0.2, 0.5, 0.65)]
	var white := Pix.flat_mat(Color(0.92, 0.92, 0.9))
	for k in 4:
		var ox := float(k % 2) * 12.0 - 6.0
		var oz := float(k / 2) * 11.0 - 5.5
		var pole := _part(root, Vector3(0.5, 4, 0.5), Vector3(ox, 2, oz), Pix.flat_mat(Color(0.75, 0.72, 0.68)))
		var canopy := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 3.2
		cm.height = 1.5
		cm.radial_segments = 8
		canopy.mesh = cm
		canopy.material_override = Pix.flat_mat(colors[(k + _rng.randi() % 2) % colors.size()])
		canopy.position = Vector3(0, 2.2, 0)
		pole.add_child(canopy)
		_cyl(root, 1.5, 1.5, 0.3, Vector3(ox + 3.4, 1.6, oz + 1.5), white, 8)
		_cyl(root, 0.2, 0.2, 1.5, Vector3(ox + 3.4, 0.75, oz + 1.5), white, 6)

## Helipad with a parked news helicopter, rotor idling.
func _helipad(root: Node3D) -> void:
	var pad_dark := Pix.flat_mat(Color(0.3, 0.32, 0.36))
	var white := Pix.flat_mat(Color(0.92, 0.92, 0.9))
	_cyl(root, 14, 14, 0.6, Vector3(0, 0.3, 0), pad_dark, 12)
	_cyl(root, 11.5, 11.5, 0.2, Vector3(0, 0.71, 0), white, 12)
	_cyl(root, 10, 10, 0.2, Vector3(0, 0.82, 0), pad_dark, 12)
	_part(root, Vector3(1.2, 0.15, 7), Vector3(-2, 0.95, 0), white)
	_part(root, Vector3(1.2, 0.15, 7), Vector3(2, 0.95, 0), white)
	_part(root, Vector3(2.8, 0.15, 1.2), Vector3(0, 0.95, 0), white)
	# helicopter
	var heli := Node3D.new()
	heli.position = Vector3(0, 1.0, 0)
	heli.rotation.y = -0.4
	root.add_child(heli)
	var body_mat := Pix.flat_mat(Color(0.9, 0.9, 0.92))
	_part(heli, Vector3(8, 3.4, 3), Vector3(0, 2.6, 0), body_mat)
	_part(heli, Vector3(8.2, 0.8, 3.1), Vector3(0, 2.0, 0), Pix.flat_mat(Color(0.85, 0.2, 0.18)))
	_part(heli, Vector3(2.2, 2.2, 2.6), Vector3(3.6, 2.8, 0), Pix.flat_mat(Color(0.25, 0.4, 0.6), 0.3))  # canopy
	_part(heli, Vector3(6, 1, 1), Vector3(-6.5, 3.2, 0), body_mat)
	_part(heli, Vector3(1, 2.6, 0.6), Vector3(-9.2, 4.2, 0), Pix.flat_mat(Color(0.85, 0.2, 0.18)))
	for side in [-1.0, 1.0]:
		_part(heli, Vector3(7, 0.4, 0.5), Vector3(0, 0.2, side * 1.6), Pix.flat_mat(Color(0.4, 0.4, 0.44)))
	var hub := Node3D.new()
	hub.position = Vector3(0.5, 4.7, 0)
	heli.add_child(hub)
	var blade_mat := Pix.flat_mat(Color(0.2, 0.2, 0.24))
	_part(hub, Vector3(15, 0.2, 0.9), Vector3.ZERO, blade_mat)
	_part(hub, Vector3(0.9, 0.2, 15), Vector3.ZERO, blade_mat)
	_rotors.append(hub)

## Quay crane on the west marina shore, boom over the water (local +X).
func _harbor_crane(root: Node3D) -> void:
	var rust := Pix.flat_mat(Color(0.6, 0.3, 0.2))
	var dark := Pix.flat_mat(Color(0.25, 0.26, 0.3))
	for side in [-1.0, 1.0]:
		_part(root, Vector3(2, 14, 2), Vector3(0, 7, side * 4.0), rust)
	_part(root, Vector3(3, 2.5, 11), Vector3(0, 15.2, 0), rust)
	_part(root, Vector3(4.5, 3.5, 4.5), Vector3(0, 18.2, 0), dark)
	var boom := _part(root, Vector3(22, 1.4, 1.4), Vector3(9, 21, 0), rust)
	boom.rotation.z = -0.28
	_part(root, Vector3(0.25, 9, 0.25), Vector3(18, 14, 0), dark)  # cable
	_part(root, Vector3(3.2, 2.6, 3.2), Vector3(18, 8.6, 0), Pix.flat_mat(Color(0.55, 0.4, 0.25)))  # crate
