extends SceneTree
## Headless AI race sim — the prototype's health metric, ported per the kickoff
## doc: 4 equal-skill AI cars, fixed timestep, assert every lap lands in a sane
## window with < 2s spread. Run after every physics change:
##   godot --headless --path pixelgp --script res://tests/headless_sim.gd

const TrackData = preload("res://scripts/track_data.gd")
const CarPhysics = preload("res://scripts/car_physics.gd")
const AIDriver = preload("res://scripts/ai_driver.gd")

const DT := 1.0 / 60.0
const TIME_LIMIT := 260.0
const LAP_MIN := 35.0
const LAP_MAX := 55.0
const MAX_SPREAD := 2.0

func _initialize() -> void:
	# every track on the calendar must pass the same health checks
	var all_ok := true
	for path in TrackData.TRACKS:
		if not _check_track(path):
			all_ok = false
	print("RESULT: %s" % ("PASS" if all_ok else "FAIL"))
	quit(0 if all_ok else 1)

func _check_track(path: String) -> bool:
	var track := TrackData.new()
	track.load_track(path)
	print("track: %s  samples=%d  length=%.0f world px" % [track.track_name, track.n, track.total_len])
	print("checkpoints=%d  corners=%d" % [track.checkpoints.size(), track.corners.size()])

	var cars: Array = []
	var drivers: Array = []
	var lanes := [-5.0, 5.0, -5.0, 5.0]
	for i in 4:
		var c := CarPhysics.new()
		c.setup(track, i)
		c.car_name = "AI_%d" % (i + 1)
		cars.append(c)
		var d := AIDriver.new()
		d.setup(c, track, 1.0, lanes[i])
		drivers.append(d)

	var t := 0.0
	while t < TIME_LIMIT:
		for i in cars.size():
			cars[i].step(DT, t, drivers[i].control(cars))
		CarPhysics.resolve_contacts(cars)
		t += DT
		var all_done := true
		for c in cars:
			if not c.finished:
				all_done = false
				break
		if all_done:
			break

	var ok := true
	var all_laps: Array[float] = []
	for c in cars:
		var laps_str := ""
		for lt in c.lap_times:
			laps_str += "%6.2f " % lt
			all_laps.append(lt)
		print("%s  laps: %s %s" % [c.car_name, laps_str, "" if c.finished else "(DNF)"])
		if not c.finished or c.lap_times.size() < track.LAPS:
			print("  FAIL: %s did not finish %d laps in %.0fs" % [c.car_name, track.LAPS, TIME_LIMIT])
			ok = false
	if not all_laps.is_empty():
		var lo: float = all_laps.min()
		var hi: float = all_laps.max()
		print("lap window: %.2f .. %.2f  spread=%.2f" % [lo, hi, hi - lo])
		if lo < LAP_MIN or hi > LAP_MAX:
			print("  FAIL: laps outside %.0f-%.0fs window" % [LAP_MIN, LAP_MAX])
			ok = false
		if hi - lo > MAX_SPREAD:
			print("  FAIL: lap spread %.2f > %.1fs" % [hi - lo, MAX_SPREAD])
			ok = false
	if not (track.corners.size() >= 12 and track.corners.size() <= 19):
		print("  FAIL: corner count %d outside 12-19" % track.corners.size())
		ok = false
	if not _branch_check(track):
		ok = false
	return ok

## Drive a scripted car through each branch corridor (pit / hidden) and
## assert: it exits back onto the main line, the speed cap holds, and the
## pit refills boost.
func _branch_check(track) -> bool:
	var ok := true
	for b in track.branches:
		var c := CarPhysics.new()
		c.setup(track, 0)
		var d0: Vector3 = b["seg_dir"][0]
		c.pos = b["pts"][0] + Vector3(0, 0, 0)
		c.heading = atan2(d0.z, d0.x)
		c.move_dir = c.heading
		c.speed = 120.0
		c.boost = 0.1
		c.idx = b["entry_idx"]
		c.prev_idx = c.idx
		c.branch = b
		c.branch_seg = 0
		var t := 0.0
		var vmax_seen := 0.0
		while c.branch != null and t < 20.0:
			var pts: PackedVector3Array = b["pts"]
			var aim: Vector3 = pts[mini(c.branch_seg + 1, pts.size() - 1)]
			var desired := atan2(aim.z - c.pos.z, aim.x - c.pos.x)
			var steer := clampf(wrapf(desired - c.heading, -PI, PI) * 4.0, -1.0, 1.0)
			c.step(DT, t, {"throttle": 1.0, "steer": steer})
			if t > 0.6:  # ignore the deliberate hot entry while the limiter bites
				vmax_seen = maxf(vmax_seen, c.speed)
			t += DT
		var exited := c.branch == null
		var idx_err: int = absi(track.wrap_index_diff(c.idx, b["exit_idx"]))
		print("branch %-14s exited=%s in %4.1fs  vmax=%5.1f (cap %d)  idx_err=%d%s" % [
			b["name"], str(exited), t, vmax_seen, int(b["cap"]),
			idx_err, "  boost_refilled" if c.boost > 0.95 else ""])
		if not exited or idx_err > 4 or vmax_seen > float(b["cap"]) + 18.0:
			print("  FAIL: branch %s misbehaved" % b["name"])
			ok = false
		if b["type"] == "pit" and c.boost < 0.95:
			print("  FAIL: pit did not refill boost")
			ok = false
	return ok
