extends SceneTree
# Look check: godot --path . --script tools/capture_wheel.gd --resolution 1600x900
# The Ferris wheel at the meadow's fair, saved as docs/wheel-<view>.png: from the plaza, getting
# in, halfway up, the starry sky at the top (up, out and down at the fair), and the striker.
var meadow: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/wheel-%s.png" % title)

func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

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
	var wheel: Node3D = meadow.fold.wheel
	var frame: Basis = wheel.global_basis.orthonormalized()
	# From the plaza, looking at the wheel and the striker beside it.
	player.set_physics_process(false)
	player.frame = frame
	player.global_position = wheel.to_global(Vector3(-6, 0.05, 26))
	var to := frame.transposed() * (wheel.to_global(Vector3(0, 16, 0)) - player.global_position)
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = 0.35
	await wait(1.5)
	await shot("plaza")
	player.global_position = wheel.to_global(wheel.PLATFORM + Vector3(0, 0.45, 0.6))
	player.yaw = 0.0
	player.pitch = 0.0
	player.set_physics_process(true)
	await wait(1.0)
	await shot("board")
	meadow.ride_wheel()
	await wait(wheel.BOARD + wheel.UP * 0.5)
	player.yaw = PI * 0.5
	player.pitch = 0.1
	await shot("halfway")
	await wait(wheel.UP * 0.5 + 3.0)
	player.yaw = -PI / 2
	player.pitch = 0.7
	await wait(0.8)
	await shot("top-sky")
	player.yaw = 0.3
	player.pitch = 0.45
	await wait(2.5)
	await shot("top-moon")
	player.yaw = -PI / 2
	player.pitch = -0.6
	await wait(1.0)
	await shot("top-down")
	quit()
