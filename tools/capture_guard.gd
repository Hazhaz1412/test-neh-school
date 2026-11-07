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
	# 306: at the teacher's desk, back to the room.
	school.get_node("Architecture/ClassroomDoor306").set_open(true, true)
	guard.place(gp.DESK_STAND, gp.DESK)
	guard.run([guard.work()])
	await frames(40)
	school.player.set_crouching(true, true)
	stand(Vector3(-30.2, 7.85, 41.5), gp.EVIDENCE + Vector3(0, 0.3, 0))
	await shot("guard-306-desk")
	stand(Vector3(-31.0, 7.85, 35.6), gp.EVIDENCE)
	await shot("guard-306-papers")
	school.player.set_crouching(false, true)
	# Chase: the pursuer model in the hall.
	var chaser: Node3D = story.escape.ghost
	guard.stop()
	chaser.appear(Vector3(-23.5, 7.85, 40.0), Vector3(-23.5, 7.85, 30))
	chaser.animate(0.1, 0.6)
	stand(Vector3(-23.5, 7.85, 31.0), Vector3(-23.5, 8.9, 40))
	await shot("guard-chase")
	chaser.vanish()
	# The chained gate and the booth.
	stand(Vector3(1.0, 0.05, 68.0), Vector3(4.0, 1.4, 76.0))
	await shot("guard-booth")
	# The tunnel.
	story.escape.reset()
	story.enter_basement()
	story._physics_process(story.DESCENT_SECONDS + 0.1)
	for i in range(240):
		story.runner.tick(1.0 / 60.0)
		await process_frame
	school.player.camera.rotation.y = PI
	await shot("guard-tunnel")
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
