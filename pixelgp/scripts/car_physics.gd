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
var boost_lock := 0.0   # wall contact pauses boost regen — mistakes cost the
						# exact resource used to mask them
var boosting := false
var slipstreaming := false

# branch corridor state (pit lane / hidden paths); null = on the main road
var branch = null       # Dictionary from track.branches
var branch_seg := 0
var branch_s := 0.0
var pit_stamp := -10.0  # race time of last pit boost refill (for HUD/audio)
var _pit_refilled := false
var _hidden_ok := false  # gate state, set from input each step
var braking := false
var wall_hit := false
var impact_stamp := -10.0  # race time of last wall impact (for fx/audio)
var impact_mag := 0.0      # speed-loss fraction of that impact
var wrong_way := false
var _idx_delta_ema := 0.0

## Coasting decelerates gently; braking is the skill tool. Full proven DRAG
## made lift-and-coast nearly as strong as braking (playtest: brake felt
## irrelevant), so only part of it applies.
const COAST_DRAG_SCALE := 0.55
## Full BRAKE force stopped the car almost instantly (playtest) — soften it.
## The AI braking formula must use the same effective force (ai_driver.gd).
const BRAKE_EFFECT := 0.8

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
	boost_lock = maxf(boost_lock - dt, 0.0)
	if boosting:
		boost = maxf(boost - 0.4 * dt, 0.0)
	elif boost_lock <= 0.0:
		boost = minf(boost + 0.045 * dt, 1.0)

	var vmax_scale := float(input.get("vmax_scale", 1.0))
	slipstreaming = vmax_scale > 1.04
	var vmax := MAXV * (BOOST_MULT if boosting else 1.0) * vmax_scale
	speed += ACCEL * (1.25 if boosting else 1.0) * throttle * dt
	speed -= BRAKE * BRAKE_EFFECT * brake_in * dt
	speed -= speed * DRAG * COAST_DRAG_SCALE * dt
	speed = clampf(speed, 0.0, vmax)

	# grip-limited turn rate: v * w <= LATG
	var w_cap := LATG / maxf(speed, 40.0)
	heading = wrapf(heading + steer * minf(2.8, w_cap) * dt, -PI, PI)

	# travel direction chases facing direction; less grip at speed = drift feel
	var grip := lerpf(9.0, 5.0, clampf(speed / MAXV, 0.0, 1.0))
	move_dir = wrapf(move_dir + wrapf(heading - move_dir, -PI, PI) * minf(1.0, grip * dt), -PI, PI)

	pos.x += cos(move_dir) * speed * dt
	pos.z += sin(move_dir) * speed * dt

	if branch != null:
		_step_branch(dt, t_now)
		_update_checkpoints(t_now)
		return

	prev_idx = idx
	idx = track.nearest_index_hint(pos.x, pos.z, idx)
	_clamp_to_walls(t_now)
	_snap_elevation()
	_update_checkpoints(t_now)
	_update_wrong_way()
	if bool(input.get("branches", false)):
		_hidden_ok = bool(input.get("hidden_ok", false))
		_check_branch_entry()

## Branch corridors (pit / hidden paths): same wall-clamp model as the main
## road on a short linear polyline. Main-track index stays synced so laps,
## checkpoints, and positions keep working while off the main line.
func _check_branch_entry() -> void:
	for b in track.branches:
		if b["gated"] and not _hidden_ok:
			continue  # gate is closed: corridor is sealed
		if absf(track.wrap_index_diff(idx, b["entry_idx"])) > 12:
			continue
		var p0: Vector3 = b["pts"][0]
		if (pos.x - p0.x) ** 2 + (pos.z - p0.z) ** 2 > (b["half"] + 3.0) ** 2:
			continue
		# must be moving INTO the corridor, not just brushing past its mouth
		var d0: Vector3 = b["seg_dir"][0]
		if cos(move_dir) * d0.x + sin(move_dir) * d0.z < 0.5:
			continue
		# and deliberately steered off-line toward the branch side
		var sp: Vector3 = track.samples[idx]
		var nrm: Vector3 = track.normals[idx]
		var lat := (pos.x - sp.x) * nrm.x + (pos.z - sp.z) * nrm.z
		if lat * b["entry_side"] < 7.0:
			continue
		branch = b
		branch_seg = 0
		branch_s = 0.0
		_pit_refilled = false
		return

func _step_branch(dt: float, t_now: float) -> void:
	var b: Dictionary = branch
	# branch speed limit (rapid limiter, not a hard snap)
	if speed > b["cap"]:
		speed = maxf(b["cap"], speed - 520.0 * dt)
	# project onto nearby segments
	var pts: PackedVector3Array = b["pts"]
	var best_seg := branch_seg
	var best_d := INF
	for k in range(maxi(branch_seg - 1, 0), mini(branch_seg + 2, pts.size() - 1) + 1):
		if k >= pts.size() - 1:
			break
		var d := (pts[k].x - pos.x) ** 2 + (pts[k].z - pos.z) ** 2
		if d < best_d:
			best_d = d
			best_seg = k
	branch_seg = best_seg
	var a: Vector3 = pts[branch_seg]
	var dir: Vector3 = b["seg_dir"][branch_seg]
	var nrm: Vector3 = b["seg_norm"][branch_seg]
	var along := (pos.x - a.x) * dir.x + (pos.z - a.z) * dir.z
	# backed out of the mouth: release to the main road, or the corridor
	# clamp would drag the car along the alley's infinite extension
	if branch_seg == 0 and along < -1.0:
		branch = null
		idx = b["entry_idx"]
		prev_idx = idx
		return
	branch_s = b["cum"][branch_seg] + maxf(along, 0.0)
	# lateral clamp with the usual angle-scaled wall penalty
	var lat := (pos.x - a.x) * nrm.x + (pos.z - a.z) * nrm.z
	var lim: float = b["half"] - 2.5
	if absf(lat) > lim:
		var side := signf(lat)
		pos.x -= nrm.x * (absf(lat) - lim) * side
		pos.z -= nrm.z * (absf(lat) - lim) * side
		var vx := cos(move_dir) * speed
		var vz := sin(move_dir) * speed
		var v_n := vx * nrm.x + vz * nrm.z
		if v_n * side > 0.0:
			var loss := clampf((absf(v_n) - 10.0) / 130.0, 0.0, 0.75)
			speed *= 1.0 - loss
			if loss > 0.02:
				impact_stamp = t_now
				impact_mag = loss
			vx -= nrm.x * v_n
			vz -= nrm.z * v_n
			if Vector2(vx, vz).length() > 1.0:
				var slide := atan2(vz, vx)
				heading = wrapf(slide + wrapf(heading - slide, -PI, PI) * 0.5, -PI, PI)
				move_dir = slide
			wall_hit = true
	pos.y = a.y
	# keep the main-track index synced (laps/positions/checkpoints stay sane)
	var span: int = track.wrap_index_diff(b["exit_idx"], b["entry_idx"])
	var t01: float = clampf(branch_s / b["len"], 0.0, 1.0)
	prev_idx = idx
	idx = posmod(b["entry_idx"] + int(round(float(span) * t01)), track.n)
	wrong_way = false
	# pit service: full boost at the pit box
	if b["type"] == "pit" and not _pit_refilled and branch_s > b["len"] * 0.45:
		_pit_refilled = true
		boost = 1.0
		boost_lock = 0.0
		pit_stamp = t_now
	if branch_s >= b["len"] - 2.0:
		idx = b["exit_idx"]
		prev_idx = idx
		branch = null

func _clamp_to_walls(t_now: float) -> void:
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
		# Penalty scales with impact angle: parallel grazing stays near-free
		# (or AI laps go bimodal — prototype lesson), but slamming in at an
		# angle is genuinely costly (playtest: walls were too forgiving).
		var loss := clampf((absf(v_n) - 10.0) / 130.0, 0.0, 0.75)
		speed *= 1.0 - loss
		if loss > 0.02:
			impact_stamp = t_now
			impact_mag = loss
			boost_lock = 2.0
			boost = maxf(boost - loss * 0.5, 0.0)
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
