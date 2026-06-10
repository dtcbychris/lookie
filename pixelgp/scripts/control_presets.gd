extends RefCounted
## Control presets + persisted settings (user://pixelgp_settings.cfg).
## Rebinds the InputMap at runtime; project.godot only defines the defaults.

const CONFIG_PATH := "user://pixelgp_settings.cfg"

const PRESETS := [
	{
		"name": "CLASSIC",
		"desc": "WASD + ARROWS",
		"throttle": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
	},
	{
		"name": "DRIVER",
		"desc": "A BRAKE / D GAS / ARROWS STEER",
		"throttle": [KEY_D],
		"brake": [KEY_A],
		"steer_left": [KEY_LEFT],
		"steer_right": [KEY_RIGHT],
	},
]

static var settings := {"preset": 0, "camera": 0}

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		settings["preset"] = clampi(cfg.get_value("input", "preset", 0), 0, PRESETS.size() - 1)
		settings["camera"] = clampi(cfg.get_value("camera", "mode", 0), 0, 1)

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "preset", settings["preset"])
	cfg.set_value("camera", "mode", settings["camera"])
	cfg.save(CONFIG_PATH)

static func apply_preset(idx: int) -> void:
	settings["preset"] = idx
	var p: Dictionary = PRESETS[idx]
	for action in ["throttle", "brake", "steer_left", "steer_right"]:
		InputMap.action_erase_events(action)
		for key in p[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

static func cycle_preset() -> Dictionary:
	var idx := (int(settings["preset"]) + 1) % PRESETS.size()
	apply_preset(idx)
	save_settings()
	return PRESETS[idx]

static func set_camera(mode: int) -> void:
	settings["camera"] = mode
	save_settings()
