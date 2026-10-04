extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func shot(filename: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func capture() -> void:
	var school: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	school.set_process_unhandled_input(false)
	current_scene = school
	await frames(10)
	school.survival.start_run()
	var opening: Node3D = school.survival.opening
	opening.set_process(false)
	school.player.set_physics_process(false)
	school.player.set_process_unhandled_input(false)
	school.survival.set_physics_process(false)
	for entry in [[4.0, "opening-evidence-preview"], [14.0, "opening-investigation-preview"], [26.0, "opening-agreement-preview"], [33.5, "opening-equipment-preview"], [42.0, "opening-arrival-preview"], [47.5, "opening-team-preview"], [53.5, "opening-service-lock-preview"], [60.0, "opening-service-entry-preview"], [63.5, "opening-glimpse-preview"]]:
		opening.sample(entry[0])
		await shot(entry[1])
	opening.finish()
	await frames(4)
	await shot("opening-2330-preview")
	school.survival.advance_clock(59.9)
	await shot("opening-2359-preview")
	school.survival.advance_clock(0.1)
	await frames(5)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	await shot("opening-midnight-preview")
	school.queue_free()
	await frames(3)
	quit()
