extends SceneTree
# Lines the night cast up in the light: godot --path . --script tools/capture_cast.gd -- out.png
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.3, 0.32, 0.35)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	stage.add_child(sun)
	var models := []
	var looks := ["Female_Adult_11", "An_Student", "Male_Adult_02", "Male_Adult_08", "Male_Adult_06"]
	var clips := ["sprint", "idle", "walk", "sprint", "crouch"]
	for i in range(looks.size()):
		var person: Node3D = preload("res://scripts/humanoid_model.gd").new()
		person.look = looks[i]
		person.target_height = 1.68 if i == 0 else (1.48 if i == 1 else 1.78)
		stage.add_child(person)
		person.position = Vector3(i * 1.1 - 2.2, 0, 0)
		person.rotation.y = 0.5
		person.animation.play(clips[i])
		person.animation.advance(0.3)
		models.append(person)
	var floor_plate := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_plate.mesh = plane
	stage.add_child(floor_plate)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 1.1, 5.2)
	camera.look_at(Vector3(0, 0.85, 0))
	camera.current = true
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
