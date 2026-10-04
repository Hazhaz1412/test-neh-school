extends Node3D

var world: Node3D
var collected := false

func _ready() -> void:
	name = "MasterKey"
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.82, 0.62, 0.23)
	gold.metallic = 0.65
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(0.5, 0.27, 0.06)
	gold.emission_energy_multiplier = 0.45
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.075
	ring.rings = 12
	ring.ring_segments = 8
	mesh_part(ring, Vector3(-0.16, 0.02, 0), gold)
	for data in [[Vector3(0.01, 0.02, 0), Vector3(0.28, 0.035, 0.035)], [Vector3(0.13, 0.02, 0.045), Vector3(0.035, 0.035, 0.11)], [Vector3(0.08, 0.02, 0.04), Vector3(0.03, 0.035, 0.09)]]:
		var box := BoxMesh.new()
		box.size = data[1]
		mesh_part(box, data[0], gold)
	var tag := Label3D.new()
	tag.text = "MASTER / 総鍵"
	tag.font_size = 24
	tag.pixel_size = 0.0025
	tag.position = Vector3(0, 0.20, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.91, 0.80, 0.50)
	add_child(tag)
	tag.hide()
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 0.32, 0.50)
	shape.shape = box
	shape.position.y = 0.10
	area.add_child(shape)
	add_child(area)

func mesh_part(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	add_child(node)

func interaction_text() -> String:
	return "E · Chìa tổng"

func interact(actor: CharacterBody3D) -> bool:
	if collected or not world.simulation_active() or actor != world.player or actor.get_interaction_target() != self:
		return false
	collected = true
	world.collect_master_key()
	hide()
	$Interaction.collision_layer = 0
	return true
