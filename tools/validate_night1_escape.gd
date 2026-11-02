extends "res://tools/validate_progression.gd"

const STEP := 1.0/60
var escape: Node3D
var scare: Node3D

func press(code: int, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	escape._input(event)

func story_for(seconds: float) -> void:
	for i in range(roundi(seconds/STEP)):
		await physics_frame
		story._physics_process(STEP)

func walk(direction: Vector3, seconds: float) -> void:
	var p: CharacterBody3D = school.player
	for i in range(roundi(seconds/STEP)):
		await physics_frame
		p.velocity = direction*5.2+Vector3.DOWN
		p.move_and_slide()
	p.velocity = Vector3.ZERO

func face(target: Vector3) -> void:
	var p: CharacterBody3D = school.player
	p.camera.rotation = Vector3.ZERO
	p.look_at(Vector3(target.x,p.global_position.y,target.z))
	await frames(1)

func turn_to_angle(point: Vector3, degrees: float) -> void:
	var p: CharacterBody3D = school.player
	await face(point)
	p.rotate_y(deg_to_rad(degrees))
	await frames(1)

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
	escape = story.escape
	scare = story.club_scare
	var p: CharacterBody3D = school.player
	var door102: Node3D = school.get_node("Architecture/ClassroomDoor102")
	var door306: Node3D = school.get_node("Architecture/ClassroomDoor306")
	await frames(3)

	# Part 1: the staircase is physically shut until the scare is over.
	check(not story.stair_gate.opened() and story.stair_gate.body.collision_layer == 5,"The stairs start behind a solid iron gate")
	p.global_position = Vector3(-4.8,.05,7.4)
	await walk(Vector3.FORWARD,1.5)
	check(p.global_position.z > 5.3 and p.global_position.y < .5,"A real capsule cannot walk up through the stair gate")
	for lane in [Vector3(-2.6,.05,4.4),Vector3(-2.6,.05,2.4)]:
		p.global_position = lane
		await walk(Vector3.LEFT,1.5)
		check(p.global_position.y < 1.0 or p.global_position.x > -3.1,"The open side of the flight cannot bypass the gate")
	p.global_position = Vector3(-6.8,.05,7.4)
	await walk(Vector3.FORWARD,1.5)
	check(p.global_position.z > 5.3,"The gap beside the flight is covered by the same gate")
	check(door306.is_locked(),"The top-floor classroom stays shut until the figure enters it")
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	check(await approach(first,1.25) and first.interact(school.player),"First classroom opens")
	await frames(35)
	check(await approach(story.bear) and story.bear.interact(p),"Teddy is collected through the real E ray")
	check(story.stage == story.Stage.BLOOD_TRAIL and story.clubs.visible and not story.room_shadow.model.visible,"The teddy no longer starts a window shadow")
	check(await approach(door102,1.25) and door102.interact(p),"Room 102 opens with no scare on the door")
	check(story.stage == story.Stage.BLOOD_TRAIL and not scare.ghost.visible,"Opening the door itself is quiet: the scare is saved for the clubs")
	await frames(35)
	p.global_position = Vector3(-14.5,.05,7.5)
	story._physics_process(.1)
	check(story.strange_sound.playing,"The knocking draws the player to the room")
	check(await approach(story.clubs) and story.clubs.interact(p),"The clubs are picked up with E")
	check(story.stage == story.Stage.CLUB_SCARE and story.evidence.size() == 2 and not story.clubs.visible,"Picking up the clubs records the clue and starts the scare")
	check(not story.strange_sound.playing and not school.soundscape.voice.playing,"Beat 1 is total silence: no knocking and no pickup cue")
	await story_for(1.4)
	check(not scare.behind.playing and scare.calls == 0,"Silence holds for about 1.5 seconds")
	await story_for(.2)
	check(scare.calls == 1 and scare.behind.playing,"Beat 2 plays a noise")
	var back: Vector3 = p.camera.global_basis.z
	back.y = 0
	back = back.normalized()
	var to_noise: Vector3 = scare.behind.global_position-p.camera.global_position
	to_noise.y = 0
	check(back.dot(to_noise.normalized()) > .9,"The 3D noise is positioned directly behind the player")
	var yaw: float = p.rotation.y
	var first_volume: float = scare.behind.volume_db
	await story_for(5.6)
	check(scare.beat == scare.Beat.WAIT_TURN and not scare.ghost.visible and p.rotation.y == yaw,"The game waits and never turns the camera for the player")
	await story_for(.6)
	check(scare.calls == 2 and scare.behind.volume_db > first_volume and scare.whisper.playing,"After 6 seconds a second, louder noise plays with the whispered name")
	await turn_to_angle(scare.threat_point,40)
	await story_for(.1)
	check(scare.beat == scare.Beat.WAIT_TURN,"Turning only 40 degrees towards it does not fire the lunge")
	await turn_to_angle(scare.threat_point,25)
	await story_for(.02)
	check(scare.beat == scare.Beat.LUNGE and scare.ghost.visible and scare.shriek.playing,"Beat 3: within 30 degrees the ghost lunges with a scream")
	check(story.controls_player() and p.get_interaction_target() == null,"Controls lock as the ghost reaches the player")
	await story_for(.4)
	check(scare.beat == scare.Beat.RECOVERY and story.fear.red > .9,"Beat 4: contact floods the screen red")
	await story_for(.3)
	check(not scare.ghost.visible and story.fear.heart.playing,"The ghost is gone and the heartbeat carries the moment")
	var red_mid: float = story.fear.red
	await story_for(1.0)
	check(story.fear.red < red_mid and story.controls_player(),"Red drains as the pulse slows, with controls still locked")
	await story_for(1.45)
	check(story.fear.red == 0 and not story.controls_player(),"After 2 to 3 seconds the red is gone and control returns")
	check(story.uneasy_music.playing and story.uneasy_music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Beat 5: looping uneasy music begins")
	check(story.room_shadow.model.visible and story.room_shadow.pane.visible and story.room_shadow.mode == story.room_shadow.Mode.WINDOW,"Beat 5: a figure stands in a lit top-floor window")
	check(story.room_shadow.model.position.y > 7.5,"The figure is on the top floor, directly below the roof")
	check(not story.stair_gate.opened(),"The gate is still shut while the player recovers")
	await story_for(1.5)
	check(story.stair_gate.opened() and story.stage == story.Stage.ASCEND,"Beat 6: the latch clicks and the gate opens with no text")
	await frames(90)
	check(story.stair_gate.body.collision_layer == 0 and story.stair_gate.leaf.scale.x < .2,"The folding gate has physically drawn back")

	# Part 2: the music rises by floor, and the figure only moves once seen.
	var volumes := []
	for feet in [Vector3(-4.8,.05,7.4),Vector3(0,3.95,7.5),Vector3(0,7.85,7.5)]:
		p.global_position = feet
		await story_for(4)
		volumes.append(story.uneasy_music.volume_db)
	check(volumes[0] < volumes[1] and volumes[1] < volumes[2],"The music gets louder on each floor")
	check(story.room_shadow.mode == story.room_shadow.Mode.HALL and not story.room_shadow.pane.visible,"Reaching the top floor moves the figure to the end of the wing")
	check(door306.is_locked(),"The door stays shut before the figure is seen")
	p.global_position = Vector3(-23.5,7.85,8.2)
	await face(Vector3(-23.5,7.85,-20))
	await story_for(2)
	check(story.room_shadow.mode == story.room_shadow.Mode.HALL,"Facing away, the figure waits however long it takes")
	await face(story.room_shadow.HALL)
	p.camera.look_at(story.room_shadow.HALL+Vector3.UP*1.5)
	await story_for(.35)
	check(story.room_shadow.mode == story.room_shadow.Mode.HALL and story.room_shadow.seen_clock > 0,"The sight ray sees the figure along the hall")
	await story_for(.25)
	check(story.room_shadow.mode == story.room_shadow.Mode.GLIDE and story.room_shadow.seen_from > 15,"After 0.5 seconds, from over 15 m away, the figure starts to move")
	check(door306.is_open,"The real classroom door opens for the figure")
	await story_for(1)
	check(story.room_shadow.mode == story.room_shadow.Mode.GONE and not door306.is_open and story.room_shadow.slam.playing,"The figure is inside and the door slams with a bang")
	check(story.notebook.visible and not door306.is_locked(),"The notebook and its room are now reachable")
	await frames(35)
	check(await approach(door306,1.25) and door306.interact(p),"The player opens the classroom door")
	await frames(35)

	# Part 3: notebook, siege, and the door bursting.
	check(await approach(story.notebook,.06),"The notebook is reachable on the classroom floor")
	var sill: float = door306.global_position.distance_to(p.global_position)
	check(story.notebook.global_position.distance_to(door306.global_position) > 3.6 and sill > .5,"The notebook is far enough inside that the door can always shut")
	check(story.notebook.interact(p),"The notebook is picked up with E")
	check(not story.uneasy_music.playing and story.panel_kind == "notebook","Picking it up cuts the music dead")
	check(not door306.is_open and story.evidence.size() == 3,"The door shuts on the player")
	await story_for(2)
	check(story.stage == story.Stage.ASCEND and story.door_siege.bangs == 0,"Nothing happens behind the open page")
	story.close()
	await story_for(1.5)
	check(story.stage == story.Stage.DOOR_SIEGE and story.door_siege.bangs == 1,"Closing the book, one blow lands on the door")
	check(door306.is_locked() and not door306.request_toggle(),"The door cannot be opened during the siege")
	await story_for(1.9)
	check(story.door_siege.bangs >= 2 and story.door_siege.sob.playing,"The blows continue and sobbing starts")
	var far_sob: Vector3 = story.door_siege.sob.global_position
	await story_for(3.0)
	check(story.door_siege.bangs >= 6,"The blows become continuous")
	check(story.door_siege.sob.global_position.distance_to(door306.global_position) < far_sob.distance_to(door306.global_position),"The sobbing is getting closer")
	var flickers := 0
	var was_dark: bool = story.blackout
	for i in range(240):
		await physics_frame
		story._physics_process(STEP)
		if story.blackout != was_dark:
			flickers += 1
			was_dark = story.blackout
		if story.stage == story.Stage.ESCAPE_RUN: break
	check(flickers >= 4,"Lights across the school flicker repeatedly (%d changes)" % flickers)
	check(story.stage == story.Stage.ESCAPE_RUN and door306.is_open and story.blackout and escape.active,"The door bursts open, the power dies and the escape begins")
	check(story.controls_player(),"The character is running on its own")

	# Segment 1: every generated pattern must have a way through.
	var clearable := true
	for seed_value in range(300):
		for assist in range(3):
			var pattern: Array[Dictionary] = escape.generate_pattern(seed_value,assist,6.0,60.0)
			clearable = clearable and escape.pattern_clearable(pattern,6.0-escape.MIN_SPACING) and pattern.size() >= 3
	check(clearable,"300 seeds at 3 assist levels all generate clearable obstacle patterns")
	check(escape.generate_pattern(5,2,6,60).size() <= escape.generate_pattern(5,0,6,60).size(),"Assist thins the pattern after a failure")
	check(escape.segment == escape.Segment.CORRIDOR and escape.hazards.size() >= 3,"Segment 1 throws furniture in the top-floor hall")
	var seen_kinds := {}
	for hazard in escape.hazards: seen_kinds[hazard.kind] = true
	var health: float = p.health
	# With no input the ghost catches the player, who only repeats this segment.
	var caught := false
	for i in range(1800):
		await physics_frame
		escape.tick(STEP)
		if int(escape.attempts.get(escape.Segment.CORRIDOR,0)) > 0:
			caught = true
			break
	check(caught,"Doing nothing in the corridor gets the player caught")
	check(escape.report[escape.Segment.CORRIDOR].mistakes >= 2,"The catch came from several mistakes in a row, not a single slip")
	check(escape.segment == escape.Segment.CORRIDOR and escape.assist == 1 and p.health == health,"Being caught restarts only this segment, costs no health and raises assist")
	check(Vector2(p.global_position.x+23.5,p.global_position.z-47.5).length() < 3,"The retry starts at the top of the hall, not in the classroom")
	await run_corridor()
	check(escape.segment == escape.Segment.STAIRS,"A reactive player clears the corridor")
	check(int(escape.attempts[escape.Segment.CORRIDOR]) == 1,"The corridor can be finished without being caught again")
	var sample_gap_high := true
	for i in range(20):
		await physics_frame
		escape.tick(STEP)
	sample_gap_high = escape.gap <= escape.GAP_HIGH+.1
	check(sample_gap_high,"Rubber-banding keeps the ghost close after a clean segment")

	# Segment 2: heartbeat rhythm.
	var rhythm_y: float = p.global_position.y
	check(rhythm_y > 7,"Segment 2 starts on the top floor")
	check(story.fear.darkness > .2 and story.fear.ring >= 0,"The screen dims and a beat marker appears")
	caught = false
	for i in range(1800):
		await physics_frame
		escape.tick(STEP)
		if int(escape.attempts.get(escape.Segment.STAIRS,0)) > 0:
			caught = true
			break
	check(caught,"Ignoring the heartbeat loses footing until the ghost arrives")
	check(escape.segment == escape.Segment.STAIRS and p.health == health,"A catch on the stairs repeats only the stairs")
	await run_stairs()
	check(escape.segment == escape.Segment.COURTYARD,"Pressing on the beat carries the player down all three floors")
	check(p.global_position.y < .3 and p.global_position.z > 9,"The real stairwell route ends outside the main entrance")
	check(escape.report[escape.Segment.STAIRS].mistakes <= 12,"On-beat play makes few mistakes after the failed attempt")

	# Segment 3: follow the lit lamps.
	check(escape.lamp_lights[0].visible and escape.lamp_lights[1].visible,"Two lamps stay lit ahead of the player")
	check(escape.lamp_lights[0].get_child(0).visible and escape.lamp_lights[0].position.distance_to(escape._lamp_head(escape.current_lamp())) < .01,"The lantern on the next lamp visibly glows")
	check(school.local_lights.all(func(light): return not light.visible),"The campus itself is in total blackout")
	var battery: float = p.battery
	var gap_before: float
	var lamp_start: int = escape.lamp_index
	# Wait for a straight run: the beam has to be aimed along the ghost's path.
	for i in range(180):
		await physics_frame
		steer_courtyard()
		escape.tick(STEP)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	escape._input(mouse)
	gap_before = escape.gap
	for i in range(60):
		await physics_frame
		steer_courtyard()
		escape.tick(STEP)
	print("BEAM / on ",escape.beam_on_ghost," battery ",p.battery," gap ",gap_before," -> ",escape.gap," lamp ",escape.lamp_index)
	check(escape.beam_on_ghost and p.battery < battery-10 and escape.gap > gap_before,"Shining the torch back slows the ghost but drains the battery fast")
	mouse = mouse.duplicate()
	mouse.pressed = false
	escape._input(mouse)
	check(not escape.looking_back and is_zero_approx(p.camera.rotation.y),"Releasing the right button looks forward again")
	check(lamp_start == 0,"Steering test started on the first lamp")
	caught = false
	for i in range(1800):
		await physics_frame
		p.rotation.y += STEP*2.5
		escape.tick(STEP)
		if int(escape.attempts.get(escape.Segment.COURTYARD,0)) > 0:
			caught = true
			break
	check(caught,"Running away from the lit lamps feeds the player to the ghost")
	check(escape.segment == escape.Segment.COURTYARD and escape.lamp_index == 0 and p.global_position.z < 12,"The retry restarts the courtyard from the entrance")
	await run_courtyard()
	check(escape.segment == escape.Segment.GATE,"Following the lamps reaches the chained gate")
	check(escape.seal.visible,"The gate shows the chains and the notebook's symbol")

	# Segment 4: redraw the symbol.
	for i in range(240):
		await physics_frame
		escape.tick(STEP)
		if escape.trace.visible: break
	check(escape.trace.visible,"Arriving at the gate opens the chalk board")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"The cursor is released for drawing")
	var slow_gap: float = escape.gap
	for i in range(60):
		await physics_frame
		escape.tick(STEP)
	check(escape.gap < slow_gap,"The ghost closes in while the player draws")
	caught = false
	for i in range(2400):
		await physics_frame
		escape.tick(STEP)
		if int(escape.attempts.get(escape.Segment.GATE,0)) > 0:
			caught = true
			break
	check(caught,"Taking too long at the gate gets the player caught")
	for i in range(240):
		await physics_frame
		escape.tick(STEP)
		if escape.trace.visible and escape.fade_clock == 0: break
	check(escape.trace.visible and escape.trace.index == 0,"The retry starts the drawing again")
	var slip_gap: float = escape.gap
	await trace_mouse(escape.trace.nodes[0],true)
	await trace_mouse(escape.trace.nodes[0]+Vector2(0,300),true)
	check(escape.trace.slips == 1 and not escape.trace.drawing and escape.gap < slip_gap,"Leaving the line breaks the stroke and costs time")
	await trace_mouse(escape.trace.nodes[0],false)
	await trace_mouse(escape.trace.nodes[0],true)
	var time_before: String = school.survival.clock_text()
	for at in escape.trace.nodes: await trace_mouse(at,true)
	check(not escape.active and story.stage == story.Stage.GATE_INTERFERENCE and story.static_sound.playing,"Finishing the symbol breaks the seal and static takes over")
	check((DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) and not escape.trace.visible,"The mouse is recaptured after drawing")
	check(p.get_node("Collision").shape.height == 1.75 and p.camera.fov == 73,"The player's pose is restored")
	await story_for(2.8)
	check(story.stage == story.Stage.CORRIDOR_RUN and story.runner.active and school.spirit_enabled,"The existing spirit corridor and Lan's flow continue from the gate")
	check(school.survival.clock_text() >= time_before or time_before > "20:00","The story clock carries on")
	print("DDA / ",JSON.stringify(escape.report)," / attempts ",JSON.stringify(escape.attempts))

	# Restart must clear all of it, including mid-chase.
	school.survival.active = false
	school.survival.start_run(false)
	await frames(3)
	check(story.stage == story.Stage.ROOM_LURE and not story.stairs_open and not story.stair_gate.opened(),"Restart closes the stair gate")
	check(story.room_shadow.mode == story.room_shadow.Mode.HIDDEN and not story.notebook.visible and not story.notebook.inspected,"Restart hides the figure and the notebook")
	check(not story.blackout and not story.power_surge and not escape.active and escape.report.is_empty() and story.fear.red == 0,"Restart restores the power and the chase state")
	# A restart in the middle of the run, and the test bypass, leave nothing active.
	story.stage = story.Stage.ESCAPE_RUN
	story.blackout = true
	escape.start()
	await frames(5)
	check(escape.active and story.controls_player(),"Fixture: chase is running")
	school.paused_by_user = true
	var frozen_travel: float = escape.travel
	var frozen_s: float = escape.rail_s
	for i in range(30): escape.tick(STEP)
	check(escape.travel == frozen_travel and escape.rail_s == frozen_s,"Esc pauses the chase")
	school.paused_by_user = false
	school.survival.active = false
	school.survival.start_run(false)
	await frames(3)
	check(not escape.active and not escape.music.playing and not escape.ghost.visible and not story.controls_player(),"Restarting mid-chase stops the music, ghost and controls")
	story.stage = story.Stage.ESCAPE_RUN
	escape.start()
	await frames(3)
	story.bypass_for_test()
	check(not escape.active and story.stair_gate.opened() and not door306.is_locked() or not escape.active and story.stair_gate.opened(),"The test bypass ends the chase and opens the stairs")
	var report := FileAccess.open("res://docs/night1-escape-validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	report.close()
	print("RESULT / ",checks," checks, ",failures," failures")
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)

func run_corridor() -> void:
	for i in range(1800):
		await physics_frame
		if escape.fade_clock == 0 and escape.segment == escape.Segment.CORRIDOR: drive_corridor()
		escape.tick(STEP)
		if escape.segment != escape.Segment.CORRIDOR: break
	press(KEY_A,false)
	press(KEY_D,false)

func drive_corridor() -> void:
	var wanted := 0.0
	for hazard in escape.hazards:
		var lead: float = hazard.s-escape.rail_s
		if lead < -.5: continue
		if hazard.kind == "side":
			var free: Vector2 = escape.free_lateral(hazard)
			wanted = (free.x+free.y)/2
		if hazard.kind == "low" and lead < 1.9 and lead > .4 and escape.jump_height == 0:
			press(KEY_SPACE)
			press(KEY_SPACE,false)
		if hazard.kind == "high" and lead < 2.2 and escape.slide_remaining == 0:
			press(KEY_CTRL)
			press(KEY_CTRL,false)
		break
	press(KEY_D,wanted-escape.lateral > .08)
	press(KEY_A,wanted-escape.lateral < -.08)

func run_stairs() -> void:
	for i in range(1800):
		await physics_frame
		if escape.fade_clock == 0 and escape.segment == escape.Segment.STAIRS:
			if escape.next_beat-escape.beat_clock < .03 and not escape.next_answered:
				press(KEY_SPACE)
				press(KEY_SPACE,false)
		escape.tick(STEP)
		if escape.segment != escape.Segment.STAIRS: break

# The fountain sits between lamps 1 and 2, so a real player has to steer past it.
func steer_courtyard() -> void:
	var p: CharacterBody3D = school.player
	var goal: Vector3 = escape.current_lamp()
	if escape.lamp_index == 1 and p.global_position.z < 36: goal = Vector3(-6,0,36)
	var yaw := atan2(-(goal.x-p.global_position.x),-(goal.z-p.global_position.z))
	var relative := Vector2(wrapf(p.rotation.y-yaw,-PI,PI)/p.LOOK_SENSITIVITY,0)
	if escape.looking_back: relative *= .2
	escape.look(relative)

func run_courtyard() -> void:
	for i in range(3000):
		await physics_frame
		if escape.fade_clock == 0 and escape.segment == escape.Segment.COURTYARD: steer_courtyard()
		escape.tick(STEP)
		if escape.segment != escape.Segment.COURTYARD: break

func trace_mouse(at: Vector2, down: bool) -> void:
	var trace: Control = escape.trace
	if trace.drawing != down and trace.visible:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		trace._input(click)
	if trace.visible:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		trace._input(motion)
	await physics_frame
	if escape.active: escape.tick(STEP)
