extends SceneTree

func _initialize() -> void:
	call_deferred("optimize")

func optimize() -> void:
	var school: Node3D = load("res://scenes/school.tscn").instantiate()
	var script: Script = school.get_script()
	var settings := {}
	for property in school.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			settings[property.name] = school.get(property.name)
	school.set_script(null)
	root.add_child(school)
	school.set_script(script)
	for key in settings:
		school.set(key, settings[key])
	preload("res://tools/runtime_optimizer.gd").save_runtime(school)
	quit()
