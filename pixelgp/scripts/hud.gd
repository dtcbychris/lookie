extends CanvasLayer
## Retro race HUD rendered inside the 640x360 pixel viewport: lap, timers,
## position, speed, boost, leaderboard, minimap, countdown, results.
## Default font as placeholder — swap for a pixel font later.

const MinimapScript = preload("res://scripts/minimap.gd")
const RM = preload("res://scripts/race_manager.gd")
const Pix = preload("res://scripts/pixel_textures.gd")

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
var _toast: Label
var _toast_t := 0.0
var _flash: ColorRect
var _impact_seen := -10.0
var _pit_seen := -10.0
var _gate_toasted := false
var _slip: Label
var _race_ui: Array[CanvasItem] = []
var _menu_ui: Array[CanvasItem] = []
var _results_ui: Array[CanvasItem] = []
var _result_rows: Array[Label] = []
var _menu_press: Label

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
	l.add_theme_font_override("font", Pix.pixel_font())
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 2)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _build() -> void:
	_race_ui.append(_panel(Rect2(4, 4, 130, 46)))
	_lap = _make_label(Vector2(10, 7), 8, Color(1.0, 0.85, 0.3))
	_time = _make_label(Vector2(10, 20), 8)
	_best = _make_label(Vector2(10, 33), 8, Color(0.5, 0.9, 1.0))

	_race_ui.append(_panel(Rect2(560, 4, 76, 28)))
	_pos = _make_label(Vector2(568, 10), 16, Color(1.0, 0.85, 0.3))

	var title := _make_label(Vector2(220, 6), 8, Color(0.85, 0.88, 0.95), true)
	title.size = Vector2(200, 12)
	title.text = track.track_name.to_upper()
	_race_ui.append_array([_lap, _time, _best, _pos, title])

	# leaderboard
	_race_ui.append(_panel(Rect2(4, 252, 126, 76)))
	for i in 4:
		var chip := ColorRect.new()
		chip.position = Vector2(10, 259 + i * 18)
		chip.size = Vector2(8, 12)
		add_child(chip)
		chip.name = "chip%d" % i
		_race_ui.append(chip)
		var row := _make_label(Vector2(24, 261 + i * 18), 8)
		_board_rows.append(row)
		_race_ui.append(row)

	# speed + boost
	_race_ui.append(_panel(Rect2(520, 296, 116, 60)))
	_speed = _make_label(Vector2(530, 302), 16)
	var kmh := _make_label(Vector2(588, 308), 8, Color(0.7, 0.75, 0.85))
	kmh.text = "KM/H"
	var boost_label := _make_label(Vector2(530, 330), 8, Color(0.4, 0.9, 1.0))
	boost_label.text = "BOOST"
	_slip = _make_label(Vector2(522, 282), 8, Color(0.3, 1.0, 0.9))
	_slip.text = "<< SLIPSTREAM >>"
	_race_ui.append_array([_speed, kmh, boost_label])
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
	_race_ui.append_array([bar_bg, _boost_fill])

	# minimap, above the speed panel
	_minimap = MinimapScript.new()
	_minimap.setup(track, race, team_colors)
	_minimap.position = Vector2(636 - _minimap.size.x, 292 - _minimap.size.y)
	add_child(_minimap)
	_race_ui.append(_minimap)

	# red impact flash (under the labels)
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.1, 0.05, 0.0)
	_flash.size = Vector2(640, 360)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	move_child(_flash, 0)

	_center = _make_label(Vector2(120, 134), 32, Color(1.0, 0.85, 0.3), true)
	_center.size = Vector2(400, 48)
	_center.add_theme_constant_override("outline_size", 4)
	_sub_center = _make_label(Vector2(120, 182), 8, Color.WHITE, true)
	_sub_center.size = Vector2(400, 14)
	_toast = _make_label(Vector2(120, 218), 8, Color(0.5, 0.95, 1.0), true)
	_toast.size = Vector2(400, 14)
	_build_menu()
	_build_results()

## Race-weekend front door: title card over the attract camera.
func _build_menu() -> void:
	var p := _panel(Rect2(150, 64, 340, 196))
	p.color = Color(0.02, 0.03, 0.06, 0.8)
	var t1 := _make_label(Vector2(150, 84), 32, Color(1.0, 0.85, 0.3), true)
	t1.size = Vector2(340, 40)
	t1.text = "PIXELGP"
	var t2 := _make_label(Vector2(150, 124), 8, Color(0.85, 0.88, 0.95), true)
	t2.size = Vector2(340, 12)
	t2.text = track.track_name.to_upper()
	var t3 := _make_label(Vector2(150, 138), 8, Color(0.65, 0.5, 0.8), true)
	t3.size = Vector2(340, 12)
	t3.text = track.league
	_menu_press = _make_label(Vector2(150, 170), 16, Color.WHITE, true)
	_menu_press.size = Vector2(340, 20)
	_menu_press.text = "PRESS ENTER TO RACE"
	var h1 := _make_label(Vector2(150, 212), 8, Color(0.6, 0.64, 0.72), true)
	h1.size = Vector2(340, 12)
	h1.text = "T CONTROLS   C CAMERA   TAB OVERVIEW"
	var h2 := _make_label(Vector2(150, 228), 8, Color(0.6, 0.64, 0.72), true)
	h2.size = Vector2(340, 12)
	h2.text = "SHIFT BOOST  -  PIT LANE REFILLS BOOST"
	_menu_ui.append_array([p, t1, t2, t3, _menu_press, h1, h2])

## Final classification table, shown under the FINISHED banner.
func _build_results() -> void:
	var p := _panel(Rect2(166, 200, 308, 96))
	p.color = Color(0.02, 0.03, 0.06, 0.8)
	_results_ui.append(p)
	for i in 4:
		var row := _make_label(Vector2(178, 208 + i * 21), 8)
		_result_rows.append(row)
		_results_ui.append(row)

func toast(msg: String) -> void:
	_toast.text = msg
	_toast_t = 2.6

func _fmt(t: float) -> String:
	if t == INF or t <= 0.0:
		return "--:--.-"
	return "%d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]

func _process(_dt: float) -> void:
	if race == null:
		return
	var car = race.cars[race.player_index]
	var in_menu: bool = race.state == RM.State.MENU
	for ci in _menu_ui:
		ci.visible = in_menu
	for ci in _race_ui:
		ci.visible = not in_menu
	for ci in _results_ui:
		ci.visible = race.state == RM.State.FINISHED
	if in_menu:
		_center.text = ""
		_sub_center.text = ""
		_slip.visible = false
		_menu_press.modulate.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() / 350.0))
		return
	# impact flash decays; toast fades out
	if car.impact_stamp > _impact_seen:
		_impact_seen = car.impact_stamp
		_flash.color.a = minf(0.08 + car.impact_mag * 0.6, 0.4)
	_flash.color.a *= exp(-5.0 * _dt)
	if car.pit_stamp > _pit_seen:
		_pit_seen = car.pit_stamp
		toast("PIT SERVICE - BOOST REFILLED")
	if race.gate_open_stamp >= 0.0 and not _gate_toasted:
		_gate_toasted = true
		toast("A GATE ON THE WEST PROMENADE SLID OPEN...")
	_slip.visible = car.slipstreaming and race.state == RM.State.RACING
	_toast_t = maxf(_toast_t - _dt, 0.0)
	_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	_lap.text = "LAP %d/%d" % [mini(car.lap + 1, track.LAPS), track.LAPS]
	var t := maxf(race.race_time, 0.0)
	_time.text = "TIME %s" % _fmt(t)
	_best.text = "BEST %s" % _fmt(car.best_lap if car.best_lap != INF else -1.0)
	_pos.text = "P%d/%d" % [race.player_position(), race.cars.size()]
	_speed.text = "%3d" % int(car.speed * 1.25)
	_boost_fill.size.x = 94.0 * car.boost
	# boost regen is locked after wall contact — show it
	_boost_fill.color = Color(0.55, 0.25, 0.2) if car.boost_lock > 0.0 else Color(0.25, 0.85, 1.0)
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
			_sub_center.text = "ENTER OR R - BACK TO MENU"
			for i in 4:
				var ci2: int = race.positions[i] if i < race.positions.size() else i
				var rc = race.cars[ci2]
				var best_txt := _fmt(rc.best_lap if rc.best_lap != INF else -1.0)
				_result_rows[i].text = "P%d %-14s %s" % [i + 1, rc.car_name, best_txt]
				_result_rows[i].add_theme_color_override("font_color",
					Color(1.0, 0.85, 0.3) if ci2 == race.player_index else Color.WHITE)
