extends Camera3D
## Smooth follow camera with speed-based zoom, velocity look-ahead, and
## impact shake. C toggles RACE (more overhead, best for racing lines) vs
## SHOWCASE (lower 3/4, shows building depth). Tab = full-circuit overview.

# [height, distance-back, speed-zoom factor]
const MODES := [
	[262.0, 172.0, 0.18],  # RACE  (~57 degrees)
	[198.0, 206.0, 0.15],  # SHOWCASE (~44 degrees)
]

const RM = preload("res://scripts/race_manager.gd")

var race  # RaceManager
var track  # TrackData
var mode := 0
var overview := false
var _look := Vector3.ZERO
var _center := Vector3.ZERO
var _overview_h := 1500.0
var _shake := 0.0
var _impact_seen := -10.0

func setup(p_race, p_track) -> void:
	race = p_race
	track = p_track
	fov = 30.0
	# tight near plane = depth precision; the default 0.05 near makes the road
	# z-fight the ground slab at distance ("see-through road" playtest bug)
	near = 4.0
	far = 6000.0
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
	if race.state == RM.State.MENU:
		# attract mode: drift along the circuit behind the menu
		var tt := Time.get_ticks_msec() / 1000.0
		var fi := fposmod(tt * 9.0, float(track.n))
		var i := int(fi)
		var p: Vector3 = track.samples[i]
		var ahead: Vector3 = track.samples[(i + 45) % track.n]
		var blend_a := 1.0 - exp(-2.0 * dt)
		position = position.lerp(p + Vector3(0, 105, 70), blend_a)
		_look = _look.lerp(ahead + Vector3(0, 8, 0), blend_a)
		look_at(_look)
		return
	if Input.is_action_just_pressed("overview"):
		overview = not overview
	var car = race.cars[race.player_index]
	# wall impacts kick the shake; decays exponentially
	if car.impact_stamp > _impact_seen:
		_impact_seen = car.impact_stamp
		_shake = minf(_shake + car.impact_mag * 26.0, 7.0)
	_shake *= exp(-7.0 * dt)
	var blend := 1.0 - exp(-6.0 * dt)
	if overview:
		position = position.lerp(_center + Vector3(0, _overview_h, _overview_h * 0.1), blend)
		_look = _look.lerp(_center, blend)
	else:
		var m: Array = MODES[mode]
		var fwd := Vector3(cos(car.move_dir), 0, sin(car.move_dir))
		var want_look: Vector3 = car.pos + fwd * minf(car.speed * 0.45, 78.0)
		_look = _look.lerp(want_look, 1.0 - exp(-5.0 * dt))
		var want_pos: Vector3 = car.pos + Vector3(0, m[0] + car.speed * m[2], m[1])
		position = position.lerp(want_pos, blend)
	if _shake > 0.05:
		position += Vector3(randf() - 0.5, (randf() - 0.5) * 0.4, randf() - 0.5) * 2.0 * _shake
	look_at(_look)
