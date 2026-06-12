extends Node3D
## Generic scenery builder: reads the track JSON's "scenery" section (the
## track kit: water zones, ground, districts, landmarks, scatter bounds) and
## renders it with the style library below. Nothing in here is specific to
## one circuit; a new track is a new data file.

const Pix = preload("res://scripts/pixel_textures.gd")

## City districts give each part of town its own palette. The style library is
## global (keyed by district name); which rect of the map belongs to which
## district comes from the track data.
enum District { OLD_TOWN, HARBOR, CASINO, CENTER, WOOD, GARDEN }
const DISTRICT_BY_NAME := {
	"oldtown": District.OLD_TOWN, "harbor": District.HARBOR, "casino": District.CASINO,
	"center": District.CENTER, "wood": District.WOOD, "garden": District.GARDEN,
}

const DISTRICT_WALLS := {
	District.OLD_TOWN: [Color(0.82, 0.62, 0.4), Color(0.8, 0.55, 0.42), Color(0.85, 0.7, 0.5), Color(0.78, 0.5, 0.34)],
	District.HARBOR: [Color(0.9, 0.74, 0.72), Color(0.88, 0.84, 0.74), Color(0.72, 0.8, 0.84), Color(0.74, 0.85, 0.76)],
	District.CASINO: [Color(0.92, 0.89, 0.8), Color(0.95, 0.92, 0.86), Color(0.88, 0.82, 0.66)],
	District.CENTER: [Color(0.85, 0.78, 0.66), Color(0.75, 0.72, 0.62), Color(0.8, 0.76, 0.72), Color(0.7, 0.66, 0.6)],
	District.WOOD: [Color(0.42, 0.3, 0.22), Color(0.5, 0.36, 0.26), Color(0.36, 0.26, 0.2), Color(0.55, 0.42, 0.3)],
	District.GARDEN: [Color(0.9, 0.88, 0.82), Color(0.85, 0.84, 0.78), Color(0.8, 0.78, 0.7), Color(0.88, 0.85, 0.76)],
}
const DISTRICT_AWNINGS := {
	District.OLD_TOWN: [Color(0.25, 0.5, 0.3), Color(0.8, 0.45, 0.15)],
	District.HARBOR: [Color(0.8, 0.2, 0.18), Color(0.15, 0.5, 0.6)],
	District.CASINO: [Color(0.7, 0.5, 0.15), Color(0.45, 0.12, 0.2)],
	District.CENTER: [Color(0.3, 0.35, 0.5), Color(0.55, 0.25, 0.25)],
	District.WOOD: [Color(0.75, 0.18, 0.15), Color(0.2, 0.25, 0.4)],
	District.GARDEN: [Color(0.65, 0.15, 0.15), Color(0.25, 0.4, 0.35)],
}
## Terracotta dominates, like the concept art; the casino quarter gets
## oxidized-copper green landmarks.
const DISTRICT_ROOFS := {
	District.OLD_TOWN: Color(0.68, 0.36, 0.22),
	District.HARBOR: Color(0.72, 0.4, 0.26),
	District.CASINO: Color(0.42, 0.58, 0.48),
	District.CENTER: Color(0.66, 0.38, 0.24),
	District.WOOD: Color(0.3, 0.32, 0.4),     # slate
	District.GARDEN: Color(0.36, 0.4, 0.48),
}

func _district(a: Vector2) -> int:
	for rule in _district_rules:
		if (rule["rect"] as Rect2).has_point(a):
			return rule["district"]
	return _district_default

var track  # TrackData
var _rng := RandomNumberGenerator.new()
var _flags: Array[Node3D] = []
var _sea_yachts: Array[Node3D] = []
var _yacht_wrap := Vector2(-200.0, 1900.0)
var _casino_sign: Label3D
var _crowd_anims: Array = []  # {"mat": StandardMaterial3D, "frames": [Texture2D, Texture2D]}
var _crowd_frame := 0
var _building_rects: Array[Rect2] = []  # art-space footprints, for tree placement

# track-kit state, loaded from track.scenery in build()
var _kit: Dictionary = {}
var _water_zones: Array = []          # {"rect": Rect2, ...config}
var _open_south_y := 1.0e9            # water beyond this art y (open sea)
var _district_rules: Array = []
var _district_default := District.CENTER
var _exclusions: Array[Rect2] = []

## Ground footprint (art px, square side) auto-reserved around each landmark
## set piece so the RNG city scatter keeps clear.
const LANDMARK_RESERVE := {"casino": 58, "yacht_club": 46, "church": 46, "hotel": 56, "torii": 30, "pagoda": 50}

## Ground footprint (art px, square side) auto-reserved around each
## set-dressing entry so RNG buildings/trees keep clear.
const DRESS_RESERVE := {
	"helipad": 40, "harbor_crane": 26, "statue": 30, "cafe_terrace": 24,
	"big_screen": 18, "tv_crane": 22, "camera_tower": 8, "marshal_post": 8,
}

var _reserved_all: Array[Rect2] = []

func _build_reservations() -> void:
	for lm in _kit.get("landmarks", []):
		var at: Array = lm["at"]
		var s: float = LANDMARK_RESERVE.get(lm["type"], 40)
		var rect := Rect2(at[0] - s * 0.5, at[1] - s * 0.5, s, s)
		_reserved_all.append(rect)
		_building_rects.append(rect)  # trees and umbrellas keep out too
	# branch corridors (pit / hidden paths) keep clear of RNG buildings/trees
	for b in track.branches:
		var pts: PackedVector3Array = b["pts"]
		for i in pts.size() - 1:
			var steps := maxi(int(Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length() / 24.0), 1)
			for s in steps + 1:
				var p: Vector3 = pts[i].lerp(pts[i + 1], float(s) / steps)
				var rect := Rect2(p.x * 0.5 - 9.0, p.z * 0.5 - 9.0, 18.0, 18.0)
				_reserved_all.append(rect)
				_building_rects.append(rect)
	for e in track.set_dressing:
		var at: Array = e["at"]
		if e["type"] == "flag_row":
			var length := float(e.get("count", 6)) * 8.0
			_reserved_all.append(Rect2(at[0] - 4.0, at[1] - 4.0, length + 8.0, 8.0))
			continue
		var s: float = DRESS_RESERVE.get(e["type"], 10)
		var rect := Rect2(at[0] - s * 0.5, at[1] - s * 0.5, s, s)
		_reserved_all.append(rect)
		_building_rects.append(rect)  # trees and umbrellas keep out too

func build(p_track) -> void:
	track = p_track
	_kit = track.scenery
	for w in _kit.get("water", []):
		var zone: Dictionary = (w as Dictionary).duplicate()
		var r: Array = zone["rect"]
		zone["rect"] = Rect2(r[0], r[1], r[2], r[3])
		_water_zones.append(zone)
		if zone.get("open_south", false):
			_open_south_y = minf(_open_south_y, (zone["rect"] as Rect2).position.y)
	for rule in _kit.get("districts", []):
		var rr: Array = rule["rect"]
		_district_rules.append({"rect": Rect2(rr[0], rr[1], rr[2], rr[3]), "district": DISTRICT_BY_NAME[rule["name"]]})
	_district_default = DISTRICT_BY_NAME[_kit.get("district_default", "center")]
	for e in _kit.get("exclusions", []):
		_exclusions.append(Rect2(e[0], e[1], e[2], e[3]))
	_rng.seed = 7
	_build_reservations()
	_build_ground_and_water()
	_build_water_features()
	_build_city()
	for lm in _kit.get("landmarks", []):
		match lm["type"]:
			"casino":
				_build_casino(lm)
			"yacht_club":
				_build_yacht_club(lm)
			"church":
				_build_church(lm)
			"hotel":
				_build_hotel(lm)
			"torii":
				_build_torii(lm)
			"pagoda":
				_build_pagoda(lm)
			"bridge":
				_build_bridge(lm)
	_build_petals()
	_build_trees()
	_build_tree_rows()
	_build_grandstands()
	_build_trackside_crowds()
	_build_palms()
	_build_umbrellas()
	_build_billboards()
	_build_streetlights()
	_build_pit_lane()

func _excluded(a: Vector2) -> bool:
	for r in _exclusions:
		if r.has_point(a):
			return true
	return false

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _flags.size():
		_flags[i].rotation.x = sin(t * 3.0 + float(i) * 1.3) * 0.18
	for i in _sea_yachts.size():
		var y := _sea_yachts[i]
		y.position.x += (8.0 + 3.0 * float(i)) * _delta * (1.0 if i % 2 == 0 else -1.0)
		if y.position.x > _yacht_wrap.y:
			y.position.x = _yacht_wrap.x
		if y.position.x < _yacht_wrap.x - 50.0:
			y.position.x = _yacht_wrap.y + 50.0
		y.position.y = -3.2 + sin(t * 1.2 + float(i)) * 0.3
	if _casino_sign:
		_casino_sign.modulate.a = 0.75 + 0.25 * sin(t * 4.0)
	for kd in _koi:
		var kn: MeshInstance3D = kd["node"]
		var ang: float = t * kd["speed"] + kd["phase"]
		var ctr: Vector2 = kd["center"]
		kn.position.x = ctr.x + cos(ang) * kd["radius"]
		kn.position.z = ctr.y + sin(ang) * kd["radius"]
		kn.rotation.y = -ang - (PI / 2.0 if kd["speed"] > 0.0 else -PI / 2.0)
	for pd in _petals:
		var node: MeshInstance3D = pd["node"]
		node.position.y -= pd["fall"] * _delta
		node.position.x += sin(t * 0.8 + pd["phase"]) * 6.0 * _delta
		node.rotation.y += _delta * 2.0
		if node.position.y < 0.5:
			node.position.y = _rng.randf_range(24.0, 32.0)
	# two-frame crowd bob
	var fi := 0 if fmod(t, 0.7) < 0.35 else 1
	if fi != _crowd_frame:
		_crowd_frame = fi
		for ca in _crowd_anims:
			ca["mat"].albedo_texture = ca["frames"][fi]

# --- helpers ------------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	return mi

func _w(ax: float, ay: float) -> Vector2:
	return Vector2(ax, ay) * track.WORLD_SCALE

func _in_water_art(a: Vector2) -> bool:
	if a.y > _open_south_y:
		return true
	for z in _water_zones:
		if (z["rect"] as Rect2).has_point(a):
			return true
	return false

func _label(text: String, pos: Vector3, face_dir: Vector3, color: Color, size := 48, px := 0.09) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font = Pix.pixel_font()
	lbl.font_size = size
	lbl.pixel_size = px
	lbl.modulate = color
	lbl.outline_size = 12
	lbl.position = pos
	lbl.rotation.y = atan2(face_dir.x, face_dir.z)
	add_child(lbl)
	return lbl

# --- ground & water -----------------------------------------------------------

func _ground_piece(r: Rect2, mat: Material) -> void:
	var size: Vector2 = r.size * track.WORLD_SCALE
	var center: Vector2 = (r.position + r.size * 0.5) * track.WORLD_SCALE
	_box(Vector3(size.x, 1.0, size.y), Vector3(center.x, -1.1, center.y), mat)

func _build_ground_and_water() -> void:
	var gmat := Pix.tex_mat(Pix.ground(_kit.get("ground_texture", "ground")))
	gmat.uv1_scale = Vector3(40, 40, 1)
	for g in _kit.get("ground", []):
		_ground_piece(Rect2(g[0], g[1], g[2], g[3]), gmat)
	var quay := Pix.flat_mat(Color(0.55, 0.52, 0.47))
	for z in _water_zones:
		var r: Rect2 = z["rect"]
		var wmat := Pix.water_material()
		if z.has("deep"):
			var dc: Array = z["deep"]
			wmat.set_shader_parameter("deep", Color(dc[0], dc[1], dc[2]))
		if z.has("lite"):
			var lc: Array = z["lite"]
			wmat.set_shader_parameter("lite", Color(lc[0], lc[1], lc[2]))
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = r.size * track.WORLD_SCALE
		mi.mesh = pm
		mi.material_override = wmat
		var c: Vector2 = (r.position + r.size * 0.5) * track.WORLD_SCALE
		mi.position = Vector3(c.x, -4.0, c.y)
		add_child(mi)
		var quay_mode: String = z.get("quay", "")
		if quay_mode == "ring" or quay_mode == "north":
			_box(Vector3(r.size.x * 2 + 8, 6, 4), Vector3(c.x, -2, r.position.y * 2), quay)
		if quay_mode == "ring":
			_box(Vector3(r.size.x * 2 + 8, 6, 4), Vector3(c.x, -2, r.end.y * 2), quay)
			_box(Vector3(4, 6, r.size.y * 2), Vector3(r.position.x * 2, -2, c.y), quay)
			_box(Vector3(4, 6, r.size.y * 2), Vector3(r.end.x * 2, -2, c.y), quay)
		if z.has("label"):
			_label(z["label"], Vector3(c.x, 8, r.position.y * 2 + 6), Vector3(0, 0, -1), Color(0.4, 0.8, 1.0), 56, 0.1)
		# koi drifting in slow circles
		for k in int(z.get("koi", 0)):
			var koi := _box(Vector3(2.6, 0.4, 1.1),
				Vector3(c.x, -3.55, c.y), Pix.flat_mat(Color(0.95, 0.45, 0.15) if k % 3 != 0 else Color(0.93, 0.9, 0.88), 0.25))
			_koi.append({
				"node": koi,
				"center": Vector2(c.x + _rng.randf_range(-r.size.x * 0.6, r.size.x * 0.6), c.y + _rng.randf_range(-r.size.y * 0.6, r.size.y * 0.6)),
				"radius": _rng.randf_range(8.0, 22.0),
				"phase": _rng.randf_range(0, TAU),
				"speed": _rng.randf_range(0.25, 0.5) * (1.0 if k % 2 == 0 else -1.0),
			})

# --- per-zone water features (piers, berthed/drifting yachts, buoys) -----------

func _build_water_features() -> void:
	_rng.seed = 11
	var wood := Pix.flat_mat(Color(0.55, 0.4, 0.25))
	var buoy_mat := Pix.flat_mat(Color(0.95, 0.4, 0.1), 0.4)
	for z in _water_zones:
		var r: Rect2 = z["rect"]
		for px in z.get("piers_x", []):
			_box(Vector3(6, 1, 80), Vector3(float(px) * 2, -3.2, r.position.y * 2 + 44), wood)
		for k in int(z.get("yachts", 0)):
			var ax := _rng.randf_range(r.position.x + 22, r.end.x - 22)
			var ay := _rng.randf_range(r.position.y + 12, r.end.y - 12)
			_yacht(Vector2(ax, ay) * 2.0, _rng.randf_range(0, TAU), _rng.randf_range(0.6, 1.4), false)
		if z.has("drift_rect"):
			var dr: Array = z["drift_rect"]
			_yacht_wrap = Vector2((dr[0] as float - 60.0) * 2.0, (dr[0] + dr[2] + 60.0) * 2.0)
			for k in int(z.get("drifting_yachts", 0)):
				var y := _yacht(Vector2(
					_rng.randf_range(dr[0], dr[0] + dr[2]) * 2.0,
					_rng.randf_range(dr[1], dr[1] + dr[3]) * 2.0), 0.0, _rng.randf_range(1.0, 2.0), true)
				_sea_yachts.append(y)
		for k in int(z.get("buoys", 0)):
			var bx := _rng.randf_range(r.position.x + 20, r.end.x - 20) * 2.0
			var bz := _rng.randf_range(r.position.y + 10, r.end.y - 10) * 2.0
			_box(Vector3(1.6, 1.6, 1.6), Vector3(bx, -3.4, bz), buoy_mat)

func _yacht(world_xz: Vector2, yaw: float, s: float, drifting: bool) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(world_xz.x, -3.2, world_xz.y)
	root.rotation.y = yaw
	add_child(root)
	var hull := Pix.flat_mat(Color(0.93, 0.93, 0.95))
	var deck := Pix.flat_mat(Color(0.75, 0.62, 0.45))
	var cabin := Pix.flat_mat(Color(0.35, 0.55, 0.75))
	for parts in [
		[Vector3(22, 2.6, 7) * s, Vector3(0, 1.0, 0), hull],
		[Vector3(16, 1.0, 5.4) * s, Vector3(-1 * s, 2.6, 0), deck],
		[Vector3(8, 2.6, 4.6) * s, Vector3(-2 * s, 4.2, 0), cabin],
		[Vector3(0.6, 9, 0.6) * s, Vector3(3 * s, 7, 0), hull],
	]:
		_yacht_part(root, parts[0], parts[1], parts[2])
	return root

func _yacht_part(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)

# --- city ---------------------------------------------------------------------

func _build_city() -> void:
	# pre-bake a few facade materials per district
	var mats := {}
	var awning_mats := {}
	for d in District.values():
		var list: Array = []
		for k in 4:
			var walls: Array = DISTRICT_WALLS[d]
			list.append(Pix.tex_mat(Pix.facade_named(d, k, walls[k % walls.size()], DISTRICT_AWNINGS[d], d != District.CASINO)))
		mats[d] = list
		var alist: Array = []
		for ac in DISTRICT_AWNINGS[d]:
			alist.append(Pix.tex_mat(Pix.awning(ac)))
		awning_mats[d] = alist
	_rng.seed = 7
	var cr: Array = _kit.get("city_rect", [-130, -130, 1190, 890])
	var gx: float = cr[0]
	while gx < cr[0] + cr[2]:
		var gy: float = cr[1]
		while gy < cr[1] + cr[3]:
			gy += 34.0
			if _rng.randf() < 0.24:
				continue
			var ax := gx + _rng.randf_range(-8, 8)
			var ay := gy + _rng.randf_range(-8, 8)
			var a := Vector2(ax, ay)
			if _in_water_art(a) or _excluded(a):
				continue
			var w := _rng.randf_range(36, 68)
			var d := _rng.randf_range(36, 68)
			var half_diag := Vector2(w, d).length() * 0.5
			var p := _w(ax, ay)
			if track.min_dist_to_track(p.x, p.y) < track.HALF + 10.0 + half_diag:
				continue
			var reserved := false
			for rr in _reserved_all:
				if rr.intersects(Rect2(ax - w * 0.25, ay - d * 0.25, w * 0.5, d * 0.5)):
					reserved = true
					break
			if reserved:
				continue
			var hr: Array = _kit.get("building_heights", [28, 95])
			var h := _rng.randf_range(hr[0], hr[1])
			# hillside city: building tops must clear nearby elevated roads
			var ni: int = track.nearest_index_hint(p.x, p.y, 0, 0, track.n - 1)
			h = maxf(h, track.samples[ni].y + 24.0)
			var dist: float = track.min_dist_to_track(p.x, p.y)
			var near_track: bool = dist < track.HALF + 75.0
			var district := _district(a)
			var dlist: Array = mats[district]
			var m: StandardMaterial3D = (dlist[_rng.randi() % dlist.size()] as StandardMaterial3D).duplicate()
			# stretch one facade over the full height so the storefront stays
			# at street level; tile horizontally per ~28 units (32px texture)
			m.uv1_scale = Vector3(maxf(roundf(w / 28.0), 1.0), 1.0, 1.0)
			var yaw := 0.0 if near_track else _rng.randf_range(-0.06, 0.06)
			var b := _box(Vector3(w, h, d), Vector3(p.x, h * 0.5 - 0.5, p.y), m, yaw)
			_building_rects.append(Rect2(ax - w * 0.25, ay - d * 0.25, w * 0.5, d * 0.5))
			# tiered "pitched" roof in the district's roof color
			var rc: Color = DISTRICT_ROOFS[district]
			var roof_mat := Pix.flat_mat(rc.lerp(rc.lightened(0.18), _rng.randf()))
			var roof := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(w + 1.5, 1.2, d + 1.5)
			roof.mesh = rm
			roof.material_override = roof_mat
			roof.position = Vector3(0, h * 0.5 + 0.3, 0)
			b.add_child(roof)
			var ridge := MeshInstance3D.new()
			var rg := BoxMesh.new()
			rg.size = Vector3(w * 0.68, 1.4, d * 0.68)
			ridge.mesh = rg
			ridge.material_override = roof_mat
			ridge.position = Vector3(0, h * 0.5 + 1.4, 0)
			b.add_child(ridge)
			if _rng.randf() < 0.55:
				var chimney := MeshInstance3D.new()
				var cm := BoxMesh.new()
				cm.size = Vector3(2, 3, 2)
				chimney.mesh = cm
				chimney.material_override = Pix.flat_mat(Color(0.5, 0.34, 0.26))
				chimney.position = Vector3(_rng.randf_range(-w * 0.3, w * 0.3), h * 0.5 + 2.0, _rng.randf_range(-d * 0.3, d * 0.3))
				b.add_child(chimney)
			if near_track:
				_building_extras(b, w, h, d, p, awning_mats[district])
		gx += 34.0

## Lush tree cover wherever there's no water, road, or building — the concept
## art has essentially zero bare ground.
func _build_trees() -> void:
	var palette: Array = _kit.get("tree_palette", [])
	var crowns := [Color(0.22, 0.48, 0.26), Color(0.3, 0.56, 0.3), Color(0.18, 0.42, 0.23), Color(0.42, 0.52, 0.22)]
	if not palette.is_empty():
		crowns = []
		for c in palette:
			crowns.append(Color(c[0], c[1], c[2]))
	var crown_mats: Array = []
	for g in crowns:
		crown_mats.append(Pix.flat_mat(g))
	var trunk_mat := Pix.flat_mat(Color(0.42, 0.3, 0.2))
	_rng.seed = 8
	var tr: Array = _kit.get("tree_rect", [-150, -150, 1230, 918])
	var ax: float = tr[0]
	while ax < tr[0] + tr[2]:
		var ay: float = tr[1]
		while ay < tr[1] + tr[3]:
			ay += 24.0
			if _rng.randf() < float(_kit.get("tree_skip", 0.7)):
				continue
			var a := Vector2(ax + _rng.randf_range(-8, 8), ay + _rng.randf_range(-8, 8))
			if _in_water_art(a) or _excluded(a):
				continue
			var p := _w(a.x, a.y)
			if track.min_dist_to_track(p.x, p.y) < track.HALF + 9.0:
				continue
			var blocked := false
			for r in _building_rects:
				if r.grow(3.0).has_point(a):
					blocked = true
					break
			if blocked:
				continue
			_tree(Vector3(p.x, 0, p.y), _rng.randf_range(0.7, 1.5), trunk_mat, crown_mats[_rng.randi() % crown_mats.size()])
		ax += 24.0

func _tree(pos: Vector3, s: float, trunk_mat: Material, crown_mat: Material) -> void:
	var trunk := _box(Vector3(1.2 * s, 3.0 * s, 1.2 * s), pos + Vector3(0, 1.5 * s, 0), trunk_mat)
	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.2 * s
	sm.height = 5.8 * s
	sm.radial_segments = 7
	sm.rings = 4
	crown.mesh = sm
	crown.material_override = crown_mat
	crown.position = Vector3(0, 4.6 * s, 0)
	trunk.add_child(crown)
	if _kit.get("tree_style", "") == "sakura":
		# fluffy double crown, blossom-season silhouette
		var puff := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 3.0 * s
		pm.height = 4.0 * s
		pm.radial_segments = 6
		pm.rings = 3
		puff.mesh = pm
		puff.material_override = crown_mat
		puff.position = Vector3(2.4 * s, 6.4 * s, 1.2 * s)
		trunk.add_child(puff)

## Rows of feature trees lining the track (sakura avenues, etc) — like palm
## rows but using the track's tree palette at hero scale.
func _build_tree_rows() -> void:
	_rng.seed = 15
	var palette: Array = _kit.get("tree_palette", [])
	if palette.is_empty() or not _kit.has("tree_rows"):
		return
	var crown_mats: Array = []
	for c in palette:
		crown_mats.append(Pix.flat_mat(Color(c[0], c[1], c[2])))
	var trunk_mat := Pix.flat_mat(Color(0.36, 0.26, 0.2))
	for row in _kit.get("tree_rows", []):
		var a := Vector2(row["from"][0], row["from"][1])
		var b := Vector2(row["to"][0], row["to"][1])
		var count := int(a.distance_to(b) / float(row["step"]))
		for k in count + 1:
			var spot := a.lerp(b, float(k) / maxf(count, 1))
			if _in_water_art(spot) or _excluded(spot):
				continue
			var p := _w(spot.x, spot.y)
			if track.min_dist_to_track(p.x, p.y) < track.HALF + 8.0:
				continue
			var blocked := false
			for r in _building_rects:
				if r.grow(2.0).has_point(spot):
					blocked = true
					break
			if not blocked:
				_tree(Vector3(p.x, 0, p.y), _rng.randf_range(1.1, 1.55), trunk_mat, crown_mats[_rng.randi() % crown_mats.size()])

## Crowd strips along the outside barriers at corners — race-day atmosphere
## beyond the three big grandstands.
func _build_trackside_crowds() -> void:
	var frames: Array = Pix.crowd_frames(_rng)
	var mat := Pix.tex_mat(frames[0])
	mat.uv1_scale = Vector3(2.4, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.25, 0.28)
	mat.emission_energy_multiplier = 0.3
	_crowd_anims.append({"mat": mat, "frames": frames})
	var stand_mat := Pix.flat_mat(Color(0.3, 0.32, 0.36))
	for c in track.corners:
		var i: int = c["index"]
		if track.in_tunnel(i):
			continue
		var side: float = -track.curv_sign[i]
		var pos: Vector3 = track.samples[i] + track.normals[i] * (track.HALF + 9.5) * side
		var a: Vector2 = track.art[i] + Vector2(track.normals[i].x, track.normals[i].z) * (track.HALF + 9.5) * side / 2.0
		if _in_water_art(a):
			continue
		if track.min_dist_to_track(pos.x, pos.z) < track.HALF + 5.0:
			continue
		var t: Vector3 = track.tangents[i]
		var root := Node3D.new()
		root.position = pos
		root.rotation.y = -atan2(t.z, t.x)
		add_child(root)
		var stand := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(26, 2.6, 3.5)
		stand.mesh = bm
		stand.material_override = stand_mat
		stand.position = Vector3(0, 1.3, 0)
		root.add_child(stand)
		var crowd := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(26, 2.4)
		crowd.mesh = qm
		crowd.material_override = mat
		crowd.position = Vector3(0, 2.6, 0)
		crowd.rotation.x = -0.2
		# quad faces local +Z; the road is on the -side of the offset normal
		crowd.rotation.y = 0.0 if side > 0.0 else PI
		root.add_child(crowd)

## Cafe umbrellas: marina promenade and scattered park spots.
func _build_umbrellas() -> void:
	_rng.seed = 9
	var colors := [Color(0.85, 0.25, 0.2), Color(0.95, 0.9, 0.82), Color(0.2, 0.5, 0.65), Color(0.9, 0.6, 0.2)]
	var spots: Array[Vector2] = []
	if _kit.has("umbrella_row"):
		var row: Dictionary = _kit["umbrella_row"]
		var a := Vector2(row["from"][0], row["from"][1])
		var b := Vector2(row["to"][0], row["to"][1])
		var count := int(a.distance_to(b) / float(row["step"]))
		for k in count + 1:
			spots.append(a.lerp(b, float(k) / maxf(count, 1)))
	var cr: Array = _kit.get("city_rect", [-130, -130, 1190, 890])
	for k in int(_kit.get("umbrella_scatter", 0)):
		spots.append(Vector2(_rng.randf_range(cr[0] + 250, cr[0] + cr[2] - 250), _rng.randf_range(cr[1] + 250, cr[1] + cr[3] - 150)))
	for a in spots:
		if _in_water_art(a):
			continue
		var p := _w(a.x, a.y)
		if track.min_dist_to_track(p.x, p.y) < track.HALF + 11.0:
			continue
		var blocked := false
		for r in _building_rects:
			if r.grow(2.0).has_point(a):
				blocked = true
				break
		if blocked:
			continue
		var pole := _box(Vector3(0.5, 4, 0.5), Vector3(p.x, 2, p.y), Pix.flat_mat(Color(0.75, 0.72, 0.68)))
		var canopy := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 3.4
		cm.height = 1.6
		cm.radial_segments = 8
		canopy.mesh = cm
		canopy.material_override = Pix.flat_mat(colors[_rng.randi() % colors.size()])
		canopy.position = Vector3(0, 2.2, 0)
		pole.add_child(canopy)

## 3D dressing on the road-facing side of buildings the camera passes close to:
## a striped awning over the storefront and a few balcony slabs.
func _building_extras(b: MeshInstance3D, w: float, h: float, d: float, p: Vector2, awnings: Array) -> void:
	var ni: int = track.nearest_index_hint(p.x, p.y, 0, 0, track.n - 1)
	var to_road := Vector2(track.samples[ni].x - p.x, track.samples[ni].z - p.y)
	var base_y := -h * 0.5  # local coords: box is centered
	var face_x := absf(to_road.x) > absf(to_road.y)
	var sx := signf(to_road.x)
	var sz := signf(to_road.y)
	var am: StandardMaterial3D = awnings[_rng.randi() % awnings.size()]
	var aw := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var awning_y := base_y + h / 4.0 + 0.4  # just above the storefront band (bottom 12/48 of the facade)
	if face_x:
		bm.size = Vector3(2.4, 0.8, d * 0.6)
		aw.position = Vector3(sx * (w * 0.5 + 1.0), awning_y, 0)
	else:
		bm.size = Vector3(w * 0.6, 0.8, 2.4)
		aw.position = Vector3(0, awning_y, sz * (d * 0.5 + 1.0))
	aw.mesh = bm
	aw.material_override = am
	b.add_child(aw)
	var bal_mat := Pix.flat_mat(Color(0.9, 0.88, 0.84))
	for k in 2 + _rng.randi() % 2:
		var by := base_y + h * (15.0 + float(k) * 8.0) / 48.0
		if by > h * 0.5 - 4.0:
			break
		var bal := MeshInstance3D.new()
		var bb := BoxMesh.new()
		if face_x:
			bb.size = Vector3(1.6, 0.6, 5.0)
			bal.position = Vector3(sx * (w * 0.5 + 0.7), by, _rng.randf_range(-d * 0.25, d * 0.25))
		else:
			bb.size = Vector3(5.0, 0.6, 1.6)
			bal.position = Vector3(_rng.randf_range(-w * 0.25, w * 0.25), by, sz * (d * 0.5 + 0.7))
		bal.mesh = bb
		bal.material_override = bal_mat
		b.add_child(bal)

## Crown Casino: hand-authored landmark set piece at the crest hairpin —
## podium hill, tiered belle-epoque block, columned portico, copper dome,
## corner turrets, fountain plaza, gold crown emblem. The template for
## bringing every landmark up to concept-art level.
func _build_casino(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var base_y: float = lm.get("base_y", 1.0)  # podium top (above any road crest)
	var stone := Pix.flat_mat(Color(0.78, 0.72, 0.6))
	var cream := Pix.flat_mat(Color(0.93, 0.89, 0.78))
	var cream_lit := Pix.flat_mat(Color(0.95, 0.91, 0.8), 0.12)
	var gold := Pix.flat_mat(Color(0.85, 0.68, 0.28), 0.25)
	var copper := Pix.flat_mat(Color(0.4, 0.62, 0.52))
	var glow := Pix.flat_mat(Color(1.0, 0.85, 0.45), 1.6)
	var red := Pix.flat_mat(Color(0.7, 0.15, 0.18))

	# podium hill from harbor grade up to the crest
	_box(Vector3(42, base_y, 56), Vector3(cx, base_y * 0.5, cz), stone)
	_box(Vector3(46, 2, 60), Vector3(cx, base_y + 1, cz), cream)  # plaza slab

	# tiered main block with gold cornice bands
	_box(Vector3(32, 14, 44), Vector3(cx, base_y + 9, cz), cream_lit)
	_box(Vector3(34, 1.2, 46), Vector3(cx, base_y + 16.6, cz), gold)
	_box(Vector3(27, 11, 38), Vector3(cx, base_y + 22.5, cz), cream)
	_box(Vector3(29, 1.2, 40), Vector3(cx, base_y + 28.6, cz), gold)
	_box(Vector3(20, 8, 28), Vector3(cx, base_y + 33, cz), cream_lit)

	# lit window strips on the first two tiers
	for side in [-1.0, 1.0]:
		for k in 5:
			_box(Vector3(1.0, 6, 2.2), Vector3(cx + side * 16.2, base_y + 9, cz - 16 + k * 8), glow)
			_box(Vector3(1.0, 5, 1.8), Vector3(cx + side * 13.7, base_y + 22.5, cz - 12 + k * 6), glow)
		for k in 3:
			_box(Vector3(2.2, 6, 1.0), Vector3(cx - 10 + k * 10, base_y + 9, cz + side * 22.2), glow)

	# columned portico facing the descent road (west)
	for k in 4:
		_box(Vector3(1.6, 9, 1.6), Vector3(cx - 19, base_y + 6.5, cz - 9 + k * 6), cream)
	_box(Vector3(7, 1.6, 24), Vector3(cx - 19, base_y + 11.8, cz), cream)
	_box(Vector3(7.6, 1.0, 25), Vector3(cx - 19, base_y + 12.9, cz), red)  # awning trim
	_box(Vector3(10, 0.4, 8), Vector3(cx - 18, base_y + 2.3, cz), red)     # red carpet
	for k in 3:
		_box(Vector3(2.5, 0.6, 20), Vector3(cx - 24 - k * 2.5, base_y + 1.8 - k * 0.6, cz), cream)  # steps

	# copper dome with gold finial
	var drum := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 8.0
	dc.bottom_radius = 9.0
	dc.height = 5.0
	dc.radial_segments = 10
	drum.mesh = dc
	drum.material_override = cream
	drum.position = Vector3(cx, base_y + 39.5, cz)
	add_child(drum)
	var dome := MeshInstance3D.new()
	var ds := SphereMesh.new()
	ds.radius = 9.0
	ds.height = 11.0
	ds.radial_segments = 10
	ds.rings = 6
	dome.mesh = ds
	dome.material_override = copper
	dome.position = Vector3(cx, base_y + 44, cz)
	add_child(dome)
	_box(Vector3(1.2, 5, 1.2), Vector3(cx, base_y + 51, cz), gold)

	# corner turrets with mini domes
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tx: float = cx + sx * 14.0
			var tz: float = cz + sz * 19.0
			var turret := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 2.6
			tc.bottom_radius = 2.6
			tc.height = 20.0
			tc.radial_segments = 8
			turret.mesh = tc
			turret.material_override = cream
			turret.position = Vector3(tx, base_y + 10, tz)
			add_child(turret)
			var cap := MeshInstance3D.new()
			var cs := SphereMesh.new()
			cs.radius = 3.2
			cs.height = 4.4
			cs.radial_segments = 8
			cs.rings = 4
			cap.mesh = cs
			cap.material_override = copper
			cap.position = Vector3(tx, base_y + 21, tz)
			add_child(cap)

	# gold crown emblem above the portico
	_box(Vector3(1.5, 1.8, 11), Vector3(cx - 17.5, base_y + 15.2, cz), gold)
	for k in 3:
		_box(Vector3(1.5, 3.2, 1.8), Vector3(cx - 17.5, base_y + 17.4, cz - 3.6 + k * 3.6), gold)
	_box(Vector3(1.0, 1.0, 1.0), Vector3(cx - 18.2, base_y + 16.4, cz), Pix.flat_mat(Color(0.85, 0.15, 0.2), 0.8))

	# fountain plaza
	var basin := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 5.0
	bc.bottom_radius = 5.5
	bc.height = 1.6
	bc.radial_segments = 10
	basin.mesh = bc
	basin.material_override = stone
	basin.position = Vector3(cx, base_y + 2.6, cz - 34)
	add_child(basin)
	var pool := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 4.4
	pc.bottom_radius = 4.4
	pc.height = 0.4
	pc.radial_segments = 10
	pool.mesh = pc
	pool.material_override = Pix.flat_mat(Color(0.3, 0.65, 0.9), 0.5)
	pool.position = Vector3(cx, base_y + 3.4, cz - 34)
	add_child(pool)
	_box(Vector3(1.2, 4, 1.2), Vector3(cx, base_y + 5, cz - 34), stone)

	# hedges and palms lining the plaza
	var hedge := Pix.flat_mat(Color(0.22, 0.45, 0.25))
	for k in 4:
		_box(Vector3(3, 2.2, 8), Vector3(cx - 13 + k * 9, base_y + 2.6, cz + 26), hedge)
		_box(Vector3(3, 2.2, 8), Vector3(cx - 13 + k * 9, base_y + 2.6, cz - 26), hedge)
	_palm(Vector3(cx - 16, base_y + 1.5, cz + 22), 0.85)
	_palm(Vector3(cx - 16, base_y + 1.5, cz - 22), 0.85)

	# marquee sign, pulsing (kept from before)
	_casino_sign = _label(lm.get("sign", "CASINO"), Vector3(cx - 21, base_y + 20, cz), Vector3(-1, 0, 0), Color(1.0, 0.84, 0.2), 48, 0.085)

## Azure Bay Yacht Club: white terraced clubhouse on the east marina shore
## with glass front, flag mast, terrace umbrellas, and a private pier.
func _build_yacht_club(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var white := Pix.flat_mat(Color(0.94, 0.94, 0.92))
	var stone := Pix.flat_mat(Color(0.8, 0.76, 0.66))
	var glass := Pix.flat_mat(Color(0.4, 0.7, 0.9), 0.4)
	var navy := Pix.flat_mat(Color(0.15, 0.25, 0.45))
	_box(Vector3(76, 1.5, 56), Vector3(cx, 0.75, cz), stone)         # terrace
	_box(Vector3(58, 10, 40), Vector3(cx + 4, 6.5, cz), white)       # main hall
	_box(Vector3(1.2, 6, 34), Vector3(cx - 25.5, 6, cz), glass)      # glass front (west, to the water)
	_box(Vector3(44, 8, 28), Vector3(cx + 8, 15.5, cz), white)       # upper deck
	_box(Vector3(46, 1, 30), Vector3(cx + 8, 20, cz), navy)          # roof trim
	for k in 5:                                                       # terrace railing posts
		_box(Vector3(0.6, 1.6, 0.6), Vector3(cx - 36, 2.3, cz - 24 + k * 12), white)
	_box(Vector3(0.5, 0.4, 52), Vector3(cx - 36, 3.0, cz), white)
	var mast := _box(Vector3(1.0, 26, 1.0), Vector3(cx + 26, 13, cz - 16), white)
	var pennant := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(4.5, 2.5)
	pennant.mesh = pq
	var pm := Pix.flat_mat(Color(0.15, 0.35, 0.7), 0.2)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pennant.material_override = pm
	pennant.position = Vector3(2.5, 11.5, 0)
	mast.add_child(pennant)
	_flags.append(pennant)
	for k in 3:
		_umbrella_at(Vector3(cx - 28 + k * 16, 1.5, cz + 20), Color(0.15, 0.35, 0.7))
	_box(Vector3(56, 1, 5), Vector3(cx - 66, -3.2, cz), Pix.flat_mat(Color(0.55, 0.4, 0.25)))  # private pier
	_yacht(Vector2(cx - 70, cz - 14), 0.4, 1.3, false)
	_yacht(Vector2(cx - 78, cz + 16), -0.3, 0.9, false)
	_label(lm.get("sign", "YACHT CLUB"), Vector3(cx - 27, 13, cz), Vector3(-1, 0, 0), Color(0.15, 0.3, 0.55), 32, 0.07)

## Old-town clock tower church: stone nave with tiered terracotta roof and a
## tall campanile with arched openings, clock face, and pyramid spire.
func _build_church(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var stone := Pix.flat_mat(Color(0.8, 0.68, 0.5))
	var stone_dark := Pix.flat_mat(Color(0.68, 0.56, 0.4))
	var terra := Pix.flat_mat(Color(0.62, 0.33, 0.2))
	var glow := Pix.flat_mat(Color(1.0, 0.85, 0.45), 1.2)
	_box(Vector3(40, 22, 64), Vector3(cx + 6, 11, cz), stone)        # nave
	_box(Vector3(44, 2, 68), Vector3(cx + 6, 23, cz), terra)         # tiered gable roof
	_box(Vector3(34, 2.4, 58), Vector3(cx + 6, 25, cz), terra)
	_box(Vector3(20, 2.6, 46), Vector3(cx + 6, 27.4, cz), terra)
	for k in 4:                                                       # nave windows
		_box(Vector3(1.0, 7, 2.4), Vector3(cx - 14.2, 12, cz - 21 + k * 14), glow)
		_box(Vector3(1.0, 7, 2.4), Vector3(cx + 26.2, 12, cz - 21 + k * 14), glow)
	# campanile
	var tx := cx - 22.0
	var tz := cz - 22.0
	_box(Vector3(15, 52, 15), Vector3(tx, 26, tz), stone_dark)
	_box(Vector3(17, 1.4, 17), Vector3(tx, 52.6, tz), stone)
	for side in [-1.0, 1.0]:                                          # arched bell openings
		_box(Vector3(2.6, 6, 1.0), Vector3(tx + side * 7.6, 46, tz), Pix.flat_mat(Color(0.1, 0.1, 0.14)))
		_box(Vector3(1.0, 6, 2.6), Vector3(tx, 46, tz + side * 7.6), Pix.flat_mat(Color(0.1, 0.1, 0.14)))
	_box(Vector3(0.8, 6, 6), Vector3(tx - 7.9, 34, tz), Pix.flat_mat(Color(0.93, 0.9, 0.84)))  # clock face
	_box(Vector3(0.4, 0.8, 2.4), Vector3(tx - 8.1, 34.4, tz - 0.6), Pix.flat_mat(Color(0.1, 0.1, 0.12)))  # hands
	var spire := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.0
	sc.bottom_radius = 10.0
	sc.height = 13.0
	sc.radial_segments = 4
	spire.mesh = sc
	spire.material_override = terra
	spire.position = Vector3(tx, 59.5, tz)
	spire.rotation.y = PI / 4.0
	add_child(spire)
	_box(Vector3(0.8, 3.5, 0.8), Vector3(tx, 67, tz), Pix.flat_mat(Color(0.85, 0.68, 0.28), 0.3))
	_tree_pair(Vector3(cx + 6, 0, cz + 40))

## Grand Riviera Hotel: belle-epoque U-block facing the start/finish straight —
## the backdrop of every starting grid screenshot.
func _build_hotel(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var cream := Pix.flat_mat(Color(0.93, 0.88, 0.76), 0.1)
	var trim := Pix.flat_mat(Color(0.85, 0.68, 0.28), 0.25)
	var copper := Pix.flat_mat(Color(0.4, 0.62, 0.52))
	var glow := Pix.flat_mat(Color(1.0, 0.85, 0.45), 1.4)
	var red := Pix.flat_mat(Color(0.7, 0.15, 0.18))
	_box(Vector3(104, 3, 66), Vector3(cx, 1.5, cz), Pix.flat_mat(Color(0.8, 0.76, 0.66)))
	_box(Vector3(56, 58, 38), Vector3(cx, 32, cz - 6), cream)        # central block
	_box(Vector3(58, 1.4, 40), Vector3(cx, 48, cz - 6), trim)        # cornice
	_box(Vector3(50, 8, 32), Vector3(cx, 64, cz - 6), copper)        # mansard roof
	for side in [-1.0, 1.0]:                                          # forward wings
		_box(Vector3(26, 42, 30), Vector3(cx + side * 39, 24, cz + 10), cream)
		_box(Vector3(28, 1.4, 32), Vector3(cx + side * 39, 45.6, cz + 10), trim)
		_box(Vector3(22, 6, 26), Vector3(cx + side * 39, 49.5, cz + 10), copper)
	# lit windows on the track-facing south faces
	for f in 5:
		for k in 6:
			_box(Vector3(2.4, 4.5, 1.0), Vector3(cx - 20 + k * 8, 12 + f * 9.5, cz + 13.2), glow)
		for side in [-1.0, 1.0]:
			for k in 2:
				_box(Vector3(2.4, 4.5, 1.0), Vector3(cx + side * 39 - 4 + k * 8, 10 + f * 7, cz + 25.2), glow)
	# entrance canopy + carpet
	_box(Vector3(18, 1.2, 8), Vector3(cx, 10, cz + 15), red)
	for k in 4:
		_box(Vector3(1.2, 7, 1.2), Vector3(cx - 7 + k * 4.6, 6.5, cz + 18), cream)
	_box(Vector3(8, 0.3, 16), Vector3(cx, 3.2, cz + 24), red)
	# rooftop sign
	for side in [-1.0, 1.0]:
		_box(Vector3(1, 7, 1), Vector3(cx + side * 22, 71, cz - 6), trim)
	_label(lm.get("sign", "GRAND HOTEL"), Vector3(cx, 72.5, cz - 5), Vector3(0, 0, 1), Color(1.0, 0.84, 0.2), 32, 0.1)
	_tree_pair(Vector3(cx - 42, 0, cz + 22))
	_tree_pair(Vector3(cx + 42, 0, cz + 22))

## Vermilion torii gate — can stand on land or in water (Miyajima style).
func _build_torii(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var base_y: float = lm.get("base_y", -4.0 if _in_water_art(Vector2(lm["at"][0], lm["at"][1])) else 0.0)
	var verm := Pix.flat_mat(Color(0.82, 0.22, 0.12))
	var ink := Pix.flat_mat(Color(0.12, 0.1, 0.1))
	for side in [-1.0, 1.0]:
		_box(Vector3(2.6, 18, 2.6), Vector3(cx, base_y + 9, cz + side * 10.0), verm)
		_box(Vector3(3.2, 1.2, 3.2), Vector3(cx, base_y + 18.2, cz + side * 10.0), ink)
	_box(Vector3(2.2, 2.2, 30), Vector3(cx, base_y + 20.4, cz), verm)   # kasagi
	_box(Vector3(2.6, 1.2, 31), Vector3(cx, base_y + 21.8, cz), ink)    # cap
	_box(Vector3(1.8, 1.8, 24), Vector3(cx, base_y + 16.2, cz), verm)   # nuki
	_box(Vector3(1.6, 3.2, 1.6), Vector3(cx, base_y + 18.4, cz), verm)  # gakuzuka

## Five-tier pagoda with slate roofs and a gold spire.
func _build_pagoda(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var base_y: float = lm.get("base_y", 0.0)
	var wallm := Pix.flat_mat(Color(0.88, 0.84, 0.74))
	var wood := Pix.flat_mat(Color(0.4, 0.28, 0.2))
	var roof := Pix.flat_mat(Color(0.28, 0.3, 0.38))
	_box(Vector3(46, 3, 46), Vector3(cx, base_y + 1.5, cz), Pix.flat_mat(Color(0.7, 0.66, 0.58)))
	var y := base_y + 3.0
	var w := 34.0
	for tier in 5:
		_box(Vector3(w, 7.0, w), Vector3(cx, y + 3.5, cz), wallm if tier % 2 == 0 else wood)
		_box(Vector3(w + 10.0, 1.8, w + 10.0), Vector3(cx, y + 7.6, cz), roof)
		_box(Vector3(w + 4.0, 1.0, w + 4.0), Vector3(cx, y + 8.8, cz), roof)
		y += 9.2
		w *= 0.82
	_box(Vector3(1.4, 9, 1.4), Vector3(cx, y + 4.0, cz), Pix.flat_mat(Color(0.85, 0.68, 0.28), 0.4))

## Arched vermilion footbridge (spans east-west across ponds/streams).
func _build_bridge(lm: Dictionary) -> void:
	var cx: float = lm["at"][0] * 2.0
	var cz: float = lm["at"][1] * 2.0
	var span: float = lm.get("span", 120.0) * 2.0
	var verm := Pix.flat_mat(Color(0.82, 0.22, 0.12))
	var wood := Pix.flat_mat(Color(0.45, 0.32, 0.22))
	var segs := 7
	for k in segs:
		var t01 := (float(k) + 0.5) / segs - 0.5  # -0.5..0.5
		var x := cx + t01 * span
		var y := 1.0 + (1.0 - 4.0 * t01 * t01) * 5.0  # arch profile
		_box(Vector3(span / segs + 1.0, 1.2, 10), Vector3(x, y, cz), wood)
		for side in [-1.0, 1.0]:
			_box(Vector3(span / segs + 1.0, 0.7, 0.7), Vector3(x, y + 3.4, cz + side * 4.6), verm)
			if k % 2 == 0:
				_box(Vector3(0.7, 3.2, 0.7), Vector3(x, y + 1.8, cz + side * 4.6), verm)
	for ex in [-0.5, 0.5]:
		_box(Vector3(1.4, 8, 1.4), Vector3(cx + ex * span, 2.5, cz - 4.6), verm)
		_box(Vector3(1.4, 8, 1.4), Vector3(cx + ex * span, 2.5, cz + 4.6), verm)

## Falling cherry-blossom petals — the track's signature animated system,
## driven by the kit's "petals" config.
var _petals: Array = []  # {"node": MeshInstance3D, "phase": float, "fall": float}
var _koi: Array = []     # {"node", "center", "radius", "phase", "speed"}

func _build_petals() -> void:
	if not _kit.has("petals"):
		return
	_rng.seed = 14
	var pk: Dictionary = _kit["petals"]
	var r: Array = pk["rect"]
	var pmat := Pix.flat_mat(Color(0.97, 0.78, 0.86), 0.25)
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var psize: float = pk.get("size", 2.4)
	for k in int(pk.get("count", 60)):
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(psize, psize)
		quad.mesh = qm
		quad.material_override = pmat
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.position = Vector3(
			_rng.randf_range(r[0], r[0] + r[2]) * 2.0,
			_rng.randf_range(2.0, 30.0),
			_rng.randf_range(r[1], r[1] + r[3]) * 2.0)
		quad.rotation.x = -PI / 3.0
		add_child(quad)
		_petals.append({"node": quad, "phase": _rng.randf_range(0, TAU), "fall": _rng.randf_range(2.5, 5.0)})

func _tree_pair(pos: Vector3) -> void:
	var trunk := Pix.flat_mat(Color(0.42, 0.3, 0.2))
	var crown := Pix.flat_mat(Color(0.24, 0.5, 0.27))
	_tree(pos + Vector3(-5, 0, 0), 0.9, trunk, crown)
	_tree(pos + Vector3(5, 0, 2), 0.75, trunk, crown)

func _umbrella_at(pos: Vector3, c: Color) -> void:
	var pole := _box(Vector3(0.5, 4, 0.5), pos + Vector3(0, 2, 0), Pix.flat_mat(Color(0.75, 0.72, 0.68)))
	var canopy := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 3.4
	cm.height = 1.6
	cm.radial_segments = 8
	canopy.mesh = cm
	canopy.material_override = Pix.flat_mat(c)
	canopy.position = Vector3(0, 2.2, 0)
	pole.add_child(canopy)

# --- grandstands ---------------------------------------------------------------

func _build_grandstands() -> void:
	_rng.seed = 12
	for g in _kit.get("grandstands", []):
		var at: Array = g["at"]
		_grandstand(Vector3(at[0] * 2.0, g.get("y", 0.0), at[1] * 2.0), g["length"], deg_to_rad(float(g.get("facing", 0))))

func _grandstand(center: Vector3, length: float, yaw: float) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	add_child(root)
	var frame := Pix.flat_mat(Color(0.35, 0.37, 0.42))
	var crowd_textures: Array = Pix.crowd_frames(_rng)
	var crowd_mat := Pix.tex_mat(crowd_textures[0])
	_crowd_anims.append({"mat": crowd_mat, "frames": crowd_textures})
	crowd_mat.uv1_scale = Vector3(length / 40.0, 1, 1)
	crowd_mat.emission_enabled = true
	crowd_mat.emission = Color(0.25, 0.25, 0.28)
	crowd_mat.emission_energy_multiplier = 0.3
	for s in 3:
		var step := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(length, 4.0 + s * 4.0, 7)
		step.mesh = bm
		step.material_override = frame
		step.position = Vector3(0, (4.0 + s * 4.0) * 0.5, s * 7.0)
		root.add_child(step)
		var crowd := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(length, 3.6)
		crowd.mesh = qm
		crowd.material_override = crowd_mat
		crowd.position = Vector3(0, 2.6 + s * 4.0, s * 7.0 - 3.6)
		crowd.rotation.x = -0.25
		crowd.rotation.y = PI
		root.add_child(crowd)
	var flag_colors := [Color(0.9, 0.25, 0.2), Color(0.25, 0.45, 0.9), Color(0.95, 0.8, 0.25), Color(0.9, 0.9, 0.9)]
	for f in 5:
		var pole := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 8, 0.5)
		pole.mesh = pm
		pole.material_override = frame
		pole.position = Vector3(-length / 2.0 + f * length / 4.0, 16, 14)
		root.add_child(pole)
		var flag := MeshInstance3D.new()
		var qm2 := QuadMesh.new()
		qm2.size = Vector2(5, 3)
		flag.mesh = qm2
		var fm := Pix.flat_mat(flag_colors[f % flag_colors.size()], 0.2)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = fm
		flag.position = Vector3(2.8, 3.2, 0)
		pole.add_child(flag)
		_flags.append(flag)

# --- street furniture -----------------------------------------------------------

func _build_palms() -> void:
	_rng.seed = 13
	var spots: Array[Vector2] = []
	for row in _kit.get("palm_rows", []):
		var from: Array = row["from"]
		var to: Array = row["to"]
		var step: float = row["step"]
		var a := Vector2(from[0], from[1])
		var b := Vector2(to[0], to[1])
		var count := int(a.distance_to(b) / step)
		for k in count + 1:
			spots.append(a.lerp(b, float(k) / maxf(count, 1)))
	for a in spots:
		var p := _w(a.x, a.y)
		if track.min_dist_to_track(p.x, p.y) < track.HALF + 9.0:
			continue
		_palm(Vector3(p.x, 0, p.y), _rng.randf_range(0.8, 1.2))

func _palm(pos: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf_range(0, TAU)
	add_child(root)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5 * s
	cm.bottom_radius = 0.9 * s
	cm.height = 11.0 * s
	trunk.mesh = cm
	trunk.material_override = Pix.flat_mat(Color(0.5, 0.38, 0.25))
	trunk.position = Vector3(0, 5.5 * s, 0)
	root.add_child(trunk)
	var leaf_mat := Pix.flat_mat(Color(0.2, 0.55, 0.3))
	for f in 5:
		var frond := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.5 * s, 0.5, 2.6 * s)
		frond.mesh = bm
		frond.material_override = leaf_mat
		frond.position = Vector3(0, 11.0 * s, 0)
		frond.rotation.y = TAU * float(f) / 5.0
		frond.rotation.z = -0.4
		# thin radial fronds cast ugly spike shadows at this sun angle
		frond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(frond)

func _build_billboards() -> void:
	var palette := {
		"CROWN CASINO": Color(0.85, 0.12, 0.15),
		"VELOBANK": Color(0.1, 0.3, 0.65),
		"TURBO COLA": Color(0.85, 0.3, 0.1),
		"APEX OIL": Color(0.12, 0.12, 0.14),
		"AZURE BAY MARINA": Color(0.1, 0.5, 0.7),
		"RIVIERA RACING LEAGUE": Color(0.5, 0.12, 0.55),
	}
	var names: Array = track.sponsors
	var count := 0
	var i := 0
	while i < track.n - 30:
		if track.curvature[i] >= 0.0022:
			i += 1
			continue
		var run_start := i
		while i < track.n and track.curvature[i] < 0.0022:
			i += 1
		if i - run_start < 26:
			continue
		var k := run_start + 8
		while k < i - 8:
			var side: float = 1.0 if count % 2 == 0 else -1.0
			var pos: Vector3 = track.samples[k] + track.normals[k] * (track.HALF + 11.0) * side
			var a: Vector2 = track.art[k] + Vector2(track.normals[k].x, track.normals[k].z) * (track.HALF + 11.0) * side / 2.0
			# global clearance check: don't sit on another corridor of the circuit
			# (e.g. the opposite carriageway of the pit straight)
			if not _in_water_art(a) and not track.in_tunnel(k) \
					and track.min_dist_to_track(pos.x, pos.z) > track.HALF + 7.0:
				var sponsor: String = names[count % names.size()]
				var col: Color = palette.get(sponsor, Color(0.2, 0.2, 0.25))
				var t: Vector3 = track.tangents[k]
				var yaw := -atan2(t.z, t.x)
				_box(Vector3(26, 8, 1.2), pos + Vector3(0, 7, 0), Pix.flat_mat(col), yaw)
				_box(Vector3(1, 3.5, 1), pos + Vector3(0, 1.75, 0), Pix.flat_mat(Color(0.3, 0.3, 0.33)), 0.0)
				var face: Vector3 = track.normals[k] * -side
				# pixel font is square: shrink long sponsor names to fit the board
				var ps := minf(0.09, 24.0 / (float(sponsor.length()) * 32.0))
				_label(sponsor, pos + Vector3(0, 7, 0) + face * 0.8, face, Color(0.95, 0.95, 0.95), 32, ps)
				count += 1
			k += 16
	# tire barrier stacks at a few corner apexes for street-circuit flavor
	var tire := Pix.flat_mat(Color(0.08, 0.08, 0.1))
	for c in track.corners:
		if c["number"] % 3 != 1:
			continue
		var ci: int = c["index"]
		var side2: float = -track.curv_sign[ci]
		var base: Vector3 = track.samples[ci] + track.normals[ci] * (track.HALF + 5.5) * side2
		for s in 3:
			_box(Vector3(6, 2.2, 3), base + Vector3(_rng.randf_range(-1, 1), 1.1 + s * 2.2, _rng.randf_range(-1, 1)), tire)

func _build_streetlights() -> void:
	var lantern: bool = _kit.get("light_style", "") == "lantern"
	var pole_mat := Pix.flat_mat(Color(0.3, 0.2, 0.14) if lantern else Color(0.25, 0.26, 0.3))
	var lamp_mat := Pix.flat_mat(Color(0.95, 0.3, 0.18), 1.4) if lantern else Pix.flat_mat(Color(1.0, 0.92, 0.7), 1.6)
	var cap_mat := Pix.flat_mat(Color(0.28, 0.3, 0.38))
	var i := 0
	while i < track.n:
		if not track.in_tunnel(i) and (i / 14) % 3 != 2:
			var side: float = 1.0 if (i / 14) % 2 == 0 else -1.0
			var pos: Vector3 = track.samples[i] + track.normals[i] * (track.HALF + 6.5) * side
			var a: Vector2 = track.art[i] + Vector2(track.normals[i].x, track.normals[i].z) * 16.0 * side
			if not _in_water_art(a) and track.min_dist_to_track(pos.x, pos.z) > track.HALF + 4.0:
				if lantern:
					# red paper lanterns on timber posts
					_box(Vector3(0.8, 7, 0.8), pos + Vector3(0, 3.5, 0), pole_mat)
					_box(Vector3(2.2, 2.8, 2.2), pos + Vector3(0, 8.2, 0), lamp_mat)
					_box(Vector3(3.0, 0.6, 3.0), pos + Vector3(0, 9.8, 0), cap_mat)
				else:
					_box(Vector3(0.7, 10, 0.7), pos + Vector3(0, 5, 0), pole_mat)
					_box(Vector3(1.8, 1.2, 1.8), pos + Vector3(0, 10.5, 0), lamp_mat)
		i += 14

# --- pit lane (decorative for the first playable) --------------------------------

func _build_pit_lane() -> void:
	# the driveable pit road itself is a branch corridor (see track JSON
	# "branches" + track_builder._build_branches); this dresses it, derived
	# entirely from the branch geometry
	for b in track.branches:
		if b["type"] != "pit":
			continue
		var pts: PackedVector3Array = b["pts"]
		var box_mat := Pix.flat_mat(Color(0.95, 0.95, 0.95), 0.1)
		for f in [0.35, 0.48, 0.61, 0.74]:
			var p := _branch_point(b, b["len"] * f)
			var seg: int = clampi(_branch_seg_at(b, b["len"] * f), 0, pts.size() - 2)
			var nrm: Vector3 = b["seg_norm"][seg]
			var d: Vector3 = b["seg_dir"][seg]
			var box := _box(Vector3(12, 0.1, 4.5), p + nrm * (b["half"] * 0.45) + Vector3(0, 0.15, 0), box_mat)
			box.rotation.y = -atan2(d.z, d.x)
		var pin := _label("PIT IN", pts[0] + Vector3(0, 6, 0), Vector3(-1, 0, 0.3), Color(0.4, 1.0, 0.5), 40)
		pin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var pout := _label("PIT OUT", pts[-1] + Vector3(0, 6, 0), Vector3(1, 0, 0), Color(1.0, 0.6, 0.3), 40)
		pout.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _branch_seg_at(b: Dictionary, s: float) -> int:
	var cum: PackedFloat32Array = b["cum"]
	for k in range(cum.size() - 1, -1, -1):
		if cum[k] <= s:
			return k
	return 0

func _branch_point(b: Dictionary, s: float) -> Vector3:
	var seg := _branch_seg_at(b, s)
	var pts: PackedVector3Array = b["pts"]
	return pts[seg] + b["seg_dir"][seg] * (s - b["cum"][seg])
