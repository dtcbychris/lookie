extends RefCounted
## Waypoint AI ported from the validated prototype:
## vAllow = min over lookahead of sqrt(LATG/curv + 2*BRAKE*0.8*dist),
## target vAllow*0.89*skill, lookahead-point steering, slipstream bonus.

const STEER_GAIN := 4.2
const LOOKAHEAD_DIST := 420.0   # world px of braking lookahead
const SLIPSTREAM_RANGE := 55.0

var car  # CarPhysics
var track  # TrackData
var skill := 1.0
var lane := 0.0  # static lateral offset so cars don't share one line

func setup(p_car, p_track, p_skill: float, p_lane: float) -> void:
	car = p_car
	track = p_track
	skill = p_skill
	lane = p_lane

func control(others: Array) -> Dictionary:
	var i0: int = car.idx
	var n: int = track.n

	# proven braking formula over distance lookahead
	var v_allow_min: float = car.MAXV
	var d := 0.0
	var k := 0
	while d < LOOKAHEAD_DIST:
		var j := (i0 + k) % n
		d += track.step_len[j]
		k += 1
		var cv: float = maxf(track.curvature[(i0 + k) % n], 0.0008)
		v_allow_min = minf(v_allow_min, sqrt(car.LATG / cv + 2.0 * car.BRAKE * 0.8 * d))
	var cv_now: float = maxf(track.curvature[i0], 0.0008)
	v_allow_min = minf(v_allow_min, sqrt(car.LATG / cv_now))
	var v_target: float = minf(car.MAXV, v_allow_min * 0.89) * skill

	# slipstream: +9% when tucked behind a car ahead
	var vmax_scale := 1.0
	var lift := false
	for o in others:
		if o == car:
			continue
		var ahead: int = track.wrap_index_diff(o.idx, car.idx)
		var dist := Vector2(o.pos.x - car.pos.x, o.pos.z - car.pos.z).length()
		if ahead > 0 and dist < SLIPSTREAM_RANGE:
			vmax_scale = 1.09
		if ahead > 0 and dist < 16.0:
			lift = true  # crude anti-ramming

	# steer at a speed-scaled lookahead point, offset by this car's lane
	var aim_k := 5 + int(car.speed * 0.05)
	var aj := (i0 + aim_k) % n
	var aim: Vector3 = track.samples[aj] + track.normals[aj] * lane
	var desired := atan2(aim.z - car.pos.z, aim.x - car.pos.x)
	var steer := clampf(wrapf(desired - car.heading, -PI, PI) * STEER_GAIN, -1.0, 1.0)

	var throttle := 1.0 if car.speed < v_target * skill_margin() else 0.0
	if lift:
		throttle = minf(throttle, 0.3)
	var brake := 1.0 if car.speed > v_target * 1.05 else 0.0
	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"boost": false,
		"vmax_scale": vmax_scale,
	}

func skill_margin() -> float:
	return 1.0
