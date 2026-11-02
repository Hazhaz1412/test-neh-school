extends SceneTree
# The lettering in place: godot --path . --resolution 1280x720 --script tools/capture_type.gd -- <folder>
var out := ""

func shot(title: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("type_" + title + ".png"))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in range(20):
		await process_frame
	await shot("menu")
	menu.queue_free()
	await process_frame
	root.get_tree().set_meta("story_stay_in_school", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(15):
		await physics_frame
	school.survival.start_run(false)
	school.set_spirit_world(true, true)
	var story: Node3D = school.progression
	story.begin_first_chase()
	var runner: Node3D = story.runner
	school.player.test_invincible()
	await shot("hud")
	var at: Transform3D = runner.route_frame(120.0)
	school.player.global_position = runner.ORIGIN + at.origin + Vector3.UP * 0.05
	school.player.rotation.y = at.basis.get_euler().y + 0.35
	runner.distance = 120.0
	await shot("wall")
	runner.scares.fire([0, "text", "NÓ Ở SAU LƯNG"])
	await shot("shout")
	runner.skip_to_refuge()
	for i in range(100):
		await process_frame
	await shot("dialogue")
	quit()
