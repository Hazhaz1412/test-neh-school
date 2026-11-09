extends "res://tools/validate_progression.gd"
# The dream tunnels: obstacles are already there, he chases by the shortest way, he cuts the
# player off twice, cracks to jump, the pump room door, the broken stair, the drain slide, the
# cutscene at the reservoir (look down, turn to him, run-up, short, the board snaps) and the
# drowning. The reservoir is checked to be closed all round, so the fall never shows the void.
# A bot drives the real movement code (held keys, jump, slide) through the tunnels.
# godot --headless --fixed-fps 60 --path . --script tools/validate_tunnel.gd
# godot --path . --resolution 1280x720 --script tools/validate_tunnel.gd -- shots

var tunnel: Node3D
var shots := false
var highest_eye := -INF
var jump_gaps := true

func step(count := 1) -> void:
	for i in range(count):
		tunnel.tick(1.0 / 60.0)
		await process_frame

# Like run_until, but ticking the tunnel each frame.
func tick_until(condition: Callable, seconds: float) -> bool:
	for i in range(int(seconds * 60)):
		if condition.call(): return true
		await step()
	return condition.call()

func feet() -> Vector3:
	return tunnel.to_local(school.player.global_position)

func place(at: Vector3, toward: Vector3) -> void:
	school.player.global_position = tunnel.to_global(at + Vector3.UP * 0.05)
	var to := toward - at
	school.player.rotation.y = atan2(-to.x, -to.z)
	school.player.velocity = Vector3.ZERO

# Run a list of waypoints like a player: sprint, jump barriers, slide under pipes, step round
# crates and carts. Returns how many seconds it took, or -1 if it stalled.
func drive(points: Array, limit := 60.0, stop := Callable()) -> float:
	var p: CharacterBody3D = school.player
	var index := 0
	var frames_run := 0
	var last := feet()
	var stuck := 0
	while index < points.size() and frames_run < int(limit * 60):
		if stop.is_valid() and stop.call(): break
		if tunnel.fade_clock > 0.0 or tunnel.chute.active or tunnel.state != "run": break
		var here := feet()
		var goal: Vector3 = points[index]
		if Vector2(goal.x - here.x, goal.z - here.z).length() < 1.2:
			index += 1
			continue
		var forward := Vector3(goal.x - here.x, 0, goal.z - here.z).normalized()
		var right := forward.cross(Vector3.UP)
		var aim := goal
		if jump_gaps:
			for gap in tunnel.gaps:
				var lip: Vector3 = gap.near if (gap.near - here).dot(forward) < (gap.far - here).dot(forward) else gap.far
				var ahead: float = (lip - here).dot(forward)
				var across: float = absf((lip - here).dot(right))
				var lead := 0.9 if gap.far.y > gap.near.y + 0.1 else 1.3
				if absf(lip.y - here.y) < 1.0 and across < 2.5 and ahead > -0.2 and ahead < lead and absf(forward.dot(gap.forward)) > 0.5:
					tunnel.jump()
		for spec in tunnel.OBSTACLES:
			var at: Vector3 = tunnel.edge_point(spec[0], spec[1], spec[2])
			var ahead: float = (at - here).dot(forward)
			var across: float = absf((at - here).dot(right))
			if ahead < -0.5 or ahead > 6.0 or across > 2.5 or absf(at.y - here.y) > 2.0: continue
			match spec[3]:
				"barrier":
					if ahead < 1.9: tunnel.jump()
				"pipe":
					if ahead < 3.2: tunnel.slide()
				_:
					var edge_right: Vector3 = tunnel.flat_forward(spec[0], spec[1]).cross(Vector3.UP)
					aim = at - edge_right * float(spec[4]) * 1.1 + forward * 2.0
		var direction := Vector3(aim.x - here.x, 0, aim.z - here.z).normalized()
		p.rotation.y = atan2(-direction.x, -direction.z)
		tunnel.held_keys[KEY_W] = true
		tunnel.held_keys[KEY_SHIFT] = true
		p.stamina = p.MAX_STAMINA
		await step()
		var eye: Vector3 = tunnel.to_local(p.camera.global_position)
		highest_eye = maxf(highest_eye, eye.y - tunnel.floor_under(feet()))
		frames_run += 1
		if feet().distance_to(last) < 0.02: stuck += 1
		else: stuck = 0
		last = feet()
		if stuck > 90: return -1.0
	tunnel.held_keys[KEY_W] = false
	tunnel.held_keys[KEY_SHIFT] = false
	return frames_run / 60.0 if index >= points.size() else -1.0

# Rays out of `from` (local) in every direction: how many get away without hitting a wall box of
# the tunnels. Each one that does would show the void and whatever hangs in it.
func open_directions(from: Vector3, boxes: Array) -> int:
	var origin := tunnel.to_global(from)
	var near: Array = boxes.filter(func(b: AABB): return b.grow(1.0).has_point(origin) or b.get_center().distance_to(origin) < 120.0)
	var count := 0
	var samples := 300
	for i in range(samples):
		var y := 1.0 - 2.0 * (i + 0.5) / samples
		var ring := sqrt(1.0 - y * y)
		var turn := i * 2.399963
		var direction := Vector3(cos(turn) * ring, y, sin(turn) * ring)
		var hit := false
		for b: AABB in near:
			if b.intersects_ray(origin, direction) != null:
				hit = true
				break
		if not hit: count += 1
	return count

func wall_boxes() -> Array:
	var boxes := []
	for mesh: MeshInstance3D in tunnel.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh is BoxMesh or not mesh.visible: continue
		if not mesh.global_basis.is_equal_approx(Basis.IDENTITY): continue
		var size: Vector3 = mesh.mesh.size
		if maxf(size.x, maxf(size.y, size.z)) < 2.0: continue
		boxes.append(mesh.global_transform * mesh.get_aabb())
	return boxes

func shot(title: String) -> void:
	if not shots: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/%s.png" % title)

func validate() -> void:
	shots = not OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless"
	root.get_tree().set_meta("story_stay_in_school", true)
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	story = school.progression
	story.set_physics_process(false)
	school.player.set_physics_process(false)
	story.begin_first_chase()
	tunnel = story.runner
	# Real mouse and keys over the window would steer the bot.
	if shots: tunnel.set_process_input(false)
	var p: CharacterBody3D = school.player
	check(tunnel.active, "The dream starts in the service tunnels")
	var bodies_before: Array = tunnel.bodies.map(func(b): return b.global_position)
	check(tunnel.OBSTACLES.size() >= 20 and tunnel.bodies.all(func(b): return b.collision_layer == 1), "%d obstacles are lying there from the start" % tunnel.OBSTACLES.size())
	check(tunnel.EDGES.size() >= 12 and tunnel.CUTOFFS.size() == 2, "Corridors with junctions, dead ends and two cut-offs")
	# He comes through the stair door behind.
	await step(int((tunnel.DOOR_START + 0.3) * 60))
	check(tunnel.guard_on and tunnel.guard.visible and tunnel.guard.global_position.distance_to(p.global_position) > 8.0, "The guard bursts through the stair door behind the player")
	await shot("tunnel-start")
	# Standing still: he takes the shortest way and catches the player.
	check(await tick_until(func(): return tunnel.fade_clock > 0.0, 8.0), "Standing still, he runs the player down")
	await step(70)
	check(tunnel.fade_clock <= 0.0 and feet().distance_to(tunnel.CHECKPOINTS[0].at) < 1.0, "Caught, the run starts again at the foot of the stairs")
	# The chained grille east of A: a dead end that is shut, seen from the junction.
	var grille: Vector3 = tunnel.edge_point("A", "E", tunnel.GRILLE[2])
	place(tunnel.node_pos("A") + Vector3(4, 0, 0), grille)
	await step(2)
	tunnel.guard_on = false
	tunnel.guard.vanish()
	var blocked := await drive([grille + Vector3(1.0, 0, 0)], 4.0)
	check(blocked < 0.0 and feet().x < grille.x, "The way east is shut by a chained grille")
	# A crack not jumped: down into the pit, and back to the checkpoint.
	check(tunnel.gaps.size() == tunnel.CRACKS.size() + 1, "%d cracks across the floor, one at the foot of the stair" % tunnel.gaps.size())
	tunnel._restart_at(0)
	await step(2)
	tunnel.door_clock = -1.0
	var crack: Dictionary = tunnel.gaps[0]
	place(crack.near - crack.forward * 3.5, crack.far)
	await step(2)
	jump_gaps = false
	await drive([crack.far + crack.forward * 3.0], 4.0)
	jump_gaps = true
	check(tunnel.fade_clock > 0.0 and tunnel.pit_fall, "Running at a crack without jumping drops the player into the pit")
	await step(70)
	check(tunnel.fade_clock <= 0.0 and feet().distance_to(tunnel.CHECKPOINTS[0].at) < 1.0, "Out of the pit, the run starts again at the checkpoint")
	# The pump room: cut off north of C, shoulder the door on the left and go through to the west tunnel.
	tunnel._restart_at(0)
	await step(2)
	tunnel.door_clock = -1.0
	tunnel._guard_off()
	place(tunnel.edge_point("C", "P1", 2.0), tunnel.node_pos("P1"))
	await step(2)
	await drive([tunnel.edge_point("C", "P1", 9.5)], 4.0)
	check(0 not in tunnel.cutoffs_left and tunnel.guard_on, "North of C he steps out of a door ahead")
	var through := await drive([tunnel.node_pos("P1"), tunnel.node_pos("P2"), tunnel.edge_point("P2", "H", 5.0)], 15.0)
	check(through > 0.0 and tunnel.fade_clock <= 0.0, "Into the pump room on the left and through it to the west tunnel (%.1f s)" % through)
	check(tunnel.push_doors.size() == 2 and tunnel.push_doors.all(func(d): return d.open), "Both pump-room doors bang open when run into")
	check(tunnel.guard_on and tunnel.guard_gap > tunnel.CATCH and tunnel.checkpoint == 1, "He follows through the room, behind (%.1f m)" % tunnel.guard_gap)
	await shot("tunnel-pump-room")
	tunnel._restart_at(0)
	check(tunnel.push_doors.all(func(d): return not d.open and d.body.collision_layer == 1), "After a restart the doors are shut again")
	# A real run: start → A → B → C, sprinting, jumping and sliding through the obstacles.
	tunnel._restart_at(0)
	await step(2)
	var hits_before: int = tunnel.hit_count
	var leg := await drive([tunnel.node_pos("A"), tunnel.node_pos("B"), tunnel.node_pos("C") + Vector3(0, 0, 2)], 40.0)
	check(leg > 0.0, "The bot runs from the stairs to the junction at C (%.1f s)" % leg)
	check(highest_eye < tunnel.HEIGHT - 0.1, "Jumping never puts the head through the ceiling (eye at most %.2f m, ceiling %.1f m)" % [highest_eye, tunnel.HEIGHT])
	check(tunnel.hit_count - hits_before <= 1, "Jumping and sliding at the right moments clears the obstacles (%d hits)" % (tunnel.hit_count - hits_before))
	check(tunnel.fade_clock <= 0.0 and tunnel.guard_gap > tunnel.CATCH, "Running flat out, he stays behind (%.1f m)" % tunnel.guard_gap)
	# Cut-off 1: on into the lit corridor north of C, he steps out of a door ahead.
	var cut := await drive([tunnel.edge_point("C", "D", 9.0)], 6.0)
	check(cut >= 0.0 and 0 not in tunnel.cutoffs_left and tunnel.guard_on, "Heading north from C, he steps out of the pump-room door ahead")
	check(tunnel.guard_pos.z < feet().z - 10.0 and story.subtitle_label.text.contains("đường"), "He is ahead of the player, between them and the dead end")
	await shot("tunnel-cutoff")
	var back := await drive([tunnel.node_pos("C"), tunnel.node_pos("G"), tunnel.node_pos("G") + Vector3(0, 0, -8)], 20.0)
	check(back > 0.0 and tunnel.fade_clock <= 0.0, "Turning back past C and west to G gets away (%.1f s)" % back)
	check(tunnel.guard_pos.distance_to(tunnel.node_pos("G")) < tunnel.node_pos("D").distance_to(tunnel.node_pos("G")), "He follows round by the corridors, behind the player")
	check(tunnel.checkpoint == 1, "Checkpoint at G")
	# The floor gives way into the drain.
	await drive([tunnel.edge_point("G", "H", 34.0)], 12.0, func(): return tunnel.chute.active)
	check(tunnel.chute.active and not tunnel.guard_on, "Further on the floor gives way into the drain")
	var chute: Node3D = tunnel.chute
	var frames_slid := 0
	while chute.active and frames_slid < 60 * 40:
		var wanted := clampf((chute.safe_arc(chute.metres) - chute.arc) * 0.9, -1.0, 1.0)
		chute.look(Vector2((wanted - chute.lean) / p.LOOK_SENSITIVITY, 0))
		chute.spiders.clear()
		await step()
		p.health = 100.0
		frames_slid += 1
	check(not chute.active and tunnel.checkpoint == 2 and absf(feet().y - tunnel.LOWER) < 1.5, "Out of the drain on the lower level (%.1f s)" % (frames_slid / 60.0))
	# Cut-off 2 at L3: he came down the stairs and is ahead again.
	var lower := await drive([tunnel.node_pos("L2"), tunnel.node_pos("L3") + Vector3(-5, 0, 0)], 20.0, func(): return 1 not in tunnel.cutoffs_left)
	check(1 not in tunnel.cutoffs_left and tunnel.guard_on and tunnel.guard_pos.z < tunnel.node_pos("L3").z - 10.0, "At L3 he comes out of a door to the north")
	var east := await drive([tunnel.node_pos("L3"), tunnel.node_pos("L5")], 15.0)
	check(east > 0.0 and tunnel.fade_clock <= 0.0 and tunnel.checkpoint == 3, "East from L3, over the crack and up the broken stair, gets past him (%.1f s)" % east)
	check(absf(feet().y - tunnel.node_pos("L5").y) < 0.3, "The stair climbs %.1f m to the far tunnel" % (feet().y - tunnel.LOWER))
	check(tunnel.fade_clock <= 0.0 and tunnel.guard_on and tunnel.guard_gap < 25.0, "He is coming up behind (%.1f m)" % tunnel.guard_gap)
	# Near the reservoir the cutscene takes over.
	await drive([tunnel.node_pos("X") + Vector3(0, 0, -3.5)], 20.0)
	check(tunnel.state == "leap" and tunnel.fade_clock <= 0.0, "Near the edge over the reservoir a cutscene takes over")
	var environment: Environment = school.get_node("Atmosphere/MoonlitEnvironment").environment
	var fog_before: bool = environment.fog_enabled
	var effects_before := AudioServer.get_bus_effect_count(0)
	var beats := []
	var lowest_pitch := 0.0
	var guard_in_view := false
	var held_board := false
	var plank_y: float = tunnel.plank.position.y
	for i in range(60 * 14):
		if tunnel.state != "leap": break
		if beats.is_empty() or beats[-1] != tunnel.leap_beat:
			beats.append(tunnel.leap_beat)
			if tunnel.leap_beat == "watch": await step(20)
			if tunnel.leap_beat in ["watch", "hang"] or (tunnel.leap_beat == "turn_back"):
				await shot("tunnel-cut-" + tunnel.leap_beat)
		lowest_pitch = minf(lowest_pitch, p.camera.rotation.x)
		if tunnel.leap_beat == "watch":
			var to_guard: Vector3 = (tunnel.guard.global_position + Vector3.UP * 1.4 - p.camera.global_position).normalized()
			if to_guard.dot(-p.camera.global_basis.z) > 0.85 and tunnel.guard.visible: guard_in_view = true
		if tunnel.leap_beat == "hang":
			var tip: Vector3 = tunnel.to_global(tunnel.plank_tip())
			if tip.distance_to(p.camera.global_position) < 0.8 and (tip - p.camera.global_position).normalized().dot(-p.camera.global_basis.z) > 0.5: held_board = true
		await step()
	check(beats == ["approach", "look_down", "turn_back", "watch", "turn_front", "back_up", "run_up", "leap", "hang"], "The beats in order: %s" % ", ".join(beats))
	check(lowest_pitch < -0.8, "At the edge the player looks down at the water (%.2f)" % lowest_pitch)
	check(guard_in_view, "Turned round, the guard is there in the tunnel, torch on the player")
	check(held_board, "Short of the walkway, the player hangs off the end of the board, looking at it")
	check(tunnel.state == "fall" and tunnel.fade_clock <= 0.0, "The board snaps and the player falls")
	await step(45)
	check(tunnel.plank.position.y < plank_y - 2.0, "The broken board falls with them")
	await shot("tunnel-fall")
	check(await tick_until(func(): return tunnel.state == "drown", 4.0), "He falls into the water")
	check(tunnel.splash_spray.emitting, "The water splashes up where he hits it")
	check(environment.fog_enabled and AudioServer.get_bus_effect_count(0) == effects_before + 1, "Under the water: thick fog and every sound muffled")
	await step(36)
	await shot("tunnel-splash")
	check(tunnel.ledge_light.visible and tunnel.guard.visible, "The guard stands on the edge shining his torch down")
	var start_depth: float = tunnel.depth
	for i in range(int(4.0 * 60)):
		if i % 15 == 0: tunnel.swim_stroke()
		await step()
	check(tunnel.depth > start_depth + 0.5, "Kicking for the surface does not get him up: %.1f m deeper" % (tunnel.depth - start_depth))
	await shot("tunnel-underwater")
	var yaw_before: float = p.rotation.y
	tunnel.look(Vector2(120, -40))
	check(absf(angle_difference(p.rotation.y, yaw_before)) > 0.05, "He can still look around under the water")
	check(school.player.camera.global_position.y < tunnel.to_global(Vector3(0, tunnel.water_y, 0)).y, "The camera is below the surface")
	await step(int((tunnel.DROWN_SECONDS - 4.0 + 0.2) * 60))
	check(not tunnel.active and story.fear.fade >= 0.99, "The light goes out: black, then the dream is over")
	check(environment.fog_enabled == fog_before and AudioServer.get_bus_effect_count(0) == effects_before, "The fog and the muffling are taken off again")
	var moved := 0
	for i in range(tunnel.bodies.size()):
		if is_instance_valid(tunnel.bodies[i]) and tunnel.bodies[i].global_position.distance_to(bodies_before[i]) > 0.01: moved += 1
	check(moved == 0, "No obstacle moved by itself the whole run")
	# Nowhere the player can be looks out into the void.
	var boxes := wall_boxes()
	var x: Vector3 = tunnel.node_pos("X")
	var spots := {
		"the hang": tunnel.plank_tip() + Vector3(0.3, -0.2, 0.3),
		"mid-fall": Vector3(x.x, x.y - 7.0, tunnel.far_z() + 1.5),
		"just above the water": Vector3(x.x + 3.0, tunnel.water_y + 0.8, tunnel.far_z()),
		"under the water": Vector3(x.x, tunnel.water_y - 4.0, tunnel.far_z() - 2.0),
		"the pump room": tunnel.edge_point("P1", "P2", 17.0) + Vector3.UP * 1.6,
	}
	for gap in tunnel.gaps:
		spots["the pit at %.0f, %.0f" % [gap.near.x, gap.near.z]] = gap.near + gap.forward * gap.width * 0.5 + Vector3.DOWN * 3.0
	for title in spots:
		var leaks := open_directions(spots[title], boxes)
		check(leaks == 0, "Closed all round from %s (%d of 300 rays escape)" % [title, leaks])
	print("RESULT / ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(5)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
