extends Node3D

var player: CharacterBody3D
var models := {}
var shown_kind := ""
var equip := 0.0

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

static func prop(kind: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = {"torch": Color(0.16, 0.20, 0.19), "battery": Color(0.68, 0.57, 0.22), "medicine": Color(0.48, 0.66, 0.56), "chalk": Color(0.80, 0.80, 0.73)}[kind]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "medicine":
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.14, 0.12)
		visual.mesh = mesh
	else:
		var mesh := CylinderMesh.new()
		mesh.height = {"torch": 0.28, "battery": 0.10, "chalk": 0.12}[kind]
		mesh.top_radius = {"torch": 0.055, "battery": 0.021, "chalk": 0.009}[kind]
		mesh.bottom_radius = mesh.top_radius * (0.6 if kind == "torch" else 1.0)
		mesh.radial_segments = 12
		visual.mesh = mesh
		visual.rotation.x = PI / 2 if kind == "torch" else -0.35
	return visual

func _ready() -> void:
	position = Vector3(0.25, -0.27, -0.52)
	models["camera"] = camera_model()
	models["camera"].rotation.y = -0.28
	for kind in ["torch", "battery", "medicine", "chalk"]:
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
	visible = player.enabled and player.health > 0 and not player.combat.busy() and not player.is_hidden() and not world.survival.opening.playing and not world.survival.finished
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
