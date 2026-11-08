extends SceneTree
# Waking from the Night 0 dream, without the hub: nothing may be written outside the game,
# and Bảy Rô still writes. A second pass covers the Sợi Chỉ contact sent by the hub.
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

func open_home() -> Node3D:
	var home: Node3D = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	await physics_frame
	await physics_frame
	return home

func run() -> void:
	var home: Node3D = await open_home()
	var story: Node = home.story
	var player: CharacterBody3D = home.player
	story.consent = false
	# Up the real stairs and through the bedroom door with real physics.
	player.enabled = true
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

	story.wake()
	check(story.step == "wake" and player.global_position.y > 2.4, "Peter wakes upstairs in his room")
	check(home.phone.fake_new == home.phone.fake.post_count, "the morning starts with new posts on Fake")
	story._bed()
	check(story.step == "wake", "he cannot fall back asleep")
	story.toggle_phone()
	check(home.phone.is_open() and not player.enabled, "Tab opens the phone and frees the mouse")
	home.phone.open_app("fake")
	var feed := str(home.phone.fake.feed_list.find_children("*", "Label", true, false).map(func(l): return l.text))
	check("gấu bông" in feed and "con mắt đang khóc" in feed, "the feed holds pieces of the dream")
	home.phone.finish_feed()
	check(story.step == "ask", "reading it all makes him want to ask the group")
	home.phone.open_thread("team")
	check(home.phone.replies.get_child_count() == story.WAKE_ASK.size(), "Peter chooses what to ask")
	home.phone.reply_chosen.emit(0)
	check(await until(func(): return story.step == "gaaglu", 20.0), "the group answers")
	var team := str(home.phone.threads["team"].log.map(func(e): return e.text))
	check("Gaaglu" in team and "Sợi Chỉ" in team, "a friend points him to Gaaglu and Sợi Chỉ")
	check(not story.installed_by_hub, "without consent nothing is sent to the hub")
	check(await until(func(): return story.step == "bayro", story.BAYRO_SELF_WAIT + 3.0), "without the hub, Bảy Rô writes on his own")
	check(home.phone.threads["bayro"].log[0].text == story.BAYRO_FIRST[false], "he heard Peter was asking around")
	home.phone.go_home()
	home.phone.open_thread("bayro")
	check(await until(func(): return home.phone.replies.get_child_count() > 0, 20.0), "he sets the terms and waits for an answer")
	var talk := str(home.phone.threads["bayro"].log.map(func(e): return e.text))
	check("Góc Cờ" in talk and "caro" in talk, "he names Góc Cờ and a game of caro")
	home.phone.reply_chosen.emit(0)
	check(await until(func(): return story.step == "go_out", 8.0), "the meeting is set")
	check(home.front_touch.label == "Ra khỏi nhà", "the front door now leads out to the street")
	story.toggle_phone()
	home.queue_free()
	await process_frame

	# With the hub: pressing "Nhắn tin" on Sợi Chỉ reaches the game as a contact message.
	home = await open_home()
	story = home.story
	story.step = "gaaglu"
	story.on_hub_message({"type": "contact", "id": "someone-else"})
	check(story.step == "gaaglu", "only Bảy Rô's contact is accepted")
	story.on_hub_message({"type": "contact", "id": "bayro"})
	check(story.step == "bayro" and home.phone.threads["bayro"].log[0].text == story.BAYRO_FIRST[true], "the contact from Sợi Chỉ brings Bảy Rô into Tili")
	story.on_hub_message({"type": "contact", "id": "bayro"})
	check(home.phone.threads["bayro"].log.size() == 1, "a second press does not repeat him")
	# Mười Gió from Sợi Chỉ: his chat gives the place, and the save remembers him for the town.
	var Gear := preload("res://scripts/night_gear.gd")
	var backup := FileAccess.get_file_as_bytes(Gear.PATH)
	story.on_hub_message({"type": "contact", "id": "muoigio"})
	var deal := str(home.phone.threads["muoigio"].log.map(func(e): return e.text))
	check("Hẻm 8" in deal and "90" in deal and "60" in deal, "Mười Gió writes where and for how much")
	check(Gear.read().muoi_gio_known, "the town will know him")
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	else:
		FileAccess.open(Gear.PATH, FileAccess.WRITE).store_buffer(backup)
	print("failures ", failures)
	quit(failures)
