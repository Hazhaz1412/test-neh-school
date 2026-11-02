extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(10): await physics_frame
	school.survival.start_run()
	var opening: Node3D = school.survival.opening
	opening.set_process(false)
	for entry in [[8.0,"opening-arrival-preview"],[17.5,"opening-service-lock-preview"],[24.0,"opening-service-entry-preview"]]:
		opening.sample(entry[0])
		for i in range(10): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/"+entry[1]+".png")
	opening.finish()
	school.queue_free()
	for i in range(5): await physics_frame
	quit()
