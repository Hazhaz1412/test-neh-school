extends SceneTree

var school: Node3D

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func shot(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/horror-" + label + ".png")

func capture() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	school.player.set_physics_process(false)
	await frames(30)
	school.scares.set_process(false)
	school.encounters.set_physics_process(false)
	school.set_spirit_world(true)
	for enemy in school.enemies:
		enemy.set_dormant(true)
		enemy.set_physics_process(false)
	school.player.position = Vector3(-23.5, 0.05, 49)
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(Vector3(-23.5, 1.5, 30))
	school.player.flashlight.show()
	school._update_light_budget()
	await frames(4)
	await shot("hallway")
	var s: Node3D = school.scares
	if not s.try_start(s.Kind.LAUGHING_STUDENT):
		push_error("No apparition stage in hallway")
		quit(1)
		return
	s._process(0.18)
	await shot("laughing-student")
	s._process(0.82)
	await shot("student-retreat")
	s.reset()
	if not s.try_start(s.Kind.THROWN_CHAIR):
		push_error("No chair stage")
		quit(1)
		return
	s._process(0.24)
	await shot("flying-chair")
	s.reset()
	if not s.try_start(s.Kind.LAMP_POP):
		push_error("No local lamp")
		quit(1)
		return
	s.set_process(true)
	await shot("lamp-pop")
	s.set_process(false)
	s.reset()
	school.player.position = Vector3(-23.0, 0.05, 47)
	school.player.camera.look_at(Vector3(-24.3, 0.6, 45))
	school._update_light_budget()
	await shot("abandoned-props")
	print("Captured six actual horror-polish views")
	quit()
