extends SceneTree

var school: Node3D
var capsule := CapsuleShape3D.new()
var occupied := {}
var failures := 0
var level_y := 0.0

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, text: String) -> void:
	if condition:
		print("PASS / ", text)
	else:
		push_error(text)
		failures += 1

func free_cell(cell: Vector2i) -> bool:
	if occupied.has(cell):
		return occupied[cell]
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), Vector3(cell.x * 0.5, level_y + 0.92, cell.y * 0.5))
	query.exclude = [school.player.get_rid()]
	var space := school.get_world_3d().direct_space_state
	var clear := space.intersect_shape(query, 1).is_empty()
	if clear:
		var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(cell.x * 0.5, level_y + 0.5, cell.y * 0.5), Vector3(cell.x * 0.5, level_y - 0.35, cell.y * 0.5))
		floor_ray.exclude = [school.player.get_rid()]
		clear = not space.intersect_ray(floor_ray).is_empty()
	occupied[cell] = clear
	return clear

func reachable(start: Vector2i, goal: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == goal:
			return true
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if abs(next.x) > 114 or next.y < -164 or next.y > 154 or seen.has(next):
				continue
			seen[next] = true
			if free_cell(next):
				queue.append(next)
	return false

func walk_to(target: Vector2) -> bool:
	var body: CharacterBody3D = school.player
	for i in range(400):
		await physics_frame
		var distance := target - Vector2(body.position.x, body.position.z)
		if distance.length() < 0.13:
			body.velocity = Vector3.ZERO
			return true
		var direction := distance.normalized()
		body.velocity.x = direction.x * 3.0
		body.velocity.z = direction.y * 3.0
		body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 18.0 / 60.0
		body.move_and_slide()
	print("Walk stopped at ", body.position, " toward ", target)
	return false

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	await physics_frame
	await physics_frame
	# Fixture: these tests exercise unlocked map geometry, not quest progression.
	school.progression.bypass_for_test()
	school.player.enabled = false
	school.player.set_physics_process(false)
	school.has_master_key = true # Door mechanics are tested after quest unlock.
	# Route checks use opened doors. Door collision and interaction have their
	# own physical tests below; walls/windows remain in place throughout.
	var doors := get_nodes_in_group("classroom_doors")
	check(doors.size() == 40, "39 diverse rooms plus a separate warehouse have physical doors")
	for door in doors:
		door.is_open = true
		door.slide = 1.0
		door.leaf.position.x = door.slide_distance
	await physics_frame
	await physics_frame
	capsule.radius = 0.29
	capsule.height = 1.75
	check(not school.has_node("Objectives"), "Obsolete fuse/diary quest nodes are removed")
	check(school.get_node("Landscape").get_child_count() > 200, "Imported nature populates the campus")
	check(school.get_node("Furniture").has_node("fountain"), "Imported fountain exists in the courtyard")
	check(reachable(Vector2i(0, 128), Vector2i(-48, 80)), "Entrance → west gallery is walkable")
	check(reachable(Vector2i(0, 128), Vector2i(64, 76)), "Entrance → east classroom is walkable")
	check(reachable(Vector2i(0, 128), Vector2i(0, 16)), "Courtyard → north gallery is walkable around the fountain")
	check(reachable(Vector2i(0, 128), Vector2i(-86, 112)), "Entrance → garden is walkable")
	check(reachable(Vector2i(0, 128), Vector2i(88, 106)), "Entrance → sports court is walkable")
	for floor_index in [1, 2]:
		level_y = floor_index * 3.9
		occupied.clear()
		check(reachable(Vector2i(0, 16), Vector2i(-48, 94)), "Floor %d: north gallery → west gallery has continuous floors" % (floor_index + 1))
		check(reachable(Vector2i(0, 16), Vector2i(64, 76)), "Floor %d: north gallery → east classroom is accessible" % (floor_index + 1))
		var window_ray := PhysicsRayQueryParameters3D.create(Vector3(23.5, level_y + 1.7, 35), Vector3(20, level_y + 1.7, 35), 1)
		window_ray.exclude = [school.player.get_rid()]
		check(not school.get_world_3d().direct_space_state.intersect_ray(window_ray).is_empty(), "Floor %d: enclosed corridor prevents exits through windows" % (floor_index + 1))
		check(not free_cell(Vector2i(38, 94)), "Floor %d: courtyard edge is not walkable outside the gallery" % (floor_index + 1))
	var camera_pos := Vector3(36.9, 1.64, 39.3)
	var sky_ray := PhysicsRayQueryParameters3D.create(camera_pos, camera_pos + Vector3(0.58, 0.4, -0.71).normalized() * 200.0)
	var excludes: Array[RID] = [school.player.get_rid()]
	for pane in school.get_node("Architecture").get_children():
		if pane.has_meta("transparent_window"):
			excludes.append(pane.get_rid())
	sky_ray.exclude = excludes
	check(school.get_world_3d().direct_space_state.intersect_ray(sky_ray).is_empty(), "Classroom window has a clear sightline to the moon")
	# Drive the actual CharacterBody across both stair ramps and landings.
	school.player.position = Vector3(-4.8, 0.1, 7.2)
	check(await walk_to(Vector2(-4.8, -3.0)), "Character can walk up the first flight")
	check(school.player.position.y > 3.75, "First flight reaches the second floor")
	check(await walk_to(Vector2(0, -3.0)), "Second-floor stair landing allows turning")
	check(await walk_to(Vector2(0, 7.2)), "Second-floor landing connects to the north gallery")
	check(await walk_to(Vector2(-4.8, 7.2)), "Second flight is reachable from the gallery")
	check(await walk_to(Vector2(-4.8, -3.0)), "Character can walk up the second flight")
	check(school.player.position.y > 7.65, "Second flight reaches the third floor")
	check(await walk_to(Vector2(-4.8, 7.2)), "Character can walk back down to the second floor")
	check(school.player.position.y < 4.05 and school.player.position.y > 3.7, "Descending stairs lands on the correct floor")
	# Reach the new rooftop with the actual CharacterBody.
	check(await walk_to(Vector2(-4.8, -3.0)), "Walk back to the third floor")
	check(await walk_to(Vector2(0, -3.0)), "Turn on the third-floor landing")
	check(await walk_to(Vector2(0, 7.2)), "Reach the third stair flight")
	check(await walk_to(Vector2(-4.8, 7.2)), "Enter the rooftop stair flight")
	check(await walk_to(Vector2(-4.8, -3.0)), "Climb to the rooftop landing")
	check(school.player.position.y > 11.5, "Rooftop landing reaches the fourth elevation")
	check(await walk_to(Vector2(0, -3.0)), "Turn on the rooftop landing")
	check(await walk_to(Vector2(12, -3.0)), "Step out onto the rooftop through the east exit")
	check(school.player.position.y > 11.6, "Rooftop has a physical walkable floor")
	await validate_doors()
	print("Map validation failures: ", failures)
	quit(0 if failures == 0 else 1)

func validate_doors() -> void:
	var door: Node3D = school.get_node("Architecture/ClassroomDoor107")
	school.player.position = Vector3(23.5, 0.05, 25)
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(Vector3(25, 1.67, 25))
	school.player.enabled = true
	door.is_open = false
	door.slide = 0.0
	door.leaf.position.x = 0.0
	await physics_frame
	await physics_frame
	check(school.player.get_door_target() == door, "Aiming at a classroom doorway selects its E interaction")
	check(not await walk_to(Vector2(27.5, 25)), "Closed classroom door physically blocks the player")
	school.player.position = Vector3(23.5, 0.05, 25)
	door.request_toggle()
	for i in range(40):
		await physics_frame
	check(door.is_open and door.slide > 0.99, "Door interaction opens the sliding leaf")
	check(await walk_to(Vector2(27.5, 25)), "Player walks through the opened classroom door")
	school.player.position = Vector3(25, 0.05, 25)
	await physics_frame
	await physics_frame
	check(not door.set_open(false) and door.is_open, "Door refuses to close through a player at the threshold")
	school.player.position = Vector3(23.5, 0.05, 25)
	school.player.camera.look_at(Vector3(25, 1.67, 25))
	await physics_frame
	await physics_frame
	check(school.player.get_door_target() == door, "Open doorway remains targetable to close it")
	check(door.set_open(false), "Player can close the door after leaving the threshold")
	for i in range(40):
		await physics_frame
	check(door.slide < 0.01, "Closed leaf returns to the doorframe")
	# A pursuing ghost reaches and opens a shut door, then enters the room.
	school.set_spirit_world(true)
	for i in range(20):
		await physics_frame
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	var ghost: CharacterBody3D = school.enemies[0]
	school.player.position = Vector3(28, 0.05, 25)
	ghost.position = Vector3(23.5, 0.05, 25)
	ghost.detection_range = 0.0
	ghost.last_known = school.player.position
	ghost.memory = 20.0
	ghost.state = 1 # SEARCH: last known player was inside this classroom.
	ghost.path_clock = 0.0
	await physics_frame
	await physics_frame
	ghost.set_physics_process(true)
	check(not ghost.has_line_of_sight(), "Closed door blocks a ghost's view into the classroom")
	for i in range(200):
		await physics_frame
		if ghost.position.x > 26.0:
			break
	check(door.is_open and ghost.position.x > 26.0, "Pursuing ghost opens the door and follows into the classroom")
	school.set_spirit_world(false)
