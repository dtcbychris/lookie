extends CanvasLayer
## Retro race HUD rendered inside the 640x360 pixel viewport: lap, timers,
## position, speed, boost, leaderboard, minimap, countdown, results.
## Default font as placeholder — swap for a pixel font later.

const MinimapScript = preload("res://scripts/minimap.gd")
const RM = preload("res://scripts/race_manager.gd")

var race  # RaceManager
var track  # TrackData
var team_colors: Array = []

var _lap: Label
var _time: Label
var _best: Label
var _pos: Label
var _speed: Label
var _boost_fill: ColorRect
var _center: Label
var _sub_center: Label
var _board_rows: Array[Label] = []
var _minimap: Control

func setup(p_race, p_track, p_colors: Array) -> void:
	race = p_race
	track = p_track
	team_colors = p_colors
	_build()

func _panel(rect: Rect2) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.03, 0.06, 0.62)
	c.position = rect.position
	c.size = rect.size
	add_child(c)
	return c

func _make_label(pos: Vector2, sz: int, color := Color.WHITE, center := false) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _build() -> void:
	_panel(Rect2(4, 4, 122, 52))
	_lap = _make_label(Vector2(10, 6), 12, Color(1.0, 0.85, 0.3))
	_time = _make_label(Vector2(10, 22), 12)
	_best = _make_label(Vector2(10, 38), 12, Color(0.5, 0.9, 1.0))

	_panel(Rect2(566, 4, 70, 30))
	_pos = _make_label(Vector2(574, 7), 20, Color(1.0, 0.85, 0.3))

	var title := _make_label(Vector2(220, 4), 10, Color(0.85, 0.88, 0.95), true)
	title.size = Vector2(200, 14)
	title.text = "HARBOR CROWN CIRCUIT - RIVIERA RACING LEAGUE"
	title.add_theme_font_size_override("font_size", 8)

	# leaderboard
	_panel(Rect2(4, 252, 118, 76))
	for i in 4:
		var chip := ColorRect.new()
		chip.position = Vector2(10, 259 + i * 18)
		chip.size = Vector2(8, 12)
		add_child(chip)
		chip.name = "chip%d" % i
		var row := _make_label(Vector2(24, 257 + i * 18), 11)
		_board_rows.append(row)

	# speed + boost
	_panel(Rect2(520, 296, 116, 60))
	_speed = _make_label(Vector2(530, 300), 22)
	var kmh := _make_label(Vector2(596, 310), 10, Color(0.7, 0.75, 0.85))
	kmh.text = "KM/H"
	var boost_label := _make_label(Vector2(530, 330), 9, Color(0.4, 0.9, 1.0))
	boost_label.text = "BOOST"
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.12, 0.18)
	bar_bg.position = Vector2(530, 344)
	bar_bg.size = Vector2(96, 7)
	add_child(bar_bg)
	_boost_fill = ColorRect.new()
	_boost_fill.color = Color(0.25, 0.85, 1.0)
	_boost_fill.position = Vector2(531, 345)
	_boost_fill.size = Vector2(94, 5)
	add_child(_boost_fill)

	# minimap, above the speed panel
	_minimap = MinimapScript.new()
	_minimap.setup(track, race, team_colors)
	_minimap.position = Vector2(636 - _minimap.size.x, 292 - _minimap.size.y)
	add_child(_minimap)

	_center = _make_label(Vector2(170, 130), 42, Color(1.0, 0.85, 0.3), true)
	_center.size = Vector2(300, 60)
	_sub_center = _make_label(Vector2(170, 180), 14, Color.WHITE, true)
	_sub_center.size = Vector2(300, 20)

func _fmt(t: float) -> String:
	if t == INF or t <= 0.0:
		return "--:--.-"
	return "%d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]

func _process(_dt: float) -> void:
	if race == null:
		return
	var car = race.cars[race.player_index]
	_lap.text = "LAP %d/%d" % [mini(car.lap + 1, track.LAPS), track.LAPS]
	var t := maxf(race.race_time, 0.0)
	_time.text = "TIME %s" % _fmt(t)
	_best.text = "BEST %s" % _fmt(car.best_lap if car.best_lap != INF else -1.0)
	_pos.text = "P%d/%d" % [race.player_position(), race.cars.size()]
	_speed.text = "%3d" % int(car.speed * 1.25)
	_boost_fill.size.x = 94.0 * car.boost
	for i in 4:
		var ci: int = race.positions[i] if i < race.positions.size() else i
		_board_rows[i].text = "P%d %s" % [i + 1, race.cars[ci].car_name]
		var chip := get_node_or_null("chip%d" % i) as ColorRect
		if chip:
			chip.color = team_colors[ci]
	# center messages
	match race.state:
		RM.State.COUNTDOWN:
			var c := int(ceil(-race.race_time))
			_center.text = str(c) if c > 0 else "GO!"
			_sub_center.text = ""
		RM.State.RACING:
			if race.race_time < 0.9:
				_center.text = "GO!"
			elif car.wrong_way:
				_center.text = "WRONG WAY"
				_center.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			else:
				_center.text = ""
				_center.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			_sub_center.text = ""
		RM.State.FINISHED:
			_center.text = "FINISHED  P%d" % race.player_finish_pos
			_sub_center.text = "BEST LAP %s   -   R TO RESTART" % _fmt(car.best_lap)
