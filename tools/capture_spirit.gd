extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(school: Node3D, pos: Vector3, focus: Vector3, filename: String, flashlight := false) -> void:
	school.player.position = pos
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(focus)
	school.player.flashlight.visible = flashlight
	school._update_light_budget()
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func capture() -> void:
	var school: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.player.set_physics_process(false)
	for i in range(25):
		await physics_frame
	school.player.enabled = true
	await shot(school, Vector3(0, 0.02, 64), Vector3(0, 5, 10), "normal-world-preview")
	school.set_spirit_world(true)
	school.player.enabled = true
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	for i in range(15):
		await physics_frame
	await shot(school, Vector3(0, 0.02, 64), Vector3(0, 5, 10), "spirit-world-preview")
	await shot(school, Vector3(6, 0.02, 56), Vector3(8.4, 1.3, 51), "bully-ghosts-preview", true)
	await shot(school, Vector3(-23.5, 0.02, 52), Vector3(-23.5, 1.6, 12), "spirit-hallway-preview", true)
	school.set_spirit_world(false)
	quit()
