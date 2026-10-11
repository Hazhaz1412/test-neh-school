extends Node3D

var story: Node3D
var kind := "bear"
var index := 0
var caption := ""
var visual: Node3D

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	if kind == "lan":
		var actor := preload("res://scripts/humanoid_model.gd").new()
		actor.variant = "Casual_Female"
		actor.target_height = 1.68
		actor.shirt_color = Color(0.38, 0.29, 0.48)
		visual.add_child(actor)
	elif kind == "bear":
		_build_bear()
	else:
		_build_clubs()
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 1.65, 0.65) if kind == "lan" else Vector3(0.9, 0.8, 0.85)
	collider.shape = shape
	collider.position.y = 0.85 if kind == "lan" else 0.3
	area.add_child(collider)
	add_child(area)

func sphere(pos: Vector3, scale_by: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 16
	mesh.rings = 8
	part.mesh = mesh
	part.position = pos
	part.scale = scale_by
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1
	part.material_override = mat
	visual.add_child(part)

func _build_bear() -> void:
	var fur := Color(0.42, 0.25, 0.13)
	var muzzle := Color(0.74, 0.56, 0.35)
	sphere(Vector3(0, 0.30, 0), Vector3(0.36, 0.44, 0.29), fur)
	sphere(Vector3(0, 0.63, 0), Vector3(0.38, 0.34, 0.30), fur)
	for side in [-1, 1]:
		sphere(Vector3(side * 0.17, 0.79, 0), Vector3(0.14, 0.15, 0.09), fur)
		sphere(Vector3(side * 0.23, 0.34, 0.015), Vector3(0.15, 0.29, 0.17), fur)
		sphere(Vector3(side * 0.13, 0.09, 0.12), Vector3(0.19, 0.17, 0.24), fur)
		sphere(Vector3(side * 0.075, 0.68, 0.14), Vector3(0.025, 0.028, 0.015), Color(0.03, 0.025, 0.02))
	sphere(Vector3(0, 0.57, 0.14), Vector3(0.22, 0.13, 0.11), muzzle)
	sphere(Vector3(0, 0.60, 0.193), Vector3(0.04, 0.027, 0.015), Color(0.035, 0.025, 0.02))
	sphere(Vector3(0, 0.33, 0.12), Vector3(0.23, 0.29, 0.08), muzzle)

func _build_clubs() -> void:
	for i in range(3):
		var pivot := Node3D.new()
		pivot.position = Vector3((i-1)*0.24, 0.07, (i-1)*0.08)
		pivot.rotation = Vector3(PI/2, 0, -0.25 + i*0.22)
		visual.add_child(pivot)
		for patch in range(5):
			var part := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.04 + patch*0.003
			mesh.bottom_radius = mesh.top_radius
			mesh.height = 0.22
			mesh.radial_segments = 10
			part.mesh = mesh
			part.position.y = (patch-2)*0.22
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.24, 0.025, 0.018) if patch >= 2 else Color(0.32, 0.20, 0.10)
			part.material_override = mat
			pivot.add_child(part)

func set_available(value: bool) -> void:
	visible = value
	$Interaction.collision_layer = 16 if value else 0

func interaction_text() -> String:
	return "E · Lan" if kind == "lan" else ("E · Nhặt gấu bông" if kind == "bear" else "E · Kiểm tra gậy dính máu")

func interact(actor: CharacterBody3D) -> bool:
	if actor != story.world.player or not story.world.simulation_active() or actor.get_interaction_target() != self:
		return false
	return story.interact_with(self)
