extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
var failures := 0
var school: Node3D

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS / ", description)
	else:
		push_error(description)
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func aim(spot: Node3D) -> void:
	school.player.global_position = spot.approach_position()
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(spot.to_global(Vector3(0, 1.1 if spot.kind == 0 else 0.55, 0.72)))
	await frames(2)

func press_e() -> void:
	if DisplayServer.get_name() == "headless":
		# Dummy display cannot capture a mouse. Use the exact E-dispatched target
		# and interaction method; GPU validation exercises the real input event.
		if not school.simulation_active():
			return
		if school.player.is_hidden():
			school.player.end_hide()
		else:
			var target: Node3D = school.player.get_interaction_target()
			if target != null:
				target.interact(school.player)
		return
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	school.player._unhandled_input(event)

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	await frames(25)
	var player: CharacterBody3D = school.player
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(school.get_node("HidingSpots").get_child_count() == 47, "47 authored covers span rooms, both halls and warehouse")
	var kinds := {0: 0, 1: 0}
	for spot in school.get_node("HidingSpots").get_children():
		kinds[spot.kind] += 1
		await aim(spot)
		check(player.can_fit(player.global_position), "%s has a clear standing approach" % spot.name)
		check(player.get_interaction_target() == spot, "%s is reachable by the real interaction ray" % spot.name)
		press_e()
		check(player.is_hidden() and player.hidden_spot == spot, "%s accepts E and conceals the player" % spot.name)
		if not player.is_hidden():
			continue
		check(not player.flashlight.visible and player.can_fit(player.global_position, 0.68 if spot.kind == 1 else 1.75), "%s has a clear physical interior and extinguishes the flashlight" % spot.name)
		await frames(2)
		press_e()
		check(not player.is_hidden() and player.can_fit(player.global_position), "%s exits to a clear standing capsule" % spot.name)
	check(kinds[0] > 0 and kinds[1] > 0, "Both lockers and hollow tables are playable")
	var cabinet: Node3D = school.get_node("HidingSpots/HallA_0")
	await aim(cabinet)
	press_e()
	var obstruction := StaticBody3D.new()
	var obstacle := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.2, 1.15)
	obstacle.shape = box
	obstruction.add_child(obstacle)
	obstruction.position = cabinet.approach_position() + Vector3(0, 1.1, 0.30)
	school.add_child(obstruction)
	await frames(3)
	press_e()
	check(player.is_hidden(), "An obstructed exit keeps the player concealed instead of teleporting through a collider")
	obstruction.queue_free()
	await frames(3)
	press_e()
	check(not player.is_hidden(), "E exits normally once the obstruction clears")
	await aim(cabinet)
	school.paused_by_user = true
	press_e()
	check(not player.is_hidden(), "Paused E cannot enter a cover")
	school.paused_by_user = false
	player.position = Vector3(0, 0.05, 64)
	check(not cabinet.interact(player), "A cover cannot be entered remotely")
	# Keep only one simulated enemy. Real navigation, LOS and melee remain active.
	school.set_spirit_world(true)
	await frames(10)
	for cover in school.get_node("HidingSpots").get_children():
		check(player.can_fit(cover.hide_position(), 0.68 if cover.kind == 1 else 1.75), "%s retains a clear hiding interior in the cursed realm" % cover.name)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	var ghost: CharacterBody3D = school.enemies[0]
	await aim(cabinet)
	ghost.global_position = Vector3(19, 0.05, 26)
	ghost.look_at(Vector3(19, 0.05, 8))
	await frames(2)
	press_e()
	check(player.is_hidden() and ghost.suspected_spot == null and not ghost.has_line_of_sight(), "Unwitnessed hiding blocks detection without giving the ghost a hiding location")
	ghost.global_position = Vector3(19, 0.05, 8.65)
	ghost.state = Ghost.State.ATTACK
	ghost.attack_time = ghost.windup
	ghost.strike_done = false
	ghost.memory = 0
	ghost.vision_clock = 0
	var health: float = player.health
	ghost.set_physics_process(true)
	await frames(50)
	check(player.health == health and player.is_hidden(), "An unwitnessed hiding place blocks an old queued melee attack")
	ghost.set_physics_process(false)
	ghost.global_position = Vector3(0, 0.05, 64)
	school.set_spirit_world(false)
	await frames(4)
	check(player.hidden_spot == cabinet and player.can_fit(player.global_position), "B preserves a safe occupied cabinet and resets enemies")
	press_e()
	check(not player.is_hidden() and player.flashlight.visible, "Exiting restores the flashlight and full standing capsule")
	school.set_spirit_world(true)
	await frames(10)
	for enemy in school.enemies:
		enemy.set_physics_process(false)
	ghost = school.enemies[0]
	await aim(cabinet)
	ghost.global_position = Vector3(19, 0.05, 8.7)
	ghost.look_at(player.global_position)
	ghost.state = Ghost.State.CHASE
	await frames(2)
	check(ghost.has_line_of_sight(), "Witness has a real clear sightline to the entry")
	press_e()
	check(player.is_hidden() and ghost.suspected_spot == cabinet and ghost.state == Ghost.State.SEARCH, "Witnessed entry records that cabinet and switches to investigation")
	ghost.set_physics_process(true)
	await frames(95)
	check(not player.is_hidden(), "A nearby witness physically checks the cover and exposes its occupant")
	await frames(100)
	check(player.health < 100, "An exposed occupant is vulnerable to the subsequent melee pursuit")
	ghost.set_physics_process(false)
	# Loss of sight must preserve the old location, never the hidden anchor.
	player.recover()
	ghost.global_position = Vector3(0, 0.05, 59)
	player.global_position = Vector3(0, 0.05, 64)
	ghost.look_at(player.global_position)
	ghost.state = Ghost.State.PATROL
	ghost.memory = 0
	ghost.vision_clock = 0
	ghost.rush_clock = 0
	ghost.set_physics_process(true)
	await frames(8)
	check(ghost.state == Ghost.State.STALK, "Detection has a brief unsettling stare before the rush")
	await frames(18)
	check(ghost.state == Ghost.State.CHASE and ghost.rush_time > 0 and Vector2(ghost.velocity.x, ghost.velocity.z).length() > player.RUN_SPEED, "The initial rush actually outruns sprinting for a limited burst")
	ghost.set_physics_process(false)
	ghost.state = Ghost.State.SEARCH
	ghost.last_known = Vector3(0, 0.05, 64)
	ghost.memory = 6
	ghost.detection_range = 0
	ghost.position = Vector3(0, 0.05, 64)
	ghost.agent.target_position = ghost.last_known
	ghost.path_clock = 0
	ghost.search_index = 0
	ghost.suspected_spot = null
	ghost.can_see = false
	ghost.velocity = Vector3.ZERO
	player.position = Vector3(32, 0.05, 31)
	await frames(3)
	print("Search start: ", ghost.global_position, " / ", ghost.velocity)
	ghost.set_physics_process(true)
	await frames(90)
	print("Search result: ", ghost.state, " / ", ghost.search_index, " / ", ghost.last_known, " / ", ghost.position)
	check(ghost.search_index > 0 and ghost.last_known.distance_to(Vector3(0, 0.05, 64)) < 0.01, "Lost-target investigation scans around the remembered location without tracking the player through walls")
	school.set_spirit_world(false)
	await frames(2)
	print("Hiding / pursuit validation failures: ", failures)
	school.queue_free()
	await frames(3)
	Ghost.reshaped_meshes.clear()
	quit(0 if failures == 0 else 1)
