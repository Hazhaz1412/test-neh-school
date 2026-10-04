extends "res://tools/validate_progression.gd"

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await frames(2)

func click(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.global_position = pos
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await frames(3)

func shot(title: String) -> void:
	school._update_light_budget()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + title + ".png")

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 0
	school.special_enemy_count = 0
	root.add_child(school)
	current_scene = school
	await frames(15)
	root.grab_focus()
	await frames(30)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	school.survival.set_physics_process(false)
	school.player.set_physics_process(false)
	p = school.progression
	for kind in range(4):
		check(await approach(p.terminals[kind]), "Rendered interaction ray reaches branch %d" % kind)
		await key(KEY_E)
		check(p.panel_visible() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Actual E opens technical UI %d and releases mouse" % kind)
		if kind == 0:
			await click(p.board.global_position + Vector2(90, 75))
			check(p.puzzles.circuits[0] == 1, "Actual mouse click switches a circuit")
		if kind == 1:
			await click(p.board.global_position + Vector2(150, 110))
			check(p.puzzles.route == [10, 5], "Actual mouse click extends the cable route")
			p.show_technique()
			await frames(6)
		if kind == 2:
			var original: int = p.puzzles.pipes[0]
			await click(p.board.global_position + Vector2(150, 50))
			check(p.puzzles.pipes[0] != original, "Actual mouse click rotates the pipe")
		if kind == 3:
			await click(p.board.global_position + Vector2(270, 170))
			check(p.puzzles.board.count(1) == 1 and p.puzzles.board.count(2) == 1, "Actual mouse move gets an NPC counter-move")
		var before: float = school.survival.run_time
		school.survival.advance_clock(0.5)
		check(school.survival.run_time > before, "Time continues while working on branch %d" % kind)
		await key(KEY_R)
		check(current_scene == school and p.panel_visible(), "R cannot accidentally restart from terminal %d" % kind)
		await shot(["puzzle-electrical", "puzzle-routing", "puzzle-plumbing", "puzzle-board"][kind])
		await key(KEY_ESCAPE)
		check(not p.panel_visible() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not school.paused_by_user, "Esc leaves branch %d and restores movement without pausing" % kind)
	school.player.position = Vector3(4.8, 11.75, 3.3)
	school.player.camera.look_at(Vector3(6.25, 12.95, 3.3))
	await frames(3)
	await shot("roof-locked-keybox")
	p.bypass_for_test()
	school.player.position = school.soul_quest.SOUL_APPROACH
	school.player.camera.look_at(school.soul_quest.soul.global_position + Vector3(0, 1, 0))
	await shot("roof-unlocked-an")
	var f := FileAccess.open("res://docs/progression-rendered-validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("Rendered progression validation: ", checks, " checks / ", failures, " failures")
	school.queue_free()
	await frames(5)
	load("res://scripts/humanoid_model.gd").animation_libraries.clear()
	load("res://scripts/humanoid_model.gd").proportion_meshes.clear()
	load("res://scripts/student_soul.gd").appearance_materials.clear()
	load("res://scripts/combat_limbs.gd").meshes.clear()
	load("res://scripts/humanoid_model.gd").faceless_mesh = null
	quit(0 if failures == 0 else 1)
