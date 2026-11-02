extends "res://tools/validate_progression.gd"

func press(code: int, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	story.runner._input(event)

func validate() -> void:
	root.get_tree().set_meta("story_stay_in_school", true)
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	story.stage = story.Stage.GATE_INTERFERENCE
	story.stage_time = 3
	school.survival.begin_midnight()
	var runner: Node3D = story.runner
	check(runner.active and runner.ghosts.size()==5 and not school.test_cheats.enabled,"Manual chase starts with five hostile ghosts and no cheats")
	check(runner.junctions.size()==10 and runner.dead_ends.size()==20,"Ten physical junctions offer wrong branches with visible barricades")
	check(runner.obstacles.any(func(item):return item.challenge=="weave") and runner.obstacles.any(func(item):return item.challenge=="drop_gate"),"The run includes slalom furniture and dropping low gates")
	check(runner.obstacles.filter(func(item):return item.kind=="slide").size()>=5,"Low passages require Ctrl repeatedly throughout the chase")
	check(not runner.slide(),"Slide needs player-generated sprint momentum")
	var start: Vector3 = school.player.position
	for i in range(25):
		await physics_frame
		runner.tick(1.0/60)
	check(Vector2(start.x-school.player.position.x,start.z-school.player.position.z).length()<0.01,"No movement input leaves the player stationary")
	var battery: float = school.player.battery
	school.player.tick_survival(12,false)
	check(school.player.battery==battery,"The chase flashlight consumes no battery")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	runner._input(mouse)
	check(runner.looking_back and absf(school.player.camera.rotation.y-PI)<0.01,"Right mouse reveals the pursuing ghosts behind the player")
	mouse.pressed = false
	runner._input(mouse)
	var move := InputEventMouseMotion.new()
	move.relative.x = 2000
	runner.look(move.relative)
	check(absf(wrapf(school.player.rotation.y + 4.4,-PI,PI))<0.02,"Mouse look can turn fully around instead of being clamped")
	school.player.rotation = Vector3.ZERO
	var driver := preload("res://tools/chase_driver.gd").new()
	driver.runner = runner
	driver.world = school
	var saw_jump := false
	var saw_slide := false
	var depleted := false
	var recovered := false
	var previous_stamina: float = school.player.stamina
	var tested_pause := false
	var saw_lan_back := false
	var lan_was_correct := true
	for frame in range(12000):
		await physics_frame
		driver.tick()
		var lan_before: Vector3 = runner.lan.position
		var lan_was_visible: bool = runner.lan.visible
		runner.tick(1.0/60)
		if lan_was_visible and runner.lan.visible and runner.lan.position.distance_to(lan_before)>.005:
			var heading: Vector3 = (runner.lan.position-lan_before).normalized()
			if heading.dot(runner.lan.basis.z.normalized())<.9: lan_was_correct = false
			else: saw_lan_back = true
		school.survival.advance_clock(1.0/60)
		if runner.jump_height>.8: saw_jump = true
		if runner.slide_remaining>0 and school.player.get_node("Collision").shape.height<1: saw_slide = true
		if school.player.stamina<100: depleted = true
		if depleted and school.player.stamina>previous_stamina: recovered = true
		previous_stamina = school.player.stamina
		if not tested_pause and runner.elapsed>=20:
			tested_pause = true
			school.paused_by_user = true
			var before: float = runner.elapsed
			var pose: Vector3 = school.player.position
			runner.tick(20)
			check(runner.elapsed==before and school.player.position==pose,"Pause holds motion, stamina, pursuers and chase timer")
			school.paused_by_user = false
		if story.stage==story.Stage.LAN_DIALOGUE or school.player.health<=0: break
	check(depleted and recovered,"Sprinting spends stamina and walking regenerates it")
	check(driver.corners.size()==10,"Actual player movement navigates all ten physical corners")
	check(driver.shifted_seen,"Furniture shifts across the corridor during the real run")
	check(saw_jump and saw_slide,"Player physically jumps over benches and slides below tables")
	check(driver.slides>=3,"The reactive player uses Ctrl to clear the mandatory low passages")
	check(saw_lan_back and lan_was_correct,"Lan's +Z facing direction follows her physical travel, showing her back to the pursuing player")
	check(runner.lan_time>=75 and runner.distance>=runner.LAN_CORNER,"Lan appears after at least 75 moving seconds and a corner")
	check(runner.room_hidden and runner.door_amount==0 and story.stage==story.Stage.LAN_DIALOGUE,"Player follows Lan and manually enters the refuge before the door shuts")
	check(not runner.active and not runner.music.playing and school.is_soul_sanctuary(school.player.position),"Lan's room ends the pursuit safely")
	print("CHASE / hits ",runner.hit_count," / HP ",school.player.health," / distance ",runner.distance," / Lan ",runner.lan_time)
	var reached_lan: float = runner.lan_time
	var chase_hits: int = runner.hit_count
	check(school.player.health > 0 and runner.hit_count < 5, "Reactive input completes moving furniture hazards with normal health")
	if story.stage==story.Stage.LAN_DIALOGUE:
		finish_lan_dialogue()
		check(story.stage==story.Stage.TABLE_ESCAPE and not story.briefing_complete and school.player.position.x>150,"Finishing Lan dialogue keeps the player in the refuge and enables the table")
		check(await approach(runner.table,.55) and runner.table.interact(school.player),"Real E interaction puts the player under Lan's table")
		check(school.player.is_hidden() and story.stage==story.Stage.UNDER_TABLE,"Portal begins only after entering the table")
		story._physics_process(1.9)
		await frames(4)
		check(story.portal_arrived and school.player.hidden_spot==story.return_table and school.player.position.x<50 and school.player.get_node("Collision").shape.height<1,"Player arrives crouched under an actual table in the school")
		check(school.player.end_hide() and story.stage==story.Stage.LAN_FAREWELL and school.player.can_fit(school.player.position),"E exits the school table into a clear standing position")
		check(story.briefing_complete and school.has_master_key and not runner.active,"Table crossing resumes An's school investigation")
	else:
		check(false,"Lan dialogue and table portal were reachable")
	# A stopped player must face real consequences, rather than an autorun rescue.
	school.survival.active = false
	school.survival.start_run(false)
	story.stage = story.Stage.GATE_INTERFERENCE
	story.stage_time = 3
	school.survival.begin_midnight()
	for frame in range(900):
		await physics_frame
		runner.tick(1.0/60)
		if school.player.health<=0: break
	check(school.player.health<=0,"Stopping in the corridor lets the ghosts catch and kill the player")
	check(runner.distance<20 and runner.elapsed<1,"Waiting cannot advance distance or count toward Lan's minimum run time")
	var report := FileAccess.open("res://docs/chase-validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"lan_seconds":reached_lan,"hits":chase_hits,"jump_inputs":driver.jumps,"slide_inputs":driver.slides,"corners":driver.corners.size(),"moving_furniture":driver.shifted_seen},"\t"))
	report.close()
	print("RESULT / ",checks," checks, ",failures," failures")
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)
