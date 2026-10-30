extends "res://tools/validate_progression.gd"
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
func click_button(button: Button) -> void:
	await frames(4)
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await frames(2)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = center
		event.global_position = center
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)
func shot(title: String) -> void:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+title+".png")
func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	root.grab_focus()
	await frames(15)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	var second: Node3D = school.get_node("Architecture/ClassroomDoor102")
	school.player.position = Vector3(14.5, 0.05, 9.2)
	school.player.camera.look_at(story.bear.position+Vector3.UP*.5)
	await shot("night1-lit-classroom")
	check(await approach(first, 1.25), "Rendered first door is reachable")
	await key(KEY_E)
	await frames(35)
	check(await approach(story.bear), "Rendered teddy is physically reachable")
	await shot("night1-teddy")
	await key(KEY_E)
	check(story.evidence.has("bear"), "Actual E collects the teddy without a paper dialogue")
	school.player.position = Vector3(5, 0.05, 7.5)
	school.player.camera.look_at(Vector3(-10, 0.1, 7.5))
	await shot("night1-blood-trail")
	check(await approach(second, 1.25), "Rendered second door is reachable")
	story._physics_process(.1)
	await key(KEY_E)
	await frames(35)
	check(await approach(story.clubs), "Rendered bloodied clubs are reachable")
	await shot("night1-bloody-clubs")
	await key(KEY_E)
	check(story.stage == story.Stage.CLUB_SCARE, "Actual E on the clubs starts the scare")
	# The full journey is rendered by tools/capture_night1_escape.gd.
	story.club_scare.reset()
	story.stage = story.Stage.ESCAPE_RUN
	story.escape.start()
	story.escape._finish()
	await shot("night1-gate-static")
	story._physics_process(2.7)
	check(story.runner.active, "Gate contact pulls player into the spirit corridor")
	var runner: Node3D = story.runner
	await shot("night1-corridor-run")
	var jumps := 0
	var slides := 0
	var shot_jump := false
	var shot_slide := false
	var driver := preload("res://tools/chase_driver.gd").new()
	driver.runner = runner
	driver.world = school
	var captured_lan := false
	for frame in range(12000):
		await physics_frame
		if frame%600==0: print("TRAVERSAL / ",frame," / ",runner.distance," / ",runner.elapsed," / active ",school.simulation_active()," / mouse ",Input.mouse_mode)
		driver.tick()
		runner.tick(1.0/60)
		school.survival.advance_clock(1.0/60)
		if not shot_jump and runner.jump_height > .9:
			await shot("night1-corridor-jump")
			shot_jump = true
		if not shot_slide and runner.slide_remaining > 0:
			await shot("night1-corridor-slide")
			shot_slide = true
		if runner.lan.visible and not captured_lan:
			captured_lan = true
			await shot("night1-lan-follow")
		if story.stage == story.Stage.LAN_DIALOGUE or school.player.health <= 0: break
	check(story.stage == story.Stage.LAN_DIALOGUE and runner.hit_count == 0, "Real WASD / Shift, turning, jumping and sliding complete the manual chase without damage")
	await shot("night1-lan-curse")
	await key(KEY_ESCAPE)
	check(not story.panel_visible() and not school.paused_by_user, "Esc closes Lan dialogue without pausing gameplay")
	school.player.camera.look_at(story.lan.position+Vector3.UP)
	await shot("night1-lan-refuge")
	await key(KEY_E)
	check(story.panel_visible(), "Actual E resumes Lan inside the closed room")
	for id in story.dialogue_data.lan.required:
		for index in range(story.dialogue_data.lan.questions.size()):
			if story.dialogue_data.lan.questions[index].id!=id: continue
			story.lan_view.reveal()
			await click_button(story.lan_view.choices.get_child(index))
			for turn in range(2):
				story.lan_view.reveal()
				await click_button(story.lan_view.choices.get_child(0))
	story.lan_view.reveal()
	await click_button(story.lan_view.choices.get_child(story.lan_view.choices.get_child_count()-1))
	check(story.stage == story.Stage.TABLE_ESCAPE, "Lan's dialogue enables the table escape")
	check(await approach(runner.table, .55), "Lan table is reachable")
	await key(KEY_E)
	story._physics_process(1.9)
	await frames(4)
	check(story.portal_arrived and school.player.hidden_spot == story.return_table, "E enters the portal and arrives beneath the school table")
	await key(KEY_E)
	check(story.briefing_complete and story.stage == story.Stage.COMFORT_AN and not school.player.is_hidden(), "E leaves the school table and resumes An's story")
	await key(KEY_J)
	await shot("night1-journal")
	await key(KEY_ESCAPE)
	var file := FileAccess.open("res://docs/progression-rendered-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"lan_seconds":runner.LAN_AFTER_SECONDS},"\t"))
	file.close()
	print("RESULT / rendered ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	# Allow the audio mixing thread to release playbacks before process exit.
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
