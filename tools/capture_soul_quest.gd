extends SceneTree
var school: Node3D
func _initialize() -> void:
	call_deferred("capture")
func frames(count := 5) -> void:
	for i in range(count): await physics_frame
func shot(title: String) -> void:
	school._update_light_budget()
	for i in range(20): await process_frame
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
	school.survival.start_run(false)
	school.player.position = Vector3(0, 0.05, 60)
	school.player.camera.look_at(Vector3(0, 3.8, 15))
	school.notice_time = 0
	await shot("compact-hud-preview")
	school.survival.begin_midnight()
	await frames(8)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		ghost.position = Vector3(50, 0.05, -30)
	school.survival.set_physics_process(false)
	school.has_master_key = true
	for door in school.get_node("Architecture").get_children():
		if door.has_method("set_open"): door.set_open(true)
	await frames(35)
	var quest: Node3D = school.soul_quest
	school.player.position = Vector3(-28.3, 7.85, -9.3)
	school.player.camera.look_at(quest.fragments[0].global_position)
	school.notice_time = 0
	await shot("soul-memory-preview")
	# Capture fixtures unlock the journal/dialog for visual review, not AI validation.
	for i in range(4): quest.found[i] = true
	quest.toggle_journal()
	await shot("soul-journal-preview")
	quest.close()
	school.player.position = quest.SOUL_APPROACH
	school.player.camera.look_at(quest.soul.global_position + Vector3(0, 1.0, 0))
	await frames()
	quest.begin_comfort(school.player)
	quest.reply.text = "Bức vẽ ấy rất quan trọng với em. Họ làm hỏng nó không phải lỗi của em. Anh sẽ ở đây lắng nghe nếu em muốn kể."
	await shot("soul-comfort-preview")
	quest.close()
	school.queue_free()
	await frames(5)
	quit()
