extends SceneTree
# Look check: godot --path . --script tools/capture_meadow.gd --resolution 1600x900
# The meadow dream after Night 1, saved as docs/meadow-<view>.png: the dark field with the one
# bright place, walking up to it, the light turning the sky, the fish, and lying on the bed.
# MEADOW_VIEW=<name> saves only that view; MEADOW_QUALITY=0|1|2 picks the graphics setting.
var meadow: Node3D
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

func eye(x: float, z: float) -> Vector3:
	return meadow.on_ground(x, z) + Vector3(0, 1.6, 0)

func shot(title: String, frames := 40) -> void:
	for i in range(frames): await process_frame
	if only != "" and only != title:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/meadow-%s.png" % title)

func run() -> void:
	only = OS.get_environment("MEADOW_VIEW")
	meadow = load("res://scenes/dream_meadow.tscn").instantiate()
	if OS.has_environment("MEADOW_QUALITY"):
		meadow.quality = int(OS.get_environment("MEADOW_QUALITY"))
	root.add_child(meadow)
	current_scene = meadow
	await process_frame
	player = meadow.player
	meadow.state = "walk"
	meadow.fade.color.a = 0.0
	look(eye(0, 90), Vector3(0, 6, 0))
	await shot("start")
	look(eye(1.5, 24), Vector3(0, 2.5, 0))
	await shot("approach")
	look(eye(-4, 6), Vector3(2.4, 1.0, 1.2))
	await shot("light")
	meadow.lit = true
	meadow.bright_from = meadow.clock - 30.0
	look(eye(5, 10), Vector3(-1, 3.5, -1))
	await shot("day-tree", 60)
	look(eye(6, 6), Vector3(-2, 14, -4))
	await shot("day-up")
	look(eye(0, 4), Vector3(40, 6, 90))
	await shot("day-field")
	look(eye(-6, -12), Vector3(30, 18, 40))
	await shot("day-fish")
	look(eye(3.6, 3.4), Vector3(2.4, 0.6, 1.2))
	await shot("bed")
	player.global_position = meadow.bed.global_position + Vector3(1.2, 0, 1.2)
	meadow.lie_down()
	for i in range(220): await process_frame
	await shot("lie", 1)
	quit()
