extends SceneTree
# Look check: godot --path . --script tools/capture_coaster.gd --resolution 1600x900
# The roller coaster at the meadow's fair, saved as docs/coaster-<view>.png: the whole circuit from
# the plaza, the station, and the ride: the launch, the ring of light, and the dream flight
# (night sea, under the sea, sunset clouds, space) and home.
var meadow: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/coaster-%s.png" % title)

func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func stand(local: Vector3, look_at_local: Vector3) -> void:
	var coaster: Node3D = meadow.fold.coaster
	var frame: Basis = coaster.global_basis.orthonormalized()
	player.set_physics_process(false)
	player.frame = frame
	player.global_position = coaster.to_global(local)
	var to: Vector3 = frame.transposed() * (coaster.to_global(look_at_local) - coaster.to_global(local + Vector3(0, 1.6, 0)))
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())

func run() -> void:
	meadow = load("res://scenes/dream_meadow.tscn").instantiate()
	root.add_child(meadow)
	current_scene = meadow
	await process_frame
	player = meadow.player
	meadow.fade.color.a = 0.0
	meadow.make_night()
	meadow.state = "walk"
	player.enabled = true
	player.gravity_field = meadow.inside.up_at
	var coaster: Node3D = meadow.fold.coaster
	stand(Vector3(20, 0.05, -2), Vector3(170, 25, -10))
	await wait(1.5)
	await shot("overview")
	stand(Vector3(120, 0.05, 60), Vector3(200, 25, -10))
	await wait(1.0)
	await shot("side")
	var board: Vector3 = coaster.boarding()
	stand(board + Vector3(-8, 0.05, 6), board + Vector3(0, 1.0, 0))
	await wait(1.0)
	await shot("station")
	player.global_position = coaster.to_global(board + Vector3(0, 0.1, 0))
	player.set_physics_process(true)
	await wait(0.5)
	meadow.ride_coaster()
	await wait(0.2)
	await shot("ride-start")
	print("start cam near ", player.camera.near, " far ", player.camera.far, " fov ", player.camera.fov, " env ", player.camera.environment)
	var start := Time.get_ticks_msec()
	for at: float in [2.5, 6.0, 12.0, 20.0, 27.0, 34.0, 46.0, 54.0, 66.0, 76.0, 84.0]:
		while (Time.get_ticks_msec() - start) / 1000.0 < at:
			await process_frame
		await shot("ride-%04.1f" % at)
		var cam: Camera3D = player.camera
		print("shot ", at, " phase ", coaster.phase, " dream ", coaster.dream_d, " speed ", coaster.speed, " shards ", coaster.dream.taken)
	quit()
