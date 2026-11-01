extends SceneTree
# The first morning at home, without the hub: nothing may be written outside the game.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func until(test: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / 60.0
		if test.call():
			return true
	return false

func run() -> void:
	var home: Node3D = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	var story: Node = home.story
	var player: CharacterBody3D = home.player
	await physics_frame
	await physics_frame
	story.consent = false
	story.step = "upstairs"
	player.enabled = true
	# Up the real stairs with real physics.
	player.global_position = Vector3(5.8, 0.05, 12.0)
	player.yaw = 0.0
	player.scripted_move = Vector2(0, -1)
	var climbed := await until(func(): return player.global_position.y > 2.4, 8.0)
	check(climbed, "the stairs reach the bedroom: y %.2f" % player.global_position.y)
	var walk := func(move: Vector2, test: Callable) -> bool:
		player.scripted_move = move
		return await until(test, 8.0)
	check(await walk.call(Vector2(0, -1), func(): return player.global_position.z < 7.45), "the stairs end on a landing")
	check(await walk.call(Vector2(-1, 0), func(): return player.global_position.x < 4.05), "the landing leads to the bedroom door")
	check(await walk.call(Vector2(0, -1), func(): return player.global_position.z < 6.0), "the door opens into the bedroom")
	player.scripted_move = Vector2.ZERO
	check(story.step == "waiting", "reaching the bedroom starts the morning")
	var arrived := await until(func(): return story.step == "lan", 8.0)
	check(arrived and home.phone.threads.has("lan"), "Lan writes first")
	check(home.phone.threads["lan"].unread == 1, "the message waits unread")
	story.toggle_phone()
	check(home.phone.is_open() and not player.enabled, "Tab opens the phone and frees the mouse")
	var count: int = story.LAN_TALK.size()
	for beat in range(count - 1):
		var offered := await until(func(): return home.phone.replies.get_child_count() > 0 and story.lan_beat == beat, 25.0)
		check(offered, "Lan asks for a reply, step %d" % beat)
		home.phone.reply_chosen.emit(0)
		await process_frame
	var text := str(home.phone.threads["lan"].log.map(func(e): return e.text))
	for word in ["Ghen Tị", "Kiêu Ngạo", "Nguyễn Bình An", "bảy linh hồn"]:
		check(word in text, "Lan explains: " + word)
	var stranger := await until(func(): return story.step == "gaaglu", 30.0)
	check(stranger, "the stranger writes, then Gaaglu arrives")
	var ghost: Dictionary = home.phone.threads["unknown"]
	check(ghost.title.strip_edges().is_empty() and ghost.initial.is_empty(), "the stranger has no name and no picture")
	check(ghost.log.size() == 3 and ghost.log.all(func(e): return e.garbled), "all three messages are unreadable")
	check(not story.installed_by_hub, "without consent nothing is sent to the hub")
	home.phone.open_thread("unknown")
	await create_timer(0.3).timeout
	var label: Label = story.world.phone.scrambled[0].label
	var first: String = label.text
	await create_timer(0.3).timeout
	check(label.text != first, "the unreadable text keeps shifting")
	story.toggle_phone()
	story._desk()
	check(story.fallback_note != null, "the note appears on Peter's computer instead")
	check("thế giới bên kia" in str(story.fallback_note.find_children("*", "Label", true, false).map(func(l): return l.text)), "the note carries the line")
	story._close_note()
	check(story.opened_gaaglu, "reading it lets the morning move on")
	print("failures ", failures)
	quit(failures)
