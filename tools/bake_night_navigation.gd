extends SceneTree
# Bakes the walkable map over campus_fixes.gd without touching the school scenes.
# godot --headless --path . --script tools/bake_night_navigation.gd
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(10):
		await physics_frame
	for body in school.get_node("HidingSpots").find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 1
	for shape in school.get_node("HidingSpots").find_children("*", "CollisionShape3D", true, false):
		shape.disabled = false
	preload("res://tools/navigation_builder.gd").bake(school, "res://scenes/night_navigation.tres")
	quit()
