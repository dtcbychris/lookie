extends Node
## Race state machine: countdown -> racing -> finished. Steps every car's
## physics at a fixed timestep, resolves car contacts, and keeps live
## positions. The same CarPhysics/AIDriver code runs in the headless sim.

const CarPhysics = preload("res://scripts/car_physics.gd")

enum State { COUNTDOWN, RACING, FINISHED }

var track  # TrackData
var cars: Array = []      # CarPhysics, index-aligned with nodes/drivers
var nodes: Array = []     # CarNode visuals
var drivers: Array = []   # AIDriver or null for the player
var player_index := 3
var state := State.COUNTDOWN
var race_time := -3.6
var positions: Array = []  # car indices, best first
var player_finish_pos := 0

func _physics_process(dt: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	race_time += dt
	if state == State.COUNTDOWN and race_time >= 0.0:
		state = State.RACING
	var t := maxf(race_time, 0.0)
	for i in cars.size():
		var input := {}
		if state != State.COUNTDOWN:
			if drivers[i]:
				# AI keeps cruising after the flag so cars don't park on the line
				input = drivers[i].control(cars)
			elif not cars[i].finished:
				input = _player_input()
		cars[i].step(dt, t, input)
		nodes[i].sync(cars[i], track)
	CarPhysics.resolve_contacts(cars)
	_update_positions()
	if state == State.RACING and cars[player_index].finished:
		state = State.FINISHED
		player_finish_pos = positions.find(player_index) + 1

func _player_input() -> Dictionary:
	return {
		"throttle": Input.get_action_strength("throttle"),
		"brake": Input.get_action_strength("brake"),
		"steer": Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"),
		"boost": Input.is_action_pressed("boost"),
	}

func _update_positions() -> void:
	var order := []
	for i in cars.size():
		order.append(i)
	order.sort_custom(func(a, b):
		var ca = cars[a]
		var cb = cars[b]
		if ca.finished and cb.finished:
			return ca.finish_time < cb.finish_time
		if ca.finished != cb.finished:
			return ca.finished
		return ca.progress() > cb.progress())
	positions = order

func player_position() -> int:
	return positions.find(player_index) + 1
