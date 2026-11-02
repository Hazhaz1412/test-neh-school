extends "res://tools/validate_progression.gd"
# Stills of the slide and the fixed corridor set pieces:
# godot --path . --resolution 1280x720 --script tools/capture_slide.gd -- <folder>
var out := ""

func shot(title: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(title + ".png"))

func teleport(runner: Node3D, meters: float, side := 0.0, turn := 0.0) -> void:
	var at: Transform3D = runner.route_frame(meters)
	school.player.global_position = runner.ORIGIN + at.origin + at.basis.x * side + Vector3.UP * 0.05
	school.player.rotation.y = at.basis.get_euler().y + turn
	runner.distance = meters

func validate() -> void:
	out = OS.get_cmdline_user_args()[0]
	root.get_tree().set_meta("story_stay_in_school", true)
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.set_spirit_world(true, true)
	story = school.progression
	story.begin_first_chase()
	var runner: Node3D = story.runner
	school.player.test_invincible()
	story.set_physics_process(false)
	await frames(10)
	for ghost in runner.ghosts:
		ghost.hide()
	teleport(runner, 107.0, 2.0, 0.0)
	await shot("row_left_gap")
	teleport(runner, 64.0, 0.0)
	await shot("slide_gate")
	teleport(runner, 374.0, 0.0)
	await frames(30)
	await shot("hole")
	var chute: Node3D = runner.chute
	chute.enter(0)
	chute.metres = 30.0
	chute._tick_gates(29.0)
	chute._place()
	await shot("slide_hands_far")
	chute.metres = 98.0
	chute.arc = 1.7
	chute.pitch = -0.1
	chute._tick_gates(97.0)
	chute._place()
	await shot("slide_hands_near")
	chute.spiders.swarm(6)
	for i in range(120):
		chute.spiders.tick(1.0 / 60)
	chute._place()
	await shot("slide_spiders")
	chute.arc = 2.2
	chute.lean = 0.6
	chute.spiders.clear()
	chute._place()
	await shot("slide_lean")
	quit(0)
