extends Node3D
# Sky, sun and haze for each part of the day.
const SKY := "res://assets/polyhaven_town/sky/qwantani_%s_puresky.hdr"
const PHASES := [
	{"title": "Sáng", "clock": "07:40", "sky": "morning", "sky_energy": 1.0, "sun": Vector3(-28, -110, 0), "energy": 1.9, "light": Color(1.0, 0.90, 0.76), "fog": Color(0.78, 0.82, 0.84), "haze": 0.0011, "ambient": 0.75},
	{"title": "Trưa", "clock": "12:10", "sky": "noon", "sky_energy": 1.0, "sun": Vector3(-68, -150, 0), "energy": 2.4, "light": Color(1.0, 0.97, 0.90), "fog": Color(0.80, 0.84, 0.88), "haze": 0.0009, "ambient": 0.85},
	{"title": "Chiều", "clock": "16:30", "sky": "late_afternoon", "sky_energy": 0.9, "sun": Vector3(-24, 110, 0), "energy": 2.0, "light": Color(1.0, 0.80, 0.56), "fog": Color(0.84, 0.76, 0.64), "haze": 0.0014, "ambient": 0.65},
	{"title": "Chập tối", "clock": "18:05", "sky": "dusk_1", "sky_energy": 0.34, "sun": Vector3(-6, 104, 0), "energy": 0.8, "light": Color(1.0, 0.56, 0.36), "fog": Color(0.42, 0.34, 0.36), "haze": 0.0048, "ambient": 0.42},
]
var environment: Environment
var sun: DirectionalLight3D
var skies := {}
var phase := 0

func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	# Pure sky ambient turns every shaded wall blue; tropical shade is warmer than that.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.96, 0.95, 0.93)
	environment.ambient_light_sky_contribution = 0.5
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 1.05
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 2.2
	environment.glow_enabled = true
	environment.glow_intensity = 0.08
	environment.glow_hdr_threshold = 1.8
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_sky_affect = 0.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.14
	environment.adjustment_contrast = 1.04
	var holder := WorldEnvironment.new()
	holder.environment = environment
	add_child(holder)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 130.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	apply(0)

func apply(index: int) -> void:
	phase = index
	var look: Dictionary = PHASES[index]
	if not skies.has(look.sky):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(SKY % look.sky)
		skies[look.sky] = panorama
	environment.sky.sky_material = skies[look.sky]
	environment.background_energy_multiplier = look.sky_energy
	environment.ambient_light_energy = look.ambient
	environment.fog_light_color = look.fog
	environment.fog_density = look.haze
	sun.rotation_degrees = look.sun
	sun.light_energy = look.energy
	sun.light_color = look.light
