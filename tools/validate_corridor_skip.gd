extends SceneTree
# F10 must leave the red corridor in the same state as finishing it.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_tree().set_meta("story_stay_in_school", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.set_spirit_world(true, true)
	var story: Node3D = school.progression
	story.begin_first_chase()
	for i in range(30): await physics_frame
	var runner: Node = story.runner
	print(("PASS  " if runner.active else "FAIL  ") + "the corridor is running")
	var key := InputEventKey.new()
	key.keycode = KEY_F10
	key.physical_keycode = KEY_F10
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(10): await process_frame
	var ok: bool = not runner.active and story.stage == story.Stage.LAN_DIALOGUE and story.panel_visible() and runner.in_refuge(school.player.global_position)
	print(("PASS  " if ok else "FAIL  ") + "F10 lands in Lan's room with her dialogue open")
	quit(0 if ok else 1)
