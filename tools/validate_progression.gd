extends SceneTree
var school: Node3D
var p: Node3D
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("validate")
func frames(count := 3) -> void:
	for i in range(count):
		await physics_frame
func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS / " if ok else "FAIL / ", description)
	if not ok:
		failures += 1
func approach(item: Node3D) -> bool:
	var floor_y := floorf((item.global_position.y + 0.2) / 3.9) * 3.9 + 0.05
	if item.global_position.y > 11.7:
		floor_y = 11.75
	for radius in [1.1, 1.6, 2.0, 2.3]:
		for angle in range(24):
			var feet: Vector3 = Vector3(item.global_position.x, floor_y, item.global_position.z) + Vector3(cos(angle * TAU / 24), 0, sin(angle * TAU / 24)) * radius
			if not school.player.can_fit(feet):
				continue
			# The key must be accessible from the staircase side of the locked roof.
			if item == p.terminals[4] and feet.x > 6.8:
				continue
			school.player.position = feet
			school.player.camera.look_at(item.global_position)
			await frames(1)
			if school.player.get_interaction_target() == item:
				return true
	return false
func open(kind: int) -> bool:
	p.close()
	if not await approach(p.terminals[kind]):
		return false
	return p.terminals[kind].interact(school.player)
func ray_blocked(a: Vector3, b: Vector3, gate: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(a, b, 5)
	var hit := school.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == gate.body
func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 0
	school.special_enemy_count = 0
	root.add_child(school)
	current_scene = school
	await frames(12)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	school.player.set_physics_process(false)
	school.survival.set_physics_process(false)
	p = school.progression
	check(p.completed.is_empty() and not p.roof_key and not p.roof_open, "Normal run starts with unsolved parallel branches and a locked roof")
	check(p.gates.size() == 5 and p.gates.all(func(g): return g.body.collision_layer == 5), "All three connector floors, service entrance and rooftop have physical barriers")
	check(ray_blocked(Vector3(1.5, 1.2, -12), Vector3(1.5, 1.2, -16), p.gates[0]), "Connector barrier really blocks movement/rays")
	check(ray_blocked(Vector3(5.8, 12.7, 1), Vector3(8.2, 12.7, 1), p.gates[4]), "Roof barrier spans the actual staircase exit")
	check(not p.sector_accessible(Vector3(1.5, 0, -20)), "Smart spawning rejects locked B sectors")
	school.player.position = Vector3(5.7, 11.75, 0)
	await frames()
	check(school.player.test_move(school.player.global_transform, Vector3(2.5, 0, 0)), "Player capsule cannot cross the locked roof exit")
	check(not p.terminals[4].interact(school.player) and not p.ready_for_rescue(), "Remote key pickup and rescue shortcuts fail")
	for i in range(4):
		check(await open(i), "Branch %d can be reached and opened BEFORE any other branch or master key" % i)
		check(school.simulation_active() and not school.player.can_use_item(), "Technical UI leaves the night active and blocks unintended item use")
		p.submit()
		p.finish_branch()
		check(p.completed.is_empty(), "Empty/wrong branch %d cannot grant a reward" % i)
		p.close()
	check(await open(1), "Routing can start first")
	p.cell_click(5)
	p.cell_click(0)
	var partial: Array = p.puzzles.route.duplicate()
	p.close()
	check(await open(2), "Can leave routing unfinished and work on plumbing")
	p.cell_click(0)
	var pipe_partial: Array = p.puzzles.pipes.duplicate()
	p.close()
	check(await open(1) and p.puzzles.route == partial, "Interrupted routing progress persists across visits")
	p.close()
	check(await open(2) and p.puzzles.pipes == pipe_partial, "Interrupted plumbing progress persists across visits")
	# Rotate the actual tiles to a closed source-to-drain path; no completion flag.
	var solved := {0: 10, 1: 12, 5: 3, 6: 12, 10: 5, 14: 3, 15: 10}
	for cell in solved:
		for _turn in range(4):
			if p.puzzles.pipes[cell] == solved[cell]:
				break
			p.cell_click(cell)
	p.submit()
	check(p.completed.has(2) and not p.completed.has(1) and not p.completed.has(0), "Plumbing can finish FIRST without electricity or routing")
	check(p.gates[3].opened() and not p.gates[0].opened() and not p.flood.visible and not p.door_locked(1204), "Pump drains archive and opens service entrance independently")
	check(p.sector_accessible(Vector3(1.5, 0, -20)) and not p.door_locked(1102), "Service entrance gives an alternative into B")
	check(not p.gates[4].opened() and not p.roof_key, "One repaired system cannot unlock An's roof")
	p.close()
	check(await open(0), "Electrical branch is available after another branch")
	# Overload must fail without clearing the branch/other progress.
	for i in range(4): p.cell_click(i)
	p.submit()
	check(not p.completed.has(0) and p.completed.has(2), "Overloaded electrical bus fails and preserves plumbing progress")
	p.cell_click(1)
	p.cell_click(2)
	p.submit()
	check(p.completed.has(0) and p.puzzles.electrical_valid(), "4A+1A and 3A+2A pass actual load partition validation")
	p.close()
	check(await open(1), "Return to preserved route")
	p.cell_click(10)
	# Cheapest upper route; tests exercise the adjacency controller.
	for cell in [5, 0, 1, 6]: p.cell_click(cell)
	check(p.puzzles.route[-1] == 6, "Only adjacent traversable route clicks are accepted")
	p.cell_click(14)
	check(p.puzzles.route[-1] == 6, "Nonadjacent route cannot teleport across blocked cells")
	p.cell_click(7)
	check(p.puzzles.route[-1] == 6, "Wall cells cannot be selected")
	# Bottom route is the optimal one on this board (cost computed by Dijkstra).
	p.cell_click(10)
	for cell in [15, 16, 11]: p.cell_click(cell)
	p.cell_click(16)
	p.cell_click(15)
	p.cell_click(20)
	check(p.puzzles.route[-1] == 20, "Backtracking trims route without restarting other branches")
	# Generate the shortest path independently using a small exhaustive relaxation.
	var distances := {10: 0}
	var prev := {}
	for iteration in range(25):
		for cell in distances.keys():
			for n in p.puzzles.neighbors(cell):
				if p.puzzles.WALLS.has(n): continue
				var cost: int = distances[cell] + p.puzzles.COSTS[n]
				if cost < int(distances.get(n, 999)):
					distances[n] = cost
					prev[n] = cell
	var path: Array[int] = [14]
	while path[0] != 10: path.push_front(prev[path[0]])
	p.cell_click(10)
	for i in range(1, path.size()): p.cell_click(path[i])
	p.submit()
	check(p.completed.has(1) and p.puzzles.route_cost() == distances[14], "Only the independently verified optimal route opens A–B")
	check(p.gates.slice(0, 3).all(func(g): return g.opened()), "Routing opens the connector on all three floors")
	p.close()
	check(await open(3), "Board opponent can be played independently")
	p.cell_click(12)
	check(p.puzzles.board.count(1) == 1 and p.puzzles.board.count(2) == 1 and p.puzzles.nodes_searched > 0, "NPC makes a real minimax response to the player move")
	var board_before: Array = p.puzzles.board.duplicate()
	p.close()
	check(await open(3) and p.puzzles.board == board_before, "Board state is preserved when leaving the NPC")
	# Tactical position fixtures exercise AI blocking and winning, not a fake reward.
	var tactics = load("res://scripts/technical_puzzles.gd").new()
	tactics.best_move(1)
	check(tactics.pruned_branches > 0, "Alpha-beta really prunes bounded NPC search branches")
	tactics.board[0] = 1; tactics.board[1] = 1; tactics.board[2] = 1
	check(tactics.best_move(2) == 3, "NPC blocks a human's immediate four-in-row threat")
	tactics.board.fill(0)
	for cell in [10, 11, 12]: tactics.board[cell] = 2
	check(tactics.best_move(2) in [13], "NPC chooses its own immediate winning move")
	# Play a complete real game using displayed player hints, NPC responds each turn.
	for attempt in range(6):
		p.puzzles.board.fill(0)
		p.puzzles.chess_result = 0
		for turn in range(13):
			var move: int = p.puzzles.best_move(1)
			if move < 0 or p.puzzles.chess_result != 0: break
			p.cell_click(move)
		if p.completed.has(3): break
	check(p.completed.has(3) and p.puzzles.chess_result in [1, 3], "An actually played winning/drawn board game completes the final independent branch")
	p.close()
	check(p.all_complete() and not p.roof_open and not p.roof_key, "Four systems only release the physical key; roof remains locked")
	check(await approach(p.terminals[4]), "Key cabinet is reachable from INSIDE the locked staircase")
	check(p.terminals[4].interact(school.player) and p.roof_key, "Physical key pickup requires the actual completed systems")
	check(not p.gates[4].opened(), "Taking key does not silently open the roof")
	var roof_gate: Node3D = p.gates[4]
	school.player.position = Vector3(5.7, 11.75, 0)
	school.player.camera.look_at(Vector3(7, 12.8, 0))
	await frames()
	check(school.player.get_interaction_target() == roof_gate and roof_gate.interact(school.player), "Player uses the final key to open the real rooftop gate")
	await frames()
	check(not school.player.test_move(school.player.global_transform, Vector3(2.5, 0, 0)), "Player capsule can cross the unlocked roof exit")
	check(p.ready_for_rescue() and roof_gate.body.collision_layer == 0, "Roof opening removes its physical blocker")
	p.cry_clock = 0
	p._process(0.1)
	check(p.cries.all(func(c): return c.playing), "An's real crying clip is spatially emitted from roof and stair vents")
	await frames(3)
	school.paused_by_user = true
	p._process(0.1)
	check(p.cries.all(func(c): return c.stream_paused), "Pausing stops all positional cry voices")
	school.paused_by_user = false
	school.survival.soul_rescued = true
	p._process(0.1)
	check(p.cries.all(func(c): return not c.playing), "Rescuing An stops her crying")
	school.survival.soul_rescued = false
	check(await open(0), "Completed systems remain inspectable")
	school.player.invulnerable_time = 0
	school.player.take_damage(1)
	check(not p.panel_visible(), "Taking damage interrupts technical work")
	p.reset()
	await frames()
	check(p.completed.is_empty() and not p.roof_key and not p.roof_open and p.puzzles.route == [10] and p.puzzles.board.count(0) == 25, "Restart resets all branches, physical blockers and persistent board states")
	check(p.gates.all(func(g): return not g.opened()), "Reset recloses every progression barrier")
	p.bypass_for_test()
	check(p.ready_for_rescue() and p.gates.all(func(g): return g.opened()), "Existing test cheat deliberately bypasses progression without hiding An")
	var report := {"checks": checks, "failures": failures}
	var f := FileAccess.open("res://docs/progression-validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	print("Progression validation: ", report)
	school.queue_free()
	await frames(5)
	load("res://scripts/humanoid_model.gd").animation_libraries.clear()
	load("res://scripts/humanoid_model.gd").proportion_meshes.clear()
	load("res://scripts/student_soul.gd").appearance_materials.clear()
	load("res://scripts/combat_limbs.gd").meshes.clear()
	load("res://scripts/humanoid_model.gd").faceless_mesh = null
	quit(0 if failures == 0 else 1)
