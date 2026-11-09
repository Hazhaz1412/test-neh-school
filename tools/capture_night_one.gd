extends SceneTree
# Night 1 shots: a kiting loop, a tipped shelf, the guard at a window, being dragged off with the
# struggle bar, and locked in a room. godot --resolution 1280x720 --path . --script tools/capture_night_one.gd
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(3): await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func look(player: CharacterBody3D, from: Vector3, at: Vector3) -> void:
	player.global_position = from
	var flat := at - from
	player.rotation.y = atan2(-flat.x, -flat.z)
	player.camera.rotation = Vector3(atan2(at.y - from.y - 1.6, Vector2(flat.x, flat.z).length()), 0, 0)

func run() -> void:
	set_meta("night_one", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(300):
		await physics_frame
		if school.hunt.started: break
	var hunter: CharacterBody3D = school.hunt.hunter
	var player: CharacterBody3D = school.player
	var team: Node = school.team
	school.hunt.set_physics_process(false)
	hunter.set_physics_process(false)
	for entry in team.members.slice(1):
		entry.body.set_physics_process(false)
	player.set_physics_process(false)
	player.flashlight.show()
	var loop: Node3D = school.kiting.get_child(3)
	# The loop from its open end: crates in the middle, a window and a shelf in each wall.
	look(player, loop.to_global(Vector3(10.5, 0.05, 1.5)), loop.to_global(Vector3(0, 1.0, 0)))
	hunter.global_position = loop.to_global(Vector3(-3, 0.05, -2.0))
	for i in range(20): await process_frame
	await shot("docs/night1-loop.png")
	# A friend running the ring, the guard on the far side of the crates.
	var friend: CharacterBody3D = team.members[1].body
	friend.global_position = loop.to_global(Vector3(3.6, 0.05, 1.9))
	friend.rotation.y = loop.global_rotation.y + PI * 0.5
	friend._animate("sprint", 1.0)
	hunter.global_position = loop.to_global(Vector3(-3.5, 0.05, -1.9))
	hunter.look_at(loop.global_position, Vector3.UP)
	hunter.model.move("stalk", 5.5 / 1.5)
	look(player, loop.to_global(Vector3(7.5, 0.05, 2.0)), loop.to_global(Vector3(0, 1.0, 0)))
	for i in range(20): await process_frame
	await shot("docs/night1-loop-chase.png")
	# Right mouse held: halfway round, then looking straight back at him.
	# Running out of the loop's open end, the guard a few metres behind.
	player.set_process(false)
	look(player, loop.to_global(Vector3(-10.0, 0.05, 0.4)), loop.to_global(Vector3(-25.0, 1.6, 0.4)))
	hunter.global_position = loop.to_global(Vector3(-5.5, 0.05, 0.0))
	hunter.rotation.y = loop.global_rotation.y + PI * 0.5
	hunter.model.move("stalk", 5.5 / 1.5)
	player.look_back = 0.5
	player._pose_look_back()
	for i in range(10): await process_frame
	await shot("docs/night1-lookback-half.png")
	player.look_back = 1.0
	player._pose_look_back()
	for i in range(10): await process_frame
	await shot("docs/night1-lookback.png")
	player.look_back = 0.0
	player._pose_look_back()
	player.set_process(true)
	# A shelf tipped across its gap.
	var shelf: Node3D = null
	for pallet in loop.get_children():
		if pallet.is_in_group("kiting_pallet"):
			shelf = pallet
			break
	print("dropping ", shelf)
	shelf.drop(player)
	for i in range(40): await process_frame
	look(player, shelf.to_global(Vector3(2.4, 0.05, 3.2 * shelf.inward)), shelf.to_global(Vector3(0, 0.3, 0)))
	await shot("docs/night1-shelf.png")
	# A low gap: crawl or slide under, he has to go round.
	var low: Node3D = null
	for node in loop.get_children():
		if node.is_in_group("kiting_low"):
			low = node
	look(player, low.to_global(Vector3(0.4, 0.05, 3.0)), low.to_global(Vector3(0, 0.6, 0)))
	player.set_crouching(true, true)
	player.camera.position.y = player.CROUCH_EYE
	for i in range(10): await process_frame
	await shot("docs/night1-lowgap.png")
	school.kiting.board(low)
	for i in range(5): await process_frame
	await shot("docs/night1-boarded.png")
	player.set_crouching(false, true)
	player.camera.position.y = player.STAND_EYE
	# The guard halfway over a window.
	var window: Node3D = null
	for node in loop.get_children():
		if node.is_in_group("kiting_vault"):
			window = node
			break
	hunter.global_position = window.to_global(Vector3(0, 0.05, 0.9))
	hunter._climb(window)
	for i in range(int(hunter.VAULT_SECONDS * 0.45 * 60.0)):
		hunter._cross(1.0 / 60.0)
	look(player, window.to_global(Vector3(1.5, 0.05, -4.5)), window.to_global(Vector3(0, 1.2, 0)))
	for i in range(10): await process_frame
	await shot("docs/night1-guard-vault.png")
	# Dragged off: the struggle bar.
	hunter.cross_time = 0.0
	player.flashlight.hide()
	hunter.global_position = Vector3(-46, 0.05, 15)
	hunter.rotation.y = 0.0
	hunter.target = player
	hunter._seize()
	hunter.grab_clock = 1.0
	hunter._carry_pose()
	team.member(player).struggle = 0.42
	for i in range(20): await process_frame
	await shot("docs/night1-dragged.png")
	# Locked in a room, free to pace it.
	hunter.set_physics_process(true)
	school.hunt.set_physics_process(true)
	var waited := 0
	while team.member(player).status != team.Status.JAILED and waited < 2400:
		await physics_frame
		waited += 1
	print("jailed after ", waited, " frames: ", team.STATUS_TEXT[team.member(player).status])
	var room: Node3D = team.member(player).jail
	hunter.global_position = Vector3(-50, 0.05, 60)
	hunter.set_physics_process(false)
	await physics_frame
	room.snap(false)
	look(player, team.inside(room, 1), room.global_position + Vector3.UP * 1.2)
	player.flashlight.show()
	for i in range(20): await process_frame
	await shot("docs/night1-jailed.png")
	quit()
