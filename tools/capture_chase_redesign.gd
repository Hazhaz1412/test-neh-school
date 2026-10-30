extends "res://tools/validate_progression.gd"

func shot(title: String) -> void:
	for i in range(5): await process_frame
	school.player.camera.force_update_transform()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+title+".png")

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.player.set_process_unhandled_input(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	check(await approach(school.get_node("Architecture/ClassroomDoor103"),1.25) and school.get_node("Architecture/ClassroomDoor103").interact(school.player),"First classroom is reachable")
	await frames(35)
	check(await approach(story.bear) and story.bear.interact(school.player),"Teddy pickup starts the separate upper-window event")
	story.room_shadow.show_at_window()
	school.player.position = Vector3(-8,0.05,8.1)
	school.player.camera.look_at(story.room_shadow.WINDOW+Vector3.UP*1.85)
	await shot("night1-upper-window-shadow")
	var unobstructed := true
	# Collision rays omit decorative jambs/mullions; include their actual render
	# bounds to verify that the silhouette's head is not hidden behind a frame.
	for batch in school.get_node("RuntimeGeometry").get_children():
		if not batch is MultiMeshInstance3D: continue
		if batch.material_override is StandardMaterial3D and batch.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA: continue
		for j in range(batch.multimesh.instance_count):
			var trans: Transform3D = batch.global_transform*batch.multimesh.get_instance_transform(j)
			if is_zero_approx(trans.basis.determinant()): continue
			var inv := trans.affine_inverse()
			var point = batch.multimesh.mesh.get_aabb().intersects_segment(inv*school.player.camera.global_position,inv*(story.room_shadow.WINDOW+Vector3.UP*1.85))
			if point == null: continue
			unobstructed = false
	check(story.room_shadow.model.visible and story.room_shadow.model.position.y>7.5 and unobstructed,"Top-floor shadow is visible from the ground-floor hall without a frame covering its head")
	story.stage = story.Stage.GATE_INTERFERENCE
	story.stage_time = 3
	school.survival.begin_midnight()
	var runner: Node3D = story.runner
	runner.set_process_input(false)
	await shot("night1-corridor-run")
	school.player.camera.rotation.y = PI
	await shot("night1-corridor-ghosts")
	school.player.camera.rotation.y = 0
	check(not school.objective_label.visible,"No persistent narrative objective covers the chase view")
	var turn: Transform3D = runner.route_frame(154)
	school.player.global_position = runner.ORIGIN+turn.origin+Vector3.UP*0.05
	school.player.rotation.y = turn.basis.get_euler().y
	runner.distance = 154
	runner._furniture(.01)
	runner._update_lights()
	for i in range(runner.corridor_lights.size()): runner.corridor_lights[i].position = runner.route_frame(154+i*8).origin+Vector3.UP*2.8
	await shot("night1-corridor-corner")
	var table_hazard: Dictionary = runner.obstacles.filter(func(item): return item.kind=="slide")[0]
	var frame: Transform3D = runner.route_frame(table_hazard.distance-8)
	school.player.global_position = runner.ORIGIN+frame.origin+Vector3.UP*0.05
	school.player.rotation.y = frame.basis.get_euler().y
	runner.distance = table_hazard.distance-8
	runner._update_lights()
	for i in range(runner.corridor_lights.size()): runner.corridor_lights[i].position = runner.route_frame(table_hazard.distance-8+i*8).origin+Vector3.UP*2.8
	await shot("night1-corridor-furniture")
	var following: Transform3D = runner.route_frame(706)
	runner.restore_pose()
	school.player.global_position = runner.ORIGIN+following.origin+Vector3.UP*.05
	school.player.rotation.y = following.basis.get_euler().y
	runner.distance = 706
	runner.elapsed = 76
	runner.tick(1.0/60)
	await shot("night1-lan-back-facing")
	check(runner.lan.visible and runner.lan.basis.z.dot(-following.basis.z)>.9,"Lan faces down the escape route and shows her back to the player")
	# Room image is a fixture; the full non-cheat traversal is separately tested.
	runner.active = false
	runner.room_hidden = true
	runner.room_open = true
	runner.restore_pose()
	school.player.position = runner.refuge.to_global(Vector3(-5.0,.05,1.0))
	story.enter_lan_room()
	finish_lan_dialogue()
	school.player.camera.look_at(runner.table.global_position+Vector3.UP*.55)
	await shot("night1-lan-table")
	check(await approach(runner.table,.55) and runner.table.interact(school.player),"Actual interaction enters Lan's table")
	story._physics_process(1.9)
	await frames(4)
	await shot("night1-school-under-table")
	check(story.portal_arrived and school.player.hidden_spot==story.return_table,"Table crossing preserves a crouched player in the school")
	check(school.player.end_hide() and school.player.can_fit(school.player.position),"Player can exit the school table")
	await shot("night1-school-table-exit")
	var file := FileAccess.open("res://docs/chase-rendered-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	file.close()
	print("RESULT / ",checks," checks, ",failures," failures")
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)
