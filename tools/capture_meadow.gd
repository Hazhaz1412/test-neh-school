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
	look(eye(0, 46), Vector3(0, 6, 0))
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
	# The blink, night, getting up.
	while meadow.state == "lie": await process_frame
	await create_timer(1.0).timeout
	await shot("blink-shut", 1)
	await create_timer(3.2).timeout
	await shot("blink-open", 1)
	while meadow.state != "walk": await process_frame
	await shot("night-wake")
	var fold: Node3D = meadow.fold
	var wall_from: float = fold.arc
	var ceiling_from: float = fold.arc * 2.0 + fold.wall
	# Down the box along x, to the horizon.
	look_on(meadow.on_ground(0, 20), Vector3.UP, -PI / 2, 0.15)
	await shot("night-box-along")
	# Straight up from beside the bed: the ceiling's meadow and the house hanging from it.
	look_on(meadow.on_ground(3, 3), Vector3.UP, 0.0, 1.3)
	await shot("night-look-up")
	# On the wall, just past the corner: the fair ahead.
	on_box(fold, 3.6, wall_from + 2.0, 0.0, 0.1)
	await shot("night-fair-ahead")
	var at_fair: float = fold.fair_s + 8.0
	on_box(fold, -2.0, at_fair, 0.5, 0.1)
	await shot("night-fair")
	on_box(fold, -2.0, at_fair, -0.7, 0.05)
	await shot("night-carousel")
	# Among the shadows at the fair, while they talk.
	await create_timer(5.0).timeout
	on_box(fold, 2.0, fold.fair_s + 6.0, PI + 0.5, 0.08)
	await shot("night-crowd-a", 60)
	on_box(fold, 2.0, fold.fair_s + 6.0, PI - 0.5, 0.08)
	await shot("night-crowd-b", 60)
	on_box(fold, 0.0, fold.fair_s - 30.0, 0.0, 0.18)
	await shot("night-fair-wide", 60)
	# Above the fair, looking back down at the meadow and the bed, standing like a wall.
	var above: float = fold.fair_s + 26.0
	on_box(fold, 1.0, above, PI, -0.2)
	await shot("night-look-back")
	# On the ceiling: the path to the house, then the sky overhead is the meadow.
	var on_top: float = ceiling_from + 4.0
	on_box(fold, 0.0, on_top, 0.0, 0.05)
	await shot("night-house-path")
	on_box(fold, 0.0, on_top, 0.0, 1.35)
	await shot("night-ceiling-up")
	var close: float = fold.house_s - 9.0
	on_box(fold, -0.9, close, 0.0, 0.12)
	await shot("night-house")
	meadow.open_house()
	await create_timer(2.0).timeout
	await shot("night-door", 1)
	quit()

# Stand on the box at (u, s), yaw 0 facing on round it (the way a walker coming from the bed faces).
func on_box(fold: Node3D, u: float, s: float, yaw: float, pitch: float) -> void:
	player.set_physics_process(false)
	var up: Vector3 = fold.up_of(s)
	var back: Vector3 = -fold.along_of(s)
	player.frame = Basis(up.cross(back), up, back)
	player.global_position = fold.point(u, s) + up * 0.02
	player.yaw = yaw
	player.pitch = pitch

# Stand with feet at `feet` in a turned gravity frame (`up`), facing `yaw` within it.
func look_on(feet: Vector3, up: Vector3, yaw: float, pitch: float) -> void:
	player.set_physics_process(false)
	player.frame = Basis(Quaternion(Vector3.UP, up)) if up != Vector3.UP else Basis.IDENTITY
	player.global_position = feet + up * 0.02
	player.yaw = yaw
	player.pitch = pitch
