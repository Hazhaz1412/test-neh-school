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

func walk_to(target: Vector2) -> bool:
	for i in range(2000):
		await physics_frame
		var offset := target - Vector2(school.player.position.x, school.player.position.z)
		if offset.length() < 0.13:
			school.player.velocity = Vector3.ZERO
			return true
		var direction := offset.normalized()
		school.player.velocity = Vector3(direction.x * 5, 0 if school.player.is_on_floor() else school.player.velocity.y - 0.3, direction.y * 5)
		school.player.move_and_slide()
	print("Stopped at ", school.player.position, " heading to ", target)
	return false

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.player.set_physics_process(false)
	await frames(25)
	check(not school.master_key.interact(school.player), "The key cannot be collected remotely from the entrance")
	var locked := 0
	for door in get_nodes_in_group("classroom_doors"):
		if int(door.get_meta("room_number")) != 990:
			locked += 1 if door.is_locked() and not door.is_open and not door.request_toggle() else 0
	check(locked == 39 and not school.has_master_key, "All 39 school room doors start shut and deny interaction before the key")
	var warehouse: Node3D = school.get_node("Architecture/ClassroomDoor990")
	check(not warehouse.is_locked(), "Warehouse door is exempt so the key remains obtainable")
	var classroom: Node3D = school.get_node("Architecture/ClassroomDoor107")
	check(not classroom.set_open(true), "Direct and ghost door opening cannot bypass a quest lock")
	# The warehouse is accessible around A's exterior before either B repair.
	school.player.position = Vector3(0, 0.05, 64)
	check(await walk_to(Vector2(-43, 64)), "Front courtyard reaches the exterior west path without a key")
	check(await walk_to(Vector2(-43, -40.5)), "Exterior route reaches the service yard with both B entrances locked")
	check(await walk_to(Vector2(-45, -43)), "Service yard reaches the warehouse approach")
	check(warehouse.request_toggle(), "Warehouse opens before the key")
	await frames(35)
	check(await walk_to(Vector2(-45, -54.5)), "Player physically enters the warehouse and reaches the key desk")
	school.player.camera.look_at(school.master_key.global_position)
	await frames(2)
	check(school.player.get_interaction_target() == school.master_key, "E ray selects the master key lying on the desk")
	school.paused_by_user = true
	check(not school.master_key.interact(school.player), "Paused gameplay cannot collect the key")
	school.paused_by_user = false
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Headless cannot always capture the mouse; use the same interaction method
	# there, and the actual input binding when running with a display.
	if DisplayServer.get_name() == "headless":
		school.master_key.interact(school.player)
	else:
		school.player._unhandled_input(event)
	check(school.has_master_key and school.master_key.collected and not school.master_key.visible, "E collects the key once and removes its visual")
	check(school.master_key.get_node("Interaction").collision_layer == 0, "Collected key is no longer targetable")
	var unlocked := 0
	for door in get_nodes_in_group("classroom_doors"):
		unlocked += 1 if not door.is_locked() else 0
	check(unlocked == 25, "Master key unlocks A and warehouse while unrepaired B remains gated")
	school.progression.bypass_for_test()
	check(get_nodes_in_group("classroom_doors").all(func(d): return not d.is_locked()), "Finished progression plus master key unlocks all forty room doors")
	check(classroom.request_toggle(), "A school door can now be opened by interaction")
	var signal_count := [0]
	school.master_key_collected.connect(func(): signal_count[0] += 1)
	school.master_key.interact(school.player)
	check(signal_count[0] == 0, "Repeated interaction cannot collect or complete the task twice")
	school.set_spirit_world(true)
	school.player.enabled = false
	await frames(2)
	check(school.has_master_key and not classroom.is_locked(), "The key stays in inventory when entering the spirit world")
	school.set_spirit_world(false)
	await frames(2)
	check(school.has_master_key and not school.master_key.visible, "Returning to normal does not respawn or lose the key")
	var fresh: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(fresh)
	check(not fresh.has_master_key and fresh.master_key.visible, "A new run resets the task, inventory and key pickup")
	fresh.queue_free()
	print("Quest validation failures: ", failures)
	quit(0 if failures == 0 else 1)
