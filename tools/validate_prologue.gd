extends SceneTree
# The evening before Night 0: Peter's rented room, the feed, the group chat, the walk to the door.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("prologue", true)
	var home: Node3D = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	var story: Node = home.story
	story.begin_prologue()
	check(not has_meta("prologue"), "the flag is spent")
	check(story.step == "feed" and home.phone.threads.has("langta"), "the evening starts with the feed")
	check(home.phone.threads.has("sau") and home.phone.threads["sau"].log[0].text.contains("Số 14"), "the landlady gives the address")
	story.toggle_phone()
	home.phone.open_thread("langta")
	await process_frame
	check(home.phone.feed_list.get_child_count() >= 8, "every post is on the phone")
	check(story.step == "feed", "opening the feed is not reading it")
	home.phone.finish_feed()
	await create_timer(0.2).timeout
	check(story.step == "chat", "reaching the end brings the group chat")
	home.phone.open_thread("team")
	var left := 12.0
	while home.phone.replies.get_child_count() == 0 and left > 0.0:
		await create_timer(0.2).timeout
		left -= 0.2
	check(home.phone.replies.get_child_count() > 0, "Peter gets to answer")
	home.phone.reply_chosen.emit(0)
	left = 8.0
	while story.step != "leave" and left > 0.0:
		await create_timer(0.2).timeout
		left -= 0.2
	check(story.step == "leave", "the plan is made")
	check(home.interactions.any(func(e): return e.label == "Ra khỏi nhà"), "the door opens the night")
	check(home.interactions.any(func(e): return e.label.begins_with("Khung cửa")), "the room keeps An's marks")
	print("failures ", failures)
	quit(failures)
