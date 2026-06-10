extends Node3D
## Generates the drivable circuit from TrackData: road ribbon, markings, curbs,
## barriers, tunnel, start line + gantry, grid slots, and numbered corner signs.
## Tracks are data; this node is one of its generated views.

const Pix = preload("res://scripts/pixel_textures.gd")

var track  # TrackData

func build(p_track) -> void:
	track = p_track
	var road_mat := Pix.tex_mat(Pix.asphalt())
	road_mat.uv1_scale = Vector3.ONE
	_ribbon(0, track.n, track.HALF, -track.HALF, 0.0, road_mat, true)

	# yellow center dashes + white edge lines
	var dash_mat := Pix.flat_mat(Color(0.95, 0.8, 0.15), 0.25)
	var line_mat := Pix.flat_mat(Color(0.92, 0.92, 0.9), 0.15)
	var i := 0
	while i < track.n:
		if i % 10 < 5:
			_ribbon(i, mini(5, track.n - i), 0.8, -0.8, 0.15, dash_mat)
		i += 1
	_ribbon(0, track.n, track.HALF - 0.8, track.HALF - 2.0, 0.12, line_mat, true)
	_ribbon(0, track.n, -track.HALF + 2.0, -track.HALF + 0.8, 0.12, line_mat, true)

	_build_curbs()
	_build_barriers()
	_build_tunnel()
	_build_start_line()
	_build_corner_signs()

# --- generic strip builders -------------------------------------------------

func _row_point(i: int, lat: float, y_off: float) -> Vector3:
	var s: Vector3 = track.samples[i % track.n]
	return s + track.normals[i % track.n] * lat + Vector3(0, y_off, 0)

func _ribbon(i_from: int, seg_count: int, lat_l: float, lat_r: float, y_off: float, mat: Material, closed := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := 0.0
	for k in seg_count:
		var i0: int = (i_from + k) % track.n
		var i1: int = (i_from + k + 1) % track.n
		var l0 := _row_point(i0, lat_l, y_off)
		var r0 := _row_point(i0, lat_r, y_off)
		var l1 := _row_point(i1, lat_l, y_off)
		var r1 := _row_point(i1, lat_r, y_off)
		var v1: float = v + track.step_len[i0] * 0.08
		# flat-up normals: uniform shading on climbs and descents, so the
		# asphalt reads the same charcoal everywhere (slope-lit road looked
		# washed out / "invisible" against the ground)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, v)); st.add_vertex(l0)
		st.set_uv(Vector2(1, v)); st.add_vertex(r0)
		st.set_uv(Vector2(0, v1)); st.add_vertex(l1)
		st.set_uv(Vector2(0, v1)); st.add_vertex(l1)
		st.set_uv(Vector2(1, v)); st.add_vertex(r0)
		st.set_uv(Vector2(1, v1)); st.add_vertex(r1)
		v = v1
	# render double-sided: ribbon winding gets back-face culled from some
	# camera angles ("see-through road" playtest bug); the walls already do
	# this, and undersides are never visible anyway
	var m2 := mat
	if m2 is StandardMaterial3D:
		m2 = (mat as StandardMaterial3D).duplicate()
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m2)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	add_child(mi)
	if closed:
		pass  # loop seam is closed by the modulo wrap above
	return mi

func _wall(i_from: int, seg_count: int, lat: float, y_bot: float, y_top: float, mat: Material, skip: Callable = Callable()) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := 0.0
	var any := false
	for k in seg_count:
		var i0: int = (i_from + k) % track.n
		var i1: int = (i_from + k + 1) % track.n
		if skip.is_valid() and skip.call(i0):
			v += track.step_len[i0] * 0.08
			continue
		any = true
		var b0 := _row_point(i0, lat, y_bot)
		var t0 := _row_point(i0, lat, y_top)
		var b1 := _row_point(i1, lat, y_bot)
		var t1 := _row_point(i1, lat, y_top)
		var v1: float = v + track.step_len[i0] * 0.08
		st.set_uv(Vector2(v, 1)); st.add_vertex(b0)
		st.set_uv(Vector2(v1, 1)); st.add_vertex(b1)
		st.set_uv(Vector2(v, 0)); st.add_vertex(t0)
		st.set_uv(Vector2(v, 0)); st.add_vertex(t0)
		st.set_uv(Vector2(v1, 1)); st.add_vertex(b1)
		st.set_uv(Vector2(v1, 0)); st.add_vertex(t1)
		v = v1
	if not any:
		return
	st.generate_normals()
	var m2 := mat
	if m2 is StandardMaterial3D:
		m2 = (mat as StandardMaterial3D).duplicate()
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m2)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	add_child(mi)

# --- circuit features --------------------------------------------------------

func _corner_zone(i: int) -> bool:
	for k in range(-10, 11):
		if track.curvature[(i + k + track.n) % track.n] > 0.005:
			return true
	return false

func _build_curbs() -> void:
	var curb_mat := Pix.tex_mat(Pix.curb())
	var i := 0
	while i < track.n:
		if _corner_zone(i):
			var run_start := i
			while i < track.n and _corner_zone(i):
				i += 1
			_ribbon(run_start, i - run_start, track.HALF + 4.5, track.HALF, 0.22, curb_mat)
			_ribbon(run_start, i - run_start, -track.HALF, -track.HALF - 4.5, 0.22, curb_mat)
		i += 1

func _pit_gap(i: int) -> bool:
	# leave the south barrier open where the pit lane peels off / rejoins
	var a: Vector2 = track.art[i]
	if a.y < 575.0 or a.y > 612.0:
		return false
	return (a.x > 198.0 and a.x < 232.0) or (a.x > 413.0 and a.x < 447.0)

func _build_barriers() -> void:
	var bar_mat := Pix.tex_mat(Pix.barrier())
	var lat: float = track.HALF + 2.0
	_wall(0, track.n, lat, 0.0, 6.0, bar_mat)
	_wall(0, track.n, -lat, 0.0, 6.0, bar_mat, _pit_gap)
	var cap_mat := Pix.flat_mat(Color(0.75, 0.76, 0.78))
	_ribbon(0, track.n, lat + 0.7, lat - 0.7, 6.0, cap_mat, true)
	_ribbon(0, track.n, -lat + 0.7, -lat - 0.7, 6.0, cap_mat, true)
	# retaining skirts where the road is elevated, so hills read as terraces
	var skirt_mat := Pix.flat_mat(Color(0.42, 0.4, 0.38))
	var i := 0
	while i < track.n:
		if track.samples[i].y > 1.5:
			var run_start := i
			while i < track.n and track.samples[i].y > 1.5:
				i += 1
			var run := i - run_start
			_skirt(run_start, run, lat, skirt_mat)
			_skirt(run_start, run, -lat, skirt_mat)
		i += 1

func _skirt(i_from: int, seg_count: int, lat: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in seg_count:
		var i0: int = (i_from + k) % track.n
		var i1: int = (i_from + k + 1) % track.n
		var t0 := _row_point(i0, lat, 0.0)
		var t1 := _row_point(i1, lat, 0.0)
		var b0 := Vector3(t0.x, -1.0, t0.z)
		var b1 := Vector3(t1.x, -1.0, t1.z)
		st.set_uv(Vector2.ZERO); st.add_vertex(b0)
		st.set_uv(Vector2.RIGHT); st.add_vertex(b1)
		st.set_uv(Vector2.DOWN); st.add_vertex(t0)
		st.set_uv(Vector2.DOWN); st.add_vertex(t0)
		st.set_uv(Vector2.RIGHT); st.add_vertex(b1)
		st.set_uv(Vector2.ONE); st.add_vertex(t1)
	st.generate_normals()
	var m2: StandardMaterial3D = mat.duplicate()
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m2)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	add_child(mi)

func _build_tunnel() -> void:
	var wall_mat := Pix.flat_mat(Color(0.32, 0.34, 0.4))
	var roof_mat := Pix.flat_mat(Color(0.38, 0.36, 0.33))
	var light_mat := Pix.flat_mat(Color(1.0, 0.85, 0.55), 2.2)
	var i := 0
	while i < track.n:
		if track.in_tunnel(i):
			var run_start := i
			while i < track.n and track.in_tunnel(i):
				i += 1
			var run := i - run_start
			_wall(run_start, run, track.HALF + 3.2, 5.5, 14.0, wall_mat)
			_wall(run_start, run, -track.HALF - 3.2, 5.5, 14.0, wall_mat)
			# cutaway roof ribs instead of a solid slab, so the top-down camera
			# never fully loses the car inside the tunnel
			var k := run_start
			while k < run_start + run:
				if (k - run_start) % 10 == 0:
					# elevated ribs cast huge hard shadows across the road
					# that read as glitches from the race camera — disable
					var rib := _ribbon(k, mini(4, run_start + run - k), track.HALF + 4.5, -track.HALF - 4.5, 14.0, roof_mat)
					rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					var lamp := _ribbon(k, mini(2, run_start + run - k), 1.2, -1.2, 13.4, light_mat)
					lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				k += 1
			_portal(run_start)
			_portal(run_start + run)
		i += 1

func _portal(i: int) -> void:
	i = i % track.n
	var p: Vector3 = track.samples[i]
	var t: Vector3 = track.tangents[i]
	var arch := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 4.5, (track.HALF + 5.0) * 2.0)
	arch.mesh = bm
	arch.material_override = Pix.flat_mat(Color(0.5, 0.48, 0.45))
	arch.position = p + Vector3(0, 14.0, 0)
	arch.rotation.y = -atan2(t.z, t.x)
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arch)
	var lbl := Label3D.new()
	lbl.text = "AZURE TUNNEL"
	lbl.font_size = 60
	lbl.pixel_size = 0.08
	lbl.modulate = Color(0.5, 0.85, 1.0)
	lbl.outline_size = 14
	lbl.position = p + Vector3(0, 18.5, 0)
	lbl.rotation.y = atan2(-t.x, -t.z)  # face oncoming traffic
	add_child(lbl)

func _build_start_line() -> void:
	_ribbon(track.n - 2, 3, track.HALF, -track.HALF, 0.18, Pix.tex_mat(Pix.checker()))
	# grid slot markings
	var slot_mat := Pix.flat_mat(Color(0.9, 0.9, 0.9), 0.1)
	for s in 4:
		var g: Dictionary = track.grid_slot(s)
		var gi: int = g["index"]
		var lat := 8.0 if s % 2 == 0 else -8.0
		_ribbon((gi - 1 + track.n) % track.n, 2, lat + 5.0, lat - 5.0, 0.12, slot_mat)
	# start gantry
	var p: Vector3 = track.samples[0]
	var t: Vector3 = track.tangents[0]
	var yaw := -atan2(t.z, t.x)
	var post_mat := Pix.flat_mat(Color(0.2, 0.2, 0.24))
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2, 17, 2)
		post.mesh = pm
		post.material_override = post_mat
		post.position = p + track.normals[0] * (track.HALF + 7.0) * side + Vector3(0, 8.5, 0)
		add_child(post)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3, 3, (track.HALF + 8.0) * 2.0)
	beam.mesh = bm
	beam.material_override = Pix.flat_mat(Color(0.1, 0.1, 0.12))
	beam.position = p + Vector3(0, 16.5, 0)
	beam.rotation.y = yaw
	add_child(beam)
	var lbl := Label3D.new()
	lbl.text = "HARBOR CROWN CIRCUIT"
	lbl.font_size = 52
	lbl.pixel_size = 0.09
	lbl.modulate = Color(1.0, 0.85, 0.3)
	lbl.outline_size = 12
	lbl.position = p + Vector3(0, 16.6, 0) - Vector3(track.tangents[0].x, 0, track.tangents[0].z) * 2.0
	lbl.rotation.y = atan2(-t.x, -t.z)  # face the cars on the main straight
	add_child(lbl)

func _build_corner_signs() -> void:
	var panel_mat := Pix.flat_mat(Color(0.95, 0.78, 0.1), 0.3)
	var post_mat := Pix.flat_mat(Color(0.3, 0.3, 0.32))
	for c in track.corners:
		var i: int = c["index"]
		# sign sits on the outside of the turn
		var side: float = -track.curv_sign[i]
		var base: Vector3 = track.samples[i] + track.normals[i] * (track.HALF + 9.0) * side
		if track.min_dist_to_track(base.x, base.z) < track.HALF + 5.0:
			base = track.samples[i] + track.normals[i] * (track.HALF + 9.0) * -side
			if track.min_dist_to_track(base.x, base.z) < track.HALF + 5.0:
				continue  # boxed in on both sides (dual carriageway) — skip sign
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.8, 6, 0.8)
		post.mesh = pm
		post.material_override = post_mat
		post.position = base + Vector3(0, 3, 0)
		add_child(post)
		var panel := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 5, 6)
		panel.mesh = bm
		panel.material_override = panel_mat
		panel.position = base + Vector3(0, 8, 0)
		var t: Vector3 = track.tangents[i]
		panel.rotation.y = -atan2(t.z, t.x)
		add_child(panel)
		var lbl := Label3D.new()
		lbl.text = str(c["number"])
		lbl.font_size = 64
		lbl.pixel_size = 0.07
		lbl.modulate = Color(0.08, 0.08, 0.08)
		# face oncoming traffic, nudged off the panel so it doesn't z-fight
		var face := Vector3(-t.x, 0, -t.z)
		lbl.position = base + Vector3(0, 8, 0) + face * 0.8
		lbl.rotation.y = atan2(face.x, face.z)
		add_child(lbl)
