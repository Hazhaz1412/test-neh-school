extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(scene: Node3D, pos: Vector3, focus: Vector3, filename: String, flashlight := false) -> void:
	scene.player.position = pos
	scene.player.camera.rotation = Vector3.ZERO
	scene.player.rotation = Vector3.ZERO
	scene.player.camera.look_at(focus)
	scene.player.flashlight.visible = flashlight
	scene._update_light_budget()
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func capture() -> void:
	var scene: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(15):
		await process_frame
	scene.player.enabled = false
	await shot(scene, Vector3(0, 0.02, 64), Vector3(0, 6.2, 10), "campus-preview")
	await shot(scene, Vector3(0, 0.02, 49), Vector3(0, 3.0, 25), "courtyard-preview")
	await shot(scene, Vector3(0, 0.02, 40), Vector3(0, 1.8, 32), "fountain-preview")
	await shot(scene, Vector3(-23.5, 7.82, 44), Vector3(0, 0.9, 32), "third-floor-preview")
	await shot(scene, Vector3(23.5, 3.92, 40), Vector3(-2, 2.5, 25), "second-floor-preview")
	await shot(scene, Vector3(36.9, 0.02, 39.3), Vector3(71.7, 25.62, -3.3), "window-moon-preview")
	await shot(scene, Vector3(31.5, 3.92, 54), Vector3(31.5, 5.5, 34), "classroom-preview", true)
	await shot(scene, Vector3(-23.5, 0.02, 52), Vector3(-23.5, 1.6, 12), "hallway-preview", true)
	await shot(scene, Vector3(0, 0.02, 6.2), Vector3(-4.5, 4, -2), "stairs-preview", true)
	await shot(scene, Vector3(-43, 0.02, 52), Vector3(-44, 0.6, 37), "garden-preview")
	await shot(scene, Vector3(44, 0.02, 65), Vector3(39, 5, 25), "sports-preview")
	await shot(scene, Vector3(-60, 32, 88), Vector3(0, 3.8, 27), "layout-preview")
	await shot(scene, Vector3(23.5, 0.02, 28), Vector3(25, 1.6, 25), "classroom-door-preview", true)
	scene.map_panel.show()
	await shot(scene, Vector3(0, 0.02, 64), Vector3(0, 6.2, 10), "map-preview")
	quit()
