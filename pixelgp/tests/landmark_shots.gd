extends Node
## Dev utility: fixed-camera screenshots of key landmarks (casino, marina,
## tunnel, grandstand) for visual QA without driving there.
##   xvfb-run godot --path pixelgp res://tests/landmark_shots.tscn

const MainScene = preload("res://scenes/harbor_crown_circuit.tscn")

# [tag, camera position, look target]
const POSES := [
	["hotel_grid", Vector3(690, 110, 1330), Vector3(690, 25, 1080)],
	["yacht_club", Vector3(1340, 110, 1490), Vector3(1470, 5, 1360)],
	["church", Vector3(390, 90, 990), Vector3(490, 25, 865)],
	["portal", Vector3(500, 60, 1640), Vector3(625, 8, 1500)],
	["casino", Vector3(1500, 220, 600), Vector3(1640, 48, 330)],
]

var f := 0
var cam: Camera3D

func _ready() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var world := main.find_child("World", true, false)
	cam = Camera3D.new()
	cam.fov = 40
	world.add_child(cam)

func _process(_dt: float) -> void:
	f += 1
	# give each pose ~50 frames to settle (shadows, water anim)
	var pose_i := f / 50
	if pose_i >= POSES.size():
		get_tree().quit()
		return
	var pose: Array = POSES[pose_i]
	cam.position = pose[1]
	cam.look_at(pose[2])
	cam.current = true
	if f % 50 == 49:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/pixelgp_shots/lm_%s.png" % pose[0])
		print("saved ", pose[0])
