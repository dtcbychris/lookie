extends Node
## Wires the procedural sounds to race state: engine pitch follows the player's
## speed, boost whoosh, wall thuds scaled by impact, countdown beeps, lap
## blips, finish sting.

const AudioGen = preload("res://scripts/audio_gen.gd")
const RM = preload("res://scripts/race_manager.gd")

var race  # RaceManager

var _engine: AudioStreamPlayer
var _boost: AudioStreamPlayer
var _thud: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _beep_low: AudioStreamWAV
var _beep_go: AudioStreamWAV
var _blip: AudioStreamWAV

var _impact_seen := -10.0
var _prev_count := 99
var _prev_state := -1
var _prev_lap := 0
var _sting_played := false

func setup(p_race) -> void:
	race = p_race
	_engine = _player(AudioGen.engine_loop(), -16.0, true)
	_boost = _player(AudioGen.boost_loop(), -13.0, false)
	_thud = _player(AudioGen.thud(), -8.0, false)
	_ui = _player(null, -9.0, false)
	_sting = _player(AudioGen.sting(), -6.0, false)
	_beep_low = AudioGen.beep(440.0, 0.16)
	_beep_go = AudioGen.beep(880.0, 0.45)
	_blip = AudioGen.blip()

func _player(stream: AudioStream, vol: float, autostart: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	if autostart:
		p.play()
	return p

func _process(_dt: float) -> void:
	if race == null:
		return
	var car = race.cars[race.player_index]

	# engine follows speed
	var frac: float = clampf(car.speed / car.MAXV, 0.0, 1.0)
	_engine.pitch_scale = 0.55 + frac * 1.55 + (0.25 if car.boosting else 0.0)
	_engine.volume_db = -20.0 + frac * 7.0

	# boost whoosh
	if car.boosting and not _boost.playing:
		_boost.play()
	elif not car.boosting and _boost.playing:
		_boost.stop()

	# wall impacts, volume scaled by how bad the hit was
	if car.impact_stamp > _impact_seen:
		_impact_seen = car.impact_stamp
		_thud.volume_db = -16.0 + car.impact_mag * 18.0
		_thud.pitch_scale = randf_range(0.9, 1.1)
		_thud.play()

	# countdown beeps + GO
	if race.state == RM.State.COUNTDOWN:
		var c := int(ceil(-race.race_time))
		if c != _prev_count and c > 0:
			_prev_count = c
			_ui.stream = _beep_low
			_ui.play()
	if race.state != _prev_state:
		if _prev_state == RM.State.COUNTDOWN and race.state == RM.State.RACING:
			_ui.stream = _beep_go
			_ui.play()
		_prev_state = race.state

	# lap complete blip (not on the finish, the sting covers that)
	if car.lap > _prev_lap:
		_prev_lap = car.lap
		if not car.finished:
			_ui.stream = _blip
			_ui.play()

	# finish sting once
	if race.state == RM.State.FINISHED and not _sting_played:
		_sting_played = true
		_engine.volume_db = -26.0
		_sting.play()
