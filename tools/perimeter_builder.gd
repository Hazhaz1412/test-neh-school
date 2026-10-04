extends RefCounted

static func part(parent: Node3D, school: Node3D, label: String, position: Vector3, size: Vector3, material: Material, solid := false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = position
	parent.add_child(node)
	node.owner = school
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	node.add_child(mesh)
	mesh.owner = school
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
		collision.owner = school
	return node

static func build(school: Node3D) -> void:
	var campus: Node3D = school.get_node("Campus")
	for child in campus.get_children():
		for prefix in ["BoundaryWall", "FrontBoundary", "BackBoundary", "RearSideBoundary", "FencePost", "FenceTopRail", "RearFence", "GatePillar", "ClosedCampusGate", "Heritage", "ServiceEntry"]:
			if String(child.name).begins_with(prefix):
				child.free()
				break
	var stucco := StandardMaterial3D.new()
	stucco.albedo_color = Color(0.55, 0.53, 0.47)
	stucco.albedo_texture = preload("res://assets/polyhaven_horror/concrete_wall_003_diff_1k.jpg")
	stucco.uv1_triplanar = true
	stucco.uv1_world_triplanar = true
	stucco.uv1_scale = Vector3.ONE * 0.35
	stucco.roughness = 1
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.25, 0.24)
	stone.roughness = 0.98
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.065, 0.085, 0.087)
	iron.roughness = 0.88
	for side in [-1, 1]:
		part(campus, school, "HeritageSideWall", Vector3(side * 58, 1.8, -2), Vector3(0.5, 3.6, 160), stucco, true)
		part(campus, school, "HeritageSideCap", Vector3(side * 58, 3.63, -2), Vector3(0.68, 0.20, 160), stone)
		for z in range(-82, 79, 10):
			part(campus, school, "HeritageSideButtress", Vector3(side * 58, 1.9, z), Vector3(0.80, 3.8, 0.72), stone)
	part(campus, school, "HeritageRearWall", Vector3(0, 1.8, -82), Vector3(116, 3.6, 0.5), stucco, true)
	part(campus, school, "HeritageRearCap", Vector3(0, 3.63, -82), Vector3(116, 0.20, 0.68), stone)
	# Main gate at x=0 stays locked. A separate 1.8 m maintenance opening is x=12.
	for span in [Vector2(-58, -3), Vector2(3, 11.1), Vector2(12.9, 58)]:
		var center: float = (span.x + span.y) / 2
		var length: float = span.y - span.x
		part(campus, school, "HeritageFrontWall", Vector3(center, 1.8, 78), Vector3(length, 3.6, 0.5), stucco, true)
		part(campus, school, "HeritageFrontCap", Vector3(center, 3.63, 78), Vector3(length, 0.20, 0.68), stone)
		part(campus, school, "HeritageFrontPlinth", Vector3(center, 0.28, 78), Vector3(length, 0.55, 0.64), stone)
	for x in [-54, -44, -34, -24, -14, 22, 32, 42, 52]:
		part(campus, school, "HeritageFrontButtress", Vector3(x, 1.9, 78), Vector3(0.75, 3.8, 0.75), stone)
	for x in [-3.3, 3.3]:
		part(campus, school, "HeritageGatePillar", Vector3(x, 2.2, 78), Vector3(0.8, 4.4, 0.9), stucco, true)
		part(campus, school, "HeritagePillarCrown", Vector3(x, 4.43, 78), Vector3(1.0, 0.2, 1.1), stone)
	var gate := StaticBody3D.new()
	gate.name = "ClosedCampusGate"
	gate.position = Vector3(0, 1.75, 78)
	campus.add_child(gate)
	gate.owner = school
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 3.5, 0.20)
	collision.shape = shape
	gate.add_child(collision)
	collision.owner = school
	for x in range(-14, 15):
		part(gate, school, "HeritageGateBar", Vector3(x * 0.20, 0, 0), Vector3(0.045, 3.5, 0.08), iron)
	for y in [-1.6, -0.7, 0.7, 1.6]:
		part(gate, school, "HeritageGateRail", Vector3(0, y, 0), Vector3(6, 0.075, 0.09), iron)
	part(campus, school, "HeritageGateLintel", Vector3(0, 4.0, 78), Vector3(6.0, 0.35, 0.48), stone)
	var nameplate := Label3D.new()
	nameplate.name = "HeritageSchoolName"
	nameplate.text = "TRƯỜNG NEH"
	nameplate.position = Vector3(0, 4.0, 78.26)
	nameplate.font_size = 48
	nameplate.pixel_size = 0.005
	nameplate.outline_size = 0
	nameplate.modulate = Color(0.76, 0.72, 0.57)
	campus.add_child(nameplate)
	nameplate.owner = school
	part(campus, school, "HeritageServiceHeader", Vector3(12, 3.3, 78), Vector3(1.8, 0.6, 0.5), stucco, true)
	var door := Node3D.new()
	door.name = "ServiceEntry"
	door.position = Vector3(11.1, 0, 78)
	campus.add_child(door)
	door.owner = school
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	door.add_child(hinge)
	hinge.owner = school
	var leaf := AnimatableBody3D.new()
	leaf.name = "Leaf"
	leaf.collision_layer = 4
	leaf.collision_mask = 3
	hinge.add_child(leaf)
	leaf.owner = school
	var rusty := iron.duplicate()
	rusty.albedo_texture = stucco.albedo_texture
	rusty.albedo_color = Color(0.25, 0.18, 0.12)
	rusty.uv1_triplanar = true
	part(leaf, school, "Panel", Vector3(0.90, 1.50, 0), Vector3(1.76, 3.0, 0.14), rusty)
	var latch := StandardMaterial3D.new()
	latch.albedo_color = Color(0.36, 0.22, 0.12)
	latch.roughness = 1
	part(leaf, school, "Padlock", Vector3(1.62, 1.1, 0.11), Vector3(0.14, 0.20, 0.09), latch)
	var door_collision := CollisionShape3D.new()
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(1.76, 3, 0.18)
	door_collision.shape = door_shape
	door_collision.position = Vector3(0.9, 1.5, 0)
	leaf.add_child(door_collision)
	door_collision.owner = school
	door.set_script(preload("res://scripts/service_entry.gd"))
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var target := CollisionShape3D.new()
	var target_shape := BoxShape3D.new()
	target_shape.size = Vector3(1.6, 2.8, 0.4)
	target.shape = target_shape
	target.position = Vector3(0.9, 1.4, 0)
	area.add_child(target)
	door.add_child(area)
	area.owner = school
	target.owner = school
