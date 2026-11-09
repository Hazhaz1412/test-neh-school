extends "res://tools/validate_progression.gd"
func validate() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	await frames(15)
	var director: Node3D = school.survival
	director.start_run()
	var opening: Node3D = director.opening
	opening.set_process(false)
	school.player.set_physics_process(false)
	director.set_physics_process(false)
	check(opening.playing and opening.DURATION == 34 and not school.player.enabled, "Arrival opening locks player controls for a 34-second cinematic")
	check(director.clock_text() == "22:30", "Arrival begins at 22:30")
	check(opening.actors.size() == 4 and opening.equipment.size() == 4 and opening.camera.current, "Animated party arrives with equipment, without the old evidence-board scene")
	var entry: Node3D = school.get_node("Campus/ServiceEntry")
	var saw_passage := false
	for sample in [8.0, 17.5, 20.5, 24.0, 26.5, 28.0, 31.0, 33.0]:
		opening.sample(sample)
		await frames(2)
		for actor in opening.actors:
			check(absf(actor.position.y-0.05) < 0.1, "Party feet remain on the ground")
		if sample == 24.0: saw_passage = absf(entry.get_node("Hinge/Leaf").rotation.y) > 1
	check(saw_passage, "Party enters through the open service door")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	opening._input(event)
	var before: float = opening.elapsed
	opening._process(2)
	check(opening.paused and opening.elapsed == before, "Escape pauses the cinematic")
	opening._input(event)
	event.keycode = KEY_ENTER
	opening._input(event)
	await frames(5)
	check(not opening.playing and school.player.enabled and school.player.camera.current and opening.actors.size() == 3, "Skip hands controls to the real player and leaves three companions")
	check(director.clock_text() == "22:30" and director.phase == director.Phase.PREPARATION and school.player.can_fit(school.player.position), "Gameplay handoff has a clear capsule and starts the new clock")
	director.advance_clock(240)
	check(director.clock_text() == "00:30", "Waiting past midnight does not replace environmental story triggers")
	print("RESULT / opening ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	# Allow the audio mixing thread to release playbacks before process exit.
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
