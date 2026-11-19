extends SceneTree
# godot --path . --script tools/capture_telescope.gd --resolution 1280x720
# Captures screenshots of:
# - `telescope-meadow.png`: Telescope, Guidebook, `key_with_tag.glb` & Secret Room in Dream Meadow
# - `telescope-book.png`: Guidebook with each page split into Top Constellation/Animal Chart & Bottom Info
# - `telescope-lens-dp.png`: Eyepiece after re-connecting from the start & revealing the Lion (Leo) figure
# - `telescope-lens-sa.png`: Eyepiece after solving all 3 constellations (Aquarius figure + `key_with_tag.glb` & Safe unlocked)
# - `telescope-secret-room.png`: Opening the Secret Room with `key_with_tag.glb` to reveal the Next Clue
# - `telescope-rooftop.png`: Telescope, Guidebook, Key & Secret Room on the School Rooftop

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

func frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func save_shot(name: String, wait_frames := 25) -> void:
	await frames(wait_frames)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/telescope-%s.png" % name)
	print("Saved res://docs/telescope-%s.png" % name)

func run() -> void:
	# 1. Dream Meadow: Telescope, Guidebook, Key (`key_with_tag.glb`) & Secret Room beside the bed and tree.
	var meadow: Node3D = load("res://scenes/dream_meadow.tscn").instantiate()
	root.add_child(meadow)
	current_scene = meadow
	await frames(5)
	meadow.fade.color.a = 0.0
	meadow.state = "walk"
	meadow.lit = true
	meadow.bright = 0.85
	meadow.shown_bright = -1.0
	meadow._apply_brightness()
	var p: CharacterBody3D = meadow.player
	p.set_physics_process(false)
	var station: Node3D = meadow.telescope_station
	var cam_from: Vector3 = station.to_global(Vector3(-0.2, 1.55, 3.4))
	var cam_target: Vector3 = station.to_global(Vector3(-0.2, 0.95, 0.0))
	p.global_position = cam_from - Vector3(0, p.EYE, 0)
	var to := cam_target - cam_from
	var flat := Vector3(to.x, 0, to.z)
	p.yaw = atan2(-flat.x, -flat.z)
	p.pitch = atan2(to.y, flat.length())
	p.camera.position = Vector3(0, p.EYE, 0)
	p.camera.rotation = Vector3(p.pitch, 0, 0)
	meadow.prompt.text = "E · Nhìn vào kính thiên văn  |  Đọc sách hướng dẫn  |  Mở Căn phòng bí mật"
	meadow.prompt.modulate.a = 1.0
	await save_shot("meadow", 35)

	# 2. Open Guidebook UI (Top half = Constellation & Animal Chart, Bottom half = Constellation Info).
	station.open_book()
	await save_shot("book", 20)

	# 3. Repair the broken telescope with the Fairground Lens Core & open Green Optical Telescope Eyepiece — Anomaly #1 (Leo, code 59) re-connected & Lion figure revealed!
	station.repair_and_open_telescope()
	await frames(5)
	var view: Control = station.active_ui
	view.select_constellation(0)
	view.lock_dome_immediately()
	view.toggle_hint()
	view.apply_optimal_solution()
	await save_shot("lens-dp", 55)

	# 4. Solve Anomalies #2 (Scorpius, code 84) & #3 (Aquarius, code 18) -> Grants `key_with_tag.glb` & Unlocks Safe.
	view.select_constellation(1)
	view.apply_optimal_solution()
	view.select_constellation(2)
	view.lock_dome_immediately()
	view.toggle_hint()
	view.apply_optimal_solution()
	view.safe_input.text = "598418"
	view._on_safe_unlock_pressed()
	await save_shot("lens-sa", 55)

	view.close_telescope()
	await frames(5)

	# 5. Use `key_with_tag.glb` to unlock the Secret Room and view the Next Clue!
	station.open_secret_room()
	await save_shot("secret-room", 20)
	if station.is_open():
		station.active_ui.queue_free()
		station.active_ui = null
	await frames(4)

	# 5b. Show the Telescope Lens Core Pickup (`TelescopeLensPickup`) in the Fairground (`Khu vui chơi`) at night!
	preload("res://scripts/telescope/telescope_event_bus.gd").instance().reset()
	meadow.fold._sync_lens_pickup()
	meadow.make_night()
	p.set_process(false)
	var fair: Node3D = meadow.fold.fair
	var pickup_pos: Vector3 = meadow.fold.lens_pickup.position
	var cam_world: Vector3 = fair.to_global(pickup_pos + Vector3(1.6, 1.45, 2.2))
	var target_world: Vector3 = fair.to_global(pickup_pos + Vector3(0.0, 0.85, 0.0))
	var up_world: Vector3 = fair.global_basis.y.normalized()
	p.camera.global_transform = Transform3D(Basis.looking_at(target_world - cam_world, up_world), cam_world)
	meadow.prompt.text = "E · Nhặt Cục Thấu Kính Tinh Tú (Sửa Kính Thiên Văn)"
	meadow.prompt.modulate.a = 1.0
	await save_shot("fair-pickup", 30)

	meadow.queue_free()
	await frames(5)

	# 6. School Rooftop: Non-interactive Telescope (`telescope.glb`) & Book (`books.glb` on the ground) on Building A's rooftop.
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(10)
	var sp: CharacterBody3D = school.player
	sp.set_physics_process(false)
	var r_station: Node3D = school.rooftop_telescope
	var eye_pos: Vector3 = r_station.global_position + Vector3(-0.4, 1.45, 2.2)
	var look_target: Vector3 = r_station.global_position + Vector3(0.32, 0.55, 0.08)
	sp.global_position = eye_pos - Vector3(0, 1.62, 0)
	var dir := look_target - eye_pos
	sp.rotation.y = atan2(-dir.x, -dir.z)
	sp.camera.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())
	sp.flashlight.show()
	school.interaction_label.text = ""
	school.interaction_label.hide()
	await save_shot("rooftop", 30)

	quit(0)
