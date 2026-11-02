extends "res://tools/validate_progression.gd"

const STEP := 1.0/60
var escape: Node3D

func shot(title: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+title+".png")

func until(segment: int, frames_limit := 900) -> void:
	for i in range(frames_limit):
		await physics_frame
		escape.tick(STEP)
		if escape.segment == segment: return

func validate() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	root.grab_focus()
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	escape = story.escape
	var p: CharacterBody3D = school.player
	# Part 1
	await frames(3)
	p.position = Vector3(-4.8,0.05,8.4)
	p.camera.look_at(Vector3(-4.8,2.0,0))
	await shot("night1-stair-gate")
	story.interact_with(story.bear)
	check(await approach(story.clubs),"Clubs are reachable once the teddy is taken")
	await shot("night1-bloody-clubs")
	story.collect_clubs()
	for i in range(100):
		await physics_frame
		story._physics_process(STEP)
	var yaw: Vector3 = story.club_scare.threat_point+Vector3.UP*1.4
	p.camera.rotation = Vector3.ZERO
	p.look_at(Vector3(yaw.x,p.position.y,yaw.z))
	for i in range(12):
		await physics_frame
		story._physics_process(STEP)
	await shot("night1-jumpscare-lunge")
	for i in range(60):
		await physics_frame
		story._physics_process(STEP)
	await shot("night1-jumpscare-red")
	for i in range(420):
		await physics_frame
		story._physics_process(STEP)
	check(story.stage == story.Stage.ASCEND,"The scare ends with the stairs open")
	# Part 2
	await frames(80)
	p.position = Vector3(-4.8,0.05,8.4)
	p.camera.look_at(Vector3(-4.8,2.0,0))
	await shot("night1-stair-gate-open")
	p.position = Vector3(-23.5,7.85,8.4)
	story.room_shadow.tick(STEP)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	p.look_at(story.room_shadow.HALL)
	p.camera.look_at(story.room_shadow.HALL+Vector3.UP*1.4)
	await shot("night1-hall-shadow")
	story.room_shadow.reset()
	story.shadow_room_open = true
	story.on_shadow_entered()
	school.get_node("Architecture/ClassroomDoor306").set_open(true)
	await frames(40)
	check(await approach(story.notebook,.06),"Notebook is reachable in room 306")
	await shot("night1-notebook-floor")
	story.notebook.interact(p)
	await shot("night1-an-notebook")
	story.close()
	await frames(2)
	story._physics_process(STEP)
	await shot("night1-siege-door")
	story.door_siege.clock = story.door_siege.FLICKER_AT
	for i in range(60):
		await physics_frame
		story._physics_process(STEP)
	p.camera.look_at(school.get_node("Architecture/ClassroomDoor306").global_position+Vector3.UP*1.4)
	await shot("night1-siege-flicker")
	for i in range(90):
		await physics_frame
		story._physics_process(STEP)
	check(story.stage == story.Stage.ESCAPE_RUN,"The siege ends with the escape")
	# Part 3: stand-in input is unnecessary, these are composition checks.
	p.camera.rotation = Vector3.ZERO
	for hazard in escape.hazards: hazard.resolved = true
	# Jump down the hall to a hazard away from the corners, and let it land.
	var thrown: Dictionary = escape.hazards[mini(2,escape.hazards.size()-1)]
	escape.rail_s = float(thrown.s)-9.5
	for i in range(36):
		await physics_frame
		escape.tick(STEP)
	check(thrown.launched and thrown.node.visible,"Thrown furniture is on screen in the hall")
	await shot("night1-escape-corridor")
	p.camera.rotation.y = PI
	await shot("night1-escape-ghost-behind")
	p.camera.rotation.y = 0
	escape.begin_segment(escape.Segment.STAIRS)
	await until(-1,200)
	await shot("night1-escape-stairs")
	escape.begin_segment(escape.Segment.COURTYARD)
	await frames(2)
	p.position = Vector3(1,0.05,13)
	p.look_at(Vector3(5.7,p.position.y,16))
	await shot("night1-escape-lamps")
	p.position = Vector3(0,0.05,36)
	escape.lamp_index = 1
	escape._set_lamps_active(true)
	p.look_at(Vector3(-5.7,p.position.y,46))
	await shot("night1-escape-lamps-2")
	escape.lamp_index = 5
	p.position = Vector3(-5.7,0.05,73)
	escape.begin_segment(escape.Segment.GATE)
	for i in range(160):
		await physics_frame
		escape.tick(STEP)
		if not escape.approaching: break
	escape.trace.hide()
	p.camera.rotation = Vector3(.05,0,0)
	await shot("night1-gate-seal")
	escape.trace.begin(0)
	escape.trace.index = 60
	await shot("night1-gate-chalkboard")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"The board releases the cursor on a real display")
	escape._finish()
	await frames(2)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"Finishing the board recaptures the mouse on a real display")
	print("RESULT / rendered ",checks," checks, ",failures," failures")
	escape.reset()
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)
