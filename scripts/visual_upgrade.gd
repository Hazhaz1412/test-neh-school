extends RefCounted
# Realistic pass over the existing map. Shared materials are edited in place, so the mesh
# batches and the spirit-world swap stay untouched. Colours are the ones the map builder uses.
const SURFACES := {
	"8c8a75": {"set": "worn_plaster_wall", "scale": 0.42, "tint": Color(0.86, 0.84, 0.74)},
	"21403b": {"set": "painted_concrete_02", "scale": 0.5, "tint": Color(0.30, 0.46, 0.42)},
	"304740": {"set": "painted_concrete_02", "scale": 0.5, "tint": Color(0.34, 0.44, 0.40)},
	"335738": {"set": "dirty_concrete", "scale": 0.4, "tint": Color(0.48, 0.62, 0.48)},
	"423021": {"set": "rough_wood", "scale": 0.7, "tint": Color(0.46, 0.34, 0.26)},
	"4d3621": {"set": "rough_wood", "scale": 0.7, "tint": Color(0.46, 0.34, 0.26)},
	"f3cca8": {"set": "rough_wood", "scale": 0.8, "tint": Color(0.58, 0.46, 0.36), "plain": true},
}
const TEXTURES := "res://assets/polyhaven_school/%s_%s_1k.jpg"

static func apply(world: Node3D) -> void:
	_tune_environment(world.get_node("Atmosphere/MoonlitEnvironment").environment)
	var done := {}
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		for material in _materials_of(node):
			if material != null and not done.has(material):
				done[material] = true
				_upgrade(material)
	_shape_flashlight(world.player.flashlight)
	_add_film_finish(world)

static func set_quality(environment: Environment, level: int) -> void:
	environment.ssao_enabled = level > 0
	environment.ssil_enabled = level > 1
	environment.volumetric_fog_enabled = level > 0

static func _tune_environment(environment: Environment) -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 5.0
	environment.ssao_enabled = true
	environment.ssao_radius = 1.3
	environment.ssao_intensity = 2.6
	environment.ssao_power = 1.8
	environment.ssil_enabled = false
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.78
	environment.adjustment_contrast = 1.12
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.016
	environment.volumetric_fog_albedo = Color(0.72, 0.76, 0.82)
	environment.volumetric_fog_length = 42.0
	environment.volumetric_fog_ambient_inject = 0.04
	environment.volumetric_fog_sky_affect = 0.0
	environment.ambient_light_energy = 0.5
	environment.tonemap_exposure = 1.5

static func _materials_of(node: GeometryInstance3D) -> Array:
	if node.material_override != null:
		return [node.material_override]
	var found := []
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		for surface in range(node.multimesh.mesh.get_surface_count()):
			found.append(node.multimesh.mesh.surface_get_material(surface))
	elif node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			found.append(node.get_active_material(surface))
	return found

static func _upgrade(material: Material) -> void:
	if material is ShaderMaterial:
		if material.shader != null and material.shader.resource_path.ends_with("ground.gdshader"):
			material.set_shader_parameter("detail_map", load(TEXTURES % ["dirty_concrete", "diff"]))
			material.set_shader_parameter("detail_normal", load(TEXTURES % ["dirty_concrete", "nor"]))
			material.set_shader_parameter("detail_scale", 0.35)
		return
	if not material is StandardMaterial3D:
		return
	var surface: Dictionary = SURFACES.get(material.albedo_color.to_html(false), {})
	if surface.is_empty():
		return
	material.albedo_color = surface.tint
	material.albedo_texture = load(TEXTURES % [surface.set, "diff"])
	material.normal_enabled = true
	material.normal_texture = load(TEXTURES % [surface.set, "nor"])
	material.normal_scale = 0.55
	material.roughness = 1.0
	material.roughness_texture = load(TEXTURES % [surface.set, "rough"])
	material.metallic = 0.0
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * surface.scale
	if surface.get("plain", false):
		material.emission_enabled = false

static func _shape_flashlight(light: SpotLight3D) -> void:
	# An uneven reflector pattern: bright core, weak ring, soft edge instead of a flat disc.
	var pattern := Gradient.new()
	pattern.offsets = PackedFloat32Array([0.0, 0.16, 0.34, 0.5, 0.72, 1.0])
	pattern.colors = PackedColorArray([Color(1, 1, 1), Color(0.88, 0.88, 0.88), Color(0.42, 0.42, 0.42), Color(0.5, 0.5, 0.5), Color(0.16, 0.16, 0.16), Color(0, 0, 0)])
	var cookie := GradientTexture2D.new()
	cookie.gradient = pattern
	cookie.fill = GradientTexture2D.FILL_RADIAL
	cookie.fill_from = Vector2(0.5, 0.5)
	cookie.fill_to = Vector2(1.0, 0.5)
	cookie.width = 256
	cookie.height = 256
	light.light_projector = cookie
	light.light_color = Color(1.0, 0.91, 0.76)
	light.light_energy = 7.0
	light.spot_angle = 33.0
	light.spot_range = 30.0
	light.spot_attenuation = 0.55
	light.spot_angle_attenuation = 1.3
	light.light_size = 0.04
	light.shadow_blur = 1.4
	light.light_volumetric_fog_energy = 0.7

static func _add_film_finish(world: Node3D) -> void:
	var layer := CanvasLayer.new()
	layer.name = "FilmFinish"
	layer.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/film_post.gdshader")
	rect.material = material
	layer.add_child(rect)
	world.add_child(layer)
