extends "res://tools/validate_progression.gd"
# The storm-drain slide: a rider who leans into each gap gets through, a rider hugging a wall
# does not, and every gate leaves exactly one lane open.
# godot --headless --fixed-fps 60 --path . --script tools/validate_chute.gd
# godot --path . --resolution 1280x720 --script tools/validate_chute.gd -- shots

func ride(chute: Node3D, index: int, policy: String) -> int:
	var p: CharacterBody3D = school.player
	chute.reset()
	chute.enter(index)
	var steps := 0
	while chute.active and steps < 60 * 60:
		match policy:
			"lean":
				var wanted := clampf((chute.safe_arc(chute.metres) - chute.arc) * 0.9, -1.0, 1.0)
				chute.look(Vector2((wanted - chute.lean) / p.LOOK_SENSITIVITY, 0))
			"left": chute.look(Vector2(-200, 0))
			"right": chute.look(Vector2(200, 0))
		chute.spiders.clear()
		chute.tick(1.0 / 60.0)
		p.health = 100.0
		steps += 1
	return chute.hits

func validate() -> void:
	root.get_tree().set_meta("story_stay_in_school", true)
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	story = school.progression
	story.begin_first_chase()
	story.set_physics_process(false)
	school.player.set_physics_process(false)
	var runner: Node3D = story.runner
	var chute: Node3D = runner.chute
	await frames(5)
	for index in range(2):
		var plan: Array = chute.plan_gates(index)
		check(plan.all(func(g): return g.closed.size() == 2 and (g.then.is_empty() or g.then.size() == 2)), "Slide %d: every gate leaves exactly one lane open" % (index + 1))
		check(plan.size() >= (6 if index == 0 else 10), "Slide %d keeps the rider busy: %d gates" % [index + 1, plan.size()])
		check(plan.filter(func(g): return not g.then.is_empty()).size() >= (1 if index == 0 else 2), "Slide %d has gates that switch late" % (index + 1))
		var tightest := 999.0
		for g in range(1, plan.size()): tightest = minf(tightest, plan[g].at - plan[g - 1].at)
		var top_speed: float = chute.SPEED + chute.SPEED_GAIN
		check(tightest / top_speed >= 1.3, "Slide %d: at least %.2f s between two gates even at top speed" % [index + 1, tightest / top_speed])
		check((chute.HAND_SEEN - chute.HAND_RISEN) / top_speed >= 1.5 and chute.SWITCH_LEAD / top_speed >= 1.1, "Slide %d: rods show over 1.5 s before full length, a switch over 1.1 s before the gate" % (index + 1))
		var clean := ride(chute, index, "lean")
		chute.used.clear()
		var left := ride(chute, index, "left")
		chute.used.clear()
		var right := ride(chute, index, "right")
		chute.used.clear()
		check(clean <= 1, "Slide %d: leaning into each gap gets through (%d hits)" % [index + 1, clean])
		check(left >= plan.size() / 2 and right >= plan.size() / 2, "Slide %d: hugging a wall is never safe (left %d, right %d of %d gates)" % [index + 1, left, right, plan.size()])
	var shots: Array = OS.get_cmdline_user_args()
	if not shots.is_empty() and DisplayServer.get_name() != "headless":
		chute.reset()
		chute.enter(0)
		for i in range(90): await process_frame
		runner.scares.flash.color = Color(0, 0, 0, 0)
		for at in [[20.0, 0.0, "slide-rebar-ahead"], [44.0, -1.7, "slide-cable"], [90.0, 2.4, "slide-wall-side"]]:
			chute.metres = at[0]
			chute.arc = at[1]
			# Real mouse motion over the window leans the camera; shots look straight down the tube.
			chute.lean = 0.0
			chute.pitch = -0.08
			chute._tick_gates(at[0] - 1.0)
			chute._place()
			var fr: Transform3D = chute.frame(0, chute.metres)
			for g in chute.gates[0]:
				var vis := 0
				for key in g.sets:
					for rod in g.sets[key]:
						if rod.node.visible: vis += 1
				if vis > 0: print("  gate at ", g.at, " closed ", g.closed, " then ", g.then, " visible rods ", vis, " sample ", g.sets.closed[0].node.global_position if not g.sets.closed.is_empty() else null, " scale ", g.sets.closed[0].node.transform.basis.get_scale() if not g.sets.closed.is_empty() else null)
			print("SHOT ", at[2], " heading=", -fr.basis.z, " prot=", school.player.rotation, " camrot=", school.player.camera.rotation, " pos=", school.player.global_position, " campos=", school.player.camera.global_position)
			await frames(6)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/%s.png" % at[2])
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
