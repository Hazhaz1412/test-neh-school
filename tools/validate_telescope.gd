extends SceneTree
# godot --headless --path . --script tools/validate_telescope.gd
# Validates the Telescope Minigame, Multi-Page Guidebook (Top Chart + Bottom Info),
# Identical-Color Decoy Stars, Replay & Animal Figure Reveal, and `key_with_tag.glb` Secret Room Clue.

const DomeProjection := preload("res://scripts/telescope/dome_projection.gd")
const HybridTSPSolver := preload("res://scripts/telescope/hybrid_tsp_solver.gd")
const TelescopeEventBus := preload("res://scripts/telescope/telescope_event_bus.gd")
const GameProgress := preload("res://scripts/game_progress.gd")

var failures := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1

func _initialize() -> void:
	GameProgress.recording = false
	call_deferred("run")

func frames(n: int) -> void:
	for _i in range(n):
		await physics_frame

func run() -> void:
	var dp_proj := DomeProjection.new()

	# --- 1. 3D Celestial Sphere & Gaussian Noise (sigma = 0.015) ---
	check(dp_proj.constellations.size() == 3, "All 3 target constellations exist on the continuous 3D Celestial Sphere")
	check(dp_proj.background_stars.size() == 1500, "1,500 background stars are populated on the 3D Celestial Sphere")
	check(absf(DomeProjection.GAUSSIAN_SIGMA - 0.015) < 1e-6, "Gaussian noise parameter sigma = 0.015")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var p_exact := DomeProjection.spherical_to_cartesian(0.7, 0.5)
	var p_noisy := DomeProjection.spherical_to_cartesian(0.7, 0.5, rng, DomeProjection.GAUSSIAN_SIGMA)
	check(absf(p_exact.length() - 1.0) < 1e-5 and absf(p_noisy.length() - 1.0) < 1e-5, "3D Cartesian vectors lie on the unit sphere S^2")
	check(p_exact.distance_to(p_noisy) > 0.001 and p_exact.distance_to(p_noisy) < 0.08, "Gaussian noise sigma = 0.015 perturbs 3D star coordinates realistically")

	# --- 2. Optical Eyepiece (FOV = 30 deg), Frustum Culling & Gnomonic + Barrel Distortion ---
	check(absf(DomeProjection.FOV_DEG - 30.0) < 1e-5, "Optical eyepiece has narrow FOV = 30 degrees")
	var f_cam := DomeProjection.camera_forward(0.7, 0.5)
	var p_inside := DomeProjection.spherical_to_cartesian(0.75, 0.52)
	var p_outside := DomeProjection.spherical_to_cartesian(1.4, 0.52)
	check(DomeProjection.frustum_cull(p_inside, f_cam), "Frustum Culling P_i . F_cam >= cos(FOV/2) accepts stars inside 30-deg cone")
	check(not DomeProjection.frustum_cull(p_outside, f_cam), "Frustum Culling P_i . F_cam >= cos(FOV/2) culls stars outside 30-deg cone")

	var proj_in := DomeProjection.project_point_3d(p_inside, 0.7, 0.5, 296.0, Vector2(440, 360))
	var proj_out := DomeProjection.project_point_3d(p_outside, 0.7, 0.5, 296.0, Vector2(440, 360))
	check(bool(proj_in.visible) and float(proj_in.get("barrel_scale", 0.0)) > 0.8, "Gnomonic + Barrel Distortion projects in-cone star onto circular lens")
	check(not bool(proj_out.visible), "Out-of-cone star is rejected before Canvas drawing")
	check(dp_proj.parallax_clouds.size() >= 20, "Parallax cloud layer is populated for atmospheric depth")

	# --- 3. Auto-Focus Lock (<= 4 deg) & Spherical Subgraph Geodesic TSP on V_real ---
	check(absf(DomeProjection.LOCK_TOLERANCE_DEG - 4.0) < 1e-5, "Auto-focus lock threshold is 4 degrees")
	var c0: Dictionary = dp_proj.constellations[0]
	check(not DomeProjection.is_locked_angle(float(c0.initial_theta), float(c0.initial_phi), float(c0.lock_alpha), float(c0.lock_delta)), "Initial anomaly hint region is > 4 deg from constellation center")
	var near_alpha := float(c0.lock_alpha) + deg_to_rad(2.5)
	var near_delta := float(c0.lock_delta) - deg_to_rad(1.5)
	check(dp_proj.find_locked_constellation(near_alpha, near_delta) == 0, "Auto-focus lock triggers when optical axis is within <= 4 deg of target constellation")

	var stars0: Array = c0.stars
	var real_cnt0 := int(c0.real_count)
	var decoy_cnt0 := int(c0.decoy_count)
	check(real_cnt0 == 8 and decoy_cnt0 == 3 and stars0.size() == 11, "Constellation 1 (Leo) has 8 real stars (V_real) + 3 decoy stars (V_decoy)")

	var dist0 := DomeProjection.compute_spherical_distance_matrix(stars0)
	check(dist0.metric == "spherical_arccos" and int(dist0.n) == real_cnt0, "Geodesic distance matrix D_ij = arccos(P_i . P_j) only includes V_real (8 real stars, excluding 3 decoys)")
	var flat0: PackedFloat32Array = dist0.flat
	var p0: Vector3 = (stars0[0] as Dictionary).pos_3d
	var p1: Vector3 = (stars0[1] as Dictionary).pos_3d
	var expected_d01 := acos(clampf(p0.dot(p1), -1.0, 1.0))
	check(absf(flat0[0 * real_cnt0 + 1] - expected_d01) < 1e-5, "D_ij matches great-circle formula arccos(P_i . P_j)")

	var res0 := HybridTSPSolver.solve(flat0, real_cnt0)
	check(res0.algorithm == "bitmask_dp" and int(res0.full_mask) == (1 << real_cnt0) - 1, "Bitmask DP solves spherical subgraph TSP over V_real")

	var dist24 := DomeProjection.compute_spherical_distance_matrix(dp_proj.dense_cluster_24.stars)
	var res24 := HybridTSPSolver.solve(dist24.flat, dist24.n, 42)
	check(res24.algorithm == "simulated_annealing_2opt" and float(res24.optimal_length) < float(res24.initial_length) * 0.75, "Simulated Annealing + 2-Opt remains operational for N = 24 > 20")

	# --- 4. Guidebook Atlas (Top Chart + Bottom Info + Animal Strokes) & Decoy Star Filtering ---
	var all_have_animal_and_info := true
	for entry in DomeProjection.ZODIAC_ATLAS:
		if str(entry.get("animal_name", "")) == "" or str(entry.get("lore", "")) == "" or (entry.get("animal_strokes", []) as Array).is_empty():
			all_have_animal_and_info = false
	check(DomeProjection.ZODIAC_ATLAS.size() == 12 and all_have_animal_and_info, "All 12 Guidebook pages contain both Top Constellation/Animal Chart data and Bottom Constellation Info")

	var real_indices0: PackedInt32Array = dist0.real_indices
	var opt_real_path0: PackedInt32Array = res0.optimal_path
	var valid_star_path := PackedInt32Array()
	for r_idx in opt_real_path0:
		valid_star_path.append(real_indices0[r_idx])
	var eval_valid := HybridTSPSolver.evaluate_spherical_subgraph_route(valid_star_path, stars0, float(res0.optimal_length), flat0, real_indices0)
	check(eval_valid.complete and int(eval_valid.decoy_count) == 0 and eval_valid.unlocked, "Connecting only V_real in optimal order achieves eta = 100% >= 95% and unlocks")

	var path_with_decoy := valid_star_path.duplicate()
	path_with_decoy[path_with_decoy.size() - 1] = real_cnt0
	var eval_decoy := HybridTSPSolver.evaluate_spherical_subgraph_route(path_with_decoy, stars0, float(res0.optimal_length), flat0, real_indices0)
	check(int(eval_decoy.decoy_count) == 1 and not eval_decoy.unlocked, "Connecting a decoy star is detected and rejected")

	# --- 5. Two-Layer Unlock & Secret Room Unlock with `key_with_tag.glb` ---
	var bus := TelescopeEventBus.instance()
	bus.reset()
	var furthest_before := GameProgress.furthest()

	var lock_early: Dictionary = bus.attempt_safe_unlock("598418")
	check(not bool(lock_early.unlocked) and str(lock_early.reason) == "drawer_locked", "Safe cannot be opened before solving all 3 sky constellations")

	var secret_early: Dictionary = bus.unlock_secret_room()
	check(not bool(secret_early.unlocked) and str(secret_early.reason) == "missing_key", "Secret Room cannot be opened before obtaining `key_with_tag.glb` (`room_key`)")

	var deduced_passcode := ""
	for idx in range(3):
		var c_i: Dictionary = dp_proj.constellations[idx]
		var d_i := DomeProjection.compute_spherical_distance_matrix(c_i.stars)
		var s_i := HybridTSPSolver.solve(d_i.flat, d_i.n)
		bus.dispatch_lock_opened(str(c_i.id), 1.0, float(s_i.optimal_length), float(s_i.optimal_length), "bitmask_dp", str(c_i.passcode_digits))
		deduced_passcode += str(c_i.passcode_digits)

	check(deduced_passcode == "598418", "Deduced 6-digit passcode from the 3 target constellations in the Guidebook is 598418")
	check(bus.is_drawer_opened() and bus.has_item("room_key"), "Solving all 3 constellations grants `key_with_tag.glb` (`room_key`)")

	var good_safe: Dictionary = bus.attempt_safe_unlock(deduced_passcode)
	check(bool(good_safe.unlocked) and bus.is_safe_opened() and bus.has_item("new_evidence"), "Entering deduced 6-digit code `598418` unlocks the Safe and grants `new_evidence`")

	var secret_ok: Dictionary = bus.unlock_secret_room()
	check(bool(secret_ok.unlocked) and bus.is_secret_room_opened() and bus.has_item("next_clue"), "Using `key_with_tag.glb` unlocks the Secret Room and grants `next_clue` (Manh mối tiếp theo)")
	check(GameProgress.furthest() == furthest_before, "Main story state (GameProgress) is completely untouched")

	# --- 6. Non-Interactive Prop Station on the School Rooftop ---
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	await frames(6)
	var r_tele: Node3D = school.rooftop_telescope
	var r_books: Node3D = r_tele.get_node_or_null("BookInteractable/BooksModel")
	check(r_tele != null and not bool(r_tele.interactive), "School rooftop station (`school_runtime.tscn`) is marked non-interactive (`interactive == false`)")
	check(r_tele.get_node_or_null("TelescopeInteractable/TelescopeModel") != null and r_books != null and absf(r_books.position.y) < 0.01, "Only the 3D Telescope (`telescope.glb`) and Book (`books.glb` lying directly on the ground, y = 0) exist on the school rooftop")
	check(r_tele.get_node_or_null("TelescopeInteractable/InteractionArea") == null and r_tele.get_node_or_null("BookInteractable/InteractionArea") == null and r_tele.get_node_or_null("SecretRoomInteractable") == null and r_tele.prompt_for(r_tele.global_position) == "", "Player cannot interact with the rooftop telescope or book, and no Secret Room / Key exists on the school rooftop")
	school.queue_free()
	await frames(4)

	# --- 7. Full Interactive Flow in Dream Meadow (Broken Telescope -> Fairground Lens Pickup -> Repair -> Replay + Animal Reveal + Secret Room Opening) ---
	bus.reset()
	var meadow: Node3D = load("res://scenes/dream_meadow.tscn").instantiate()
	root.add_child(meadow)
	await frames(6)
	var m_station: Node3D = meadow.telescope_station
	check(m_station != null and m_station.get_node_or_null("BookInteractable/KeyModel") != null, "Telescope, Guidebook, `key_with_tag.glb` & Secret Room exist in dream_meadow.tscn")
	check(bool(m_station.is_broken()), "Telescope at the start of Dream Meadow begins in a broken state (`is_broken() == true`)")
	check(meadow.fold != null and meadow.fold.lens_pickup != null, "Fairground (`Khu vui chơi`) contains the glowing Telescope Lens Core pickup (`TelescopeLensPickup`)")

	m_station.open_telescope()
	await frames(2)
	check(m_station.is_open() and m_station.active_ui.name == "BrokenTelescopeView", "Interacting with the broken telescope before finding the lens core opens BrokenTelescopeView instead of TelescopeView")
	m_station.active_ui.queue_free()
	m_station.active_ui = null
	await frames(2)

	var picked_ok: bool = meadow.fold.take_lens_pickup()
	check(picked_ok and bus.has_item(TelescopeEventBus.ITEM_LENS_CORE), "Picking up the Lens Core in the Fairground grants `telescope_lens_core` and hides the orb on the pedestal")

	m_station.open_book()
	await frames(2)
	check(m_station.is_open() and m_station.active_ui.name == "TelescopeBookView", "Opening Guidebook shows the 2-page spread with Top Constellation Chart and Bottom Info")

	m_station.open_telescope()
	await frames(2)
	check(not bool(m_station.is_broken()) and bus.is_lens_installed() and m_station.active_ui.name == "TelescopeView", "Interacting with the telescope while holding `telescope_lens_core` installs the part, repairs the telescope, and opens TelescopeView")
	var t_view: Control = m_station.active_ui
	for k in range(3):
		t_view.select_constellation(k)
		t_view.apply_optimal_solution()
	await frames(45)
	check(t_view.replay_progress >= 0.99 and t_view.animal_reveal_alpha >= 0.99, "Solving a constellation replays the connection from the start and reveals the representative animal figure")
	t_view.close_telescope()
	await frames(2)

	m_station.open_secret_room()
	await frames(2)
	check(bus.is_secret_room_opened() and bus.has_item("next_clue") and absf(m_station.secret_door_hinge.rotation_degrees.y - (-96.0)) < 1.0, "Using `key_with_tag.glb` on the Secret Room swings the door open and reveals the Next Clue UI")
	if m_station.is_open():
		m_station.active_ui.queue_free()
	await frames(2)
	bus.reset()

	print("Passed %d/%d checks" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
