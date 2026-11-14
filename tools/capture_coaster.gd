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
	stand(Vector3(60, 0.05, 0), Vector3(400, 6, -20))
	await wait(1.5)
	await shot("overview")
	stand(Vector3(300, 0.05, 0), Vector3(1200, 6, 0))
	await wait(1.0)
	await shot("endless")
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
	# Frame by frame across the two seams, by distance: into the cloud and the dream, and home.
	var gate: float = fposmod(coaster.gate_at - coaster.HOME, coaster.length)
	var home: float = fposmod(coaster.return_at - coaster.HOME, coaster.length)
	var marks := [["a-out-300", func() -> bool: return coaster.phase == "track" and coaster.travelled > gate - 300.0],
		["b-out-120", func() -> bool: return coaster.phase == "track" and coaster.travelled > gate - 120.0],
		["c-out-20", func() -> bool: return coaster.phase == "track" and coaster.travelled > gate - 20.0],
		["d-in-30", func() -> bool: return coaster.phase == "dream" and coaster.dream_d > 30.0],
		["e-in-160", func() -> bool: return coaster.phase == "dream" and coaster.dream_d > 160.0],
		["f-in-400", func() -> bool: return coaster.phase == "dream" and coaster.dream_d > 400.0],
		["g-end-300", func() -> bool: return coaster.phase == "dream" and coaster.dream_d > coaster.Dream.END - 300.0],
		["h-end-120", func() -> bool: return coaster.phase == "dream" and coaster.dream_d > coaster.Dream.END - 120.0],
		["i-end-65", func() -> bool: return coaster.phase == "dream" and coaster.dream_d > coaster.Dream.END - 65.0],
		["j-home-20", func() -> bool: return coaster.phase == "home" and coaster.travelled > home + 20.0],
		["k-home-160", func() -> bool: return coaster.phase == "home" and coaster.travelled > home + 160.0],
		["l-home-400", func() -> bool: return coaster.phase == "home" and coaster.travelled > home + 400.0]]
	for mark: Array in marks:
		var ready: Callable = mark[1]
		while not ready.call():
			await process_frame
		await shot("seam-" + mark[0])
		print("shot ", mark[0], " speed ", coaster.speed, " cloud ", coaster.cloud)
	quit()
