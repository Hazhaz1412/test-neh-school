extends SceneTree

var school: Node3D

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func shot(filename: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func capture() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	await frames(20)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	await frames(6)
	var player: CharacterBody3D = school.player
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	school.survival.set_physics_process(false)
	school.camera_flash.set_process(false)
	# A staged encounter using the actual four archetypes, not extra enemies.
	var staged := {}
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		ghost.position = Vector3(54, 0.05, 65)
		if not staged.has(ghost.archetype):
			staged[ghost.archetype] = ghost
	var x := -3.0
	for ghost in staged.values():
		ghost.position = Vector3(x, 0.05, 43)
		ghost.look_at(Vector3(0, 0.05, 50))
		ghost._play("idle")
		x += 2
	player.position = Vector3(0, 0.05, 50)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(Vector3(0, 1.6, 43))
	player.select_item("camera")
	school.notice_time = 0
	await frames(20)
	await shot("camera-ready-preview")
	assert(player.take_photo())
	await shot("camera-flash-preview")
	school.camera_flash._process(0.7)
	for ghost in school.enemies:
		ghost._physics_process(school.camera_banish_seconds + 0.1)
	await shot("camera-return-preview")
	player.select_item("chalk")
	assert(player.begin_chalk_charge("mouse"))
	player.tick_chalk_charge(1.5)
	await shot("chalk-charge-preview")
	player.cancel_chalk_charge()
	school.queue_free()
	await frames(4)
	quit()
