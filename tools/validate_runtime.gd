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

func rounded(transform: Transform3D) -> String:
	var result := ""
	for vector in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
		for axis in range(3):
			result += str(snappedf(vector[axis], 0.001)) + ","
	return result

func visual_key(transform: Transform3D, mesh: Mesh) -> String:
	if mesh is BoxMesh:
		transform.basis = transform.basis.scaled_local(mesh.size)
	return mesh.get_class() + "/" + rounded(transform)

func add_key(catalog: Dictionary, key: String) -> void:
	catalog[key] = catalog.get(key, 0) + 1

func gameplay_visual(node: Node, scene: Node) -> bool:
	var path := String(scene.get_path_to(node))
	return path.begins_with("MasterKey/") or path.begins_with("RealmScenery/") or path.begins_with("SurvivalSystems/") or path.begins_with("Player/Camera3D/HeldItem/")

func visual_catalog(scene: Node3D) -> Dictionary:
	var catalog := {}
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		if gameplay_visual(mesh, scene):
			continue
		if mesh.mesh != null:
			add_key(catalog, visual_key(mesh.global_transform, mesh.mesh))
	for batch in scene.find_children("*", "MultiMeshInstance3D", true, false):
		if gameplay_visual(batch, scene):
			continue
		# Read persisted data, independent of the dummy renderer's GPU buffers.
		var placements: Array[Transform3D] = batch.multimesh.placements
		if placements.size() != batch.multimesh.instance_count:
			check(false, "Batch %s retains all placements after scene reload" % batch.name)
		for index in range(placements.size()):
			var placement := placements[index]
			if DisplayServer.get_name() != "headless" and not batch.multimesh.get_instance_transform(index).is_equal_approx(placement):
				check(false, "Batch %s restores GPU transform %d" % [batch.name, index])
			add_key(catalog, visual_key(batch.global_transform * placement, batch.multimesh.mesh))
	return catalog

func collision_catalog(scene: Node3D) -> Dictionary:
	var catalog := {}
	for node in scene.find_children("*", "CollisionShape3D", true, false):
		if gameplay_visual(node, scene):
			continue
		if node.shape == null or node.disabled:
			continue
		var size := ""
		for property in node.shape.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and not String(property.name).begins_with("resource_") and property.name != "script":
				size += property.name + "=" + str(node.shape.get(property.name))
		add_key(catalog, "%s/%s/%s/%d/%d" % [node.shape.get_class(), size, rounded(node.global_transform), node.get_parent().collision_layer, node.get_parent().collision_mask])
	return catalog

func validate() -> void:
	var source: Node3D = load("res://scenes/school.tscn").instantiate()
	source.set_script(null)
	root.add_child(source)
	source.get_node("Player").set_physics_process(false)
	var runtime: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(runtime)
	runtime.set_process_unhandled_input(false)
	runtime.player.set_physics_process(false)
	check(runtime.has_meta("runtime_optimized"), "F5 starts the optimized runtime scene")
	check(visual_catalog(source) == visual_catalog(runtime), "All source meshes retain their world placements and dimensions after reload")
	check(collision_catalog(source) == collision_catalog(runtime), "All source collision shapes retain their geometry, transforms and layers")
	check(source.get_meta("room_catalog") == runtime.get_meta("room_catalog"), "Room catalog survives optimization")
	for level in range(3):
		runtime.set_quality(level, false)
		var visible := 0
		for light in runtime.local_lights:
			if light.visible:
				visible += 1
		check(visible == [8, 12, 24][level], "Quality %d activates its light budget" % level)
		check(runtime.player.flashlight.shadow_enabled == (level > 0), "Quality %d applies flashlight shadow settings" % level)
	runtime.set_quality(1, false)
	runtime.player.position = Vector3(-21, 0.05, -52)
	runtime._update_light_budget()
	var closest: OmniLight3D
	var distance := INF
	for light in runtime.local_lights:
		var d: float = light.global_position.distance_squared_to(runtime.player.position)
		if d < distance:
			closest = light
			distance = d
	check(closest.visible, "Teleporting to B keeps the nearest light enabled")
	var key := InputEventKey.new()
	key.keycode = KEY_F7
	key.pressed = true
	runtime._unhandled_input(key)
	check(runtime.performance_label.visible, "F7 enables the performance display")
	runtime._unhandled_input(key)
	check(not runtime.performance_label.visible, "F7 hides the performance display")
	print("Runtime validation failures: ", failures)
	quit(0 if failures == 0 else 1)
