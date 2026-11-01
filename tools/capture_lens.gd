extends SceneTree
# Runs the game against a live hub and reports what the phone lens costs.
# Start the hub first, then: godot --path . --script tools/capture_lens.gd --resolution 1280x720
var school: Node3D
func _initialize() -> void:
	call_deferred("run")

func frame_time(count: int) -> float:
	var started := Time.get_ticks_usec()
	for i in range(count): await process_frame
	return (Time.get_ticks_usec() - started) / (count * 1000.0)

func run() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.survival.set_physics_process(false)
	school.player.set_physics_process(false)
	school.progression.set_physics_process(false)
	school.player.flashlight.show()
	var spot := Vector3(-20, 7.85, 6.3)
	school.player.position = spot
	school.player.camera.look_at_from_position(spot + Vector3.UP * 1.6, spot + Vector3(-5, 1.5, 0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var bridge: Node = school.get_node("ArgBridge")
	bridge.set_process(true)
	for i in range(600):
		if bridge.linked: break
		await process_frame
	print("linked=", bridge.linked)
	for i in range(60): await process_frame
	print("lens off frame_ms=", snappedf(await frame_time(120), 0.01))
	for i in range(1200):
		if bridge.lens.active: break
		await process_frame
	print("lens active=", bridge.lens.active, " clones=", bridge.lens.originals.size())
	bridge.lens.set_aiming(true)
	for i in range(90): await process_frame
	print("lens on frame_ms=", snappedf(await frame_time(240), 0.01))
	var back: Vector3 = school.player.camera.global_basis.z
	bridge.lens.stalker.get_parent().global_position = school.player.global_position - back * 3.0
	bridge.lens.phone_update({"calibrating": true, "progress": 0.0})
	bridge.lens.phone_update({"progress": 0.42})
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/lens-gate.png")
	bridge.lens.phone_update({"progress": 0.9})
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/lens-gate-charged.png")
	bridge.lens.phone_update({"calibrating": false, "aim": true, "anchored": true})
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/lens-gate-open.png")
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/lens-gate-after.png")
	print("gate closed visible=", bridge.lens.marker_layer.visible)
	bridge.lens.marker_free = false
	bridge.lens.set_aiming(true)
	bridge.lens.marker_layer.visible = true
	var holder: Node3D = bridge.lens.stalker.get_parent()
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/lens-desktop.png")
	# Hold the stalker in view while a viewer collects frames.
	var until := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < until:
		holder.global_position = school.player.global_position - back * 2.6
		await process_frame
	print("lens done")
	quit()
