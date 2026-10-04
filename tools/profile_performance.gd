extends SceneTree

func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var started := Time.get_ticks_msec()
	var scene: Node3D = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	current_scene = scene
	var load_ms := Time.get_ticks_msec() - started
	var args := OS.get_cmdline_user_args()
	var quality := int(args[1]) if args.size() > 1 else 1
	scene.set_quality(quality, false)
	scene.player.set_physics_process(false)
	scene.player.set_process_unhandled_input(false)
	scene.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var results := {"adapter": RenderingServer.get_video_adapter_name(), "viewport": root.size, "quality": scene.quality_level, "load_ms": load_ms, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "samples": []}
	var views := [
		["campus", Vector3(0, 0.05, 64), Vector3(0, 5, 10)],
		["hallway", Vector3(-23.5, 0.05, 52), Vector3(-23.5, 1.6, 12)],
		["library", Vector3(-21, 0.05, -44.5), Vector3(-21, 1.6, -59)]]
	for spirit in [false, true]:
		scene.set_spirit_world(spirit)
		scene.player.enabled = true
		for ghost in scene.enemies:
			ghost.set_physics_process(false)
		for view in views:
			scene.player.position = view[1]
			scene.player.camera.look_at(view[2])
			scene.player.recover()
			var warm_until := Time.get_ticks_msec() + 1200
			while Time.get_ticks_msec() < warm_until:
				await process_frame
			var frame_times: Array[float] = []
			var cpu := 0.0
			var physics := 0.0
			var draws := 0.0
			var primitives := 0.0
			var until := Time.get_ticks_msec() + 1800
			var count := 0
			while Time.get_ticks_msec() < until:
				var before := Time.get_ticks_usec()
				await process_frame
				frame_times.append((Time.get_ticks_usec() - before) / 1000.0)
				cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000
				physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
				draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
				count += 1
			frame_times.sort()
			var sample := {"view": view[0], "spirit": spirit, "median_frame_ms": snappedf(frame_times[int(count * 0.5)], 0.01), "p95_frame_ms": snappedf(frame_times[int(count * 0.95)], 0.01), "cpu_ms": snappedf(cpu / count, 0.01), "physics_ms": snappedf(physics / count, 0.01), "draw_calls": int(draws / count), "primitives": int(primitives / count)}
			results.samples.append(sample)
			print(JSON.stringify(sample))
	var output: String = args[0] if not args.is_empty() else "/tmp/neh-performance.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("PROFILE ", output, " / ", results.adapter, " / ", results.nodes, " nodes")
	quit()
