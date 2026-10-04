extends SceneTree

var school: Node3D

func _initialize() -> void:
	call_deferred("capture")

func shot(filename: String) -> void:
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func place(pos: Vector3, focus: Vector3) -> void:
	school.player.global_position = pos
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(focus)
	school._update_light_budget()
	for i in range(3):
		await physics_frame

func e() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	school.player._unhandled_input(key)

func capture() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.player.set_physics_process(false)
	for i in range(25):
		await physics_frame
	var cabinet: Node3D = school.get_node("HidingSpots/HallA_0")
	await place(Vector3(17.8, 0.05, 8.35), cabinet.to_global(Vector3(0, 1.25, 0.68)))
	school.player.flashlight.visible = true
	await shot("hiding-locker-preview")
	await place(cabinet.approach_position(), cabinet.to_global(Vector3(0, 1.1, 0.72)))
	e()
	assert(school.player.is_hidden())
	school.notice_time = 0
	await shot("hiding-locker-inside")
	e()
	var table: Node3D = school.get_node("HidingSpots/WarehouseTable")
	await place(table.approach_position(), table.to_global(Vector3(0, 0.55, 0.72)))
	await shot("hiding-table-preview")
	e()
	assert(school.player.is_hidden())
	school.notice_time = 0
	await shot("hiding-table-inside")
	e()
	school.set_spirit_world(true)
	for i in range(10):
		await physics_frame
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	# Capture the actual rush pose while its CharacterBody runs toward the camera.
	await place(Vector3(8, 0.05, 52), Vector3(8, 1.4, 44))
	school.player.flashlight.visible = true
	var ghost: CharacterBody3D = school.enemies[0]
	for other in school.enemies:
		if other != ghost:
			other.hide()
	ghost.position = Vector3(8, 0.05, 44)
	ghost.look_at(school.player.position)
	ghost.state = 0
	ghost.vision_clock = 0
	ghost.rush_clock = 0
	for i in range(3):
		await physics_frame
	ghost.set_physics_process(true)
	for i in range(65):
		await physics_frame
	assert(ghost.state == 2 and ghost.rush_time > 0)
	ghost.set_physics_process(false)
	await shot("ghost-rush-preview")
	school.set_spirit_world(false)
	school.queue_free()
	for i in range(3):
		await physics_frame
	quit()
