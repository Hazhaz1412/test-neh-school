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
	check(story.bear.visible and story.lure_light.visible and not story.clubs.visible and not story.blood.visible, "Only the teddy is available in the illuminated classroom")
	check(not school.master_key.visible, "The old warehouse key objective is absent")
	school.survival.advance_clock(200)
	check(school.survival.clock_text() == "00:10" and school.survival.phase == school.survival.Phase.PREPARATION and not school.spirit_enabled, "Clock crosses midnight freely without triggering the story")
	school.survival.begin_midnight()
	check(school.survival.phase == school.survival.Phase.PREPARATION, "Early realm entry cannot skip the gate event")
	check(not story.bear.interact(school.player), "Remote teddy interaction is rejected")
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	var second: Node3D = school.get_node("Architecture/ClassroomDoor102")
	check(not first.is_locked() and second.is_locked(), "Illuminated classroom is accessible before obtaining a key")
	check(await approach(first, 1.25) and first.interact(school.player), "The first classroom door can be opened through the real interaction ray")
	await frames(35)
	check(await approach(story.bear), "Teddy pickup has an unobstructed physical approach")
	check(story.bear.interact(school.player) and story.evidence.size() == 1 and school.soul_quest.found.size() == 1, "Picking up the teddy completes the first clue immediately")
	check(not story.bear.visible and story.blood.visible and not second.is_locked(), "Blood appears across the hall and the opposite room becomes accessible")
	check(not story.notebook.visible and school.player.get_interaction_target()==null or not story.notebook.visible, "The notebook is not available yet: it waits on the top floor")
	school.player.position = Vector3(-14.5, 0.05, 7.5)
	story._physics_process(0.1)
	check(story.strange_sound.playing, "Approaching the blood trail starts the repeating strange sound")
	check(await approach(second, 1.25) and second.interact(school.player), "Opening the opposite door through E is quiet")
	check(story.stage == story.Stage.BLOOD_TRAIL and story.clubs.visible, "The clubs wait inside the room")
	await frames(35)
	check(await approach(story.clubs), "The clubs can be reached physically")
	check(story.clubs.interact(school.player), "Picking up the clubs records the second clue")
	check(story.stage == story.Stage.CLUB_SCARE and story.evidence.size() == 2 and not story.blackout, "Two clues start the scare, not the blackout")
	# The detailed beat-by-beat behaviour is covered by validate_night1_escape.gd.
	story.club_scare.beat = story.club_scare.Beat.AFTERMATH
	story.club_scare.clock = 2
	story._physics_process(0.1)
	check(story.stage == story.Stage.ASCEND and story.stairs_open, "The stairs open after the scare")
	story.room_shadow.show_at_window()
	story.shadow_room_open = true
	story.on_shadow_entered()
	check(await approach(story.notebook,.06) and story.notebook.interact(school.player), "The notebook is collected through a real nearby E ray")
	story.close()
	story._physics_process(0.01)
	check(story.stage == story.Stage.DOOR_SIEGE and story.evidence.size() == 3, "The third clue starts the siege")
	story.door_siege.clock = story.door_siege.BURST_AT
	story._physics_process(0.01)
	check(story.stage == story.Stage.ESCAPE_RUN and story.blackout and story.escape.active and school.local_lights.all(func(light): return not light.visible), "The door bursts, school lights die and the escape starts")
	check(story.current_goal().contains("THOÁT"), "The objective changes to escape through the main gate")
	check(school.enemies.is_empty(), "The escape spawns no campus enemies")
	story.escape._finish()
	check(story.stage == story.Stage.GATE_INTERFERENCE and story.static_sound.playing and story.interference.visible, "Breaking the seal starts sustained static")
	var time_before: String = school.survival.clock_text()
	story._physics_process(2.7)
	check(story.stage == story.Stage.CORRIDOR_RUN and story.runner.active and school.spirit_enabled, "Gate interference pulls the player into the endless spirit corridor")
	check(school.survival.clock_text() == time_before, "Realm transition preserves the clock rather than resetting to midnight")
	check(school.player.position.x == 220 and school.player.can_fit(school.player.position) and school.enemies.is_empty(), "Corridor entry is clear of physical colliders and campus combat")
	check(story.runner.ghosts.size() == 5 and story.runner.music.playing and story.runner.chase_steps.playing, "Five ghosts chase with dedicated tense music and footsteps")
	check(not story.runner.slide(), "Ctrl cannot slide without momentum")
	var elapsed_before: float = story.runner.elapsed
	school.paused_by_user = true
	story.runner.tick(2)
	school.survival.advance_clock(2)
	check(story.runner.elapsed == elapsed_before and school.survival.clock_text() == time_before, "Escape menu pauses both minigame and clock")
	school.paused_by_user = false
	check(not school.player.can_use_item() and not school.player.take_photo(), "Normal combat and item controls cannot override the runner")
	school.test_cheats.toggle()
	check(school.test_cheats.enabled and school.soul_quest.found.size() == 3 and school.soul_quest.accepted.is_empty() and story.briefing_complete and not story.runner.active, "Explicit test mode grants all three clues while retaining real AI dialogue")
	school.test_cheats.enabled = false
	school.survival.active = false
	school.survival.start_run(false)
	check(school.survival.clock_text() == "22:30" and story.stage == story.Stage.ROOM_LURE and not story.blackout and story.evidence.is_empty() and school.soul_quest.found.is_empty(), "Restart resets clock, clues, lights and story")
	check(not story.runner.music.playing and not story.laugh.playing and not story.interference.visible and school.player.get_node("Collision").shape.height == 1.75, "Restart restores standing posture and stops all chase/static audio")
	var file := FileAccess.open("res://docs/progression-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"flow":"22:30 / teddy / blood / clubs scare / stairs / notebook / siege / escape / gate / 75-second corridor / Lan"}, "\t"))
	file.close()
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	# Allow the audio mixing thread to release playbacks before process exit.
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
