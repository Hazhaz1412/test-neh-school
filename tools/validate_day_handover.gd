extends SceneTree
# Night 1 won, Enter on the dawn screen must open the town.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.finished = true
	school.survival.won = false
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(10): await process_frame
	var stayed := current_scene == school
	print(("PASS  " if stayed else "FAIL  ") + "losing the night keeps the player at the school")
	school.survival.won = true
	key = key.duplicate()
	Input.parse_input_event(key)
	for i in range(240):
		await process_frame
		if current_scene != school and current_scene != null:
			break
	var moved := current_scene != null and current_scene.name == "Town"
	print(("PASS  " if moved else "FAIL  ") + "dawn hands over to the town")
	quit(0 if stayed and moved else 1)
