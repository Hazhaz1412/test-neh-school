extends RefCounted
# Player settings, shared by the menu and every scene. Environments register themselves so a
# brightness change reaches whatever is on screen.
const PATH := "user://settings.cfg"
const BRIGHTNESS_MIN := 0.8
const BRIGHTNESS_MAX := 2.5
const DEFAULTS := {"brightness_value": 1.3, "quality": 1, "volume": 1.0, "fullscreen": false}
static var environments: Array[WeakRef] = []

static func read(key: String) -> Variant:
	var file := ConfigFile.new()
	file.load(PATH)
	return file.get_value("graphics", key, DEFAULTS[key])

static func write(key: String, value: Variant) -> void:
	var file := ConfigFile.new()
	file.load(PATH)
	file.set_value("graphics", key, value)
	file.save(PATH)

static func track(environment: Environment) -> void:
	environment.adjustment_enabled = true
	environment.adjustment_brightness = read("brightness_value")
	environments.append(weakref(environment))

static func set_brightness(value: float) -> void:
	write("brightness_value", value)
	for entry in environments:
		var environment: Environment = entry.get_ref()
		if environment != null:
			environment.adjustment_brightness = value

static func set_volume(value: float) -> void:
	write("volume", value)
	apply_volume(value)

static func apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))

static func set_fullscreen(on: bool) -> void:
	write("fullscreen", on)
	apply_fullscreen(on)

static func apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
