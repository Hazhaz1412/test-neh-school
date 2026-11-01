extends SceneTree
# Honest difficulty number: real spawn, real director, a player standing still in the open.
const LIMIT := 300.0
var school: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
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
	school.has_master_key = true
	school.progression.stairs_open = true
	var director: Node = school.envy
	director.hunting_night = true
	var map: RID = school.get_world_3d().navigation_map
	var places := [Vector3(-45, 0, -56), Vector3(0, 0, 40), Vector3(30, 0, 64), Vector3(-20, 3.9, 6.3), Vector3(-20, 7.85, 6.3), Vector3(20, 7.85, 6.3), Vector3(45, 0, 20)]
	var total := 0.0
	var found := 0
	for spot in places:
		var feet := NavigationServer3D.map_get_closest_point(map, spot) + Vector3.UP * 0.05
		school.player.global_position = feet
		await physics_frame
		if director.demon == null:
			for i in range(30): await physics_frame
		var demon: CharacterBody3D = director.demon
		school.player.health = 100.0
		director.quiet_time = 0.0
		director.menace = 0.0
		director.hint_clock = director.FIRST_HINT
		demon.global_position = director._far_point(feet)
		demon.fall_back(demon.global_position, 0.0)
		demon.checked.clear()
		var path := NavigationServer3D.map_get_path(map, demon.global_position, feet, true)
		var reachable: bool = not path.is_empty() and path[-1].distance_to(feet) < 1.5
		var length := 0.0
		for i in range(1, path.size()): length += path[i - 1].distance_to(path[i])
		Engine.time_scale = 8.0
		var clock := 0.0
		var hit := false
		var moved := 0.0
		var last: Vector3 = demon.global_position
		while clock < LIMIT:
			await physics_frame
			clock += 8.0 / 60.0
			moved += demon.global_position.distance_to(last)
			last = demon.global_position
			if demon.is_hunting():
				hit = true
				break
			if OS.has_environment("NEH_TRACE") and fmod(clock, 40.0) < 0.14:
				print("   t", int(clock), " ", demon.state_name(), " at ", demon.global_position.snappedf(0.1), " next ", demon.agent.get_next_path_position().snappedf(0.1), " wall ", demon.is_on_wall(), " goal ", demon.goal.name if demon.goal else "-", " left ", int(demon.agent.distance_to_target()))
		Engine.time_scale = 1.0
		print("%s path %dm reachable %s -> %s after %ds, walked %dm, ended %s y=%.1f, area r=%d, checked %d" % [spot, length, reachable, "FOUND" if hit else "NOT FOUND", clock, moved, demon.state_name(), demon.global_position.y, demon.area_radius, demon.checked.size()])
		if hit:
			found += 1
			total += clock
	print("RESULT found %d/%d, average %ds" % [found, places.size(), total / maxi(found, 1)])
	quit()
