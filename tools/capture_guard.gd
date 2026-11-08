extends "res://tools/capture_prologue_restroom.gd"

# Screenshots of the guard part of the prologue.
# godot --path . --script tools/capture_guard.gd --resolution 1280x720

func validate() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.player.set_process_unhandled_input(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	var gp: Node3D = story.guard_part
	var guard: Node3D = gp.guard
	story.collect_clip()
	story.stage = story.Stage.MIRROR_FOUND
	story.begin_guard()
	guard.sensing = false
	guard.run([])
	# He calls up from the ground floor corridor.
	guard.place(Vector3(-12.5, 0.05, 7.5), Vector3(-1, 0.05, 7.5))
	stand(Vector3(-4.0, 0.05, 7.7), Vector3(-12.5, 1.3, 7.5))
	await shot("guard-call")
	# Checking a room on floor 2, seen from the corridor.
	guard.place(Vector3(-14.5, 3.95, 4.6), Vector3(-14.5, 3.95, 0))
	guard.run([guard.wait(9.0, "look_around", true)])
	school.get_node("Architecture/ClassroomDoor202").set_open(true, true)
	await frames(30)
	stand(Vector3(-11.5, 3.95, 8.3), Vector3(-14.5, 4.9, 3.0))
	await shot("guard-room-check")
	# Inside a shut stall.
	var stall: Node3D = story.restroom.stall_doors[5]
	story.restroom.toggle_stall(5)
	await frames(40)
	stand(Vector3(21.3, 3.95, -10.1 + 5 * 1.55 + 0.78), Vector3(19.0, 5.3, -10.1 + 5 * 1.55 + 0.78))
	await shot("guard-stall-hide")
	# Walking ahead down the west wing, seen from behind.
	guard.place(Vector3(-23.5, 7.85, 30.0), Vector3(-23.5, 7.85, 45))
	guard.run([guard.walk([Vector3(-23.5, 7.85, 46)], 0.6)])
	school.player.flashlight.hide()
	stand(Vector3(-23.5, 7.85, 18.5), Vector3(-23.5, 8.9, 30))
	await shot("guard-tail")
	# Looking back with the torch.
	guard.place(Vector3(-23.5, 7.85, 30.0), Vector3(-23.5, 7.85, 10))
	guard.run([guard.wait(9.0, "look_around", true)])
	await frames(20)
	stand(Vector3(-23.5, 7.85, 20.5), Vector3(-23.5, 9.0, 30))
	await shot("guard-look-back")
	# The corridor to block B: piers to press in behind when he looks back, and a peek round one.
	guard.place(Vector3(1.5, 7.85, -36.0), Vector3(1.5, 7.85, -10.0))
	guard.run([guard.wait(30.0, "look_around", true)])
	school.player.flashlight.hide()
	stand(Vector3(-1.1, 7.85, -23.4), Vector3(1.5, 9.0, -36.0))
	await frames(20)
	await shot("guard-connector-bay")
	school.player.lean_offset = 0.6
	school.player.camera.position.x = 0.6
	school.player.camera.rotation.z = -0.17
	await shot("guard-connector-peek")
	school.player.lean_offset = 0.0
	school.player.camera.position.x = 0.0
	school.player.camera.rotation.z = 0.0
	stand(Vector3(1.5, 7.85, -6.0), Vector3(1.5, 8.6, -30.0))
	guard.stop()
	await shot("guard-connector")
	# B-302: at the teacher's desk, back to the room.
	school.get_node("Architecture/ClassroomDoor1302").set_open(true, true)
	guard.place(gp.DESK_STAND, gp.DESK)
	guard.run([guard.work()])
	await frames(40)
	school.player.set_crouching(true, true)
	stand(Vector3(-1.2, 7.85, -46.5), gp.EVIDENCE + Vector3(0, 0.3, 0))
	await shot("guard-b302-desk")
	school.player.set_crouching(false, true)
	# The flash: four seconds to get into a locker.
	gp.part = gp.Part.PHOTO
	story.stage = story.Stage.PHOTO_EVIDENCE
	gp.photo_taken()
	for i in range(70):
		gp._process(1.0 / 60.0)
		await process_frame
	stand(Vector3(-2.5, 7.85, -43.0), Vector3(-6.0, 8.6, -41.0))
	await shot("guard-duck")
	# In the locker with him listening at the door.
	var locker: Node3D = school.get_node("HidingSpots/HallB_2b")
	locker.occupant = school.player
	locker.entry_position = locker.approach_position()
	school.player.begin_hide(locker)
	gp._start_search(locker)
	guard.place(Vector3(locker.global_position.x, 7.85, -40.1), locker.global_position)
	guard.run([guard.wait(30.0, "listen")])
	for i in range(30):
		gp._process(1.0 / 60.0)
		await process_frame
	await shot("guard-locker")
	school.player.end_hide()
	gp.stand_down()
	# In the yard: he shouts from the third-floor window and pins the player in his torch.
	var escape: Node3D = story.escape
	school.player.global_position = Vector3(1.0, 0.05, 64.0)
	story.begin_escape()
	for i in range(150):
		escape._physics_process(1.0 / 60.0)
		escape.tick(1.0 / 60.0)
		await process_frame
	await shot("guard-gate-call")
	# The clock, the booth and the toolbox.
	for i in range(int(escape.CALL_SECONDS * 60)):
		escape._physics_process(1.0 / 60.0)
	stand(Vector3(3.2, 0.05, 71.2), escape.TOOLBOX + Vector3(0.4, 0.4, 1.0))
	escape.time_left = 15.3
	escape._physics_process(1.0 / 60.0)
	await shot("guard-toolbox")
	# The lock plate: one screw out, one being turned.
	escape.take_tool()
	var breaker: Control = escape.breaker
	breaker.turn(1, -TAU * 3.0)
	breaker.engage(0, breaker.screw_center(0) + Vector2(80, 0))
	breaker.turn(0, -TAU * 1.7)
	Input.warp_mouse(breaker.get_global_transform_with_canvas() * (breaker.screw_center(0) + Vector2.from_angle(-0.9) * 85.0))
	escape.time_left = 11.6
	escape._physics_process(1.0 / 60.0)
	for i in range(20): escape.tick(1.0 / 60.0)
	await shot("guard-screws")
	for i in [0, 2, 3]: breaker.turn(i, -TAU * 3.0)
	for k in range(8): breaker.kick()
	escape.time_left = 6.4
	escape._physics_process(1.0 / 60.0)
	for i in range(20): escape.tick(1.0 / 60.0)
	await shot("guard-kick")
	while escape.active: breaker.kick()
	# The tunnel: the guard runs behind with his torch.
	story._physics_process(story.DESCENT_SECONDS + 0.1)
	for i in range(240):
		story.runner.tick(1.0 / 60.0)
		await process_frame
	story.runner.ghost_distance = story.runner.travel_distance - 5.0
	for i in range(30):
		story.runner.tick(1.0 / 60.0)
		await process_frame
	school.player.camera.rotation.y = PI
	await shot("guard-tunnel")
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
