extends RefCounted
## Arcade car model ported from the validated web prototype: speed-blended
## velocity, grip-limited turn rate, lateral-g cap, centerline wall clamp with
## near-free grazing (see proven_tuning in harbor_crown_track.json).
## Pure math on the track's sample array — no physics engine, so the headless
## sim and the game run the exact same code.

var track  # TrackData

# tuning (loaded from proven_tuning, world px & seconds)
var MAXV := 215.0
var ACCEL := 150.0
var BRAKE := 330.0
var DRAG := 0.62
var LATG := 140.0
var BOOST_MULT := 1.38

var car_name := "PLAYER"
var color := Color.WHITE

var pos := Vector3.ZERO
var heading := 0.0     # facing angle, radians, +X = 0, +Z positive
var move_dir := 0.0    # actual travel direction (lags heading -> drift feel)
var speed := 0.0
var idx := 0           # nearest centerline sample (window-tracked, anti-cut)
var prev_idx := 0

var lap := 0                    # completed laps
var next_cp := 1
var lap_times: Array[float] = []
var lap_start_time := 0.0
var best_lap := INF
var finished := false
var finish_time := 0.0

var boost := 0.5
var boosting := false
var braking := false
var wall_hit := false
var wrong_way := false
var _idx_delta_ema := 0.0

func setup(p_track, slot: int) -> void:
	track = p_track
	var t: Dictionary = track.tuning
	MAXV = t.get("MAXV", MAXV)
	ACCEL = t.get("ACCEL", ACCEL)
	BRAKE = t.get("BRAKE", BRAKE)
	DRAG = t.get("DRAG", DRAG)
	LATG = t.get("LATG", LATG)
	BOOST_MULT = t.get("boost_multiplier", BOOST_MULT)
	var g: Dictionary = track.grid_slot(slot)
	pos = g["pos"]
	heading = g["heading"]
	move_dir = heading
	idx = g["index"]
	prev_idx = idx

func progress() -> float:
	var p: float = float(lap) * track.total_len + track.cum_dist[idx]
	# just crossed the line but the lap increments at the checkpoint: keep monotonic
	if next_cp == 0 and idx < track.n / 4:
		p += track.total_len
	return p

func step(dt: float, t_now: float, input: Dictionary) -> void:
	var throttle: float = clampf(input.get("throttle", 0.0), 0.0, 1.0)
	var brake_in: float = clampf(input.get("brake", 0.0), 0.0, 1.0)
	var steer: float = clampf(input.get("steer", 0.0), -1.0, 1.0)
	braking = brake_in > 0.1

	boosting = bool(input.get("boost", false)) and boost > 0.02
	if boosting:
		boost = maxf(boost - 0.4 * dt, 0.0)
	else:
		boost = minf(boost + 0.07 * dt, 1.0)

	var vmax := MAXV * (BOOST_MULT if boosting else 1.0) * float(input.get("vmax_scale", 1.0))
	speed += ACCEL * (1.25 if boosting else 1.0) * throttle * dt
	speed -= BRAKE * brake_in * dt
	speed -= speed * DRAG * dt
	speed = clampf(speed, 0.0, vmax)

	# grip-limited turn rate: v * w <= LATG
	var w_cap := LATG / maxf(speed, 40.0)
	heading = wrapf(heading + steer * minf(2.8, w_cap) * dt, -PI, PI)

	# travel direction chases facing direction; less grip at speed = drift feel
	var grip := lerpf(9.0, 5.0, clampf(speed / MAXV, 0.0, 1.0))
	move_dir = wrapf(move_dir + wrapf(heading - move_dir, -PI, PI) * minf(1.0, grip * dt), -PI, PI)

	pos.x += cos(move_dir) * speed * dt
	pos.z += sin(move_dir) * speed * dt

	prev_idx = idx
	idx = track.nearest_index_hint(pos.x, pos.z, idx)
	_clamp_to_walls()
	_snap_elevation()
	_update_checkpoints(t_now)
	_update_wrong_way()

func _clamp_to_walls() -> void:
	wall_hit = false
	var p: Vector3 = track.samples[idx]
	var nrm: Vector3 = track.normals[idx]
	var lat := (pos.x - p.x) * nrm.x + (pos.z - p.z) * nrm.z
	# corridor narrows slightly in corners (proven wall_clamp formula)
	var lim: float = track.HALF - 5.0 - clampf(track.curvature[idx] * 200.0, 0.0, 6.0)
	if absf(lat) <= lim:
		return
	var side := signf(lat)
	pos.x -= nrm.x * (absf(lat) - lim) * side
	pos.z -= nrm.z * (absf(lat) - lim) * side
	var vx := cos(move_dir) * speed
	var vz := sin(move_dir) * speed
	var v_n := vx * nrm.x + vz * nrm.z
	if v_n * side > 0.0:  # moving into the wall
		# grazing must be near-free or AI laps go bimodal (prototype lesson)
		speed *= 1.0 - clampf((absf(v_n) - 12.0) / 220.0, 0.0, 0.5)
		vx -= nrm.x * v_n
		vz -= nrm.z * v_n
		if Vector2(vx, vz).length() > 1.0:
			var slide := atan2(vz, vx)
			heading = wrapf(slide + wrapf(heading - slide, -PI, PI) * 0.5, -PI, PI)
			move_dir = slide
		wall_hit = true

func _snap_elevation() -> void:
	var a: Vector3 = track.samples[idx]
	var b: Vector3 = track.samples[(idx + 1) % track.n]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf(Vector2(pos.x - a.x, pos.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	pos.y = lerpf(a.y, b.y, t)

func _update_checkpoints(t_now: float) -> void:
	if finished:
		return
	var cps: Array = track.checkpoints
	var target: int = cps[next_cp]
	var cp: Vector3 = track.samples[target]
	var r: float = track.HALF * 1.6
	# anti-cut: radius check AND nearest-sample index check (prototype lesson)
	if (pos.x - cp.x) ** 2 + (pos.z - cp.z) ** 2 > r * r:
		return
	if absf(track.wrap_index_diff(idx, target)) > track.CHECKPOINT_INDEX_WINDOW:
		return
	if next_cp == 0:
		lap += 1
		var lt := t_now - lap_start_time
		lap_times.append(lt)
		best_lap = minf(best_lap, lt)
		lap_start_time = t_now
		if lap >= track.LAPS:
			finished = true
			finish_time = t_now
	next_cp = (next_cp + 1) % cps.size()

func _update_wrong_way() -> void:
	var d := float(track.wrap_index_diff(idx, prev_idx))
	_idx_delta_ema = lerpf(_idx_delta_ema, d, 0.08)
	wrong_way = _idx_delta_ema < -0.25 and speed > 30.0

static func resolve_contacts(cars: Array) -> void:
	# simple pairwise push-apart so cars don't stack; wall clamp re-tidies next step
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a = cars[i]
			var b = cars[j]
			var dx: float = b.pos.x - a.pos.x
			var dz: float = b.pos.z - a.pos.z
			var d := sqrt(dx * dx + dz * dz)
			if d > 8.0 or d < 0.001:
				continue
			var push := (8.0 - d) * 0.5 / d
			a.pos.x -= dx * push
			a.pos.z -= dz * push
			b.pos.x += dx * push
			b.pos.z += dz * push
