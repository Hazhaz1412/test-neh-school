extends Node

# One global illumination pulse; no extra shadow-casting lights or map rebuilds.
var world: Node3D
var cooldown := 0.0
var remaining := 0.0
var intensity := 0.0
var saved_environment: Environment
var saved_values: Array = []
var moon: DirectionalLight3D
var moon_color: Color
var moon_energy := 0.0

func trigger() -> bool:
	if cooldown > 0 or not world.simulation_active():
		return false
	clear_light()
	saved_environment = world.get_node("Atmosphere/MoonlitEnvironment").environment
	saved_values = [saved_environment.ambient_light_color, saved_environment.ambient_light_energy,
		saved_environment.ambient_light_source, saved_environment.ambient_light_sky_contribution,
		saved_environment.fog_density]
	moon = world.get_node("Atmosphere/Moonlight")
	moon_color = moon.light_color
	moon_energy = moon.light_energy
	remaining = 0.55
	cooldown = world.camera_shot_cooldown
	_apply_light(1.0)
	for ghost in world.enemies:
		if is_instance_valid(ghost) and not ghost.dormant:
			ghost.banish(world.camera_banish_seconds)
	world.encounters.give_break(world.camera_banish_seconds + 2)
	world.soundscape.cue("camera", -13)
	world.player.startle = 0.28
	return true

func _apply_light(amount: float) -> void:
	intensity = amount
	saved_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	saved_environment.ambient_light_sky_contribution = 0
	saved_environment.ambient_light_color = saved_values[0].lerp(Color(0.92, 0.96, 1), amount)
	saved_environment.ambient_light_energy = lerpf(saved_values[1], 2.8, amount)
	saved_environment.fog_density = lerpf(saved_values[4], saved_values[4] * 0.12, amount)
	moon.light_color = moon_color.lerp(Color(0.92, 0.96, 1), amount)
	moon.light_energy = lerpf(moon_energy, 3.0, amount)

func _process(delta: float) -> void:
	if not world.simulation_active():
		return
	cooldown = maxf(0, cooldown - delta)
	if remaining <= 0:
		return
	remaining = maxf(0, remaining - delta)
	if remaining == 0:
		clear_light()
	else:
		_apply_light(minf(1, remaining / 0.42))

func clear_light() -> void:
	if saved_environment != null:
		saved_environment.ambient_light_color = saved_values[0]
		saved_environment.ambient_light_energy = saved_values[1]
		saved_environment.ambient_light_source = saved_values[2]
		saved_environment.ambient_light_sky_contribution = saved_values[3]
		saved_environment.fog_density = saved_values[4]
		moon.light_color = moon_color
		moon.light_energy = moon_energy
		saved_environment = null
	remaining = 0
	intensity = 0

func reset() -> void:
	clear_light()
	cooldown = 0
