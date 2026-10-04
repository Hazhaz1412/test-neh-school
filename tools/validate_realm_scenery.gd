extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func validate() -> void:
	var school: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.player.set_physics_process(false)
	await frames(30)
	var normal_shapes := {}
	var normal_materials := {}
	var count_before: int = school.realm_scenery.decor.get_child_count()
	for shape in school.realm_scenery.shapes:
		normal_shapes[shape] = shape.transform
	for entry in school.realm_scenery.visuals:
		normal_materials[entry.node] = entry.node.material_override
	check(not school.realm_scenery.decor.visible and normal_shapes.size() > 100, "Normal world hides manifestations and retains furniture physics")
	var sample: CollisionShape3D
	for shape in school.realm_scenery.shapes:
		if shape.global_position.y < 0.7:
			sample = shape
			break
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.06
	query.shape = box
	query.transform = Transform3D(Basis(), sample.global_position)
	query.collision_mask = 1
	query.exclude = [school.player.get_rid()]
	check(not school.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Normal chair has a real collider at its original location")
	school.set_spirit_world(true)
	school.player.enabled = false
	await frames(3)
	check(school.realm_scenery.moved_instances > 100, "B physically transforms existing desks, chairs and books")
	check(school.realm_scenery.decor.visible and school.realm_scenery.decor.has_node("CreepingRoots") and school.realm_scenery.decor.has_node("Handprints"), "B reveals roots and handprints in the actual scenery")
	check(sample.global_position.y > 2.0 and school.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "The lifted chair's collider follows it; no invisible obstacle remains below")
	var materials_changed := true
	for entry in school.realm_scenery.visuals:
		materials_changed = materials_changed and entry.node.material_override == entry.cursed
		if entry.node is MultiMeshInstance3D and not entry.placements.is_empty() and DisplayServer.get_name() != "headless":
			for i in range(entry.placements.size()):
				materials_changed = materials_changed and entry.node.multimesh.get_instance_transform(i).is_equal_approx(entry.placements[i])
	check(materials_changed, "Corruption changes scene materials and restores every realm placement to the GPU")
	check(not school.has_master_key and school.get_node("Architecture/ClassroomDoor107").is_locked(), "B cannot bypass the master-key gate")
	check(not school.get_node("Architecture/ClassroomDoor990").is_locked(), "Warehouse remains usable in the spirit world")
	# Stand under a floating chair before restoring its normal collider.
	school.player.position = Vector3(query.transform.origin.x, 0.05, query.transform.origin.z)
	var under_chair: Vector3 = school.player.position
	for i in range(4):
		school.set_spirit_world(false)
		await frames(3)
		var restored := true
		for shape in normal_shapes:
			restored = restored and shape.transform.is_equal_approx(normal_shapes[shape])
		for node in normal_materials:
			restored = restored and node.material_override == normal_materials[node]
			if node is MultiMeshInstance3D and DisplayServer.get_name() != "headless":
				for j in range(node.multimesh.placements.size()):
					restored = restored and node.multimesh.get_instance_transform(j).is_equal_approx(node.multimesh.placements[j])
		check(restored and not school.realm_scenery.decor.visible, "Toggle %d restores normal materials, visuals and physical furniture exactly" % (i + 1))
		if i == 0:
			check(school.player.position.distance_to(under_chair) > 0.2 and absf(school.player.position.y - under_chair.y) < 0.1, "Returning while under suspended furniture moves the player to nearby clear floor")
		school.set_spirit_world(true)
		school.player.enabled = false
		await frames(3)
	check(school.realm_scenery.decor.get_child_count() == count_before, "Repeated realm toggles do not allocate duplicate scenery")
	school.set_spirit_world(false)
	print("Realm scenery validation failures: ", failures)
	quit(0 if failures == 0 else 1)
