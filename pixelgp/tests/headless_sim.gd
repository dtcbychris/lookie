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
	var track := TrackData.new()
	track.load_track()
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
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
