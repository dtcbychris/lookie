extends Control
## Minimap: track polyline, start line, sector ticks, and live car dots.
## Drawn from the same TrackData art-space samples the level is built from.

const ART_MIN := Vector2(104, 107)
const ART_MAX := Vector2(853, 754)
const MAP_SCALE := 0.165
const PAD := 7.0

var track  # TrackData
var race  # RaceManager
var colors: Array = []

func setup(p_track, p_race, p_colors: Array) -> void:
	track = p_track
	race = p_race
	colors = p_colors
	custom_minimum_size = (ART_MAX - ART_MIN) * MAP_SCALE + Vector2(PAD * 2, PAD * 2)
	size = custom_minimum_size

func _process(_dt: float) -> void:
	queue_redraw()

func _map(a: Vector2) -> Vector2:
	return (a - ART_MIN) * MAP_SCALE + Vector2(PAD, PAD)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.65))
	if track == null:
		return
	var pts := PackedVector2Array()
	for i in range(0, track.n, 5):
		pts.append(_map(track.art[i]))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.2, 0.24, 0.3), 4.0)
	draw_polyline(pts, Color(0.85, 0.88, 0.92), 1.5)
	# sector ticks at checkpoints 0 / 3 / 6 (sector boundaries)
	for k in [0, 3, 6]:
		var i: int = track.checkpoints[k]
		var nrm := Vector2(track.normals[i].x, track.normals[i].z) * 4.0
		var c := _map(track.art[i])
		draw_line(c - nrm, c + nrm, Color(0.3, 0.9, 1.0) if k > 0 else Color.WHITE, 2.0)
	if race == null:
		return
	for i in race.cars.size():
		var car = race.cars[i]
		var p := _map(Vector2(car.pos.x, car.pos.z) / track.WORLD_SCALE)
		if i == race.player_index:
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), colors[i])
