extends SceneTree
# The evening Peter moves in: an empty phone, the house and its doors, and the bed that
# leads into the Night 0 dream.
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
	check(story.step == "settle" and home.goal.text.contains("ngủ"), "the evening asks only for sleep")
	check(home.phone.threads.is_empty(), "no old chats are waiting on the phone")
	check(home.phone.fake_new == 0, "nothing on Fake pulls him in yet")
	var labels: Array = home.interactions.map(func(e): return e.label)
	check("Cửa chính" in labels and "Mở cửa phòng tắm" in labels and "Đóng cửa phòng ngủ" in labels, "the house has a front door, a bathroom door and an open bedroom door")
	var bathroom: Dictionary = home.interactions.filter(func(e): return e.label == "Mở cửa phòng tắm")[0]
	bathroom.action.call()
	await create_timer(0.8).timeout
	check(bathroom.label == "Đóng cửa phòng tắm", "the bathroom door swings open and offers to close")
	home.front_touch.action.call()
	check(not home.front_door.is_open, "the front door stays shut tonight")
	check(home.interactions.any(func(e): return e.label.begins_with("Khung cửa")), "the room keeps An's marks")
	story.toggle_phone()
	check(home.phone.app == "home", "the phone opens on its home screen")
	home.phone._tap_app("camera", home.phone.badges["camera"].get_parent().get_child(0))
	check(home.phone.app == "home", "other apps only wiggle")
	story.toggle_phone()
	story._bed()
	check(story.step == "dreaming", "lying down starts the dream")
	var moved := false
	for i in range(600):
		await process_frame
		if current_scene != home and current_scene != null:
			moved = true
			break
	check(moved and current_scene.scene_file_path == "res://scenes/school_runtime.tscn" and not has_meta("night_one"), "the dream is Night 0 at the school")
	print("failures ", failures)
	quit(failures)
