extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(scene: Node3D, pos: Vector3, focus: Vector3, filename: String, flashlight := false) -> void:
	scene.player.position = pos
	scene.player.rotation = Vector3.ZERO
	scene.player.camera.rotation = Vector3.ZERO
	scene.player.camera.look_at(focus)
	scene.player.flashlight.visible = flashlight
	scene._update_light_budget()
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func capture() -> void:
	var scene: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(25):
		await physics_frame
	scene.player.enabled = false
	await shot(scene, Vector3(-70, 53, 95), Vector3(0, 3, -12), "campus-ab-preview")
	await shot(scene, Vector3(1.5, 0.02, -8), Vector3(1.5, 1.6, -38), "connector-preview", true)
	await shot(scene, Vector3(1.5, 0.02, -40.5), Vector3(26, 1.6, -40.5), "annex-hall-preview", true)
	await shot(scene, Vector3(-21, 0.02, -44.5), Vector3(-21, 1.6, -59), "library-preview", true)
	await shot(scene, Vector3(0, 0.02, -44.5), Vector3(0, 1.6, -59), "annex-classroom-preview", true)
	await shot(scene, Vector3(21, 0.02, -44.5), Vector3(21, 1.6, -59), "lab-preview", true)
	await shot(scene, Vector3(-45, 0.02, -48.5), Vector3(-45, 1.6, -57), "warehouse-preview", true)
	await shot(scene, Vector3(-36, 0.02, -43), Vector3(-45, 2, -52), "warehouse-exterior-preview", true)
	await shot(scene, Vector3(31.5, 3.92, 54), Vector3(31.5, 5.5, 34), "classroom-preview", true)
	await shot(scene, Vector3(30, 11.72, 52), Vector3(32, 12.2, 18), "rooftop-preview")
	await shot(scene, Vector3(22.5, 11.72, 37), Vector3(0, 2, 32), "rooftop-courtyard-preview")
	scene.map_panel.show()
	await shot(scene, Vector3(1.5, 0.02, -25), Vector3(1.5, 1.6, -38), "map-preview")
	scene.map_panel.hide()
	scene.set_spirit_world(true)
	scene.player.enabled = false
	await shot(scene, Vector3(1.5, 0.02, -8), Vector3(1.5, 1.6, -38), "spirit-connector-preview", true)
	quit()
