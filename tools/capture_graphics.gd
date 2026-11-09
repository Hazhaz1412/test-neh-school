extends SceneTree
# Before/after look check: godot --path . --script tools/capture_graphics.gd --resolution 1280x720
var school: Node3D
func _initialize() -> void:
	call_deferred("run")

func shot(title: String) -> void:
	for i in range(24): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/gfx-" + title + ".png")

func view(at: Vector3, target: Vector3) -> void:
	school.player.position = at
	school.player.camera.look_at_from_position(at + Vector3.UP * 1.6, target)

func run() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.survival.set_physics_process(false)
	school.player.set_physics_process(false)
	school.progression.set_physics_process(false)
	for i in range(5): await physics_frame
	school.player.flashlight.show()
	view(Vector3(-20, 7.85, 6.3), Vector3(-60, 9.2, 6.3))
	await shot("corridor")
	view(Vector3(0, 0.05, 60), Vector3(0, 6, 0))
	await shot("courtyard")
	var guard: Node3D = load("res://scripts/chase_guard.gd").new()
	school.add_child(guard)
	var spot := Vector3(-20, 7.85, 6.3)
	await process_frame
	guard.global_position = spot + Vector3(-3.2, 0, 0)
	guard.show()
	guard.look_at(spot + Vector3.UP * 0.01)
	guard.model.set_process(true)
	guard.model.animation.speed_scale = 1.0
	guard.model.animation.play("walk")
	view(spot, spot + Vector3(-3.2, 1.3, 0))
	await shot("guard")
	guard.model.animation.play("sprint")
	await shot("guard-run")
	guard.model.animation.play("idle")
	guard.model.melee_swing = 0.45
	await shot("guard-attack")
	guard.model.melee_swing = -1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	view(Vector3(0, 0.05, 60), Vector3(0, 6, 0))
	for level in range(3):
		school.set_quality(level, false)
		for i in range(30): await process_frame
		var started := Time.get_ticks_usec()
		for i in range(120): await process_frame
		print("level ", level, " frame_ms=", snappedf((Time.get_ticks_usec() - started) / 120000.0, 0.01))
	print("capture done")
	quit()
