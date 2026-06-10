extends Node
## Dev utility: boots the level, puts the player car on autopilot, and saves
## screenshots at a few interesting moments. Run under a virtual display:
##   xvfb-run godot --path pixelgp res://tests/screenshot_runner.tscn

const MainScene = preload("res://scenes/harbor_crown_circuit.tscn")
const AIDriver = preload("res://scripts/ai_driver.gd")

var f := 0
var main: Node
var out_dir := "/tmp/pixelgp_shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = MainScene.instantiate()
	add_child(main)
	# autopilot the player so action shots have all 4 cars racing
	var race := main.get_node("RaceManager")
	var drv := AIDriver.new()
	drv.setup(race.cars[race.player_index], race.track, 0.97, 3.0)
	race.drivers[race.player_index] = drv

func _process(_dt: float) -> void:
	f += 1
	match f:
		260:
			_shot("01_start")
		760:
			_shot("02_harbor_u")
		1150:
			_shot("03_tunnel")
		1750:
			_shot("04_esses_climb")
		2150:
			_shot("05_casino_hairpin")
		2250:
			_overview(true)
		2400:
			_shot("06_overview")
			_overview(false)
		3400:
			_shot("07_late_race")
		3500:
			get_tree().quit()

func _overview(on: bool) -> void:
	var cam := main.find_child("FollowCamera", true, false)
	cam.overview = on

func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, tag])
	print("saved ", tag)
