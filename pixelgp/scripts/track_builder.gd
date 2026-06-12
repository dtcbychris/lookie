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
	_build_branches()

## Branch corridors: pit lane and hidden paths get real driveable-looking
## roads. Pit reads official (white walls, edge lines); hidden paths hide
## behind hedges and stay off the minimap — player knowledge.
func _build_branches() -> void:
	var road_mat := Pix.tex_mat(Pix.asphalt())
	var hedge_mat := Pix.flat_mat(Color(0.2, 0.42, 0.24))
	var pit_wall_mat := Pix.flat_mat(Color(0.88, 0.88, 0.9))
	for b in track.branches:
		var pts: PackedVector3Array = b["pts"]
		var half: float = b["half"]
		# road strip
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in pts.size() - 1:
			var nrm: Vector3 = b["seg_norm"][s]
			var l0: Vector3 = pts[s] + nrm * half + Vector3(0, 0.02, 0)
			var r0: Vector3 = pts[s] - nrm * half + Vector3(0, 0.02, 0)
			var l1: Vector3 = pts[s + 1] + nrm * half + Vector3(0, 0.02, 0)
			var r1: Vector3 = pts[s + 1] - nrm * half + Vector3(0, 0.02, 0)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0, 0)); st.add_vertex(l0)
			st.set_uv(Vector2(1, 0)); st.add_vertex(r0)
			st.set_uv(Vector2(0, 2)); st.add_vertex(l1)
			st.set_uv(Vector2(0, 2)); st.add_vertex(l1)
			st.set_uv(Vector2(1, 0)); st.add_vertex(r0)
			st.set_uv(Vector2(1, 2)); st.add_vertex(r1)
		var m2: StandardMaterial3D = road_mat.duplicate()
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(m2)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		add_child(mi)
		# low side walls per segment — only where the corridor is clear of the
		# main road, so branch railings never intersect the circuit's barriers
		var wall_mat: StandardMaterial3D = pit_wall_mat if b["type"] == "pit" else hedge_mat
		var wall_h := 2.6 if b["type"] == "pit" else 3.4
		for s in range(1, pts.size() - 2):
			var a: Vector3 = pts[s]
			var c: Vector3 = pts[s + 1]
			var mid := (a + c) * 0.5
			if track.min_dist_to_track(mid.x, mid.z) < track.HALF + 4.0:
				continue
			var seg_len := Vector2(c.x - a.x, c.z - a.z).length()
			var yaw := -atan2(c.z - a.z, c.x - a.x)
			for side in [-1.0, 1.0]:
				var nrm2: Vector3 = b["seg_norm"][s]
				var w := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(seg_len + 2.0, wall_h, 1.4)
				w.mesh = bm
				w.material_override = wall_mat
				w.position = mid + nrm2 * (half + 1.2) * side + Vector3(0, wall_h * 0.5, 0)
				w.rotation.y = yaw
				add_child(w)
		# hidden entry: the gate and its dressing sit at the first point of the
		# alley that is CLEAR of the main road, so nothing encroaches on the
		# racing surface or clips the circuit barriers. Closed, the gate reads
		# as solid hedge; the race director opens it for one lap and it sinks.
		if b["type"] == "hidden":
			var gi := 1
			while gi < pts.size() - 2 and track.min_dist_to_track(pts[gi].x, pts[gi].z) < track.HALF + 4.0:
				gi += 1
			var gp: Vector3 = pts[gi]
			var gd: Vector3 = b["seg_dir"][mini(gi, pts.size() - 2)]
			var gn: Vector3 = b["seg_norm"][mini(gi, pts.size() - 2)]
			var mouth_yaw := -atan2(gd.z, gd.x)
			for side in [-1.0, 1.0]:
				var hpos: Vector3 = gp + gn * (half + 2.8) * side - gd * 2.0
				if track.min_dist_to_track(hpos.x, hpos.z) < track.HALF + 2.0:
					continue
				var h := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(7, 4.2, 2.2)
				h.mesh = hm
				h.material_override = hedge_mat
				h.position = hpos + Vector3(0, 2.1, 0)
				h.rotation.y = mouth_yaw
				add_child(h)
			hidden_gate = MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(1.6, 4.0, half * 2.0 + 2.0)
			hidden_gate.mesh = gm
			hidden_gate.material_override = hedge_mat.duplicate()
			hidden_gate.position = gp + gd * 0.5 + Vector3(0, 2.0, 0)
			hidden_gate.rotation.y = mouth_yaw
			add_child(hidden_gate)
			_gate_closed_y = hidden_gate.position.y
			# signal lamp on a post beside the gate, on the away-from-road side
			var lamp_side: float = -b["entry_side"]
			var lpos: Vector3 = gp + gn * (half + 2.0) * lamp_side
			var post := MeshInstance3D.new()
			var pm2 := BoxMesh.new()
			pm2.size = Vector3(0.7, 6.5, 0.7)
			post.mesh = pm2
			post.material_override = Pix.flat_mat(Color(0.3, 0.3, 0.33))
			post.position = lpos + Vector3(0, 3.25, 0)
			add_child(post)
			gate_lamp_mat = Pix.flat_mat(Color(0.7, 0.12, 0.1), 1.8)
			var lamp := MeshInstance3D.new()
			var lm2 := BoxMesh.new()
			lm2.size = Vector3(1.4, 1.4, 1.4)
			lamp.mesh = lm2
			lamp.material_override = gate_lamp_mat
			lamp.position = lpos + Vector3(0, 7.0, 0)
			add_child(lamp)

## Animate the hidden gate (called from main each frame): sinks into the
## ground while open, lamp flips red -> green.
var hidden_gate: MeshInstance3D
var gate_lamp_mat: StandardMaterial3D
var _gate_closed_y := 2.0

func update_gate(open: bool, dt: float) -> void:
	if hidden_gate == null:
		return
	var target_y := _gate_closed_y - 4.6 if open else _gate_closed_y
	hidden_gate.position.y = lerpf(hidden_gate.position.y, target_y, 1.0 - exp(-5.0 * dt))
	var c := Color(0.2, 0.85, 0.3) if open else Color(0.7, 0.12, 0.1)
	gate_lamp_mat.albedo_color = c
	gate_lamp_mat.emission = c

# --- generic strip builders -------------------------------------------------

func _row_point(i: int, lat: float, y_off: float) -> Vector3:
	var s: Vector3 = track.samples[i % track.n]
	return s + track.normals[i % track.n] * lat + Vector3(0, y_off, 0)

func _ribbon(i_from: int, seg_count: int, lat_l: float, lat_r: float, y_off: float, mat: Material, closed := false, skip: Callable = Callable()) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := 0.0
	var last_l: Vector3
	var last_r: Vector3
	var has_last := false
	for k in seg_count:
		var i0: int = (i_from + k) % track.n
		var i1: int = (i_from + k + 1) % track.n
		if skip.is_valid() and skip.call(i0):
			v += track.step_len[i0] * 0.08
			has_last = false
			continue
		var l0 := last_l if has_last else _row_point(i0, lat_l, y_off)
		var r0 := last_r if has_last else _row_point(i0, lat_r, y_off)
		var l1 := _row_point(i1, lat_l, y_off)
		var r1 := _row_point(i1, lat_r, y_off)
		# anti-fold: inside tight corners the offset curve reverses against
		# the direction of travel and self-intersects ("torn barrier" bug);
		# clamp reversed rows so the strip degenerates cleanly instead
		var tg: Vector3 = track.tangents[i0]
		if (l1 - l0).dot(tg) < 0.0:
			l1 = l0
		if (r1 - r0).dot(tg) < 0.0:
			r1 = r0
		last_l = l1
		last_r = r1
		has_last = true
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
	var last_b: Vector3
	var last_t: Vector3
	var has_last := false
	for k in seg_count:
		var i0: int = (i_from + k) % track.n
		var i1: int = (i_from + k + 1) % track.n
		if skip.is_valid() and skip.call(i0):
			v += track.step_len[i0] * 0.08
			has_last = false
			continue
		any = true
		var b0 := last_b if has_last else _row_point(i0, lat, y_bot)
		var t0 := last_t if has_last else _row_point(i0, lat, y_top)
		var b1 := _row_point(i1, lat, y_bot)
		var t1 := _row_point(i1, lat, y_top)
		# anti-fold (see _ribbon)
		if (b1 - b0).dot(track.tangents[i0]) < 0.0:
			b1 = b0
			t1 = t0
		last_b = b1
		last_t = t1
		has_last = true
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

## The main barrier opens where a branch corridor (pit / hidden path) peels
## off or rejoins, on the branch's side only — so alternate roads pass
## through a gap instead of intersecting the railing.
func _branch_gap(i: int, side: float) -> bool:
	for b in track.branches:
		if signf(b["entry_side"]) == side and absi(track.wrap_index_diff(i, b["entry_idx"])) <= 3:
			return true
		if signf(b["exit_side"]) == side and absi(track.wrap_index_diff(i, b["exit_idx"])) <= 3:
			return true
	return false

func _build_barriers() -> void:
	var bar_mat := Pix.tex_mat(Pix.barrier())
	var lat: float = track.HALF + 2.0
	_wall(0, track.n, lat, 0.0, 6.0, bar_mat, _branch_gap.bind(1.0))
	_wall(0, track.n, -lat, 0.0, 6.0, bar_mat, _branch_gap.bind(-1.0))
	var cap_mat := Pix.flat_mat(Color(0.75, 0.76, 0.78))
	_ribbon(0, track.n, lat + 0.7, lat - 0.7, 6.0, cap_mat, true, _branch_gap.bind(1.0))
	_ribbon(0, track.n, -lat + 0.7, -lat - 0.7, 6.0, cap_mat, true, _branch_gap.bind(-1.0))
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
	var last_t: Vector3
	var has_last := false
	for k in seg_count:
		var i0: int = (i_from + k) % track.n
		var i1: int = (i_from + k + 1) % track.n
		var t0 := last_t if has_last else _row_point(i0, lat, 0.0)
		var t1 := _row_point(i1, lat, 0.0)
		if (t1 - t0).dot(track.tangents[i0]) < 0.0:
			t1 = t0  # anti-fold (see _ribbon)
		last_t = t1
		has_last = true
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
			# thin pergola beams: read as "covered section" from above without
			# occluding the car. Sized and spaced by DISTANCE, not samples —
			# samples sit ~24 units apart on this straight (14 per control
			# segment), so sample-count geometry comes out 4x too large here.
			var d_acc := 99.0
			var k := run_start
			while k < run_start + run:
				d_acc += track.step_len[k % track.n]
				if d_acc >= 26.0:
					d_acc = 0.0
					var p: Vector3 = track.samples[k % track.n]
					var t: Vector3 = track.tangents[k % track.n]
					var yaw := -atan2(t.z, t.x)
					var beam := MeshInstance3D.new()
					var bb := BoxMesh.new()
					bb.size = Vector3(3.0, 0.8, (track.HALF + 4.5) * 2.0)
					beam.mesh = bb
					beam.material_override = roof_mat
					beam.position = p + Vector3(0, 14.0, 0)
					beam.rotation.y = yaw
					beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(beam)
					var lamp := MeshInstance3D.new()
					var lb := BoxMesh.new()
					lb.size = Vector3(2.0, 0.5, 2.4)
					lamp.mesh = lb
					lamp.material_override = light_mat
					lamp.position = p + Vector3(0, 13.3, 0)
					lamp.rotation.y = yaw
					lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(lamp)
				k += 1
			_portal(run_start)
			_portal(run_start + run)
		i += 1

## Tunnel portal as a stone gallery facade: pillars, lintel, cornice, parapet.
func _portal(i: int) -> void:
	i = i % track.n
	var p: Vector3 = track.samples[i]
	var t: Vector3 = track.tangents[i]
	var root := Node3D.new()
	root.position = p
	root.rotation.y = -atan2(t.z, t.x)
	add_child(root)
	var stone := Pix.flat_mat(Color(0.74, 0.68, 0.56), 0.18)
	var trim := Pix.flat_mat(Color(0.86, 0.81, 0.7), 0.2)
	var recess := Pix.flat_mat(Color(0.12, 0.13, 0.18))
	# pillars clear of the barriers so they never read as standing on the road
	var lat: float = track.HALF + 7.0
	for side in [-1.0, 1.0]:
		_portal_part(root, Vector3(5, 16, 5), Vector3(0, 8, side * lat), stone, false)
		_portal_part(root, Vector3(6, 1.2, 6), Vector3(0, 16.6, side * lat), trim, false)
	# dark arch recess under the lintel, then lintel band, cornice, parapet
	_portal_part(root, Vector3(3.5, 3.0, (track.HALF + 4.5) * 2.0), Vector3(0, 12.6, 0), recess, true)
	_portal_part(root, Vector3(4.5, 4.0, (lat + 2.0) * 2.0), Vector3(0, 16, 0), stone, true)
	_portal_part(root, Vector3(5.5, 1.4, (lat + 3.0) * 2.0), Vector3(0, 18.7, 0), trim, true)
	_portal_part(root, Vector3(4, 2.4, 12), Vector3(0, 20.6, 0), stone, true)
	var lbl := Label3D.new()
	lbl.text = "AZURE TUNNEL"
	lbl.font = Pix.pixel_font()
	lbl.font_size = 48
	lbl.pixel_size = 0.08
	lbl.modulate = Color(0.5, 0.85, 1.0)
	lbl.outline_size = 14
	lbl.position = p + Vector3(0, 22.6, 0)
	lbl.rotation.y = atan2(-t.x, -t.z)  # face oncoming traffic
	add_child(lbl)

func _portal_part(root: Node3D, size: Vector3, pos: Vector3, mat: Material, no_shadow: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if no_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

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
	lbl.font = Pix.pixel_font()
	lbl.font_size = 32
	lbl.pixel_size = 0.08
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
		lbl.font = Pix.pixel_font()
		lbl.font_size = 64
		lbl.pixel_size = 0.07
		lbl.modulate = Color(0.08, 0.08, 0.08)
		# face oncoming traffic, nudged off the panel so it doesn't z-fight
		var face := Vector3(-t.x, 0, -t.z)
		lbl.position = base + Vector3(0, 8, 0) + face * 0.8
		lbl.rotation.y = atan2(face.x, face.z)
		add_child(lbl)
