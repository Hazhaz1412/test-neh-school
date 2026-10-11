extends "res://tools/validate_progression.gd"

func shot(title: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + title + ".png")

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
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
	check(not story.room_shadow.visible and not story.room_shadow.activated, "First illuminated-room event has no silhouette")
	check(not story.notebook.visible and story.room_shadow.model.variant=="Casual_Female", "A female shadow and her notebook are reserved for the second event")
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	check(await approach(first, 1.25) and first.interact(school.player), "Illuminated classroom door remains physically usable")
	await frames(35)
	check(await approach(story.bear) and story.bear.interact(school.player), "Teddy remains the first clue and can be picked up")
	for i in range(3): await process_frame
	check(not story.window_lure.visible and not school.notice_label.visible, "Teddy collection extinguishes the window lure without text")
	check(story.room_shadow.activated and story.room_shadow.visible and story.blood.visible, "Picking up the teddy starts the separate upper-window shadow event")
	school.player.position = Vector3(12, 0.05, 7.5)
	school.player.camera.look_at(story.room_shadow.WINDOW+Vector3.UP*1.85)
	await shot("night1-opposite-shadow")
	check(not story.room_shadow.withdrawn, "The second shadow waits while the player is far away")
	school.paused_by_user = true
	var retreat_before: float = story.room_shadow.retreat
	await frames(10)
	check(story.room_shadow.retreat == retreat_before, "Pause holds the second event")
	school.paused_by_user = false
	school.player.camera.look_at(story.room_shadow.WINDOW+Vector3.UP*1.85)
	# Looking at it for longer than the old trigger must never make it leave.
	story.room_shadow._process(6)
	check(not story.room_shadow.withdrawn and story.room_shadow.visible, "Looking from the ground floor does not trigger retreat, even after six seconds")
	var upper: Node3D = school.get_node("Architecture/ClassroomDoor205")
	check(not upper.is_locked(), "The actual classroom behind the upper-floor shadow is unlocked after the teddy")
	school.player.position = Vector3(0,2.6,7.5)
	story.room_shadow._process(.1)
	check(not story.room_shadow.withdrawn, "Climbing partway up the staircase does not trigger the retreat")
	school.player.position = Vector3(0,3.95,7.5)
	story.room_shadow._process(.1)
	check(story.room_shadow.withdrawn and upper.is_open, "Reaching the second-floor landing triggers retreat from across the building")
	school.player.position = Vector3(-23.4,3.95,19)
	school.player.camera.look_at(story.room_shadow.WINDOW+Vector3.UP*1.6)
	await shot("night1-shadow-approach")
	check(story.room_shadow.withdrawn and upper.is_open, "The female shadow opens the actual room and walks inside")
	for i in range(400):
		await frames(1)
		if not story.room_shadow.visible: break
	await shot("night1-shadow-withdrawn")
	check(not story.room_shadow.visible and story.room_shadow.position.x<-25 and story.blood.visible, "The figure disappears inside the actual accessible classroom, leaving the blood trail")
	check(await approach(upper,1.25) and school.player.get_interaction_target()==upper, "Player can physically approach and interact with the shadow's upstairs door")
	upper.set_open(true)
	await frames(35)
	school.player.position = Vector3(-23.5,3.95,25)
	for i in range(60):
		await physics_frame
		school.player.velocity = Vector3(-4,0,0)
		school.player.move_and_slide()
	check(school.player.position.x<-26, "Player can walk through the real door into the room that the shadow entered")
	check(await approach(story.notebook,.06) and story.notebook.interact(school.player), "The notebook has an unobstructed real E interaction inside room 205")
	await shot("night1-an-notebook")
	check(story.panel_kind=="notebook" and story.notebook_page.visible and story.evidence.has("notebook") and school.soul_quest.found.size()==2 and not story.blackout, "The notebook counts as the second real clue; the remaining clubs are still required")
	story.close()
	check(story.journal_context().contains("Nguyễn Bình An"), "The notebook owner's full name is retained in the journal")
	story.bypass_for_test()
	for i in range(3): await process_frame
	check(is_equal_approx(school.normal_environment.ambient_light_energy, story.window_lure.normal_ambient), "Leaving the introduction restores normal lighting")
	school.survival.active = false
	school.survival.start_run(false)
	for i in range(3): await process_frame
	check(story.window_lure.visible and not story.room_shadow.visible and not story.room_shadow.activated and not story.notebook.visible and not story.notebook.inspected, "Restart restores the first event and clears the female shadow and notebook")
	var report := FileAccess.open("res://docs/classroom-lure-validation.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
