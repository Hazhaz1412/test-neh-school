extends SceneTree
# Entering through the gate must give a playable night: demon hunting, An reachable, dawn winnable.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("night_one", true)
	var school: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(40): await physics_frame
	var story: Node3D = school.progression
	check(school.survival.active and school.survival.phase == school.survival.Phase.NIGHT, "the night is running")
	check(not school.survival.opening.playing, "no opening cutscene")
	check(school.spirit_enabled, "the school is in the spirit world")
	check(story.stage == story.Stage.COMFORT_AN, "An's story is open: " + story.current_goal())
	check(story.stairs_open and school.has_master_key, "the campus is open")
	check(school.player.global_position.distance_to(Vector3(12, 0.05, 75.2)) < 2.0, "Peter starts at the gate")
	check(school.simulation_active(), "the game is playable")
	var demon_up: bool = school.envy.started
	for i in range(60):
		await physics_frame
		demon_up = school.envy.started
		if demon_up: break
	await physics_frame
	await physics_frame
	check(demon_up, "the demon is awake")
	check(school.envy.demon.global_position.distance_to(school.player.global_position) > 20.0, "it does not start on top of Peter")
	check(school.enemies.all(func(e): return e.dormant), "the old ghosts are gone")
	check(not school.survival.soul_rescued, "An still has to be saved")
	var quest: Node3D = school.soul_quest
	var missing: int = quest.memories.size() - quest.found.size()
	print("memories still in the school: ", missing)
	Engine.time_scale = 6.0
	for i in range(1800): await physics_frame
	Engine.time_scale = 1.0
	check(school.player.health < 100.0 or school.envy.demon.is_hunting() or not school.envy.demon.stolen.is_empty(), "standing still in the open, Peter gets found")
	print("demon state ", school.envy.demon.state_name(), " distance ", int(school.envy.demon.global_position.distance_to(school.player.global_position)))
	print("failures ", failures)
	quit(failures)
