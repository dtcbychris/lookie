extends Node
## Dev utility: fixed-camera screenshots of key landmarks (casino, marina,
## tunnel, grandstand) for visual QA without driving there.
##   xvfb-run godot --path pixelgp res://tests/landmark_shots.tscn

const MainScene = preload("res://scenes/harbor_crown_circuit.tscn")

# [tag, camera position, look target]
const POSES := [
	["esses_side", Vector3(1420, 70, 1050), Vector3(1660, 30, 870)],
	["esses_low", Vector3(1560, 45, 1080), Vector3(1655, 32, 900)],
	["esses_top", Vector3(1650, 320, 1000), Vector3(1655, 30, 880)],
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
