extends SceneTree
# Night 1 on the real scene: the ordinary school, four students, the guard dragging whoever he
# catches to a locked room, friends unlocking it, the life bar, and the kiting walls.
var failures := 0
var school: Node3D

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func until(test: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second * Engine.time_scale
		if test.call():
			return true
	return false

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func run() -> void:
	set_meta("night_one", true)
	school = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(40): await physics_frame
	var player: CharacterBody3D = school.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var team: Node = school.team
	var story: Node3D = school.progression
	check(school.survival.active and school.survival.phase == school.survival.Phase.NIGHT, "the night is running")
	check(not school.spirit_enabled and school.guard_night, "the school stays the ordinary night school, as in Night 0")
	check(story.journal_context().begins_with("ĐÊM 1\n"), "it is called just Night 1")
	check(player.inventory[0] == "torch" and not player.inventory.has("crank"), "the Night 0 torch, no crank light")
	check(player.max_stamina == school.HUNT_STAMINA and player.stamina == school.HUNT_STAMINA, "a longer breath for running")
	check(team != null and team.members.size() == 4 and team.standing() == 4, "four students, all free")
	var walled := []
	for entry in team.members.slice(1):
		var spot := NavigationServer3D.map_get_closest_point(school.get_world_3d().navigation_map, entry.body.global_position)
		if Vector2(spot.x - entry.body.global_position.x, spot.z - entry.body.global_position.z).length() > 0.3:
			walled.append(entry.title)
	check(walled.is_empty(), "the friends start out on open ground " + str(walled))
	check(school.get_tree().get_nodes_in_group("kiting_vault").size() == 16 and school.get_tree().get_nodes_in_group("kiting_pallet").size() == 8 and school.get_tree().get_nodes_in_group("kiting_low").size() == 16, "8 loops, each with two windows, a shelf and two low gaps")
	# None of it may sit inside something already there (planters, lamps, trees: the invisible walls).
	var space := school.get_world_3d().direct_space_state
	var buried := []
	for body in school.kiting.find_children("*", "StaticBody3D", true, false):
		if body.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var box: BoxShape3D = body.get_child(0).shape
		var query := PhysicsShapeQueryParameters3D.new()
		var shrunk := BoxShape3D.new()
		shrunk.size = box.size - Vector3(0.1, 0.1, 0.1)
		query.shape = shrunk
		query.transform = body.global_transform.translated(Vector3.UP * 0.05)
		query.collision_mask = 1
		for hit in space.intersect_shape(query, 8):
			if not school.kiting.is_ancestor_of(hit.collider):
				buried.append(str(body.get_parent().name, " ", hit.collider.name))
	check(buried.is_empty(), "no loop overlaps anything already in the yard " + str(buried.slice(0, 4)))
	check(school.get_node("Navigation").navigation_mesh.resource_path.ends_with("hunt_navigation.tres"), "the guard's map knows the walls")
	await until(func(): return school.envy.started, 6.0)
	var demon: CharacterBody3D = school.envy.demon
	check(demon != null and demon.model.get_script() == preload("res://scripts/guard_hunter_model.gd"), "the hunter wears the guard's body")
	check(demon.CHASE_SPEED > player.RUN_SPEED, "the guard runs faster than a student")
	var map: RID = school.get_world_3d().navigation_map
	await until(func(): return NavigationServer3D.map_get_iteration_id(map) > 2, 5.0)

	# A low gap: students go under, the guard has to go all the way round the wall.
	var low: Node3D = school.get_tree().get_nodes_in_group("kiting_low")[1]
	var near_side: Vector3 = low.to_global(Vector3(0, 0.05, 2.2))
	var far_side: Vector3 = low.to_global(Vector3(0, 0.05, -2.2))
	var length := func(path: PackedVector3Array) -> float:
		var total := 0.0
		for i in range(1, path.size()): total += path[i - 1].distance_to(path[i])
		return total
	var student_way: float = length.call(NavigationServer3D.map_get_path(map, near_side, far_side, true, 3))
	var guard_way: float = length.call(NavigationServer3D.map_get_path(map, near_side, far_side, true, 1))
	print("through a low gap: student %.1f m, guard %.1f m" % [student_way, guard_way])
	check(guard_way > student_way + 8.0, "the guard cannot follow under a low gap")
	check(not player.can_fit(low.to_global(Vector3(0, 0.05, 0)), player.STAND_HEIGHT), "nobody stands up under the boards")
	# Sprint, C: the slide carries the player right through.
	demon.global_position = Vector3(-50, 0.05, 60)
	demon.set_physics_process(false)
	player.global_position = low.to_global(Vector3(0, 0.05, 2.4))
	player.rotation.y = low.global_rotation.y
	player.camera.rotation = Vector3.ZERO
	await physics_frame
	player.velocity = -player.global_basis.z * player.RUN_SPEED
	player._start_slide()
	while player.slide_time > 0.0:
		await physics_frame
		player._tick_slide(1.0 / 60.0)
	var under: float = low.to_local(player.global_position).z
	check(under < 0.6, "a slide carries the player under the boards (now %.2f m along)" % -under)
	player.set_crouching(true, true)
	for i in range(90):
		player.velocity = -player.global_basis.z * player.CROUCH_SPEED
		player.move_and_slide()
		await physics_frame
	check(low.to_local(player.global_position).z < -0.8, "and crawling gets them out the other side")
	player.set_crouching(false, true)

	# He boards up a gap he saw used: crawling stops, E for five seconds or a slide at a cost.
	var course: Node3D = school.kiting
	course.seen_used[low] = true
	demon.set_physics_process(true)
	demon.state = demon.State.ROAM
	demon.global_position = low.to_global(Vector3(0.6, 0.05, 1.9))
	demon.agent.target_position = demon.global_position
	player.global_position = Vector3(-30, 0.05, 66)
	var boarded := await until(func(): return course.is_boarded(low), 5.0)
	check(boarded, "passing a gap he saw used, he boards it up")
	demon.global_position = Vector3(-50, 0.05, 60)
	demon.set_physics_process(false)
	player.global_position = low.to_global(Vector3(0, 0.05, 2.0))
	player.rotation.y = low.global_rotation.y
	player.set_crouching(true, true)
	for i in range(90):
		player.velocity = -player.global_basis.z * player.CROUCH_SPEED
		player.move_and_slide()
		await physics_frame
	check(low.to_local(player.global_position).z > 0.5, "the planks stop a crawl")
	player.set_crouching(false, true)
	check(course.prompt().contains("Giữ E"), "it says how to get through: " + course.prompt())
	key(KEY_E, true)
	var pulled_off := await until(func(): return not course.is_boarded(low), 6.5)
	key(KEY_E, false)
	check(pulled_off and course.unboarding == 0.0, "holding E for five seconds pulls the planks off")
	course.board(low)
	player.health = 100.0
	player.invulnerable_time = 0.0
	player.global_position = low.to_global(Vector3(0, 0.05, 2.4))
	player.rotation.y = low.global_rotation.y
	await physics_frame
	player.velocity = -player.global_basis.z * player.RUN_SPEED
	player._start_slide()
	while player.slide_time > 0.0:
		await physics_frame
		player._tick_slide(1.0 / 60.0)
	check(not course.is_boarded(low) and absf(player.health - 75.0) < 0.01, "a slide smashes through for a quarter of the health: %d left" % player.health)
	player.set_crouching(false, true)
	player.health = 100.0

	# A real SPACE at a vault window: over and out the other side in half a second.
	var window: Node3D = school.get_tree().get_nodes_in_group("kiting_vault")[0]
	demon.global_position = Vector3(-50, 0.05, 60)
	demon.set_physics_process(false)
	player.global_position = window.to_global(Vector3(0, 0.05, 1.0))
	player.rotation.y = window.global_rotation.y
	player.camera.rotation = Vector3.ZERO
	for i in range(5): await physics_frame
	# Headless runs cannot hold the mouse captured, which the movement code waits for.
	var started: bool = player._try_vault()
	await until(func(): return player.vault_time <= 0.0, 1.5)
	var side: float = window.to_local(player.global_position).z
	check(started and side < -0.6, "SPACE at the window vaults it (now %.2f m beyond)" % -side)
	# 0.2 s into the climb, too late for him to grab.
	player.global_position = window.to_global(Vector3(0, 0.05, -1.0))
	player.rotation.y = window.global_rotation.y + PI
	player._try_vault()
	var early: bool = demon._out_of_reach(player)
	for i in range(15):
		player._tick_vault(1.0 / 60.0)
	check(not early and demon._out_of_reach(player), "after 0.2 s of a climb the player cannot be caught")
	while player.vault_time > 0.0:
		player._tick_vault(1.0 / 60.0)
	player.global_position = Vector3(-30, 0.05, 66)

	# The guard is three times slower over the same sill.
	demon.set_physics_process(true)
	demon.global_position = window.to_global(Vector3(0, 0.05, 1.6))
	demon.agent.target_position = window.to_global(Vector3(0, 0.05, -1.6))
	demon.state = demon.State.REST
	demon.rest_left = 6.0
	var vaulted := await until(func(): return demon.cross_time > 0.0, 4.0)
	var took := 0.0
	while demon.cross_time > 0.0 and took < 3.0:
		await physics_frame
		took += 1.0 / 60.0
	check(vaulted and took > player.VAULT_SECONDS * 2.5, "the guard climbs over slowly: %.2f s" % took)
	demon.chase_time = 12.0
	demon._climb(window)
	check(demon.chase_time == 0.0, "a climb winds his speed back down to the base")
	demon.cross_time = 0.0
	check(absf(demon.CHASE_SPEED / player.RUN_SPEED - 1.05) < 0.01, "his base speed is 5%% over a sprint")

	# A shelf tipped into its gap: students vault it, the guard has to drag it clear.
	var shelf: Node3D = school.get_tree().get_nodes_in_group("kiting_pallet")[0]
	demon.state = demon.State.ROAM
	demon.global_position = Vector3(-50, 0.05, 60)
	player.global_position = shelf.to_global(Vector3(0, 0.05, 1.2 * shelf.inward))
	player.rotation.y = shelf.global_rotation.y + (0.0 if shelf.inward > 0 else PI)
	await physics_frame
	check(school.kiting.prompt().begins_with("E"), "beside a standing shelf: " + school.kiting.prompt())
	key(KEY_E, true)
	await physics_frame
	key(KEY_E, false)
	await until(func(): return false, 0.6)
	check(shelf.is_down(), "E tips the shelf into the gap")
	check(school.kiting.prompt().begins_with("SPACE"), "then it can be vaulted: " + school.kiting.prompt())
	var over: bool = player._try_vault()
	await until(func(): return player.vault_time <= 0.0, 1.5)
	check(over and signf(shelf.to_local(player.global_position).z) != signf(shelf.inward), "a student vaults the fallen shelf")
	demon.global_position = shelf.to_global(Vector3(0, 0.05, 2.0 * shelf.inward))
	demon.agent.target_position = shelf.to_global(Vector3(0, 0.05, -3.0 * shelf.inward))
	demon.state = demon.State.REST
	demon.rest_left = 10.0
	var halted := await until(func(): return demon.clear_time > 0.0, 4.0)
	var cleared_in := 0.0
	while demon.clear_time > 0.0 and cleared_in < 5.0:
		await physics_frame
		cleared_in += 1.0 / 60.0
	check(halted and cleared_in > 2.0 and shelf.state == shelf.State.CLEARED, "the guard spends %.1f s dragging it clear" % cleared_in)
	# Dropped on him, it knocks him back.
	var second: Node3D = school.get_tree().get_nodes_in_group("kiting_pallet")[1]
	demon.state = demon.State.CHASE
	demon.target = player
	demon.global_position = second.to_global(Vector3(0, 0.05, 0.4))
	second.drop(player)
	check(demon.state == demon.State.STAGGER and demon.stunned, "a shelf dropped on him stuns him")
	await until(func(): return not demon.stunned, 4.0)
	check(demon.state == demon.State.CHASE, "and then he is straight back after you")

	# Right mouse held: the head turns back smoothly, not in one jump, and comes back the same way.
	player.look_back = 0.0
	player._pose_look_back()
	var turns := []
	for i in range(30):
		player.look_back = move_toward(player.look_back, 1.0, (1.0 / 60.0) / player.LOOK_BACK_SECONDS)
		player._pose_look_back()
		turns.append(player.camera.rotation.y)
	var steps_ok := true
	for i in range(1, turns.size()):
		steps_ok = steps_ok and turns[i] - turns[i - 1] < 0.4 and turns[i] >= turns[i - 1]
	check(steps_ok and absf(turns[-1] - player.LOOK_BACK_YAW) < 0.01, "the head sweeps round in about a third of a second")
	check(turns[1] - turns[0] < turns[10] - turns[9], "it eases out of the turn like a neck, not at full speed")
	for i in range(30):
		player.look_back = move_toward(player.look_back, 0.0, (1.0 / 60.0) / player.LOOK_BACK_SECONDS)
		player._pose_look_back()
	check(absf(player.camera.rotation.y) < 0.001 and player.look_back_eased == 0.0, "and turns back the same way")

	# Sprint, then C: a slide faster than running, paid for in breath.
	demon.state = demon.State.ROAM
	demon.global_position = Vector3(-50, 0.05, 60)
	player.global_position = Vector3(-30, 0.05, 66)
	player.rotation.y = PI * 0.5
	player.velocity = -player.global_basis.z * player.RUN_SPEED
	var breath: float = player.stamina
	player._start_slide()
	check(player.slide_time > 0.0 and player.stamina < breath and player.crouching, "a slide costs stamina and drops you low")
	player._tick_slide(1.0 / 60.0)
	check(Vector2(player.velocity.x, player.velocity.z).length() > player.RUN_SPEED, "sliding starts faster than a sprint")
	player.slide_time = 0.0
	player.set_crouching(false, true)

	# Fatigue: chased, each second and each breath won back slows the next one.
	demon.target = player
	demon.state = demon.State.CHASE
	player.fatigue = 0.0
	for i in range(30):
		player._tick_fatigue(1.0, 15.0)
	check(player.fatigue > 0.6 and player.recovery() < 0.5, "thirty seconds of chase: fatigue %.2f, breath back at %d%%" % [player.fatigue, player.recovery() * 100])
	demon.state = demon.State.SWEEP
	for i in range(8):
		player._tick_fatigue(1.0, 0.0)
	check(player.fatigue < 0.05, "shaking him off clears it")
	demon.state = demon.State.ROAM

	# He catches a friend: dragged off, locked in, a quarter of a life gone.
	var friend: CharacterBody3D = team.members[1].body
	friend.global_position = Vector3(30, 0.05, 66)
	demon.global_position = friend.global_position + Vector3(1.0, 0, 0)
	player.global_position = Vector3(-30, 0.05, 66)
	await physics_frame
	demon.target = friend
	demon._seize()
	check(friend.seized and team.member(friend).status == team.Status.CARRIED, "a catch is a grab, not a death")
	# Lambdas copy locals, so the farthest point is kept in an array.
	var carried_far := [0.0]
	var start: Vector3 = friend.global_position
	var jailed := await until(func():
		carried_far[0] = maxf(carried_far[0], friend.global_position.distance_to(start))
		return team.member(friend).status == team.Status.JAILED, 60.0)
	var held_at: Node3D = team.member(friend).jail
	check(jailed and carried_far[0] > 5.0, "he drags them %.0f m to a room and locks them in" % carried_far[0])
	check(absf(team.member(friend).life - (team.LIFE - team.CAPTURE_COST)) < 2.0, "the catch costs 200 of 600 seconds")
	check(held_at != null and held_at.is_locked() and team.beacons.has(held_at), "the room is locked and marked for the team")
	var left: float = team.member(friend).life
	await until(func(): return false, 2.0)
	check(team.member(friend).life < left - 1.5, "the bar keeps draining while locked up")

	# The other friends go and unlock it once he has walked off.
	demon.fall_back(Vector3(-40, 0.05, -70), 40.0)
	var freed := await until(func(): return team.member(friend).status == team.Status.FREE, 90.0)
	check(freed, "a friend comes and lets them out")
	check(not friend.seized and not held_at.is_locked(), "free to run again, the door unlocked")

	# The player is caught: dragged, unable to act, but still looking around.
	demon.state = demon.State.ROAM
	demon.global_position = player.global_position + Vector3(1.0, 0, 0)
	demon.target = player
	demon._seize()
	check(player.seized and player.captive and not player.can_use_item(), "caught, the player cannot do anything")
	# A then D then A fights the grip; one key hammered does nothing.
	var me = team.member(player)
	var press := func(code: Key) -> void:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		team._unhandled_key_input(event)
	press.call(KEY_A)
	var one_press: float = me.struggle
	press.call(KEY_A)
	check(is_equal_approx(me.struggle, one_press) and one_press > 0.0, "the same key twice counts once")
	me.struggle = 0.995
	press.call(KEY_D)
	await physics_frame
	await physics_frame
	check(me.status == team.Status.FREE and not player.seized and demon.state == demon.State.STAGGER, "a full bar breaks his grip")
	check(me.escapes == 1, "and the next struggle is harder")
	demon.stunned = false
	demon.state = demon.State.ROAM
	player.invulnerable_time = 0.0
	demon.global_position = player.global_position + Vector3(1.0, 0, 0)
	demon.target = player
	demon._seize()
	press.call(KEY_A)
	check(absf(me.struggle - one_press / 1.5) < 0.002, "50%% harder after one escape: %.4f a press" % me.struggle)
	jailed = await until(func(): return me.status == team.Status.JAILED, 60.0)
	check(jailed and me.escapes == 0, "locked up in a room, the struggle count starts over")
	var my_room: Node3D = me.jail
	check(not player.seized and not player.captive and player.collision_layer == 0, "free to walk about the room, and never in the guard's way")
	player.global_position = team.outside(my_room)
	await physics_frame
	await physics_frame
	var inside_now: float = my_room.to_local(player.global_position).z * float(my_room.get_meta("swing_side", 1.0))
	check(inside_now > 0.3, "but not out through the doorway")
	check(not team.is_free(player) and not demon._exposed(player), "the guard leaves a locked-up student alone")

	# Hold E at a locked door to let a friend out (the real key, three seconds).
	team._free_jail(my_room, team.members[2].body)
	var other: CharacterBody3D = team.members[3].body
	other.global_position = Vector3(30, 0.05, 66)
	team.seize(other)
	team.imprison(other, held_at)
	demon.fall_back(Vector3(-40, 0.05, -70), 40.0)
	for entry in team.members.slice(1):
		if entry.body != other:
			entry.body.global_position = Vector3(-55, 0.05, -75)
	player.global_position = team.outside(held_at)
	await physics_frame
	check(team.prompt().begins_with("Giữ E"), "standing at the door says hold E: " + team.prompt())
	key(KEY_E, true)
	var unlocked := await until(func(): return team.member(other).status == team.Status.FREE, 5.0)
	key(KEY_E, false)
	check(unlocked, "holding E unlocks the room")

	# Third time is the end of a student.
	team.member(other).life = 100.0
	team.seize(other)
	team.imprison(other, held_at)
	check(team.member(other).status == team.Status.OUT and not other.visible, "a catch with under 250 left knocks them out")

	# Everyone held at once: the night is lost.
	for entry in team.members:
		if entry.status == team.Status.FREE:
			team.seize(entry.body)
	check(school.survival.finished and not school.survival.won and team.lost, "the whole team caught together loses the night")
	print("failures ", failures)
	quit(failures)
