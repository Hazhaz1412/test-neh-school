extends SceneTree
# Look check for the shop panel, its door and the grab: godot --path . --script tools/capture_gear.gd --resolution 1600x900
func shot(title: String) -> void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/gear-%s.png" % title)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var town: Node3D = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await create_timer(3.4).timeout
	var door: Dictionary = town.plan.place_lot("curio")
	var player: CharacterBody3D = town.player
	var along := Vector2(-door.normal.y, door.normal.x)
	var stand: Vector2 = door.front - door.normal * 0.9 - along * 3.0
	player.global_position = Vector3(stand.x, 0, stand.y)
	var view: Vector2 = door.front + door.normal * 2.0 - stand
	player.look_yaw = atan2(-view.x, -view.y)
	await shot("door")
	town.story.gear.pawned = ["camera"]
	town.story.open_shop()
	await shot("shop")
	town.queue_free()
	await process_frame
	set_meta("night_one", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	while school.hunt.hunter == null:
		await physics_frame
	await create_timer(1.5).timeout
	school.hunt.set_physics_process(false)
	school.player.inventory[2] = "medicine"
	var hunter: Node = school.hunt.hunter
	hunter.global_position = school.player.global_position + Vector3(0, 0, -1.4)
	hunter.rotation.y = PI
	hunter._seize()
	hunter.wait = 60.0
	await create_timer(1.0).timeout
	await shot("grab")
	quit()
