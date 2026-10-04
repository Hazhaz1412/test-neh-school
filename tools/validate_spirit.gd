extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
var school: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS / ", description)
	else:
		push_error(description)
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 8
	school.special_enemy_count = 5
	school.smart_spawn_enabled = false
	root.add_child(school)
	current_scene = school
	await frames(25)
	school.player.set_physics_process(false)
	check(not school.spirit_enabled and school.enemies.is_empty(), "Normal world starts without ghosts")
	check(not school.realm_audio.playing and not school.threat_audio.playing, "Normal world starts without cursed ambience")
	var baseline: Environment = school.get_node("Atmosphere/MoonlitEnvironment").environment
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.pressed = true
	school._unhandled_input(event)
	check(school.spirit_enabled, "B enables the spirit world")
	check(school.enemies.size() == 13, "Spirit realm spawns eight bullies and five specialized entities")
	check(school.get_node("Atmosphere/MoonlitEnvironment").environment != baseline, "Spirit realm replaces the environment")
	check(school.cursed_environment.fog_density > baseline.fog_density, "Resentment increases fog density")
	check(school.cursed_environment.sky.sky_material.get_shader_parameter("spirit_amount") == 1.0, "Spirit sky uses the cursed moon palette")
	check(school.spirit_decor.get_child_count() == 4, "Ash effects cover the courtyard and upper floors")
	var groups := {}
	var solitary := 0
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		if ghost.archetype != "bully":
			continue
		if ghost.squad_id < 0:
			solitary += 1
		else:
			groups[ghost.squad_id] = groups.get(ghost.squad_id, 0) + 1
	check(groups.get(0) == 2 and solitary == 6, "One pair and six lone ghosts spread over the campus in the stress fixture")
	await frames(2)
	check(school.realm_audio.playing and school.threat_audio.playing, "B starts ambience and the threat heartbeat loop")
	var ghost: CharacterBody3D = school.enemies[0]
	check(ghost.animation_names.has("walk") and ghost.animation_names.has("sprint") and ghost.animation_names.has("attack-melee-right"), "Imported walk, sprint and melee animations are available")
	var head := ghost.model.find_child("head", true, false) as MeshInstance3D
	check(head != null and head.material_override is ShaderMaterial and head.material_override.shader == preload("res://assets/materials/ghost_skin.gdshader"), "Faceless porcelain head uses the new grime shader")
	check(ghost.model.find_child("StudentBadge", true, false) != null and ghost.model.find_child("SchoolTie", true, false) != null, "Ghost keeps recognizable student uniform details")
	check(ghost.model.find_child("WoodenClub", true, false) != null, "Club is attached to the animated hand")
	var nav_map: RID = school.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(nav_map, Vector3(8, 0, 51), Vector3(0, 7.8, 8), true)
	check(path.size() > 2 and path[path.size() - 1].y > 7.5, "Navigation reaches the third floor via the staircase")
	# Follow a real multilevel path using the ghost CharacterBody and agent.
	school.player.enabled = true
	ghost.position = Vector3(-4.8, 0.05, 7.2)
	ghost.detection_range = 0.0
	ghost.state = Ghost.State.SEARCH
	ghost.memory = 90.0
	ghost.last_known = Vector3(0, 7.8, 8)
	ghost.path_clock = 0.0
	ghost.set_physics_process(true)
	for i in range(1600):
		await physics_frame
		if ghost.position.y > 7.6:
			break
	check(ghost.position.y > 7.6, "Ghost physically climbs the staircase to the third floor")
	print("Ghost stair endpoint: ", ghost.position)
	ghost.set_physics_process(false)
	ghost.detection_range = school.ghost_detection_range
	ghost.memory = 0.0
	ghost.cooldown = 0.0
	# Pursuit, squad alert, and an actual timed melee hit on the player.
	school.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	school.player.position = Vector3(0, 0.05, 64)
	ghost.position = Vector3(0, 0.05, 59)
	ghost.look_at(Vector3(0, 0.05, 64))
	school.enemies[1].position = Vector3(4, 0.05, 60)
	ghost.state = Ghost.State.PATROL
	ghost.path_clock = 0
	ghost.vision_clock = 0
	ghost.set_physics_process(true)
	await frames(30)
	check(ghost.state == Ghost.State.SEARCH, "Distant sight starts investigation before close confirmation")
	check(school.enemies[1].state == Ghost.State.SEARCH, "A detected player alerts nearby squadmates")
	await frames(20)
	check(ghost.state == Ghost.State.CHASE, "Confirmed close sight switches investigation to pursuit")
	var initial_distance := ghost.position.distance_to(school.player.position)
	await frames(25)
	check(ghost.position.distance_to(school.player.position) < initial_distance - 1.0, "Ghost physically closes the distance along its path")
	for i in range(160):
		await physics_frame
		if school.player.health < 100:
			break
	check(school.player.health < 100.0, "A melee swing damages the player after windup")
	var after_hit: float = school.player.health
	school.player.take_damage(14)
	check(school.player.health == after_hit, "Hit invulnerability prevents instant damage stacking")
	# Freeze the aggressor, then put a classroom wall between it and the player.
	ghost.set_physics_process(false)
	ghost.position = Vector3(32, 0.05, 32.8)
	school.player.position = Vector3(32, 0.05, 31.2)
	await frames(2)
	check(not ghost.has_line_of_sight(), "Classroom wall blocks detection and melee line of sight")
	school.set_spirit_world(false)
	await frames(2)
	check(school.enemies.is_empty() and school.enemy_root.get_child_count() == 0, "Leaving the spirit world despawns every ghost")
	check(school.get_node("Atmosphere/MoonlitEnvironment").environment == baseline, "Normal fog, sky and environment are restored")
	check(baseline.sky.sky_material.get_shader_parameter("spirit_amount") == 0.0, "Normal moon palette is preserved across realm toggles")
	check(school.player.health == 100.0, "Toggle resets health for repeated visual playtests")
	for i in range(3):
		school.set_spirit_world(true)
		school.set_spirit_world(false)
		await frames(2)
	check(school.enemy_root.get_child_count() == 0, "Repeated B toggles do not accumulate enemies")
	check(not school.realm_audio.playing and not school.threat_audio.playing, "Returning to normal stops both spirit audio loops")
	school.set_spirit_world(true)
	school.player.invulnerable_time = 0
	school.player.take_damage(200)
	check(school.death_panel.visible and not school.player.enabled, "Death stops movement and displays restart / B controls")
	school.set_spirit_world(false)
	check(not school.death_panel.visible and school.player.health == 100.0, "B recovers from death into the normal world")
	var early_scene: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(early_scene)
	early_scene.set_spirit_world(true)
	early_scene.set_spirit_world(false)
	await frames(30)
	check(early_scene.enemies.is_empty(), "An early cancelled toggle cannot spawn ghosts after navigation sync")
	early_scene.queue_free()
	print("Spirit validation failures: ", failures)
	quit(0 if failures == 0 else 1)
