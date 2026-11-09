extends SceneTree
var school: Node3D
var story: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("validate")

func frames(count := 3) -> void:
	for i in range(count): await physics_frame

func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS / " if ok else "FAIL / ", description)
	if not ok: failures += 1

func finish_lan_dialogue() -> void:
	for id in story.dialogue_data.lan.required:
		for index in range(story.dialogue_data.lan.questions.size()):
			if story.dialogue_data.lan.questions[index].id!=id: continue
			story.lan_view.reveal()
			story.lan_view.select_choice(index)
			for turn in range(2):
				story.lan_view.reveal()
				story.lan_view.select_choice(0)
	story.lan_view.reveal()
	story.lan_view.select_choice(story.lan_view.choices.get_child_count()-1)

func approach(item: Node3D, aim_height := 0.35) -> bool:
	for radius in [1.3, 1.8, 0.9, 2.1]:
		for angle in range(16):
			var feet: Vector3 = item.global_position + Vector3(cos(angle*TAU/16), 0, sin(angle*TAU/16))*radius
			feet.y = item.global_position.y+0.05
			if not school.player.can_fit(feet): continue
			school.player.global_position = feet
			school.player.camera.look_at(item.global_position+Vector3.UP*aim_height)
			await frames(1)
			if school.player.get_interaction_target() == item: return true
	return false

func run_until(condition: Callable, seconds: float) -> bool:
	for i in range(int(seconds * 60)):
		if condition.call(): return true
		await process_frame
	return condition.call()

func validate_guard() -> void:
	var gp: Node3D = story.guard_part
	var guard: Node3D = gp.guard
	var F1 := 0.05
	var F2 := 3.95
	var F3 := 7.85
	story.set_physics_process(true)
	check(await run_until(func(): return story.stage == story.Stage.HIDE, 3.0), "A moment after the mirror the guard calls out")
	check(guard.visible and absf(guard.global_position.y - F2) < 0.3 and guard.global_position.x < 0 and story.subtitle_label.visible and story.subtitle_label.text.contains("Ai đó"), "He shouts from the top of the stairs on floor 2")
	# Hide: into the last stall, shut the door from inside with the real E ray.
	var stall: Node3D = story.restroom.stall_doors[5]
	school.player.global_position = Vector3(21.15, F2, -10.1 + 5 * 1.55 + 0.78)
	school.player.rotation.y = PI / 2
	school.player.camera.rotation = Vector3(-0.15, 0, 0)
	await frames(2)
	var handle: Node3D = stall.get_node("StallHandle")
	check(school.player.get_interaction_target() == handle and handle.interact(school.player), "The stall door closes from inside with E")
	check(story.restroom.player_in_closed_stall(), "The player counts as hidden inside the shut stall")
	var seen := {"prompt": false, "held": 0.0, "lowest": 100.0, "frames": 0, "arrive": -1.0}
	var watch := func():
		seen.frames += 1
		if seen.arrive < 0.0 and guard.global_position.z < 6.0 and guard.global_position.x > 7.0 and absf(guard.global_position.y - F2) < 0.5:
			seen.arrive = seen.frames / 60.0
		# A careful player: hold the breath exactly while he is right outside.
		gp.test_hold = gp.breath_close
		if gp.breath_panel.visible: seen.prompt = true
		if gp.breath_held(): seen.held += 1.0 / 60.0
		seen.lowest = minf(seen.lowest, gp.breath)
		return gp.part == gp.Part.STEALTH or gp.fail_clock >= 0.0
	check(await run_until(watch, 200.0) and gp.fail_clock < 0.0, "Hidden in the stall and holding the breath at the right moments, the guard never finds the player")
	gp.test_hold = false
	check(seen.arrive > 3.5 and seen.arrive < 7.0, "He runs straight up into the restroom about five seconds after the shout (%.1f s)" % seen.arrive)
	var shoved := range(5).all(func(i): return story.restroom.stall_open(i))
	check(shoved and not story.restroom.stall_open(5), "In the restroom he shoved open every other stall, leaving the player's for last")
	check(seen.prompt and seen.held > 2.0 and seen.lowest > 0.0, "Next to the player's stall the breath had to be held (%.1f s), without running out" % seen.held)
	check(guard.global_position.z < 6.0 and story.stage == story.Stage.STEALTH and gp.hud.visible, "At the player's door the noise upstairs takes him away and stealth begins")
	school.player.battery = 100
	school.player.select_item("camera")
	check(not school.player.take_photo(), "The camera does not fire in the restroom or on the tail")
	# The stall test leaves the player behind; losing him is checked further down.
	gp.follow_grace = 1e9
	check(await run_until(func(): return guard.global_position.y > F3 - 0.2, 60.0), "He climbs to the third floor")
	# Hearing: a sprint behind him is heard, a crouch at the same distance is not.
	var behind: Vector3 = guard.global_position + guard.global_basis.z * 5.0
	behind.y = F3
	var before: float = guard.awareness
	school.emit_noise(behind, school.player.movement_noise(false, true), "steps")
	check(guard.awareness == before, "Crawling five metres behind him makes no sound he can hear")
	school.emit_noise(behind, school.player.movement_noise(true, false), "steps")
	check(guard.awareness > before + 0.1 and guard.busy_with("face"), "Running five metres behind him: he hears it and turns")
	# Sight: standing in his torch beam gets the player caught, then the follow restarts.
	await frames(60)
	var ahead: Vector3 = guard.global_position - guard.global_basis.z * 4.0
	school.player.global_position = Vector3(ahead.x, guard.global_position.y, ahead.z)
	check(await run_until(func(): return gp.fail_clock >= 0.0, 4.0), "Standing in his torch beam, the player is caught")
	check(await run_until(func(): return gp.fail_clock < 0.0, 3.0) and gp.part == gp.Part.STEALTH and school.player.global_position.y < 5 and guard.global_position.distance_to(gp.NEAR_RESTROOM) < 3.0, "Being caught restarts the tail from the restroom")
	# Falling far behind loses him.
	gp.follow_grace = 0.0
	await run_until(func(): return gp.follow_grace <= 0.0 and guard.global_position.distance_to(school.player.global_position) > gp.LOSE_RANGE + 1.0, 40.0)
	check(await run_until(func(): return gp.warn.visible, 2.0), "Too far behind, a warning says he is getting away")
	check(await run_until(func(): return gp.fail_clock >= 0.0, gp.LOSE_SECONDS + 1.0), "Staying too far behind loses him")
	check(await run_until(func(): return gp.fail_clock < 0.0, 3.0) and gp.part == gp.Part.STEALTH, "Losing him restarts the tail")
	# A careful tail: crouched, torch off, sixteen metres behind on his own path, all the way to B-302.
	school.player.flashlight.hide()
	school.player.set_crouching(true, true)
	var trail: Array = []
	var walked := {"total": 0.0}
	var shadow := func():
		var at: Vector3 = guard.global_position
		if trail.is_empty() or at.distance_to(trail[-1][1]) > 0.25:
			if not trail.is_empty(): walked.total += at.distance_to(trail[-1][1])
			trail.append([walked.total, at])
		var want: float = walked.total - 16.0
		if want > 0.0:
			for point in trail:
				if point[0] >= want:
					school.player.global_position = point[1]
					break
		return gp.part == gp.Part.PHOTO or gp.fail_clock >= 0.0
	check(await run_until(shadow, 180.0) and gp.fail_clock < 0.0, "Tailing him crouched sixteen metres back, torch off, he never notices and is never lost")
	check(gp.part == gp.Part.PHOTO and guard.busy_with("work") and school.get_node("Architecture/ClassroomDoor1302").is_open and guard.global_position.distance_to(gp.DESK_STAND) < 0.4, "He goes up to block B and works at the teacher's desk in B-302 with the door open")
	check(school.player.global_position.y > F3 - 0.3 and school.player.global_position.z < -30.0, "The tail ends on block B's top floor")
	# The photo from behind him, between the desks.
	school.player.global_position = Vector3(-1.2, F3, -46.5)
	school.player.look_at(Vector3(gp.EVIDENCE.x, F3, gp.EVIDENCE.z))
	school.player.camera.look_at(gp.EVIDENCE)
	await frames(30)
	check(gp.fail_clock < 0.0, "Crouched behind him among the desks, the player is not noticed")
	check(gp.evidence_in_frame(), "The papers are framed from there")
	school.player.battery = 100
	school.player.select_item("camera")
	check(school.player.take_photo() and story.evidence.has("photo") and school.journal.found.size() == 3, "The photo is the third clue")
	check(gp.part == gp.Part.DUCK and gp.duck_panel.visible, "The flash gives the player away: four seconds to hide")
	school.player.set_crouching(false, true)
	# Not hiding: he has the player when the four seconds run out, and the dash starts again.
	check(await run_until(func(): return gp.fail_clock >= 0.0, gp.DUCK_SECONDS + 0.5), "Not in a locker after four seconds: caught")
	check(await run_until(func(): return gp.fail_clock < 0.0, 3.0) and gp.part == gp.Part.DUCK and gp.duck_clock > gp.DUCK_SECONDS - 0.3, "The four seconds start again from the doorway")
	check(story.stage == story.Stage.ESCAPE_RUN and not school.player.take_photo(), "The camera is off again once he is after the player")
	# Into the nearest hall locker through the real E ray.
	var locker: Node3D = school.get_node("HidingSpots/HallB_2b")
	var dash_from: Vector3 = school.player.global_position
	check(dash_from.distance_to(locker.approach_position()) < 9.0, "The nearest locker is %.1f m from the doorway, two seconds at a run" % dash_from.distance_to(locker.approach_position()))
	check(await approach(locker, 1.0) and locker.interact(school.player), "The locker is entered with E")
	check(await run_until(func(): return gp.part == gp.Part.SEARCH, gp.DUCK_SECONDS + 0.5), "Inside a locker when the time is up, he comes out searching")
	var heard := {"held": 0.0}
	var hold := func():
		gp.test_hold = gp.breath_close
		if gp.breath_held(): heard.held += 1.0 / 60.0
		return gp.part == gp.Part.SNEAK or gp.fail_clock >= 0.0
	check(await run_until(hold, 30.0) and gp.fail_clock < 0.0, "He listens at the locker; holding the breath, the player is not found")
	gp.test_hold = false
	check(heard.held > 1.5, "The breath had to be held while he stood at the locker (%.1f s)" % heard.held)
	check(gp.part == gp.Part.SNEAK and guard.hunting and gp.hud.visible, "He goes off to hunt the floors")
	check(school.player.end_hide(), "The player climbs out of the locker")
	# The hunt: standing still out of his way, he gets a feel for where the player is and comes.
	var nav: RID = school.get_world_3d().navigation_map
	school.player.global_position = Vector3(-14.0, F2, 7.5)
	gp.hunch_clock = 0.0
	var start_gap: float = guard.global_position.distance_to(school.player.global_position)
	check(await run_until(func(): return guard.global_position.distance_to(school.player.global_position) < 10.0 or gp.hunt_mode == "chase" or gp.fail_clock >= 0.0, 45.0), "Standing still, he homes in on the player (from %.0f m away)" % start_gap)
	await run_until(func(): return gp.fail_clock < 0.0 and gp.part == gp.Part.SNEAK, 6.0)
	# A run within earshot: he turns and walks over to look.
	gp.hunch_clock = 99.0
	school.player.global_position = Vector3(-23.5, F1, 40)
	await frames(30)
	var noise_at: Vector3 = guard.global_position + guard.global_basis.z * 6.0
	noise_at = NavigationServer3D.map_get_closest_point(nav, noise_at) - Vector3.UP * 0.35
	guard.heard_clock = 0.0
	guard.awareness = 0.0
	school.emit_noise(noise_at, school.player.movement_noise(true, false), "steps")
	var gap_before: float = guard.global_position.distance_to(noise_at)
	await run_until(func(): return guard.global_position.distance_to(noise_at) < 1.5, 8.0)
	check(guard.global_position.distance_to(noise_at) < minf(gap_before, 2.0), "A run nearby: he walks over to where it came from")
	guard.awareness = 0.0
	# Seen: he runs at the player instead of standing there.
	guard.place(Vector3(-10.0, F2, 7.5), Vector3(-20.0, F2, 7.5))
	guard.run([guard.wait(5.0, "idle")])
	school.player.global_position = Vector3(-14.5, F2, 7.5)
	var ok_chase: bool = await run_until(func(): return gp.hunt_mode == "chase", 3.0)
	check(ok_chase and gp.fail_clock < 0.0 and guard.deaf, "Seen, he gives chase")
	school.player.global_position = Vector3(-23.5, F1, 40)
	check(await run_until(func(): return gp.hunt_mode == "search", gp.LOSE_SIGHT + 1.5), "Out of his sight long enough, he loses the player and searches where they vanished")
	check(await run_until(func(): return gp.hunt_mode == "hunt", 40.0) and not guard.deaf, "Then he goes back to hunting")
	# Run down: he catches the player when he gets to them.
	await run_until(func(): return gp.fail_clock < 0.0, 3.0)
	gp.hunch_clock = 99.0
	gp.hunt_mode = "hunt"
	guard.place(Vector3(-10.0, F2, 7.5), Vector3(-20.0, F2, 7.5))
	guard.run([guard.wait(5.0, "idle")])
	school.player.global_position = Vector3(-13.5, F2, 7.5)
	check(await run_until(func(): return gp.fail_clock >= 0.0, 4.0), "Seen close up, he runs the player down")
	await run_until(func(): return gp.fail_clock < 0.0, 3.0)
	check(gp.part == gp.Part.SNEAK and school.player.global_position.distance_to(gp.SNEAK_START) < 0.5 and guard.visible and absf(guard.global_position.y - F3) < 0.6, "The sneak restarts by the lockers, with him on the same floor")
	var back_gap: float = guard.global_position.distance_to(school.player.global_position)
	school.player.global_position = Vector3(-14.0, F3, -40.5)
	await run_until(func(): return gp.fail_clock >= 0.0 or guard.global_position.distance_to(school.player.global_position) < back_gap - 8.0, 10.0)
	check(gp.fail_clock >= 0.0 or guard.global_position.distance_to(school.player.global_position) < back_gap - 8.0, "After a catch he comes straight back for the player, not off somewhere else")
	await run_until(func(): return gp.fail_clock < 0.0, 3.0)
	# A locker he opens is no hiding place.
	var trap: Node3D = school.get_node("HidingSpots/HallB_2")
	trap.occupant = school.player
	trap.entry_position = trap.approach_position()
	school.player.begin_hide(trap)
	guard.place(Vector3(2.0, F3, -40.5), trap.global_position)
	guard.run(gp._spot_checks(trap.global_position, 1))
	check(await run_until(func(): return gp.fail_clock >= 0.0, 10.0), "Hiding in the locker he decides to open gets the player caught")
	await run_until(func(): return gp.fail_clock < 0.0, 3.0)
	# Out in the yard by the gate: he shouts down from the window, and the gate is chained.
	var escape: Node3D = story.escape
	school.player.global_position = Vector3(1.0, F1, 63.0)
	school.player.rotation.y = 0.0
	check(await run_until(func(): return story.stage == story.Stage.GATE_BREAK, 1.0) and escape.active and escape.segment == escape.Segment.CALL, "Near the gate the guard calls out")
	check(guard.visible and absf(guard.global_position.y - F3) < 0.3 and guard.global_position.z < 10.0 and escape.beam.visible and escape.beam_glare.visible, "He stands at a third-floor window with his torch on the player")
	check(story.controls_player() and story.subtitle_label.text.contains("Đứng yên"), "\"Đứng yên đó!\": the player is held for the cutscene")
	check(await run_until(func(): return escape.segment == escape.Segment.BREAK_IN, escape.CALL_SECONDS + 1.0), "After the cutscene the clock starts")
	check(not story.controls_player() and escape.time_left > escape.TIME_LIMIT - 0.5 and escape.timer_panel.visible, "The player moves freely, with %.0f s on the clock" % escape.time_limit)
	check(await run_until(func(): return escape.guard_phase == "stairs", escape.time_limit - escape.YARD_SECONDS - escape.STAIRS_SECONDS + 1.0) and not guard.visible, "He keeps his torch on the player from the window, then leaves for the stairs")
	escape.time_left = escape.YARD_SECONDS + 0.05
	check(await run_until(func(): return escape.guard_phase == "yard", 1.0) and guard.visible and guard.global_position.z < 12.0, "He comes out of the main entrance")
	var yard_start: Vector3 = guard.global_position
	await run_until(func(): return escape.time_left < escape.YARD_SECONDS * 0.5, escape.YARD_SECONDS)
	check(guard.global_position.z > yard_start.z + 20.0, "He runs across the yard towards the booth")
	# Out of time: caught, and the break-in starts again with more time.
	check(await run_until(func(): return escape.fade_clock > 0.0, escape.YARD_SECONDS), "Out of time, he catches the player")
	check(await run_until(func(): return escape.fade_clock <= 0.0, 2.0) and escape.step == "tool" and escape.attempts == 1 and is_equal_approx(escape.time_limit, escape.TIME_LIMIT + escape.TIME_PER_RETRY), "The break-in restarts with %.0f s" % escape.time_limit)
	check(not escape.has_tool and escape.screwdriver.visible and escape.booth_door.rotation.y == 0.0, "Tool back in the box, door shut")
	# The toolbox through the real E ray: taking the screwdriver goes straight to the lock plate.
	check(await approach(escape.toolbox, -0.05) and escape.toolbox.interact(school.player), "The screwdriver is taken from the toolbox with E")
	check(escape.step == "screws" and escape.breaker.visible and story.controls_player() and school.player.global_position.distance_to(escape.DOOR_STAND) < 0.1, "The player kneels at the lock plate")
	var breaker: Control = escape.breaker
	breaker.size = Vector2(1280, 720)
	# Circling too wide slips off the screw.
	breaker.engage(0, breaker.screw_center(0) + Vector2(60, 0))
	breaker.drag(breaker.screw_center(0) + Vector2(breaker.SLIP + 20, 0))
	check(breaker.held == -1 and breaker.progress(0) == 0.0, "Swinging the mouse too far slips off the screw")
	# Back and forth does nothing; three full circles back a screw out.
	breaker.engage(0, breaker.screw_center(0) + Vector2(60, 0))
	for k in range(12): breaker.drag(breaker.screw_center(0) + Vector2.from_angle(0.4 * (1 if k % 2 == 0 else -1)) * 60.0)
	check(breaker.progress(0) < 0.05, "Wiggling does not turn it")
	for i in range(4):
		breaker.engage(i, breaker.screw_center(i) + Vector2(70, 0))
		for k in range(1, 24 * 3 + 5):
			breaker.drag(breaker.screw_center(i) + Vector2.from_angle(-k * TAU / 24.0) * 70.0)
		if i < 3: check(breaker.removed[i] and not escape.plate_screws[i].visible, "Screw %d is out after three turns" % (i + 1))
	check(escape.step == "kick" and breaker.step == "kick" and not escape.lock_plate.visible, "All four out: the plate drops and the door has to be kicked")
	# Slow kicks fade away; fast ones break it.
	for k in range(6):
		breaker.kick()
		await run_until(func(): return false, 0.5)
	check(breaker.power < 0.3 and escape.step == "kick", "Two kicks a second never get the door open")
	var kicks := 0
	while escape.active and kicks < 60:
		breaker.kick()
		kicks += 1
		await run_until(func(): return false, 1.0 / 9.0)
	check(not escape.active and story.stage == story.Stage.BASEMENT_DESCENT and escape.booth_door.rotation.y < -1.0, "Kicking fast (%d kicks) bursts the door and the player runs down" % kicks)
	print("BREAK-IN / ", escape.report)
	story._physics_process(story.DESCENT_SECONDS + 0.1)
	check(story.stage == story.Stage.CORRIDOR_RUN and story.runner.active, "Down the stairs: the service tunnels")
	var tunnel: Node3D = story.runner
	for i in range(int((tunnel.DOOR_START + 0.4) * 60)): tunnel.tick(1.0 / 60.0)
	check(tunnel.guard_on and tunnel.guard.visible and tunnel.guard.model.variant == "guard", "The guard bursts through the stair door after the player")
	var body_y: float = tunnel.guard.model.visual.global_position.y
	check(absf(body_y - tunnel.guard.global_position.y) < 0.5 and tunnel.guard.model.body_mesh.is_visible_in_tree(), "His body is where his torch is (model %.1f m from his feet)" % absf(body_y - tunnel.guard.global_position.y))
	story.runner.reset()
	story.runner.restore_pose()
	# The corridor to block B: wide, with piers to press in behind when he looks back.
	story.runner.active = false
	gp.reset()
	var hall_floor := PhysicsRayQueryParameters3D.create(Vector3(-1.2, F3 + 1.0, -20.0), Vector3(-1.2, F3 - 0.5, -20.0), 1)
	check(not school.get_world_3d().direct_space_state.intersect_ray(hall_floor).is_empty(), "The corridor to block B is six metres wide")
	guard.place(Vector3(1.5, F3, -36.0), Vector3(1.5, F3, -10.0))
	guard.sweep = 0.0
	var p: CharacterBody3D = school.player
	p.set_crouching(false, true)
	p.global_position = Vector3(-1.1, F3, -23.6)
	p.look_at(Vector3(1.5, F3, -36.0))
	p.lean_offset = 0.0
	p.camera.position.x = 0.0
	await frames(2)
	check(not guard.can_see_player(), "Pressed in behind a pier, he looks straight down the corridor and does not see the player")
	p.lean_offset = 0.6
	p.camera.position.x = 0.6
	await frames(1)
	check(guard.can_see_player(), "Leaning out to peek (Z / X) shows the head: hold it too long and he sees it")
	p.lean_offset = 0.0
	p.camera.position.x = 0.0
	guard.stop()
	# Breathing normally with him right outside the stall gives the player away.
	story.runner.active = false
	gp.part = gp.Part.HIDE
	guard.place(story.restroom.stall_front(5), story.restroom.stall_center(5))
	guard.sensing = true
	guard.awareness = 0.0
	guard.run([guard.wait(30.0, "listen")])
	school.player.global_position = story.restroom.stall_center(5)
	if story.restroom.stall_open(5): story.restroom.toggle_stall(5)
	check(story.restroom.player_in_closed_stall(), "Back in the shut stall for the breathing test")
	check(await run_until(func(): return gp.fail_clock >= 0.0, 8.0), "Not holding the breath with him at the door: he hears it and finds the player")
	await run_until(func(): return gp.fail_clock < 0.0, 3.0)
	gp.reset()

func validate() -> void:
	root.get_tree().set_meta("story_stay_in_school", true)
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	check(school.survival.clock_text() == "22:30", "The clock starts at 22:30")
	check(school.journal.entries.size() == 3, "The case journal holds the three pieces of evidence")
	check(story.clip.visible and story.lure_light.visible and not story.restroom.broken, "Only the hair clip is available in the illuminated classroom")
	school.survival.advance_clock(200)
	check(school.survival.clock_text() == "00:10" and school.survival.phase == school.survival.Phase.PREPARATION, "Clock crosses midnight freely without triggering the story")
	school.survival.begin_midnight()
	check(school.survival.phase == school.survival.Phase.PREPARATION, "Early realm entry cannot skip the gate event")
	check(not story.clip.interact(school.player), "Remote hair clip interaction is rejected")
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	var restroom_door: Node3D = school.get_node("Architecture/ClassroomDoor203")
	check(restroom_door.room_label == "NHÀ VỆ SINH", "Room 203, right above 103, is the second-floor restroom")
	check(not first.is_locked() and restroom_door.is_locked(), "Illuminated classroom is open; the restroom is still shut")
	check(await approach(first, 1.25) and first.interact(school.player), "The first classroom door can be opened through the real interaction ray")
	await frames(35)
	check(await approach(story.clip, 0.05), "Hair clip pickup has an unobstructed physical approach")
	check(story.clip.interact(school.player) and story.evidence.size() == 1 and school.journal.found.size() == 1, "Picking up the hair clip completes the first clue")
	check(story.stage == story.Stage.NOISE_UPSTAIRS and not story.restroom.broken, "The crash waits a beat after the pickup")
	story._physics_process(story.CRASH_DELAY + 0.05)
	check(story.restroom.broken and story.crash_sound.playing and story.crash_sound.global_position.y > 3.9, "The mirror crashes on the floor above")
	check(not restroom_door.is_locked(), "The restroom door can now be opened")
	for i in range(40): story.restroom._process(0.5)
	check(story.restroom.leak.playing and story.restroom.drips.emitting and story.restroom.puddles[-1].visible, "Water sprays, drips through 103's ceiling and seeps out under the restroom door")
	check(story.restroom.puddles[-1].global_position.z > 6.2, "The wet trail reaches the corridor outside the restroom")
	check(await approach(restroom_door, 1.25) and restroom_door.interact(school.player), "The restroom door opens through E")
	await frames(35)
	school.player.global_position = Vector3(14.5, 3.95, 3.0)
	for i in range(40): story.restroom._process(0.1)
	check(not story.restroom.leak.playing and not story.restroom.spray.emitting, "Inside the restroom the leak dies away, so it is quiet for hiding")
	var handle: Node3D = story.restroom.cabinet.get_node("CabinetHandle")
	check(story.restroom.cabinet_glint.visible, "Something glints through the crack of the cleaning cabinet")
	check(await approach(handle, 1.0) and handle.interact(school.player), "The cabinet opens through the real E ray")
	check(story.stage == story.Stage.CABINET_SCARE and story.restroom.swarm.active() and story.controls_player(), "Opening it lets the insects out and holds the player for a moment")
	await frames(20)
	var leaping: int = story.restroom.swarm.bugs.filter(func(b): return b.state in ["leap", "crawl"]).size()
	check(leaping > 0, "Insects leap at the camera")
	for i in range(600):
		await process_frame
		if not story.restroom.swarm.locks_player(): break
	check(not story.controls_player(), "Control comes back while the rest of the swarm scatters across the tiles")
	await frames(2)
	check(story.restroom.hand_mirror.visible, "The broken hand mirror is left on the shelf")
	check(await approach(story.restroom.hand_mirror, 0.0) and story.restroom.hand_mirror.interact(school.player), "The hand mirror is collected through a real nearby E ray")
	check(story.stage == story.Stage.MIRROR_FOUND and story.evidence.size() == 2 and school.journal.found.size() == 2, "The hand mirror is the second clue")
	check(story.journal_context().contains("cài tóc") and story.journal_context().contains("gương cầm tay"), "The journal records both clues")
	await validate_guard()
	school.test_cheats.toggle()
	check(school.test_cheats.enabled and school.journal.found.size() == 3 and story.briefing_complete and not story.runner.active, "Explicit test mode grants all three pieces of evidence")
	school.test_cheats.enabled = false
	school.survival.active = false
	school.survival.start_run(false)
	check(school.survival.clock_text() == "22:30" and story.stage == story.Stage.ROOM_LURE and not story.blackout and story.evidence.is_empty() and school.journal.found.is_empty(), "Restart resets clock, clues, lights and story")
	check(not story.runner.music.playing and school.player.get_node("Collision").shape.height == 1.75, "Restart restores standing posture and stops the chase music")
	check(story.clip.visible and not story.restroom.broken and not story.restroom.leak.playing and not story.restroom.hand_mirror.visible and school.get_node("Architecture/ClassroomDoor203").is_locked(), "Restart puts the mirror back, stops the leak and shuts the restroom")
	var file := FileAccess.open("res://docs/progression-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"flow":"22:30 / lit room 103 / hair clip / crash upstairs / restroom 203 / cabinet insects / hand mirror"}, "\t"))
	file.close()
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	# Allow the audio mixing thread to release playbacks before process exit.
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
