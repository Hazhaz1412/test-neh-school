extends "res://tools/validate_progression.gd"

# Screenshots of the rewritten prologue: lit room 103 and its hair clip, the crash and leak,
# the restroom trail upstairs, the cabinet glint, the insect jumpscare and the hand mirror.
# godot --path . --script tools/capture_prologue_restroom.gd --resolution 1280x720

func shot(title: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + title + ".png")

func stand(feet: Vector3, look: Vector3) -> void:
	school.player.global_position = feet
	school.player.look_at(Vector3(look.x, feet.y, look.z))
	school.player.camera.look_at(look)

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
	school.player.camera.look_at(Vector3(15.5, 2.0, 9))
	await shot("prologue-lure-arrival")
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	first.set_open(true)
	await frames(40)
	stand(Vector3(14.5, 0.05, 7.6), Vector3(14.4, 1.0, 1.0))
	await shot("prologue-lure-doorway")
	stand(Vector3(14.6, 0.05, 4.4), story.clip.global_position)
	await shot("prologue-hair-clip")
	check(story.clip.interact(school.player), "The hair clip can be picked up")
	story._physics_process(story.CRASH_DELAY + 0.05)
	for i in range(30): story.restroom._process(0.5)
	stand(Vector3(14.3, 0.05, 4.6), Vector3(12.4, 2.6, 2.3))
	await shot("prologue-ceiling-drip")
	stand(Vector3(2.0, 3.95, 7.5), Vector3(12.0, 3.95, 7.4))
	await shot("prologue-stair-top-trail")
	stand(Vector3(6.5, 3.95, 7.5), Vector3(14.5, 3.95, 7.0))
	await shot("prologue-corridor-wet-trail")
	var door: Node3D = school.get_node("Architecture/ClassroomDoor203")
	door.set_open(true)
	await frames(40)
	stand(Vector3(14.5, 3.95, 4.8), Vector3(7.5, 5.2, -2.0))
	await shot("prologue-restroom-mirror")
	stand(Vector3(13.2, 3.95, -1.0), Vector3(19.0, 4.8, -5.0))
	await shot("prologue-restroom-stalls")
	stand(Vector3(10.2, 3.95, -7.2), story.restroom.cabinet_glint.global_position)
	await shot("prologue-cabinet-glint")
	var handle: Node3D = story.restroom.cabinet.get_node("CabinetHandle")
	check(await approach(handle, 1.0), "The cabinet can be reached")
	stand(Vector3(8.6, 3.95, -8.6), Vector3(7.4, 5.0, -8.6))
	check(handle.interact(school.player), "The cabinet opens")
	await frames(14)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/prologue-insects-leap.png")
	await frames(14)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/prologue-insects-face.png")
	for i in range(30): await process_frame
	var runners: Array = story.restroom.swarm.bugs.filter(func(b): return b.state == "run")
	print("floor runners: ", runners.size())
	if not runners.is_empty(): school.player.camera.look_at(runners[0].pos)
	await shot("prologue-insects-floor")
	for i in range(240):
		await process_frame
		if story.restroom.hand_mirror.visible: break
	stand(Vector3(8.35, 3.95, -8.5), story.restroom.hand_mirror.global_position)
	await shot("prologue-hand-mirror")
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
