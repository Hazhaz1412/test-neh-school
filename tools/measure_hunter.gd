extends SceneTree
# Honest difficulty number: real spawn, real director, a player standing still in the open.
const LIMIT := 300.0
var school: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.progression.briefing_complete = true
	# The hunter runs on a guard night only (world.night_hunt).
	school.guard_night = true
	school.progression.set_physics_process(false)
	school.survival.set_physics_process(false)
	school.player.set_physics_process(false)
	school.has_master_key = true
	school.progression.stairs_open = true
	var director: Node = school.hunt
	director.hunting_night = true
	var map: RID = school.get_world_3d().navigation_map
	var places := [Vector3(-45, 0, -56), Vector3(0, 0, 40), Vector3(30, 0, 64), Vector3(-20, 3.9, 6.3), Vector3(-20, 7.85, 6.3), Vector3(20, 7.85, 6.3), Vector3(45, 0, 20)]
	var total := 0.0
	var found := 0
	for spot in places:
		var feet := NavigationServer3D.map_get_closest_point(map, spot) + Vector3.UP * 0.05
		school.player.global_position = feet
		await physics_frame
		if director.hunter == null:
			for i in range(30): await physics_frame
		var hunter: CharacterBody3D = director.hunter
		school.player.health = 100.0
		director.quiet_time = 0.0
		director.menace = 0.0
		director.hint_clock = director.FIRST_HINT
		hunter.global_position = director._far_point(feet)
		hunter.fall_back(hunter.global_position, 0.0)
		hunter.checked.clear()
		var path := NavigationServer3D.map_get_path(map, hunter.global_position, feet, true)
		var reachable: bool = not path.is_empty() and path[-1].distance_to(feet) < 1.5
		var length := 0.0
		for i in range(1, path.size()): length += path[i - 1].distance_to(path[i])
		Engine.time_scale = 8.0
		var clock := 0.0
		var hit := false
		var moved := 0.0
		var last: Vector3 = hunter.global_position
		while clock < LIMIT:
			await physics_frame
			clock += 8.0 / 60.0
			moved += hunter.global_position.distance_to(last)
			last = hunter.global_position
			if hunter.is_hunting():
				hit = true
				break
			if OS.has_environment("NEH_TRACE") and fmod(clock, 40.0) < 0.14:
				print("   t", int(clock), " ", hunter.state_name(), " at ", hunter.global_position.snappedf(0.1), " next ", hunter.agent.get_next_path_position().snappedf(0.1), " wall ", hunter.is_on_wall(), " goal ", hunter.goal.name if hunter.goal else "-", " left ", int(hunter.agent.distance_to_target()))
		Engine.time_scale = 1.0
		print("%s path %dm reachable %s -> %s after %ds, walked %dm, ended %s y=%.1f, area r=%d, checked %d" % [spot, length, reachable, "FOUND" if hit else "NOT FOUND", clock, moved, hunter.state_name(), hunter.global_position.y, hunter.area_radius, hunter.checked.size()])
		if hit:
			found += 1
			total += clock
	print("RESULT found %d/%d, average %ds" % [found, places.size(), total / maxi(found, 1)])
	quit()
