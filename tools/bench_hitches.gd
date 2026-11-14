extends SceneTree
# Hitch check: godot --path . --script tools/bench_hitches.gd --resolution 1600x900
# Walks the night box through the fair and rides the roller coaster with vsync off, and prints
# every frame slower than LIMIT ms with where it happened, plus the average FPS of each part.
const LIMIT := 12.0
var meadow: Node3D
var player: CharacterBody3D
var where := ""
var hitches := []
var frames := 0
var spent := 0.0

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("run")

func tick() -> void:
	var start := Time.get_ticks_usec()
	await process_frame
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	frames += 1
	spent += ms
	if ms > LIMIT:
		hitches.append("%6.1f ms  %s" % [ms, where])

func part(title: String) -> void:
	if frames > 0:
		print("%-28s %5.0f FPS avg (%d frames)" % [where, frames / (spent / 1000.0), frames])
	where = title
	frames = 0
	spent = 0.0

func run() -> void:
	meadow = load("res://scenes/dream_meadow.tscn").instantiate()
	root.add_child(meadow)
	current_scene = meadow
	for i in 10: await process_frame
	player = meadow.player
	meadow.fade.color.a = 0.0
	meadow.make_night()
	meadow.state = "walk"
	player.enabled = true
	player.gravity_field = meadow.inside.up_at
	var fold: Node3D = meadow.fold
	for i in 60: await process_frame
	# Walk round the plaza.
	part("fair walk")
	var frame: Basis = fold.fair.global_basis.orthonormalized()
	player.frame = frame
	player.global_position = fold.fair.to_global(Vector3(0, 0.3, 25))
	player.drive_run = true
	for i in range(900):
		var a := i / 900.0 * TAU
		var target: Vector3 = fold.fair.to_global(Vector3(sin(a) * 22.0, 0, cos(a) * 22.0))
		var to: Vector3 = player.frame.transposed() * (target - player.global_position)
		player.yaw = atan2(-to.x, -to.z)
		player.drive = Vector2(0, -1)
		await tick()
	player.drive = Vector2.ZERO
	# The coaster.
	part("coaster ride")
	var coaster: Node3D = fold.coaster
	player.frame = coaster.global_basis.orthonormalized()
	player.global_position = coaster.to_global(coaster.boarding() + Vector3(0, 0.2, 0))
	for i in 20: await process_frame
	meadow.ride_coaster()
	var last_phase := ""
	while meadow.state == "coaster":
		if coaster.phase != last_phase:
			last_phase = coaster.phase
			part("coaster " + last_phase)
		await tick()
	part("")
	print("frames over %.0f ms: %d" % [LIMIT, hitches.size()])
	for line in hitches.slice(0, 40):
		print(line)
	quit()
