extends SceneTree
# Look check: godot --path . --script tools/capture_home.gd --resolution 1600x900
const VIEWS := {"living": [Vector3(0.8, 1.6, 12.4), Vector3(4.2, 1.0, 8.0)], "dining": [Vector3(5.0, 1.6, 7.6), Vector3(2.2, 0.8, 1.0)], "bath": [Vector3(1.75, 1.6, 3.0), Vector3(1.0, 0.8, 0.3)], "bedroom": [Vector3(4.6, 4.5, 6.2), Vector3(1.2, 3.3, 1.2)], "desk": [Vector3(2.4, 4.5, 4.4), Vector3(4.0, 3.7, 0.4)], "landing": [Vector3(5.8, 4.5, 8.4), Vector3(4.05, 3.9, 6.2)], "stairs": [Vector3(5.8, 1.6, 12.8), Vector3(5.8, 2.5, 7.0)]}
var home: Node3D

func _initialize() -> void:
	call_deferred("run")

func shot(title: String) -> void:
	for i in range(14): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/home-%s.png" % title)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	var player: CharacterBody3D = home.player
	player.set_physics_process(false)
	for title in VIEWS:
		player.global_position = VIEWS[title][0] - Vector3.UP * player.EYE
		player.camera.position = Vector3(0, player.EYE, 0)
		player.camera.look_at(VIEWS[title][1])
		await shot(title)
	var story: Node = home.story
	story._ask_consent()
	await shot("consent")
	story.panel.queue_free()
	story.panel = null
	home.goal.text = "Mở điện thoại · Tab"
	home.phone.add_thread("lan", "Lan", "Vừa truy cập", Color(0.55, 0.38, 0.62), "L")
	home.phone.receive("lan", story.LAN_TALK[0].say[0])
	await shot("banner")
	home.phone.toggle()
	await wait(4.0)
	home.phone.show_list()
	await shot("phone-list")
	home.phone.open_thread("lan")
	for beat in range(3):
		for line in story.LAN_TALK[beat].say:
			home.phone.receive("lan", line)
		if beat < 2:
			home.phone.send_mine("lan", story.LAN_TALK[beat].ask[0])
	home.phone.offer_replies(story.LAN_TALK[2].ask)
	await shot("phone-chat")
	home.phone.clear_replies()
	home.phone.add_thread("unknown", " ", " ", Color(0.70, 0.72, 0.74), "")
	home.phone.open_thread("unknown")
	for size in story.GARBLED:
		home.phone.receive("unknown", "x".repeat(size), true)
	await shot("phone-stranger")
	home.phone.toggle()
	quit()
