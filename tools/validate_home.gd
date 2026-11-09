extends SceneTree
# Waking from the Night 0 dream, without the hub: nothing may be written outside the game, the
# phone holds no leftover chats or posts, and the front door leads out to the town.
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
	check(story.step == "go_out" and player.global_position.y > 2.4, "Peter wakes upstairs in his room")
	check(home.front_touch.label == "Ra khỏi nhà", "the front door leads out to the street")
	story._bed()
	check(story.step == "go_out", "he cannot fall back asleep")
	check(not story.installed_by_hub, "without consent nothing is sent to the hub")
	story.toggle_phone()
	check(home.phone.is_open() and not player.enabled, "Tab lifts the phone and frees the mouse")
	# The old story's chats and posts are gone; the apps are empty until the new story fills them.
	check(home.phone.threads.is_empty() and home.phone.fake.post_count == 0, "no old chats or posts are left")
	home.phone.open_app("fake")
	var feed := str(home.phone.fake.feed_list.find_children("*", "Label", true, false).map(func(l): return l.text))
	check("Chưa có bài viết nào" in feed, "Fake says there is nothing posted yet")
	story.on_hub_message({"type": "contact", "id": "bayro"})
	check(home.phone.threads.is_empty(), "a contact from the web no longer starts an old chat")
	story.toggle_phone()
	check(not home.phone.is_open() and player.enabled, "Tab again puts it away")
	print("failures ", failures)
	quit(failures)
