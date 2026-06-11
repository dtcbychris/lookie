extends RefCounted
## Loads data/harbor_crown_track.json and builds the sampled centerline shared
## by car physics, AI, the track/scenery builders, the minimap, and the
## headless sim. Tracks are data, not hand-built scenes (see kickoff doc).
##
## Units: 1 Godot unit == 1 "world px" (art px * 2), matching proven_tuning.
## Art y maps to +Z. Start/finish heading is +X.

const WORLD_SCALE := 2.0      # art px -> world units
const ELEV_SCALE := 4.0       # elevation meters -> world units
const ROAD_BASE := 0.8        # road rides clear of the ground slab (anti z-fight)
const SAMPLES_PER_SEG := 14
const HALF := 23.0            # road half width, world units
const CHECKPOINT_COUNT := 8
const CHECKPOINT_INDEX_WINDOW := 22
const LAPS := 3

## Hand-authored elevation per control point (meters), following the JSON's
## elevation_intent: harbor level at start, climb the esses to the casino
## crest (+12 m), descend back to the harbor. The tunnel runs at harbor grade:
## any dip puts the road surface within z-fighting range of the ground slab
## (playtest: "see-through road") — the covered ribs sell the tunnel instead.
const ELEVATION_M := [
	0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3,
	0.8, 1.6, 2.5, 3.4, 4.4, 5.4, 6.4, 7.4, 8.4, 9.2,
	9.9, 10.5, 11.2, 11.7, 12.0, 12.0, 12.0, 12.0, 11.8, 11.4,
	11.0, 10.5, 10.0, 9.4, 8.8, 8.2, 7.6, 7.0, 6.5, 6.1,
	5.7, 5.3, 4.9, 4.5, 4.1, 3.7, 3.2, 2.6, 1.9, 1.1,
	0.6, 0.2, 0.0,
]

var samples: PackedVector3Array
var art: PackedVector2Array          # sample positions in art px, for region tests
var tangents: PackedVector3Array     # unit XZ tangent
var normals: PackedVector3Array      # unit XZ left normal
var curvature: PackedFloat32Array    # unsigned, smoothed (1 / world px)
var curv_sign: PackedFloat32Array    # +1 turning toward +normal side, -1 away
var step_len: PackedFloat32Array     # distance sample i -> i+1
var cum_dist: PackedFloat32Array
var total_len := 0.0
var n := 0
var checkpoints: Array[int] = []     # sample indices; checkpoint 0 == start line
var corners: Array[Dictionary] = []  # {"index": int, "number": int}
var teams: Array = []
var sponsors: Array = []
var tuning: Dictionary = {}
var set_dressing: Array = []   # hand-placed prop layer (see set_dressing.gd)
var track_name := "Harbor Crown Circuit"

func load_track(path := "res://data/harbor_crown_track.json") -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	track_name = data["track"]
	teams = data["teams"]
	sponsors = data["sponsors"]
	tuning = data["proven_tuning"]
	set_dressing = data.get("set_dressing", [])
	var cps: Array = data["centerline_control_points"]
	var m := cps.size()
	var ctrl: Array[Vector3] = []
	for i in m:
		var p: Array = cps[i]
		ctrl.append(Vector3(p[0] * WORLD_SCALE, ELEVATION_M[i] * ELEV_SCALE + ROAD_BASE, p[1] * WORLD_SCALE))
	var pts := PackedVector3Array()
	for i in m:
		var p0 := ctrl[(i - 1 + m) % m]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % m]
		var p3 := ctrl[(i + 2) % m]
		for s in SAMPLES_PER_SEG:
			pts.append(_catmull(p0, p1, p2, p3, float(s) / SAMPLES_PER_SEG))
	# Rotate the sample array so index 0 sits on the start/finish line.
	var sf: Array = data["start_finish_art_xy"]
	var sfx := float(sf[0]) * WORLD_SCALE
	var sfz := float(sf[1]) * WORLD_SCALE
	var best := 0
	var bd := INF
	for i in pts.size():
		var d := (pts[i].x - sfx) ** 2 + (pts[i].z - sfz) ** 2
		if d < bd:
			bd = d
			best = i
	samples = PackedVector3Array()
	for i in pts.size():
		samples.append(pts[(best + i) % pts.size()])
	n = samples.size()
	_build_derived()
	_build_checkpoints()
	_build_corners()

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _build_derived() -> void:
	art = PackedVector2Array()
	tangents = PackedVector3Array()
	normals = PackedVector3Array()
	step_len = PackedFloat32Array()
	cum_dist = PackedFloat32Array()
	var raw_curv := PackedFloat32Array()
	curv_sign = PackedFloat32Array()
	var dist := 0.0
	for i in n:
		art.append(Vector2(samples[i].x / WORLD_SCALE, samples[i].z / WORLD_SCALE))
		cum_dist.append(dist)
		var nxt := samples[(i + 1) % n]
		var sl := Vector2(nxt.x - samples[i].x, nxt.z - samples[i].z).length()
		step_len.append(sl)
		dist += sl
		var prv := samples[(i - 1 + n) % n]
		var t := Vector2(nxt.x - prv.x, nxt.z - prv.z).normalized()
		tangents.append(Vector3(t.x, 0, t.y))
		normals.append(Vector3(t.y, 0, -t.x))
		# discrete curvature: turn angle between adjacent segments / avg length
		var a := Vector2(samples[i].x - prv.x, samples[i].z - prv.z)
		var b := Vector2(nxt.x - samples[i].x, nxt.z - samples[i].z)
		var ang := a.angle_to(b)
		var avg_len := maxf((a.length() + b.length()) * 0.5, 0.001)
		raw_curv.append(absf(ang) / avg_len)
		# does the turn bend toward the +normal side?
		curv_sign.append(1.0 if (b - a).dot(Vector2(normals[i].x, normals[i].z)) > 0.0 else -1.0)
	total_len = dist
	# smooth curvature (box filter) so AI braking and wall clamps are stable
	curvature = PackedFloat32Array()
	var w := 4
	for i in n:
		var acc := 0.0
		for k in range(-w, w + 1):
			acc += raw_curv[(i + k + n) % n]
		curvature.append(acc / float(2 * w + 1))

func _build_checkpoints() -> void:
	checkpoints.clear()
	for k in CHECKPOINT_COUNT:
		var target := total_len * float(k) / CHECKPOINT_COUNT
		var best := 0
		var bd := INF
		for i in n:
			var d := absf(cum_dist[i] - target)
			if d < bd:
				bd = d
				best = i
		checkpoints.append(best)

func _build_corners() -> void:
	# adaptive threshold so the circuit lands in the brief's 12-19 corners
	var thr := 0.006
	for _attempt in 10:
		corners = _find_corners(thr)
		if corners.size() > 19:
			thr *= 1.25
		elif corners.size() < 12:
			thr *= 0.82
		else:
			break

func _find_corners(thr: float) -> Array[Dictionary]:
	# local curvature maxima above threshold, clustered, numbered from the line
	var apex_idx: Array[int] = []
	for i in n:
		var c := curvature[i]
		if c < thr:
			continue
		var is_max := true
		for k in range(-7, 8):
			if curvature[(i + k + n) % n] > c:
				is_max = false
				break
		if is_max:
			apex_idx.append(i)
	apex_idx.sort()
	var clustered: Array[int] = []
	for idx in apex_idx:
		if clustered.is_empty() or idx - clustered[-1] > 8:
			clustered.append(idx)
		elif curvature[idx] > curvature[clustered[-1]]:
			clustered[-1] = idx
	# wraparound cluster merge
	if clustered.size() >= 2 and (clustered[0] + n) - clustered[-1] <= 8:
		if curvature[clustered[-1]] > curvature[clustered[0]]:
			clustered[0] = clustered[-1]
		clustered.remove_at(clustered.size() - 1)
	var out: Array[Dictionary] = []
	for k in clustered.size():
		out.append({"index": clustered[k], "number": k + 1})
	return out

func wrap_index_diff(a: int, b: int) -> int:
	# shortest signed distance from b to a around the loop
	var d := (a - b) % n
	if d > n / 2:
		d -= n
	elif d < -n / 2:
		d += n
	return d

func nearest_index_hint(x: float, z: float, hint: int, back := 8, fwd := 45) -> int:
	var best := hint
	var bd := INF
	for k in range(-back, fwd + 1):
		var i := (hint + k + n) % n
		var d := (samples[i].x - x) ** 2 + (samples[i].z - z) ** 2
		if d < bd:
			bd = d
			best = i
	return best

func min_dist_to_track(x: float, z: float) -> float:
	# distance in world units from an XZ point to the nearest centerline sample
	var bd := INF
	for i in n:
		var d := (samples[i].x - x) ** 2 + (samples[i].z - z) ** 2
		if d < bd:
			bd = d
	return sqrt(bd)

func in_tunnel(i: int) -> bool:
	var a := art[i]
	return a.y > 700.0 and a.x > 300.0 and a.x < 680.0

func grid_slot(slot: int) -> Dictionary:
	# staggered 2-wide grid behind the start line; slot 0 = pole
	var back := 30.0 + float(slot) * 19.0
	var lat := 8.0 if slot % 2 == 0 else -8.0
	var i := 0
	while cum_dist[n - 1 - i] > total_len - back and i < n - 1:
		i += 1
	var idx := (n - i) % n
	var p := samples[idx] + normals[idx] * lat
	return {
		"pos": p,
		"heading": atan2(tangents[idx].z, tangents[idx].x),
		"index": idx,
	}
