extends "res://tools/validate_progression.gd"

var runner: Node3D

func visible_gap_clear(hazard: Node3D) -> bool:
	# Inspect actual imported GLB triangles, not just the collision boxes.
	for x in [-2.0,0.0,2.0]:
		for height in [.18,.35,.70]:
			var a: Vector3 = hazard.to_global(Vector3(x,height,2))
			var b: Vector3 = hazard.to_global(Vector3(x,height,-2))
			for mesh in hazard.find_children("*","MeshInstance3D",true,false):
				for surface in range(mesh.mesh.get_surface_count()):
					var arrays: Array = mesh.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for triangle in range(0,indices.size(),3):
						if Geometry3D.segment_intersects_triangle(a,b,mesh.to_global(vertices[indices[triangle]]),mesh.to_global(vertices[indices[triangle+1]]),mesh.to_global(vertices[indices[triangle+2]]))!=null: return false
	return true

func press(code: int, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	runner._input(event)

func fixture(at: float) -> void:
	runner.restore_pose()
	runner.start()
	school.player.health = 100
	school.player.global_position = runner.ORIGIN+runner.route_frame(at).origin+Vector3.UP*.05
	school.player.rotation.y = runner.route_frame(at).basis.get_euler().y
	runner.distance = at
	runner.travel_distance = at
	runner.previous_feet = school.player.position
	runner.ghost_distance = at-9
	runner.trail.clear()
	for meter in range(int(at)+1): runner.trail.append({"distance":float(meter),"position":runner.route_frame(meter).origin+Vector3.UP*.05})
	runner.trail.append({"distance":at,"position":runner.route_frame(at).origin+Vector3.UP*.05})

func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		runner.tick(1.0/60)

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
	story.stage = story.Stage.GATE_INTERFERENCE
	story.stage_time = 3
	school.survival.begin_midnight()
	runner = story.runner
	await frames(2)
	var low: Dictionary = runner.obstacles.filter(func(item):return item.kind=="slide")[0]
	check(visible_gap_clear(low.visual),"The imported table has a visibly empty passage across its center and both sides")
	var ray := PhysicsRayQueryParameters3D.create(low.visual.to_global(Vector3(0,.5,2)),low.visual.to_global(Vector3(0,.5,-2)),1)
	check(school.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"The visible under-table opening is also physically empty")
	ray.from = low.visual.to_global(Vector3(0,1.62,2))
	ray.to = low.visual.to_global(Vector3(0,1.62,-2))
	check(not school.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Standing height meets the clearly visible furniture above the low passage")
	fixture(151)
	press(KEY_W)
	press(KEY_SHIFT)
	await step(150)
	var wrong: Vector3 = school.player.position-runner.ORIGIN
	check(wrong.z < -175 and wrong.z > -183,"A wrong branch is physically enterable and stops at its furniture barricade")
	check(runner.distance<161 and runner.travel_distance>172,"Running into a dead end does not falsely advance the main route or Lan trigger")
	check(school.player.health==100,"A ghost cannot attack remotely just because main-route projection stops at the junction")
	check(runner._trail_frame(runner.travel_distance-2).origin.z < -170,"The pursuit trail includes the player's actual wrong turn")
	school.player.rotation.y = PI
	await step(120)
	check(school.player.position.z > -165,"A player can turn and run back out of a dead end")
	school.player.rotation.y = -PI/2
	await step(100)
	check(school.player.position.x-runner.ORIGIN.x>10 and school.player.health>0,"Returning to the fork lets the player choose the marked continuing corridor")
	fixture(115)
	press(KEY_W)
	press(KEY_SHIFT)
	await step(22)
	press(KEY_SPACE)
	press(KEY_SPACE,false)
	await step(78)
	check(runner.distance<124,"Jumping cannot bypass the first full-height low-passage obstruction")
	fixture(115)
	press(KEY_W)
	press(KEY_SHIFT)
	press(KEY_CTRL)
	var crouched := false
	for i in range(110):
		await step(1)
		if runner.slide_remaining>0: crouched = true
	press(KEY_CTRL,false)
	check(crouched and runner.distance>129 and runner.hit_count==0,"Holding Ctrl while building momentum produces a real slide through the mandatory low opening")
	await step(70)
	check(school.player.get_node("Collision").shape.height>1.7,"Leaving the low passage restores standing height")
	var file := FileAccess.open("res://docs/corridor-choices-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	file.close()
	print("RESULT / ",checks," checks, ",failures," failures")
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)
