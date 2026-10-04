extends SceneTree

var school: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func cinematic_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	school.survival.opening._input(event)

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 8
	school.special_enemy_count = 5
	school.smart_spawn_enabled = false
	root.add_child(school)
	school.set_process_unhandled_input(false)
	current_scene = school
	await frames(10)
	var director: Node3D = school.survival
	var opening: Node3D = director.opening
	school.player.set_process_unhandled_input(false)
	director.start_run()
	opening.set_process(false)
	director.set_physics_process(false)
	check(opening.playing and not school.simulation_active() and not school.get_node("HUD").visible, "Story opening locks gameplay and switches from HUD to cinematic")
	check(opening.camera.current and opening.actors.size() == 4 and opening.vehicle.find_child("body", true, false) != null, "Opening uses a real Kenney van and four animated team members")
	check(director.clock_text() == "23:30" and director.run_time == 0 and school.enemies.is_empty(), "Intro starts at 23:30 without advancing survival or spawning threats")
	var beginning: Vector3 = opening.vehicle.position
	check(opening.investigation.board.get_child_count() >= 15, "Investigation prelude has readable newspaper clues linked on an evidence board")
	opening.sample(26)
	check(opening.investigation.visible and not opening.scenery.visible and opening.actors.any(func(actor): return actor.head_pitch > 0.05) and not opening.subtitle.visible, "The group exchanges nods without dialogue before the vehicle scene")
	check(opening.investigation.board.find_children("EvidencePhoto", "MeshInstance3D", true, false).size() == 6 and opening.investigation.board.find_children("RedCircle", "MeshInstance3D", true, false).size() == 6, "Evidence uses six in-world images with red circles and connecting strings")
	opening.sample(33.5)
	check(opening.investigation.equipment[0].global_position.distance_to(opening.actors[0].global_position) < 1.5, "Team members gather equipment before leaving")
	opening.sample(42.9)
	check(opening.vehicle.position.distance_to(beginning) > 20, "The van actually moves along the exterior road")
	opening.sample(46)
	check(opening.actors.all(func(actor): return actor.visible) and opening.actors[0].position.z > 78, "The whole team leaves the vehicle outside the school wall")
	opening.sample(51)
	check(opening.cutters.visible and opening.actors.all(func(actor): return is_equal_approx(actor.position.y, 0.05)), "The team uses visible bolt cutters while all feet remain on the ground")
	opening.sample(57.5)
	await frames(3)
	check(school.get_node("Campus/ServiceEntry/Hinge/Leaf").rotation.y < -1.5, "The maintenance door opens on its hinge before the team crosses")
	opening.sample(62.9)
	check(opening.actors.all(func(actor): return actor.position.z < 78 and actor.position.y < 0.2), "All four members enter through the maintenance doorway")
	opening.sample(63.5)
	await frames(3)
	check(school.spirit_enabled and school.realm_scenery.enabled and school.enemies.is_empty(), "The first glimpse changes actual scenery without spawning enemies")
	var before: float = opening.elapsed
	cinematic_key(KEY_ESCAPE)
	opening._process(3)
	check(opening.paused and opening.elapsed == before and opening.animations[0].speed_scale == 0 and (not opening.engine.playing or opening.engine.stream_paused), "Esc freezes cinematic time, animation and any playing engine audio")
	cinematic_key(KEY_ESCAPE)
	opening.sample(64.5)
	check(not school.spirit_enabled, "The glimpse returns to the normal campus")
	cinematic_key(KEY_ENTER)
	await frames(4)
	check(not opening.playing and director.phase == director.Phase.PREPARATION and school.player.camera.current and school.simulation_active(), "Enter skips to the same playable preparation phase")
	check(school.player.can_fit(school.player.position) and school.player.position.z < 78 and school.player.position.z > 73, "Camera handoff places the player's real capsule safely inside the wall")
	var entry: Node3D = school.get_node("Campus/ServiceEntry")
	school.player.set_physics_process(false)
	school.player.position = Vector3(12, 0.05, 80)
	await frames(3)
	check(school.player.move_and_collide(Vector3(0, 0, -4)) != null, "Closed maintenance door blocks the player's real capsule")
	entry.set_open_amount(1)
	school.player.position = Vector3(12, 0.05, 80)
	await frames(3)
	var passage_collision: KinematicCollision3D = school.player.move_and_collide(Vector3(0, 0, -4))
	if passage_collision != null:
		print("ENTRY COLLISION / ", passage_collision.get_collider().get_path(), " / ", passage_collision.get_position(), " / player ", school.player.position)
	check(passage_collision == null and school.player.position.z < 78, "The open maintenance doorway admits a full player capsule without crossing a wall")
	entry.set_open_amount(0)
	school.player.position = Vector3(20, 1.9, 76)
	await frames(3)
	check(school.player.move_and_collide(Vector3(0, 0, 4)) != null, "The high perimeter also blocks the capsule above the height of the old wall")
	school.player.position = Vector3(12, 0.05, 75.2)
	check(opening.actors.size() == 3 and opening.actors.all(func(actor): return actor.visible), "Three companions remain inside during the preparation minute")
	check(director.clock_text() == "23:30" and school.get_node("HUD").visible and not school.spirit_enabled, "Preparation restores HUD at 23:30 in the normal world")
	director.advance_clock(12.3)
	await frames(3)
	check(school.spirit_enabled and school.enemies.is_empty() and director.clock_text() == "23:36", "The playable preparation clock drives brief realm glimpses")
	var prepared: float = director.preparation_time
	school.paused_by_user = true
	director.advance_clock(30)
	check(director.preparation_time == prepared, "Esc pause does not consume preparation time")
	school.paused_by_user = false
	school.set_spirit_world(false)
	check(school.spirit_enabled, "B cannot override the scripted pre-midnight glimpse")
	director.advance_clock(1)
	check(not school.spirit_enabled and school.player.health == 100, "Glimpse resolves normally without resetting health")
	director.advance_clock(45.7)
	check(director.clock_text() == "23:59" and school.enemies.is_empty(), "There is no premature midnight trigger or enemy spawn")
	director.advance_clock(1)
	await frames(5)
	check(director.phase == director.Phase.NIGHT and school.spirit_enabled and school.enemies.size() == 13 and director.clock_text() == "00:00", "At midnight the realm locks and exactly thirteen entities spawn")
	check(director.midnight_bell.playing and director.midnight_bell.stream.get_length() >= 4.9, "Midnight plays the dedicated four-note ding-dong ding-dong cue")
	check(opening.actors.is_empty() and not is_instance_valid(opening.scenery), "Midnight removes companions and cinematic props are already freed")
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	school.player.set_physics_process(false)
	school.has_master_key = true
	director.win()
	check(not director.won and not director.finished, "A key or early win call cannot complete the new night")
	director.advance_clock(120)
	check(director.clock_text() == "01:00", "Twelve real minutes map to six hours, not six real hours")
	school.map_panel.show()
	director.advance_clock(120)
	check(director.clock_text() == "02:00", "Viewing the map does not freeze the survival clock")
	school.map_panel.hide()
	school.paused_by_user = true
	director.advance_clock(120)
	check(director.clock_text() == "02:00", "Esc freezes the night clock")
	school.paused_by_user = false
	director.advance_clock(480)
	check(director.finished and not director.won and director.clock_text() == "06:00" and director.end_panel.visible, "Dawn without a rescued soul remains an unfinished night")
	check(not school.simulation_active() and not school.spirit_enabled, "Dawn stops combat, restores the normal campus and shows the outcome")
	director.start_run(false)
	check(director.clock_text() == "23:30" and not director.finished and not director.soul_rescued, "Restart resets the story clock and rescue flag")
	director.begin_midnight()
	await frames(5)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	check(not director.mark_soul_rescued() and not director.won, "Rescue cannot bypass the four memories and AI conversations")
	director.advance_clock(720)
	check(not director.won and director.finished, "Dawn refuses an unconfirmed rescue")
	print("Opening / night clock validation failures: ", failures)
	school.queue_free()
	await frames(3)
	quit(0 if failures == 0 else 1)
