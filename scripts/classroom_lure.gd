extends Node3D

var world: Node3D
var story: Node3D
var panes: Array[ShaderMaterial] = []
var lamps: Array[Light3D] = []
var elapsed := 0.0
var normal_ambient := 0.0
var moon: DirectionalLight3D

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "ClassroomWindowLure"
	normal_ambient = world.normal_environment.ambient_light_energy
	moon = world.get_node("Atmosphere/Moonlight")
	# The room is behind an opaque corridor wall. Light its two courtyard-facing
	# frosted panes as well, keeping the existing sills, frames and mullions.
	for x in [13.5, 16.9]:
		var pane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.14, 1.32)
		pane.mesh = quad
		pane.position = Vector3(x, 1.9, 9.024)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/materials/classroom_lure.gdshader")
		pane.material_override = material
		panes.append(material)
		add_child(pane)
		var spill := SpotLight3D.new()
		spill.position = Vector3(x, 2.1, 9.25)
		spill.rotation_degrees = Vector3(-24, 180, 0)
		spill.light_color = Color(1.0, 0.68, 0.28)
		spill.light_energy = 3.5
		spill.spot_range = 17
		spill.spot_angle = 48
		spill.spot_attenuation = 0.7
		spill.shadow_enabled = true
		add_child(spill)
		lamps.append(spill)
	var hallway := OmniLight3D.new()
	hallway.position = Vector3(14.5, 2.5, 7.5)
	hallway.light_color = Color(1.0, 0.74, 0.36)
	hallway.light_energy = 2.0
	hallway.omni_range = 7
	hallway.shadow_enabled = true
	add_child(hallway)
	lamps.append(hallway)
	reset()

func reset() -> void:
	elapsed = 0
	for material in panes: material.set_shader_parameter("brightness", 1.0)

func _process(delta: float) -> void:
	# Dim the campus only during the investigation. Preserve the cinematic,
	# spirit realm, dawn and free preview lighting.
	var investigating: bool = world.survival.active and world.survival.phase == world.survival.Phase.PREPARATION and not story.briefing_complete
	world.normal_environment.ambient_light_energy = normal_ambient * (0.38 if investigating else 1.0)
	var baseline: float = world.light_defaults[moon][1]
	moon.light_energy = baseline * (0.60 if world.spirit_enabled else (0.40 if investigating else 1.0))
	visible = investigating and story.lure_light.visible
	if not visible or not world.simulation_active(): return
	elapsed += delta
	var shimmer := 0.94 + sin(elapsed * 8.5) * 0.025 + sin(elapsed * 19) * 0.015
	for material in panes: material.set_shader_parameter("brightness", shimmer)
	for i in range(lamps.size()): lamps[i].light_energy = (2.0 if i == 2 else 3.5) * shimmer
