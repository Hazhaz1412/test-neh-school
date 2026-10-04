extends SceneTree

var school: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(35):
		await physics_frame
	# Fixture: these tests exercise unlocked map geometry, not quest progression.
	school.progression.bypass_for_test()
	school.player.enabled = false
	school.player.set_physics_process(false)
	for door in get_nodes_in_group("classroom_doors"):
		door.is_open = true
		door.slide = 1.0
		door.leaf.position.x = door.slide_distance
	await physics_frame
	await physics_frame
	var rooms: Array = school.get_meta("room_catalog")
	var kinds := {}
	var layouts := {}
	var counts := {"A": 0, "B": 0, "SERVICE": 0}
	for room in rooms:
		kinds[room.kind] = true
		counts[room.block] += 1
		if room.kind == "classroom":
			layouts[room.layout] = true
			check(room.size.x * room.size.y >= 270, "%s-%d classroom is larger than the previous layout" % [room.block, room.number % 1000])
	check(counts.A == 24 and counts.B == 15 and counts.SERVICE == 1, "A has 24 rooms, B has 15 rooms, and the warehouse is separate")
	check(kinds.size() >= 10 and layouts.size() == 3, "Functional rooms and three classroom arrangements provide varied interiors")
	var nav_map: RID = school.get_world_3d().navigation_map
	for floor_index in range(3):
		var y := floor_index * 3.9
		var from := Vector3(1.5, y, 0)
		var to := Vector3(18, y, -40.5)
		var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
		check(not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.0, "Floor %d: A connects to B through the long corridor" % (floor_index + 1))
		for room in rooms:
			if room.block != "B" or absf(room.center.y - y) > 0.1:
				continue
			var inside := NavigationServer3D.map_get_path(nav_map, to, room.center, true)
			check(not inside.is_empty() and inside[inside.size() - 1].distance_to(room.center) < 1.0, "B-%d %s is reachable through its doorway" % [room.number % 1000, room.kind])
	var storage := Vector3(-45, 0, -53)
	var storage_path := NavigationServer3D.map_get_path(nav_map, Vector3(0, 0, -40.5), storage, true)
	check(not storage_path.is_empty() and storage_path[storage_path.size() - 1].distance_to(storage) < 1, "Service yard connects B to the standalone warehouse")
	var rooftop := Vector3(12, 11.7, -3)
	var roof_path := NavigationServer3D.map_get_path(nav_map, Vector3(0, 7.8, -40.5), rooftop, true)
	check(not roof_path.is_empty() and roof_path[roof_path.size() - 1].distance_to(rooftop) < 1, "Shared navigation connects B floor 3 to A's rooftop; enemy sanctuary guard restricts enemies separately")
	# Walk a real capsule along all 35 metres, not just a navmesh query.
	school.player.position = Vector3(1.5, 0.05, -2)
	var reached := false
	for i in range(900):
		await physics_frame
		school.player.velocity = Vector3(0, 0 if school.player.is_on_floor() else school.player.velocity.y - 0.3, -3)
		school.player.move_and_slide()
		if school.player.position.z < -40:
			reached = true
			break
	check(reached and absf(school.player.position.y) < 0.2, "Player physically walks the connector and enters B without obstruction")
	print("Annex validation failures: ", failures)
	quit(0 if failures == 0 else 1)
