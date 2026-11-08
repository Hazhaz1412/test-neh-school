extends SceneTree
# Night 1 in the ordinary school: the guard as the hunter, seen down a corridor and up close.
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func run() -> void:
	set_meta("night_one", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	var director: Node = school.envy
	for i in range(240):
		await physics_frame
		if director.started: break
	var demon: CharacterBody3D = director.demon
	var player: CharacterBody3D = school.player
	demon.set_physics_process(false)
	player.set_physics_process(false)
	player.flashlight.hide()
	# Corridor of block A, ground floor, looking down the hall at him.
	player.global_position = Vector3(-2, 0.05, 7.5)
	player.rotation.y = PI * 0.5
	player.camera.rotation = Vector3.ZERO
	demon.global_position = Vector3(-14, 0.05, 7.5)
	demon.rotation.y = -PI * 0.5
	demon.model.move("stalk", 3.6 / 1.5)
	for i in range(30): await process_frame
	await shot("docs/night1-hall.png")
	demon.global_position = Vector3(-5.2, 0.05, 7.5)
	demon.model.move("stalk", 5.5 / 1.5)
	for i in range(20): await process_frame
	await shot("docs/night1-close.png")
	print("spirit ", school.spirit_enabled, " guard_night ", school.guard_night)
	quit()
