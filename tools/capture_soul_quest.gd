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
	school = load("res://scenes/school_runtime.tscn").instantiate()
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
	# Fixture: isolate this system after the Night 1 investigation/tutorial.
	school.progression.bypass_for_test()
	school.survival.begin_midnight()
	school.progression.bypass_for_test()
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
	# Capture fixtures unlock the journal/dialog for visual review, not AI validation.
	for i in range(quest.memories.size()): quest.found[i] = true
	quest.toggle_journal()
	await shot("soul-journal-preview")
	quest.close()
	school.player.position = quest.SOUL_APPROACH
	school.player.camera.look_at(quest.soul.global_position + Vector3(0, 1.0, 0))
	await frames()
	quest.begin_comfort(school.player)
	quest.ask_topic(0)
	quest.dialog.reveal()
	quest.dialog.select_choice(0)
	quest.dialog.reveal()
	await shot("soul-comfort-preview")
	quest.close()
	school.queue_free()
	await frames(5)
	quit()
