extends SceneTree
# Frame-time check: godot --path . --script tools/bench_meadow.gd --resolution 1600x900
# Plays the meadow at its heaviest views with vsync off and prints FPS, CPU/GPU frame time,
# draw calls and triangles for each. MEADOW_QUALITY=0|1|2 picks the graphics setting (default 1).
var meadow: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

func look(from: Vector3, at: Vector3) -> void:
	player.set_physics_process(false)
	player.global_position = from - Vector3.UP * player.EYE
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	player.yaw = atan2(-flat.x, -flat.z)
	player.pitch = atan2(at.y - from.y, flat.length())

func measure(title: String) -> void:
	for i in range(30): await process_frame
	var frames := 0
	var start := Time.get_ticks_usec()
	var gpu := 0.0
	var cpu := 0.0
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	while Time.get_ticks_usec() - start < 2_000_000:
		await process_frame
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var seconds := (Time.get_ticks_usec() - start) / 1e6
	print("BENCH %-12s %6.1f fps  cpu %5.2f ms  gpu %5.2f ms  draws %5d  tris %8d" % [title, frames / seconds, cpu / frames, gpu / frames,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])

func eye(x: float, z: float) -> Vector3:
	return meadow.on_ground(x, z) + Vector3(0, 1.6, 0)

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("GPU ", RenderingServer.get_video_adapter_name())
	var level := int(OS.get_environment("MEADOW_QUALITY")) if OS.has_environment("MEADOW_QUALITY") else 1
	print("QUALITY ", level)
	meadow = load("res://scenes/dream_meadow.tscn").instantiate()
	meadow.quality = level
	root.add_child(meadow)
	current_scene = meadow
	await process_frame
	player = meadow.player
	meadow.state = "walk"
	meadow.fade.color.a = 0.0
	look(eye(0, 90), Vector3(0, 6, 0))
	await measure("start")
	look(eye(1.5, 24), Vector3(0, 2.5, 0))
	await measure("approach")
	meadow.lit = true
	meadow.bright_from = meadow.clock - 30.0
	look(eye(5, 10), Vector3(-1, 3.5, -1))
	await measure("day-tree")
	look(eye(0, 4), Vector3(40, 6, 90))
	await measure("day-field")
	quit()
