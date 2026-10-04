extends SceneTree

var school: Node3D

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func shot(title: String) -> void:
	school._update_light_budget()
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + title + ".png")

func capture() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	school.player.set_process_unhandled_input(false)
	school.player.set_physics_process(false)
	await frames(12)
	root.grab_focus()
	await frames(30)
	school.test_cheats.toggle()
	school.survival.set_physics_process(false)
	await frames(8)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	school.test_cheats.prepare_ai_test()
	school.notice_time = 0
	await frames(3)
	await shot("soul-rooftop-preview")
	school.paused_by_user = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await shot("cheat-menu-preview")
	school.paused_by_user = false
	var quest: Node3D = school.soul_quest
	if not quest.begin_comfort(school.player):
		push_error("Cannot open An's rooftop dialogue")
		quit(1)
		return
	quest.reply.text = "Bức vẽ ấy rất quan trọng với em. Họ làm hỏng nó không phải lỗi của em. Anh sẽ ở đây lắng nghe nếu em muốn kể."
	# Real localhost bridge request; no fixture scores and no provider key in the scene.
	quest.submit()
	var deadline := Time.get_ticks_msec() + 15000
	while quest.pending and Time.get_ticks_msec() < deadline:
		await process_frame
	print("Real AI request pending: ", quest.pending, "; feedback: ", quest.feedback.text)
	await shot("soul-ai-status-preview")
	quest.close()
	school.queue_free()
	await frames(4)
	quit()
