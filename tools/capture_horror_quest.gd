extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(school: Node3D, pos: Vector3, focus: Vector3, filename: String) -> void:
	school.player.position = pos
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(focus)
	school.player.flashlight.visible = true
	school._update_light_budget()
	if filename == "bully-ghosts-preview":
		for ghost in school.enemies:
			ghost.look_at(Vector3(pos.x, ghost.position.y, pos.z))
	for i in range(20):
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
	await shot(school, Vector3(-45, 0.05, -54.5), school.master_key.position, "master-key-preview")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	school.player._unhandled_input(key)
	assert(school.has_master_key)
	await shot(school, Vector3(-45, 0.05, -54.5), Vector3(-45, 0.92, -56), "master-key-collected-preview")
	school.notice_time = 0.0
	await shot(school, Vector3(0, 0.05, -44.5), Vector3(0, 2.3, -56), "realm-classroom-before")
	school.set_spirit_world(true)
	for i in range(20):
		await physics_frame
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		ghost._play("idle")
	await shot(school, Vector3(1.5, 0.05, -8), Vector3(1.5, 1.9, -30), "spirit-connector-preview")
	await shot(school, Vector3(0, 0.05, -44.5), Vector3(0, 2.3, -56), "realm-classroom-after")
	await shot(school, Vector3(-21, 0.05, -44.5), Vector3(-23, 2.0, -54), "realm-library-preview")
	await shot(school, Vector3(-23.5, 0.05, 35), Vector3(-24.85, 1.8, 34), "realm-handprints-preview")
	await shot(school, Vector3(-45, 0.05, -54.5), Vector3(-45, 2.0, -58.5), "realm-warehouse-preview")
	await shot(school, Vector3(6, 0.05, 56), Vector3(8.4, 1.3, 51), "bully-ghosts-preview")
	school.set_spirit_world(false)
	quit()
