extends SceneTree
# Look check: godot --path . --script tools/capture_house.gd --resolution 1600x900
# The inside of the meadow's little house, saved as docs/house-<view>.png: the doorway from the
# path, the giant room, the book stairs and the table, the fall into the glass ball frame by
# frame, the planet, and the planet house's doorway back out. HOUSE_VIEW=<name> saves only that.
var meadow: Node3D
var player: CharacterBody3D
var inside: Node3D
var fold: Node3D
var only := ""

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

# Stand the eye at `from` in the frame `frame` (its y is up there), looking at `at`.
func look(from: Vector3, at: Vector3, frame: Basis) -> void:
	player.set_physics_process(false)
	player.frame = frame
	player.global_position = from - frame.y * player.EYE
	var to := frame.transposed() * (at - from)
	var flat := Vector3(to.x, 0, to.z)
	player.yaw = atan2(-flat.x, -flat.z)
	player.pitch = atan2(to.y, flat.length())
	player.camera.position = Vector3(0, player.EYE, 0)
	player.camera.rotation = Vector3(player.pitch, 0, 0)

func shot(title: String, frames := 30) -> void:
	for i in range(frames): await process_frame
	if only != "" and only != title:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/house-%s.png" % title)

func run() -> void:
	only = OS.get_environment("HOUSE_VIEW")
	meadow = load("res://scenes/dream_meadow.tscn").instantiate()
	root.add_child(meadow)
	current_scene = meadow
	await process_frame
	player = meadow.player
	inside = meadow.inside
	fold = meadow.fold
	meadow.fade.color.a = 0.0
	meadow.make_night()
	meadow.state = "walk"
	player.gravity_field = inside.up_at
	player.enabled = true
	fold.open_door()
	fold.door_open = 1.0
	await process_frame
	var door: Node3D = fold.door_frame
	var house_frame := Basis(door.global_basis.x, door.global_basis.y, door.global_basis.z)
	look(door.to_global(Vector3(0.6, 1.6, 4.5)), door.to_global(Vector3(0, 1.1, 0)), house_frame)
	await shot("door", 60)
	look(door.to_global(Vector3(0.1, 1.6, 1.3)), door.to_global(Vector3(0, 1.4, -2)), house_frame)
	await shot("door-close")
	var room_at: Vector3 = inside.ROOM_AT
	var up := Basis.IDENTITY
	look(room_at + Vector3(-29, 1.6, 57), room_at + Vector3(0, 8, -10), up)
	await shot("room-door", 60)
	look(room_at + Vector3(-28, 1.6, 50), room_at + Vector3(-30, 6, 60), up)
	await shot("room-back")
	look(room_at + Vector3(20, 1.6, 30), room_at + Vector3(0, 9, -6), up)
	await shot("room-stairs")
	var top: Vector3 = room_at + inside.stair_top()
	look(top + Vector3(0, 1.6, 0), inside.globe_centre(), up)
	await shot("room-table")
	var globe: Vector3 = inside.globe_centre()
	var stand := globe + Vector3(0, 0, 3.6)
	stand.y = inside.table_top()
	player.global_position = stand
	look(stand + Vector3(0, 1.6, 0), globe, up)
	await shot("globe")
	meadow.touch_globe()
	var start := Time.get_ticks_msec()
	for at: float in [1.2, 2.4, 3.6, 4.6, 5.4, 6.2, 6.8, 7.4]:
		while (Time.get_ticks_msec() - start) / 1000.0 < at:
			await process_frame
		if only == "" or only.begins_with("zoom"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/house-zoom-%.1f.png" % at)
	while meadow.state != "walk":
		await process_frame
	await shot("planet-land", 30)
	var centre: Vector3 = inside.PLANET_AT
	var ground: Vector3 = centre + Vector3.UP * inside.PLANET_R
	look(ground + Vector3(0, 1.6, 0), ground + Vector3(0, 60, -40), up)
	await shot("planet-up")
	look(ground + Vector3(3, 1.6, 4), inside.planet_house.global_position + Vector3(0, 2, 0), up)
	await shot("planet-house")
	inside.open_planet_door()
	inside.planet_door = 1.0
	var planet_door: Node3D = inside.portal_planet
	var pf := Basis(Quaternion(Vector3.UP, (planet_door.global_position - centre).normalized()))
	look(planet_door.to_global(Vector3(0.3, 1.6, 3.0)), planet_door.to_global(Vector3(0, 1.1, 0)), pf)
	await shot("planet-door", 60)
	quit()
