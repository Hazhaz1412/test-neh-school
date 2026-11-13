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
	check(story.step == "hungry" and player.global_position.y > 2.4, "Peter wakes upstairs in his room")
	check(home.goal.text == "Xuống bếp kiếm gì ăn", "waking, the goal is breakfast")
	check(not home.exit_action.is_valid(), "the front door stays shut until he has eaten")
	story._bed()
	check(story.step == "hungry", "he cannot fall back asleep")
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
	await cook(home)
	print("failures ", failures)
	quit(failures)

# --- Breakfast: the mì net minigame, played through with good timing --------------------------

func step_shown(kitchen: Node3D, title: String) -> bool:
	return await until(func(): return kitchen.step_title.text == title and kitchen.panel.visible, 15.0)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func cook(home: Node3D) -> void:
	var story: Node = home.story
	var kitchen: Node3D = home.kitchen
	var player: CharacterBody3D = home.player
	home._open_fridge()
	check(story.step == "cooking" and kitchen.busy and not player.enabled, "the fridge starts the cooking")
	story.toggle_phone()
	check(not home.phone.is_open(), "the phone stays away while cooking")
	check(await step_shown(kitchen, "Bắc nồi nước"), "first the water goes on")
	kitchen.acted.emit()
	check(await step_shown(kitchen, "Xé gói mì"), "then the pack is torn open")
	kitchen.tear = 1.0
	check(await step_shown(kitchen, "Nấu mì"), "the noodles cook")
	await wait(3.0)
	kitchen.acted.emit()
	await wait(0.1)
	check(kitchen.noodle_result == "good", "taken out in the green zone they are just right: " + kitchen.noodle_result)
	check(await step_shown(kitchen, "Chắt nước"), "mì khô: the water is poured off")
	kitchen.holding = true
	check(await until(func(): return kitchen.water_left <= 0.0, 8.0), "holding tips the pot until it is empty")
	kitchen.holding = false
	check(await step_shown(kitchen, "Trộn gia vị"), "then the seasoning is stirred in")
	check(not kitchen.spilled and kitchen.pot.position.is_equal_approx(kitchen.pot_home), "nothing spilled, the pot is back on the stove")
	for i in range(kitchen.STIRS):
		await wait(0.35)
		kitchen.acted.emit()
	check(await step_shown(kitchen, "Đập trứng"), "the egg is cracked")
	await wait(0.5)
	kitchen.acted.emit()
	check(await step_shown(kitchen, "Chiên"), "egg and sausage fry")
	check(kitchen.toppings.size() == 2 and not kitchen.shell, "a clean crack: egg and sausage in the pan, no shell")
	await wait(0.5)
	for food: Node3D in kitchen.toppings:
		var off := Vector2(food.global_position.x - kitchen.pan_centre.x, food.global_position.z - kitchen.pan_centre.z).length()
		check(off < 0.07, "%s lies in the pan, %.3f m from its middle" % [food.name, off])
	await wait(3.6)
	kitchen.acted.emit()
	await wait(0.1)
	check(kitchen.egg_result == "good", "the egg comes out golden: " + kitchen.egg_result)
	check(await step_shown(kitchen, "Thái hành"), "spring onion is chopped")
	for i in range(kitchen.CHOPS):
		await wait(0.12)
		kitchen.acted.emit()
	check(await step_shown(kitchen, "Xịt tương ớt"), "chilli sauce goes on")
	check(kitchen.toppings.size() == 2 + kitchen.CHOPS, "every chopped piece lands in the bowl")
	for i in range(30):
		kitchen.squirt(kitchen.bowl.position + Vector3(0.002 * i - 0.03, 0.088, 0))
	kitchen.acted.emit()
	check(await step_shown(kitchen, "Khui lon Xiteen"), "the Xiteen is opened")
	kitchen.acted.emit()
	check(await until(func(): return story.step == "carry", 10.0), "cooked, he carries it to the table")
	check(player.enabled and not kitchen.busy and kitchen.can.get_parent().get_parent() == player.camera, "bowl and can are in his hands")
	check(home.goal.text == "Bưng tô mì ra bàn ăn", "the goal points at the table")
	check(home.interactions.has(kitchen.table_touch), "the table offers a seat")
	kitchen.table_touch.action.call()
	check(await step_shown(kitchen, "Ăn mì"), "he sits and eats")
	check(story.step == "eating" and not home.interactions.has(kitchen.table_touch), "seated at the table")
	var space := home.get_world_3d().direct_space_state
	for thing: Node3D in [kitchen.bowl, kitchen.can]:
		var spot: Vector3 = thing.global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.5, spot + Vector3.DOWN * 0.5))
		check(not hit.is_empty() and absf(hit.position.y - spot.y) < 0.02, "%s stands on the tabletop (%.2f)" % [thing.name, spot.y])
	var chair_box := Vector2(home.seat_chair.global_position.x, home.seat_chair.global_position.z)
	check(chair_box.x > 3.2 and absf(chair_box.y - 4.6) < 0.01, "his chair is beside the table, not inside it")
	var lines: Array = kitchen._verdicts()
	check("Ngon hơn" in lines[-1], "a perfect bowl gets the best verdict")
	var mouth_seen := false
	for i in range(lines.size()):
		await wait(0.3)
		kitchen.acted.emit()
		var reached := await until(func(): return kitchen.chopsticks.global_position.distance_to(kitchen._mouth()) < 0.01, 3.0)
		mouth_seen = reached if i == 0 else (mouth_seen and reached)
		await until(func(): return kitchen.chopsticks.global_position.distance_to(kitchen._mouth()) > 0.05, 3.0)
	check(mouth_seen, "every bite is lifted to his mouth")
	check(await step_shown(kitchen, "Uống Xiteen"), "then a sip of Xiteen")
	kitchen.acted.emit()
	check(await until(func(): return story.step == "go_out", 10.0), "breakfast done")
	check(player.enabled and home.front_touch.label == "Ra khỏi nhà" and home.exit_action.is_valid(), "now the front door leads out to the street")
	check(home.goal.text == "Ra khỏi nhà · Tới khu phố", "and the goal says so")
