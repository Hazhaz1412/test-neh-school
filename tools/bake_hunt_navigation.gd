extends SceneTree
# Finer than the school-wide map: 0.375 m of real clearance round every wall end, and a
# 1.3 m classroom door still leaves a 0.55 m lane.
const CELL := 0.125
const RADIUS := 0.375
# Real stair treads are ~0.16 m; at 0.5 the flights were joined to the floor along their low sides.
const CELL_HEIGHT := 0.125
const CLIMB := 0.3
# Bakes Night 1's walkable map: the night map plus the kiting walls of scripts/kiting_course.gd.
# godot --headless --path . --script tools/bake_hunt_navigation.gd
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(10):
		await physics_frame
	# After the physics frames: the loops find the floor by raycast.
	preload("res://scripts/kiting_course.gd").build(school, false)
	for i in range(3):
		await physics_frame
	for body in school.get_node("HidingSpots").find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 1
	for shape in school.get_node("HidingSpots").find_children("*", "CollisionShape3D", true, false):
		shape.disabled = false
	var map: RID = school.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)
	preload("res://tools/navigation_builder.gd").bake(school, "res://scenes/hunt_navigation.tres", CELL, RADIUS, CELL_HEIGHT, CLIMB)
	quit()
