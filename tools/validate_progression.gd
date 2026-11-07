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
	stall = story.restroom.stall_doors[5]
	if story.restroom.stall_open(5): story.restroom.toggle_stall(5)
	school.player.global_position = Vector3(21.15, F2, -10.1 + 5 * 1.55 + 0.78)
	check(await run_until(func(): return gp.part == gp.Part.PHOTO, 150.0) and gp.fail_clock < 0.0, "Left alone, he walks the whole route to 306 and starts clearing the desk")
	check(guard.busy_with("work") and school.get_node("Architecture/ClassroomDoor306").is_open and guard.global_position.distance_to(gp.DESK_STAND) < 0.3, "In 306 he works at the teacher's desk with the door open")
	# The photo from behind him, between the desks.
	school.player.global_position = Vector3(-31.0, F3, 41.5)
	school.player.set_crouching(true, true)
	school.player.look_at(Vector3(gp.EVIDENCE.x, F3, gp.EVIDENCE.z))
	school.player.camera.look_at(gp.EVIDENCE)
	await frames(30)
	check(gp.fail_clock < 0.0, "Crouched behind him among the desks, the player is not noticed")
	check(gp.evidence_in_frame(), "The papers are framed from there")
	school.player.battery = 100
	school.player.select_item("camera")
	check(school.player.take_photo() and story.evidence.has("photo") and school.soul_quest.found.size() == 3, "The photo is the third clue")
	check(await run_until(func(): return story.stage == story.Stage.ESCAPE_RUN, 3.0) and story.escape.active and story.escape.ghost.visible and not guard.visible, "The flash gives the player away and the escape starts with the guard behind")
	check(story.escape.ghost.global_position.distance_to(gp.DESK_STAND) < 7.0, "The chase starts from where he stood")
	school.player.set_crouching(false, true)
	# The gate segment: chained, so the booth's basement door, pulled open with E.
	story.set_physics_process(false)
	school.player.global_position = Vector3(0, 0.05, 10)
	story.escape.begin_segment(story.escape.Segment.GATE)
	for i in range(1500):
		story.escape.tick(1.0 / 60.0)
		if not story.escape.approaching and story.escape.rattle <= 0 and story.escape.rail_s >= story.escape.rail_lengths[-1] - 0.05: break
	check(school.player.global_position.distance_to(story.escape.BOOTH_DOOR) < 1.2, "After the chained gate the player ends at the booth's basement door")
	check(not story.escape.ghost.global_position.is_equal_approx(Vector3.ZERO) and story.escape.gap > 0, "The guard is still behind")
	for i in range(story.escape.DOOR_PULLS): story.escape.pull_door()
	check(story.stage == story.Stage.BASEMENT_DESCENT and not story.escape.active, "Wrenching the door open leads down to the basement")
	story._physics_process(story.DESCENT_SECONDS + 0.1)
	check(story.stage == story.Stage.CORRIDOR_RUN and story.runner.active and not school.spirit_enabled, "The red corridor is the service tunnel, with no spirit world")
	check(story.runner.ghosts.size() == 1 and story.runner.ghosts[0].model.variant == "guard", "Only the guard chases through the tunnel")
	story.runner.reset()
	story.runner.restore_pose()
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
	check(school.soul_quest.memories.size() == 3 and school.soul_quest.fragments.is_empty(), "Three opening clues replace the old physical puzzle chain")
	check(story.clip.visible and story.lure_light.visible and not story.restroom.broken, "Only the hair clip is available in the illuminated classroom")
	check(not school.master_key.visible, "The old warehouse key objective is absent")
	school.survival.advance_clock(200)
	check(school.survival.clock_text() == "00:10" and school.survival.phase == school.survival.Phase.PREPARATION and not school.spirit_enabled, "Clock crosses midnight freely without triggering the story")
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
	check(story.clip.interact(school.player) and story.evidence.size() == 1 and school.soul_quest.found.size() == 1, "Picking up the hair clip completes the first clue")
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
	check(story.stage == story.Stage.MIRROR_FOUND and story.evidence.size() == 2 and school.soul_quest.found.size() == 2, "The hand mirror is the second clue")
	check(story.journal_context().contains("cài tóc") and story.journal_context().contains("gương cầm tay"), "The journal records both clues")
	await validate_guard()
	school.test_cheats.toggle()
	check(school.test_cheats.enabled and school.soul_quest.found.size() == 3 and school.soul_quest.accepted.is_empty() and story.briefing_complete and not story.runner.active, "Explicit test mode grants all three clues while retaining real AI dialogue")
	school.test_cheats.enabled = false
	school.survival.active = false
	school.survival.start_run(false)
	check(school.survival.clock_text() == "22:30" and story.stage == story.Stage.ROOM_LURE and not story.blackout and story.evidence.is_empty() and school.soul_quest.found.is_empty(), "Restart resets clock, clues, lights and story")
	check(not story.runner.music.playing and not story.laugh.playing and not story.interference.visible and school.player.get_node("Collision").shape.height == 1.75, "Restart restores standing posture and stops all chase/static audio")
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
