extends SceneTree

func _initialize() -> void:
	call_deferred("update")

func update() -> void:
	var school: Node3D = load("res://scenes/school.tscn").instantiate()
	var script: Script = school.get_script()
	var settings := {}
	for property in school.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			settings[property.name] = school.get(property.name)
	var original_mode := school.process_mode
	school.process_mode = Node.PROCESS_MODE_DISABLED
	school.set_script(null)
	root.add_child(school)
	preload("res://tools/perimeter_builder.gd").build(school)
	preload("res://tools/navigation_builder.gd").bake(school)
	school.set_script(script)
	for key in settings:
		school.set(key, settings[key])
	school.process_mode = original_mode
	var packed := PackedScene.new()
	assert(packed.pack(school) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/school.tscn") == OK)
	preload("res://tools/runtime_optimizer.gd").save_runtime(school)
	print("Updated perimeter without rebuilding classrooms, furniture or gardens.")
	school.queue_free()
	for i in range(3):
		await process_frame
	quit()
