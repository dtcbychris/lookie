extends Camera3D
## Smooth 3/4 follow camera with speed-based zoom and velocity look-ahead.
## Tab toggles a fixed full-circuit overview (debug track view).

var race  # RaceManager
var track  # TrackData
var overview := false
var _look := Vector3.ZERO
var _center := Vector3.ZERO
var _overview_h := 1500.0

func setup(p_race, p_track) -> void:
	race = p_race
	track = p_track
	fov = 30.0
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for p in track.samples:
		lo.x = minf(lo.x, p.x); lo.z = minf(lo.z, p.z)
		hi.x = maxf(hi.x, p.x); hi.z = maxf(hi.z, p.z)
	_center = (lo + hi) * 0.5
	_overview_h = maxf(hi.x - lo.x, hi.z - lo.z) * 2.1
	var car = race.cars[race.player_index]
	position = car.pos + Vector3(0, 270, 175)
	_look = car.pos
	current = true

func _physics_process(dt: float) -> void:
	if Input.is_action_just_pressed("overview"):
		overview = not overview
	var car = race.cars[race.player_index]
	var blend := 1.0 - exp(-6.0 * dt)
	if overview:
		position = position.lerp(_center + Vector3(0, _overview_h, _overview_h * 0.1), blend)
		_look = _look.lerp(_center, blend)
	else:
		var fwd := Vector3(cos(car.move_dir), 0, sin(car.move_dir))
		var want_look: Vector3 = car.pos + fwd * minf(car.speed * 0.45, 78.0)
		_look = _look.lerp(want_look, 1.0 - exp(-5.0 * dt))
		var want_pos: Vector3 = car.pos + Vector3(0, 262.0 + car.speed * 0.18, 172.0)
		position = position.lerp(want_pos, blend)
	look_at(_look)
