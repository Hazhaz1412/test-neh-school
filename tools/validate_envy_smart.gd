extends SceneTree
# The demon in the places players caught it being stupid, in the real school.
# godot --headless --path . --script tools/validate_envy_smart.gd
# With a window and a folder as argument it also photographs the view from under a cot.
var school: Node3D
var demon: CharacterBody3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func until(test: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if test.call():
			return true
	return false

func spot_named(title: String) -> Node3D:
	return school.get_node("HidingSpots/" + title)

func place_demon(at: Vector3, facing: Vector3) -> void:
	var map: RID = school.get_world_3d().navigation_map
	demon.fall_back(at, 0.0)
	demon.rest_left = 0.0
	demon.state = demon.State.ROAM
	demon.notice = 0.0
	demon.global_position = NavigationServer3D.map_get_closest_point(map, at) + Vector3.UP * 0.05
	var flat := facing - demon.global_position
	demon.rotation.y = atan2(-flat.x, -flat.z)
	demon.agent.target_position = demon.global_position
	demon.checked.clear()
	await physics_frame

func tuck(spot: Node3D) -> void:
	school.player.global_position = spot.approach_position()
	spot.occupant = school.player
	school.player.begin_hide(spot)

func leave() -> void:
	school.player.health = 100.0
	if school.player.is_hidden():
		school.player.end_hide()
	school.player.holding_breath = false

func run() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.progression.briefing_complete = true
	school.set_spirit_world(true, true)
	school.progression.set_physics_process(false)
	school.survival.set_physics_process(false)
	school.scares.enabled = false
	school.player.set_physics_process(false)
	school.player.flashlight.hide()
	school.player.global_position = Vector3(0, 0.05, 66)
	var director: Node = school.envy
	director.hunting_night = true
	await until(func(): return director.started, 3.0)
	demon = director.demon
	director.set_physics_process(false)
	var map: RID = school.get_world_3d().navigation_map
	var space := school.get_world_3d().direct_space_state
	# The fountain is round for bodies and for the map.
	var probe := PhysicsPointQueryParameters3D.new()
	probe.collision_mask = 1
	probe.position = Vector3(3.2, 1.0, 35.2)
	check(space.intersect_point(probe, 1).is_empty(), "the fountain's square corners are gone")
	probe.position = Vector3(0, 1.0, 32)
	check(not space.intersect_point(probe, 1).is_empty(), "the fountain itself is still solid")
	var across := NavigationServer3D.map_get_path(map, Vector3(0, 0.05, 25), Vector3(0, 0.05, 40), true)
	var nearest := 99.0
	for step in range(across.size() - 1):
		nearest = minf(nearest, Geometry2D.get_closest_point_to_segment(Vector2(0, 32), Vector2(across[step].x, across[step].z), Vector2(across[step + 1].x, across[step + 1].z)).distance_to(Vector2(0, 32)))
	check(nearest > 3.0, "the walkable map goes around the fountain: %.1f m" % nearest)
	# Every place to hide can be walked to.
	var unreachable := []
	var total := 0
	for spot in school.get_tree().get_nodes_in_group("hiding_spots"):
		var path := NavigationServer3D.map_get_path(map, Vector3(0, 0.05, 57), spot.approach_position(), true)
		total += 1
		if path.is_empty() or path[-1].distance_to(spot.approach_position()) > 1.6:
			unreachable.append(str(spot.name, " ", spot.global_position))
	print("places to hide ", total, " unreachable ", unreachable.slice(0, 8))
	check(total >= 100, "there are many more places to hide: %d" % total)
	check(unreachable.is_empty(), "the demon can walk to them: %d not" % unreachable.size())
	# Climbing in under its nose, however well the breath is held.
	var hall: Node3D = spot_named("HallA_0")
	await place_demon(hall.approach_position() + Vector3(-9, 0, 0.2), hall.global_position)
	demon.state = demon.State.SWEEP
	demon.goal = spot_named("Hide_107")
	demon.goal_is_spot = true
	demon.agent.target_position = demon.goal.approach_position()
	school.player.global_position = hall.approach_position()
	await physics_frame
	demon.witness(hall)
	tuck(hall)
	school.player.holding_breath = true
	check(demon.goal == hall and demon.certain, "seeing the player climb in overrides what it was doing")
	var pulled := await until(func(): return not school.player.is_hidden(), 8.0)
	check(pulled, "a held breath does not save someone it watched hide")
	leave()
	# Lured into a room with one locker: that locker, not the one through the wall in the hall.
	await place_demon(Vector3(-14.5, 0.05, 8), Vector3(-14.5, 0.05, 0))
	demon.last_seen = Vector3(-14.5, 0.05, 1)
	demon.goal = null
	demon._lost_sight()
	var searched: Array = [demon.goal] + demon.suspects
	print("search order ", searched.map(func(s): return str(s.name, " ", s.global_position)))
	var inside := func(s): return s.global_position.z < 5.5 and absf(s.global_position.x + 14.5) < 8.0
	check(inside.call(searched[0]), "it searches inside the room it lost them in")
	check(inside.call(searched[1]), "every cover in that room comes before the hall")
	# A desk hides nobody up close; a cot does, until it stands right beside it.
	var desk: Node3D = spot_named("Hide_102")
	tuck(desk)
	await place_demon(desk.approach_position() + desk.global_basis.z * 2.2, desk.global_position)
	var spotted := await until(func(): return demon.goal == desk and demon.certain, 3.0)
	check(spotted, "standing near a desk it sees who is under it")
	leave()
	var cot: Node3D = null
	for spot in school.get_tree().get_nodes_in_group("hiding_spots"):
		if spot.kind == spot.Kind.BED:
			cot = spot
			break
	check(cot != null and school.player.can_fit(cot.hide_position(), cot.body_height()), "a body fits under the cot")
	tuck(cot)
	check(school.player.is_hidden() and school.player.camera.position.y < 0.2, "under a cot the eye is at floor height")
	await place_demon(cot.approach_position() + cot.global_basis.z * 1.8, cot.global_position)
	var ignored := not await until(func(): return demon.certain, 1.5)
	check(ignored, "from a few metres the cot hides the player")
	var folder: Array = OS.get_cmdline_user_args()
	if not folder.is_empty():
		demon.set_physics_process(false)
		demon.global_position = cot.approach_position() + cot.global_basis.z * 0.8 + Vector3(0.7, 0, 0)
		school.player.camera.rotation = Vector3.ZERO
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder[0].path_join("under_cot.png"))
		demon.set_physics_process(true)
	leave()
	# Straight across the courtyard: it has to go round and arrive.
	await place_demon(Vector3(0, 0.05, 25), Vector3(0, 0.05, 32))
	school.player.global_position = Vector3(0.5, 0.05, 40)
	demon.state = demon.State.CHASE
	demon.chase_time = 0.0
	demon.unseen = 0.0
	demon.last_seen = school.player.global_position
	var closest := [99.0]
	var arrived := await until(func():
		closest[0] = minf(closest[0], Vector2(demon.global_position.x, demon.global_position.z - 32).length())
		return demon.state in [demon.State.STRIKE, demon.State.GRAB], 8.0)
	check(arrived, "it reaches a player on the far side of the fountain")
	check(closest[0] > 2.5, "without running into it: %.1f m from the centre" % closest[0])
	# Faster than a sprint once it is wound up.
	check(demon.RAGE_SPEED > school.player.RUN_SPEED and demon.CHASE_SPEED < school.player.RUN_SPEED, "a sprint escapes it at first, not forever")
	print("RESULT / ", failures, " failures")
	quit(1 if failures else 0)
