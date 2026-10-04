extends Node3D

var quest: Node3D
var model: Node3D
var released := false
static var appearance_materials: Array[Material] = []

func _ready() -> void:
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "Casual_Female"
	model.target_height = 1.48
	model.shirt_color = Color(0.25, 0.36, 0.38)
	add_child(model)
	model.head_pitch = 0.27
	var body: MeshInstance3D = model.visual.find_child("Body2", true, false)
	if appearance_materials.is_empty():
		for surface in range(body.mesh.get_surface_count()):
			var material: StandardMaterial3D = body.get_active_material(surface).duplicate()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = material.albedo_color.lerp(Color(0.48, 0.69, 0.72), 0.45)
			material.albedo_color.a = 0.88
			material.emission_enabled = true
			material.emission = Color(0.28, 0.55, 0.58) * 0.65
			appearance_materials.append(material)
	for surface in range(body.mesh.get_surface_count()):
		body.set_surface_override_material(surface, appearance_materials[surface])
	# A small spectral marker is visible without consuming a realtime light.
	var halo := MeshInstance3D.new()
	halo.name = "SoulHalo"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.39
	ring.outer_radius = 0.44
	ring.rings = 16
	ring.ring_segments = 8
	halo.mesh = ring
	halo.position.y = 0.025
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.42, 0.80, 0.82)
	halo.material_override = glow
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.50
	shape.radius = 0.30
	collider.shape = shape
	collider.position.y = 0.78
	area.add_child(collider)
	add_child(area)
	hide()

func interaction_text() -> String:
	return "E · An" if quest.found.size() == 4 else "E · Ký ức còn thiếu"

func interact(actor: CharacterBody3D) -> bool:
	return quest.begin_comfort(actor)

func _process(_delta: float) -> void:
	var director: Node3D = quest.world.survival
	# B previews the spirit world outside a run; An should be locatable there too.
	visible = not released and quest.world.spirit_enabled and not director.finished and (not director.active or director.phase == director.Phase.NIGHT)
	$Interaction.collision_layer = 16 if visible else 0
	model.position.y = sin(quest.world.elapsed * 1.4) * 0.025
	model.head_pitch = 0.27 * (1 - float(quest.accepted.size()) / 4)
