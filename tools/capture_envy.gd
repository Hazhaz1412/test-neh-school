extends SceneTree
# Look check: godot --path . --script tools/capture_envy.gd --resolution 1280x720
var school: Node3D

func _initialize() -> void:
	call_deferred("run")

func shot(title: String) -> void:
	for i in range(24): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/envy-%s.png" % title)

func run() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.survival.set_physics_process(false)
	school.player.set_physics_process(false)
	school.progression.set_physics_process(false)
	for i in range(5): await physics_frame
	school.player.flashlight.show()
	var demon: Node3D = load("res://scripts/envy_demon_model.gd").new()
	school.add_child(demon)
	var spot := Vector3(-20, 7.85, 6.3)
	demon.global_position = spot + Vector3(-6, 0, 0)
	await process_frame
	demon.look_at(spot, Vector3.UP, true)
	demon.move("stalk", 0.7)
	school.player.position = spot
	school.player.camera.look_at_from_position(spot + Vector3.UP * 1.6, demon.global_position + Vector3.UP * 1.3)
	await shot("far")
	demon.global_position = spot + Vector3(-2.3, 0, 0)
	school.player.camera.look_at_from_position(spot + Vector3.UP * 1.6, demon.global_position + Vector3.UP * 1.6)
	await shot("near")
	quit()
