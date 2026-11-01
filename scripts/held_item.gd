extends Node3D

var player: CharacterBody3D
var models := {}
var shown_kind := ""
var equip := 0.0
const TORCH_SCALE := 0.62
const TORCH_ROTATION := Vector3(0.05, PI, 0.0)
const TORCH_OFFSET := Vector3(0.0, 0.09, 0.0)
# The beam starts inside the held torch, which must not catch its own light.
const HELD_LAYER := 1 << 19

static func camera_model() -> Node3D:
	var pivot := Node3D.new()
	var source: Node3D = preload("res://assets/models/camera/camera.glb").instantiate()
	source.scale = Vector3.ONE * 0.068
	source.position.y = -0.129
	source.rotation.y = PI
	pivot.add_child(source)
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pivot

static func torch_model() -> Node3D:
	var pivot := Node3D.new()
	var source: Node3D = preload("res://assets/polyhaven_torch/pastic_torch_6v_1k.gltf").instantiate()
	source.scale = Vector3.ONE * TORCH_SCALE
	source.rotation = TORCH_ROTATION
	source.position = TORCH_OFFSET
	pivot.add_child(source)
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = HELD_LAYER
	return pivot

static func prop(kind: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = {"battery": Color(0.68, 0.57, 0.22), "medicine": Color(0.48, 0.66, 0.56), "chalk": Color(0.80, 0.80, 0.73), "salt_gun": Color(0.34, 0.30, 0.26), "medal": Color(0.86, 0.68, 0.24)}[kind]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "medicine":
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.14, 0.12)
		visual.mesh = mesh
	else:
		var mesh := CylinderMesh.new()
		mesh.height = {"battery": 0.10, "chalk": 0.12, "salt_gun": 0.34, "medal": 0.012}[kind]
		mesh.top_radius = {"battery": 0.021, "chalk": 0.009, "salt_gun": 0.034, "medal": 0.05}[kind]
		mesh.bottom_radius = mesh.top_radius
		mesh.radial_segments = 12
		visual.mesh = mesh
		visual.rotation.x = -0.35
	return visual

func _ready() -> void:
	position = Vector3(0.25, -0.27, -0.52)
	models["camera"] = camera_model()
	models["camera"].rotation.y = -0.28
	models["torch"] = torch_model()
	player.flashlight.light_cull_mask &= ~HELD_LAYER
	for kind in ["battery", "medicine", "chalk", "salt_gun", "medal"]:
		models[kind] = prop(kind)
	for model in models.values():
		add_child(model)
		model.hide()
	# Keep an equipped camera readable without adding a realtime light.
	for mesh in models["camera"].find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D = original.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(surface, material)

func _process(delta: float) -> void:
	var world: Node3D = player.get_parent()
	if world.get("survival") == null:
		hide()
		return
	visible = player.enabled and not player.seized and player.health > 0 and not player.combat.busy() and not player.is_hidden() and not world.survival.opening.playing and not world.survival.finished
	var kind: String = player.selected_item()
	if kind != shown_kind:
		shown_kind = kind
		equip = 1.0
		for item in models:
			models[item].visible = item == kind
	if not world.simulation_active():
		return
	equip = maxf(0, equip - delta * 7)
	var recoil: float = world.camera_flash.intensity if kind == "camera" else 0.0
	position = Vector3(0.25, -0.27 - equip * 0.18 - recoil * 0.035, -0.52 + recoil * 0.06)
	var charge: float = player.chalk_charge_fraction() if kind == "chalk" and player.chalk_charging else 0.0
	position += Vector3(0.03, -0.02, 0.10) * charge
	rotation.x = -charge * 0.45
	rotation.z = sin(player.step_time) * player.velocity.length() * 0.003
