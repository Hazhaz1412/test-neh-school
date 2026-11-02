extends "res://tools/validate_progression.gd"

func shot(title: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + title + ".png")

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
	await shot("night1-lure-arrival")
	check(not school.objective_label.visible and not school.notice_label.visible, "No explanatory text at the arrival view")
	school.player.position = Vector3(-10, 0.05, 43)
	school.player.camera.look_at(Vector3(15.5, 2.0, 9))
	await shot("night1-lure-courtyard")
	check(not story.room_shadow.model.visible and story.room_shadow.mode == story.room_shadow.Mode.HIDDEN, "First illuminated-room event has no silhouette")
	check(not story.notebook.visible and story.room_shadow.model.look=="Female_Adult_05", "A female shadow and her notebook are reserved for later")
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	check(await approach(first, 1.25) and first.interact(school.player), "Illuminated classroom door remains physically usable")
	await frames(35)
	check(await approach(story.bear) and story.bear.interact(school.player), "Teddy remains the first clue and can be picked up")
	for i in range(3): await process_frame
	check(not story.window_lure.visible and not school.notice_label.visible, "Teddy collection extinguishes the window lure without text")
	check(not story.room_shadow.model.visible and story.blood.visible, "The teddy leads to the blood trail, with no shadow yet")
	# The shadow is the reward after the club scare, seen by looking up.
	story.room_shadow.show_at_window()
	for at in [Vector3(-8,0.05,8.1),Vector3(10,0.05,40)]:
		school.player.position = at
		school.player.camera.look_at(story.room_shadow.WINDOW+Vector3.UP*1.85)
		await shot("night1-opposite-shadow" if at.z<10 else "night1-window-shadow-courtyard")
	check(story.room_shadow.model.visible and story.room_shadow.pane.visible, "The top-floor window shows the figure")
	story.bypass_for_test()
	for i in range(3): await process_frame
	check(is_equal_approx(school.normal_environment.ambient_light_energy, story.window_lure.normal_ambient), "Leaving the introduction restores normal lighting")
	school.survival.active = false
	school.survival.start_run(false)
	for i in range(3): await process_frame
	check(story.window_lure.visible and not story.room_shadow.model.visible and not story.notebook.visible and not story.notebook.inspected, "Restart restores the first event and clears the female shadow and notebook")
	var report := FileAccess.open("res://docs/classroom-lure-validation.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
