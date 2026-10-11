extends "res://tools/validate_progression.gd"

func validate() -> void:
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
	var first: Node3D = school.get_node("Architecture/ClassroomDoor103")
	check(await approach(first,1.25) and first.interact(school.player),"The initial classroom opens through a real E ray")
	await frames(35)
	check(await approach(story.bear) and story.bear.interact(school.player),"The teddy is the first evidence")
	var second: Node3D = school.get_node("Architecture/ClassroomDoor102")
	check(await approach(second,1.25) and second.interact(school.player),"The blood-room door triggers the scare")
	story._physics_process(1.2)
	await frames(35)
	check(await approach(story.clubs) and story.clubs.interact(school.player),"The bloody clubs can be collected before the upstairs notebook")
	check(story.evidence.size()==2 and not story.blackout and not story.laugh.playing and story.room_shadow.visible,"Two clues leave the school lights and female-window event available")
	school.player.position = Vector3(0,3.95,7.5)
	story.room_shadow._process(.1)
	check(story.room_shadow.withdrawn and school.get_node("Architecture/ClassroomDoor205").is_open,"The second-floor landing still triggers the female shadow after collecting clubs")
	check(await approach(story.notebook,.06) and story.notebook.interact(school.player),"Reading the real notebook completes the third evidence")
	story.close()
	var pressure: Node = story.escape_pressure
	check(story.blackout and pressure.active and school.soul_quest.found.size()==3 and story.laugh.playing,"All three clues start the blackout and environmental pressure")
	check(school.enemies.is_empty() and story.exit_beacon.visible,"The escape uses an exit beacon and no pursuing school ghosts")
	check(not second.is_locked() and not school.get_node("Architecture/ClassroomDoor205").is_locked(),"Slamming doors remain unlocked so the player can escape the classroom")
	for i in range(480): pressure.tick(1.0/60)
	check(school.player.health==100 and pressure.flashes>0 and pressure.overlay.visible and pressure.breathing.playing,"Eight seconds of escalating warnings cause no damage")
	school.paused_by_user = true
	var before: float = pressure.elapsed
	pressure.tick(20)
	check(pressure.elapsed==before and school.player.health==100,"Pause freezes suffocation and its warning period")
	school.paused_by_user = false
	# This fixture starts an actual, unobstructed run from the courtyard.
	school.player.position = Vector3(8,.05,50)
	pressure.last_feet = school.player.position
	pressure.best_gate_distance = pressure.gate_distance(school.player.position)
	var initial: float = pressure.pressure
	for i in range(60):
		await physics_frame
		school.player.velocity = Vector3(0,0,6)
		school.player.move_and_slide()
		pressure.tick(1.0/60)
	check(school.player.position.z>55 and pressure.pressure<initial-3 and school.player.health==100,"Physical movement toward the gate eases pressure before it causes harm")
	story.stage = story.Stage.ESCAPE_GATE
	school.player.position = Vector3(0,.05,76.5)
	pressure.pressure = 18
	pressure.elapsed = 30
	story._physics_process(.01)
	check(story.stage==story.Stage.GATE_INTERFERENCE and not pressure.active and school.player.health==100,"Reaching the gate stops suffocation before any same-frame damage")
	story._physics_process(2.7)
	check(story.runner.active and not pressure.overlay.visible and not pressure.breathing.playing,"The corridor begins with the school's pressure overlay and audio stopped")
	school.survival.active = false
	school.survival.start_run(false)
	story.interact_with(story.bear)
	story.stage = story.Stage.BLOODY_CLUBS
	story.collect_notebook()
	story.discover_clubs()
	for i in range(2100):
		pressure.tick(1.0/60)
		if school.player.health<=0: break
	check(school.player.health<=0 and pressure.damage_events>0 and pressure.elapsed>=10 and pressure.elapsed<35,"Standing still has real, warned suffocation consequences without ghost actors")
	school.survival.active = false
	school.survival.start_run(false)
	check(not pressure.active and not pressure.overlay.visible and not pressure.breathing.playing and not pressure.heartbeat.playing and story.evidence.is_empty(),"Restart clears every clue and every environmental pressure effect")
	var file := FileAccess.open("res://docs/escape-pressure-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	file.close()
	print("RESULT / ",checks," checks, ",failures," failures")
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)
