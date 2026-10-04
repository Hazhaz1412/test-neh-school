extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var school: Node3D = load("res://scenes/school.tscn").instantiate()
	var world_script: Script = school.get_script()
	var exported_settings := {}
	for property in school.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			exported_settings[property.name] = school.get(property.name)
	# Bake without starting the HUD or spirit-world gameplay.
	school.set_script(null)
	school.get_node("Player").set_script(null)
	root.add_child(school)
	preload("res://tools/navigation_builder.gd").bake(school)
	school.set_script(world_script)
	for key in exported_settings:
		school.set(key, exported_settings[key])
	school.get_node("Player").set_script(load("res://scripts/player.gd"))
	var scene := PackedScene.new()
	assert(scene.pack(school) == OK)
	assert(ResourceSaver.save(scene, "res://scenes/school.tscn") == OK)
	preload("res://tools/runtime_optimizer.gd").save_runtime(school)
	quit()
