extends RefCounted

# Keep school.tscn editable. Build a separate runtime scene with spatially
# partitioned instancing and compound static bodies, preserving every shape.
const CELL := 16.0
var groups := {}
var physics_groups := {}
var materials := {}
var material_ids := {}
var adapted_meshes := {}
var unit_box := BoxMesh.new()
const RealmRules = preload("res://scripts/realm_prop_rules.gd")

func canonical(mat: Material) -> Material:
	if mat == null or not mat is StandardMaterial3D:
		return mat
	var id := mat.get_instance_id()
	if material_ids.has(id):
		return material_ids[id]
	var signature := ""
	for property in mat.get_property_list():
		var key: String = property.name
		if property.usage & PROPERTY_USAGE_STORAGE and not key.begins_with("resource_") and key != "script":
			signature += key + "=" + str(mat.get(key)) + ";"
	if not materials.has(signature):
		materials[signature] = mat
	material_ids[id] = materials[signature]
	return materials[signature]

func cell_for(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x / CELL), floori(position.y / 3.9), floori(position.z / CELL))

func origin_for(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL, cell.y * 3.9, cell.z * CELL)

func dynamic(node: Node, school: Node) -> bool:
	var path := String(school.get_path_to(node))
	return path.begins_with("Player/") or path.begins_with("Architecture/ClassroomDoor") or path.begins_with("Campus/ServiceEntry/")

func optimize(school: Node3D) -> void:
	unit_box.size = Vector3.ONE
	var inverse := school.global_transform.affine_inverse()
	var meshes := school.find_children("*", "MeshInstance3D", true, false)
	var mesh_count := 0
	for node in meshes:
		if dynamic(node, school) or node.mesh == null:
			continue
		var mesh: Mesh = node.mesh
		var transform: Transform3D = inverse * node.global_transform
		var realm_transform: Transform3D = inverse * RealmRules.change_for(node, school) * node.global_transform
		var category: int = RealmRules.category_for(node, school)
		if node.material_override is ShaderMaterial:
			category = 0
		var override: Material = canonical(node.material_override)
		if mesh is BoxMesh:
			transform.basis = transform.basis.scaled_local(mesh.size)
			realm_transform.basis = realm_transform.basis.scaled_local(mesh.size)
			mesh = unit_box
		else:
			var overrides: Array[Material] = []
			var mesh_key := str(mesh.get_instance_id())
			var adapted := false
			for surface in range(mesh.get_surface_count()):
				var mat: Material = canonical(node.get_surface_override_material(surface))
				overrides.append(mat)
				mesh_key += "/" + str(mat.get_instance_id() if mat != null else 0)
				adapted = adapted or mat != null
			if adapted and mesh is ArrayMesh:
				if not adapted_meshes.has(mesh_key):
					var copy: ArrayMesh = mesh.duplicate()
					for surface in range(overrides.size()):
						if overrides[surface] != null:
							copy.surface_set_material(surface, overrides[surface])
					adapted_meshes[mesh_key] = copy
				mesh = adapted_meshes[mesh_key]
		var cell := cell_for(transform.origin)
		transform.origin -= origin_for(cell)
		realm_transform.origin -= origin_for(cell)
		var key := "%s/%d/%d/%d/%d" % [cell, mesh.get_instance_id(), override.get_instance_id() if override != null else 0, node.cast_shadow, category]
		if not groups.has(key):
			groups[key] = {"cell": cell, "mesh": mesh, "material": override, "shadow": node.cast_shadow, "category": category, "transforms": [], "realm_transforms": [], "moved": false}
		groups[key].transforms.append(transform)
		groups[key].realm_transforms.append(realm_transform)
		groups[key].moved = groups[key].moved or not transform.is_equal_approx(realm_transform)
		mesh_count += 1
	# Batch static physics; window bodies stay separate for transparent sightline
	# queries. Moving doors retain their own AnimatableBody and interaction area.
	var bodies := school.find_children("*", "StaticBody3D", true, false)
	var body_count := 0
	for body in bodies:
		if body.has_meta("transparent_window") or dynamic(body, school):
			continue
		var cell := cell_for((inverse * body.global_transform).origin)
		var key := "%s/%d/%d" % [cell, body.collision_layer, body.collision_mask]
		if not physics_groups.has(key):
			physics_groups[key] = {"cell": cell, "layer": body.collision_layer, "mask": body.collision_mask, "shapes": []}
		for collision in body.get_children():
			if collision is CollisionShape3D and collision.shape != null and not collision.disabled:
				var transform: Transform3D = inverse * collision.global_transform
				var realm_transform: Transform3D = inverse * RealmRules.change_for(collision, school) * collision.global_transform
				transform.origin -= origin_for(cell)
				realm_transform.origin -= origin_for(cell)
				physics_groups[key].shapes.append({"shape": collision.shape, "transform": transform, "realm_transform": realm_transform})
		body_count += 1
	for node in meshes:
		if is_instance_valid(node) and not dynamic(node, school):
			node.free()
	for body in bodies:
		if is_instance_valid(body) and not body.has_meta("transparent_window") and not dynamic(body, school):
			body.free()
	for container_name in ["Furniture", "Landscape"]:
		for pivot in school.get_node(container_name).get_children():
			if pivot.has_node("Model"):
				var model: Node = pivot.get_node("Model")
				pivot.set_meta("source_asset", model.scene_file_path if not model.scene_file_path.is_empty() else model.get_meta("source_asset", ""))
				model.free()
	for container_name in ["Architecture", "Atmosphere", "Campus"]:
		for child in school.get_node(container_name).get_children():
			if child is Node3D and child.get_child_count() == 0 and child.get_script() == null and not child is VisualInstance3D and not child is WorldEnvironment:
				child.free()
	var visuals := Node3D.new()
	visuals.name = "RuntimeGeometry"
	school.add_child(visuals)
	visuals.owner = school
	for group in groups.values():
		var instances: MultiMesh = preload("res://scripts/static_multimesh.gd").new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = group.mesh
		var placements: Array[Transform3D] = []
		placements.assign(group.transforms)
		instances.placements = placements
		var bounds := AABB()
		for index in range(group.transforms.size()):
			var part: AABB = group.transforms[index] * group.mesh.get_aabb()
			bounds = part if index == 0 else bounds.merge(part)
			bounds = bounds.merge(group.realm_transforms[index] * group.mesh.get_aabb())
		instances.custom_aabb = bounds
		var node := MultiMeshInstance3D.new()
		node.name = "Batch_%04d" % visuals.get_child_count()
		node.multimesh = instances
		node.material_override = group.material
		node.cast_shadow = group.shadow
		node.position = origin_for(group.cell)
		node.set_meta("realm_category", group.category)
		if group.moved:
			var realm_placements: Array[Transform3D] = []
			realm_placements.assign(group.realm_transforms)
			node.set_meta("realm_placements", realm_placements)
		visuals.add_child(node)
		node.owner = school
	var physics: Node3D = school.get_node("Architecture")
	for group in physics_groups.values():
		var body := StaticBody3D.new()
		body.name = "PhysicsChunk_%04d" % physics.get_child_count()
		body.position = origin_for(group.cell)
		body.collision_layer = group.layer
		body.collision_mask = group.mask
		physics.add_child(body)
		body.owner = school
		for part in group.shapes:
			var shape := CollisionShape3D.new()
			shape.shape = part.shape
			shape.transform = part.transform
			if not part.transform.is_equal_approx(part.realm_transform):
				shape.set_meta("normal_transform", part.transform)
				shape.set_meta("realm_transform", part.realm_transform)
			body.add_child(shape)
			shape.owner = school
	school.set_meta("runtime_optimized", true)
	school.set_meta("optimization_stats", {"source_meshes": mesh_count, "batches": groups.size(), "source_bodies": body_count, "physics_chunks": physics_groups.size()})
	print("Optimized meshes %d → %d batches; bodies %d → %d chunks" % [mesh_count, groups.size(), body_count, physics_groups.size()])

static func save_runtime(school: Node3D) -> void:
	var optimizer: RefCounted = load("res://tools/runtime_optimizer.gd").new()
	optimizer.optimize(school)
	var packed := PackedScene.new()
	assert(packed.pack(school) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/school_runtime.tscn") == OK)
