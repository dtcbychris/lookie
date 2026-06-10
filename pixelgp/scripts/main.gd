extends Node
## Harbor Crown Circuit — first playable level for PixelGP.
## Assembles the pixel-render pipeline (640x360 SubViewport, nearest-filtered
## 2x upscale), generates the circuit + scenery from harbor_crown_track.json,
## spawns the player + 3 AI cars, and wires race logic, camera, and HUD.

const TrackData = preload("res://scripts/track_data.gd")
const CarPhysics = preload("res://scripts/car_physics.gd")
const AIDriver = preload("res://scripts/ai_driver.gd")
const TrackBuilder = preload("res://scripts/track_builder.gd")
const SceneryBuilder = preload("res://scripts/scenery_builder.gd")
const CarNode = preload("res://scripts/car_node.gd")
const RaceManager = preload("res://scripts/race_manager.gd")
const FollowCamera = preload("res://scripts/follow_camera.gd")
const HUD = preload("res://scripts/hud.gd")

const AI_SKILLS := [0.99, 0.962, 0.935]
const AI_LANES := [-5.0, 5.0, -5.0]

func _ready() -> void:
	# pixel pipeline: window 1280x720 -> SubViewport 640x360, nearest upscale
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.stretch_shrink = 2
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	svc.add_child(sv)

	var world := Node3D.new()
	world.name = "World"
	sv.add_child(world)
	_setup_environment(world)

	var track := TrackData.new()
	track.load_track()

	var track_builder: Node3D = TrackBuilder.new()
	world.add_child(track_builder)
	track_builder.build(track)

	var scenery: Node3D = SceneryBuilder.new()
	world.add_child(scenery)
	scenery.build(track)

	var race: Node = RaceManager.new()
	race.name = "RaceManager"
	race.track = track
	add_child(race)

	# grid: 3 AI ahead, player starts P4 — overtaking is the fantasy
	var team_colors: Array = []
	var grid_teams := [track.teams[1], track.teams[2], track.teams[3], track.teams[0]]
	for slot in 4:
		var team: Dictionary = grid_teams[slot]
		var phys := CarPhysics.new()
		phys.setup(track, slot)
		phys.car_name = team["name"]
		phys.color = Color(team["primary"])
		var node: Node3D = CarNode.new()
		world.add_child(node)
		node.build(Color(team["primary"]), Color(team["secondary"]))
		node.sync(phys, track)
		race.cars.append(phys)
		race.nodes.append(node)
		team_colors.append(Color(team["primary"]))
		if slot < 3:
			var drv := AIDriver.new()
			drv.setup(phys, track, AI_SKILLS[slot], AI_LANES[slot])
			race.drivers.append(drv)
		else:
			race.drivers.append(null)  # player
	race.player_index = 3

	var cam: Camera3D = FollowCamera.new()
	cam.name = "FollowCamera"
	world.add_child(cam)
	cam.setup(race, track)

	var hud: CanvasLayer = HUD.new()
	sv.add_child(hud)
	hud.setup(race, track, team_colors)

func _setup_environment(world: Node3D) -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.85, 0.78, 0.68)
	sky_mat.ground_bottom_color = Color(0.2, 0.3, 0.45)
	sky_mat.ground_horizon_color = Color(0.85, 0.78, 0.68)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.88)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	world.add_child(sun)
