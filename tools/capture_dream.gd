extends SceneTree
# Look check: godot --path . --script tools/capture_dream.gd --resolution 1600x900
# Plays the dream shore through its puzzles and saves docs/dream-<view>.png at each beat.
# DREAM_VIEW=<name> saves only that view (the beats before it still run).
var dream: Node3D
var player: CharacterBody3D
var only := ""

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

func look(from: Vector3, at: Vector3) -> void:
	player.set_physics_process(false)
	player.global_position = from - Vector3.UP * player.EYE
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	player.yaw = atan2(-flat.x, -flat.z)
	player.pitch = atan2(at.y - from.y, flat.length())
	player.rotation.y = player.yaw
	player.camera.rotation.x = player.pitch

func shot(title: String, frames := 30) -> void:
	for i in range(frames): await process_frame
	if only != "" and only != title:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/dream-%s.png" % title)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func snap() -> void:
	dream.camera.raised = true
	for i in range(4): await process_frame
	dream.camera.take()
	dream.camera.raised = false

func hold_level() -> void:
	dream.camera.holding = true
	player.pitch = dream.camera.photo.pitch
	player.camera.rotation.x = player.pitch

func run() -> void:
	only = OS.get_environment("DREAM_VIEW")
	dream = load("res://scenes/dream_shore.tscn").instantiate()
	root.add_child(dream)
	current_scene = dream
	await process_frame
	player = dream.player
	var cam: CanvasLayer = dream.camera
	dream.state = "walk"
	dream.fade.color.a = 0.0
	player.enabled = false
	player.eye = player.EYE
	look(Vector3(0, 1.6, 6), Vector3(0, 1.2, -40))
	await shot("wake")
	look(Vector3(-4.0, 1.6, 5.0), Vector3(2.0, 2.2, -6.0))
	await shot("props-near")
	# The floor goes.
	look(Vector3(1.0, 1.6, -18.0), Vector3(0, -2.0, -40))
	await wait(1.3)
	await shot("collapse", 1)
	await wait(5.0)
	look(Vector3(2.5, 2.2, -22.0), Vector3(0, -6.0, -80))
	await shot("rift")
	# 1. Bridge 1.
	look(Vector3(-2.0, 1.6, -27.0), Vector3(0, 0, -41))
	await shot("1-pieces-off")
	look(dream.EYE, Vector3(0, 0, -41))
	await shot("1-pieces-eye")
	await snap()
	await wait(2.5)
	look(Vector3(0, 1.6, -54.0), Vector3(-2, 0, -58))
	await shot("2-island-now")
	# 2. The board that only exists back then.
	cam.raised = true
	await shot("2-island-then")
	cam.raised = false
	look(Vector3(-2, 1.6, -52.5), Vector3(-2, 0, -57))
	await snap()
	look(Vector3(0, 1.6, -62.3), Vector3(0, 0, -66.8))
	hold_level()
	await shot("2-side-on-hold")
	cam.holding = false
	look(Vector3(-7.0, 1.6, -57), Vector3(-2, 0, -57))
	await snap()
	look(Vector3(0, 1.6, -62.4), Vector3(0, 0.03, -66.9))
	hold_level()
	await shot("2-end-on-hold")
	cam.place()
	await shot("2-placed")
	# 3. Leapfrog.
	look(Vector3(0, 1.6, -72), Vector3(0, 0, -80))
	await shot("3-island", 10)
	var b1: Node3D = dream.boards[1].node
	var b2: Node3D = dream.boards[2].node
	var from := -80.4
	for b in [b1, b2]:
		var dir: Vector3 = b.global_basis.z.normalized()
		look(b.global_position + dir * 5.0 + Vector3(0, 1.6, 0), b.global_position - dir * 0.5)
		await snap()
		look(Vector3(0, 1.64, from + 0.2), Vector3(0, 0, from - 4.4))
		hold_level()
		for i in range(3): await process_frame
		cam.place()
		from = minf((b.global_position - b.global_basis.z * 4.0).z, (b.global_position + b.global_basis.z * 4.0).z) + 0.8
	look(Vector3(0, 1.68, from), Vector3(0, 0, from - 12))
	await shot("3-two-down")
	look(Vector3(0, 1.68, -90.2), b1.global_position)
	await snap()
	look(Vector3(0, 1.68, from), Vector3(0, 0, from - 4.4))
	hold_level()
	await shot("3-third-hold")
	cam.place()
	# 4. The viewpoint over the void.
	look(Vector3(0, 1.6, -101), Vector3(4, 1.0, -112))
	await shot("4-island", 20)
	look(Vector3(5.0, 1.6, -102.0), Vector3(13.0, 0.6, -104.0))
	await shot("4-desk-in-air")
	look(Vector3(-4, 1.6, -100.0), Vector3(-4, 0, -104.9))
	await snap()
	look(Vector3(8.4, 1.6, -104.0), Vector3(12.9, 0, -104.0))
	hold_level()
	for i in range(3): await process_frame
	cam.place()
	await shot("4-pier")
	look(dream.EYE2 + Vector3(0, 0.04, 0), Vector3(0, 0, -120))
	await shot("4-pieces-eye")
	await snap()
	await wait(2.5)
	# 5. The gate.
	var gz: float = dream.GATE_AT.z
	look(Vector3(1.5, 1.6, gz + 20), Vector3(0, 2.0, gz))
	await shot("5-gate-now")
	cam.raised = true
	await shot("5-gate-then")
	cam.take()
	cam.raised = false
	cam.holding = true
	await shot("5-gate-hold")
	cam.place()
	await shot("5-gate-open")
	look(Vector3(6.0, 1.6, gz - 8.0), Vector3(0, 4.0, gz - 46))
	await shot("schoolyard")
	# 6. Lucid: the yard lets go.
	dream._begin_lucid()
	var sky: Node3D = dream.sky
	look(Vector3(2.0, 1.6, gz - 6.0), Vector3(0, 6.0, gz - 22))
	await wait(3.0)
	await shot("6-rise", 1)
	await wait(7.0)
	look(Vector3(-3.0, 1.6, gz - 6.0), Vector3(0, 11.0, gz - 22))
	await shot("6-spiral")
	var on3: Vector3 = sky.pieces[3].body.global_position + Vector3(0, 1.6, 0)
	var loose: Dictionary = sky.pieces[4]
	look(on3, loose.body.global_position)
	await shot("6-pull-aim")
	sky.set_pulling(true)
	look(on3, sky.to_global(sky.slot_at(4)))
	await wait(0.6)
	await shot("6-pull-coming", 1)
	await wait(3.0)
	sky.set_pulling(false)
	await shot("6-pull-placed")
	var on12: Vector3 = sky.pieces[12].body.global_position + Vector3(0, 1.6, 0)
	look(on12, sky.to_global(sky.slot_at(15)) + Vector3(0, 2.0, 0))
	await shot("6-high")
	look(on12, on12 + Vector3(4, -14, 3))
	await shot("6-down")
	var cloud: Node3D = sky.get_node("CloudIsland")
	var door: Node3D = sky.door
	look(cloud.global_position + Vector3(0, 2.1, 0) - sky.island_dir * 12.0, door.global_position + Vector3(0, 1.2, 0))
	await shot("6-cloud")
	look(door.global_position - door.global_basis.z * 2.5 + Vector3(0, 1.6, 0), door.global_position + Vector3(0, 1.3, 0))
	await shot("6-door")
	quit()
