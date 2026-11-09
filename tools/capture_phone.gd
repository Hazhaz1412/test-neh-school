extends SceneTree
# Look check of the phone: godot --path . --script tools/capture_phone.gd --resolution 1600x900
# Frames of the lift, the lock screen, home, both apps empty and a chat, into docs/phone-*.png.
var home: Node3D

func _initialize() -> void:
	call_deferred("run")

func shot(title: String, frames := 2) -> void:
	for i in range(frames): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/phone-%s.png" % title)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	var player: CharacterBody3D = home.player
	home.fade.hide()
	player.global_position = Vector3(4.6, 4.5, 6.2) - Vector3.UP * player.EYE
	player.yaw = 0.6
	await shot("room", 14)
	var phone: Control = home.phone
	phone.toggle()
	await wait(0.12)
	await shot("lift-1", 1)
	await wait(0.16)
	await shot("lift-2", 1)
	await wait(0.3)
	await shot("lock", 1)
	await wait(1.3)
	await shot("home", 1)
	phone.open_app("fake")
	await wait(0.09)
	await shot("app-zoom", 1)
	await wait(0.6)
	await shot("fake-empty", 1)
	phone.go_home()
	await wait(0.6)
	phone.show_list()
	await wait(0.6)
	await shot("tili-empty", 1)
	phone.add_thread("demo", "Nhóm điều tra", "Bơ Tồ, Ba Rô, Huna", Color(0.42, 0.46, 0.52), "N")
	phone.open_thread("demo")
	for i in range(14):
		phone.receive("demo", ("Huna: " if i % 2 == 0 else "Ba Rô: ") + "Tin nhắn thử số %d để xem cuộn." % (i + 1))
	await wait(0.8)
	await shot("chat", 1)
	phone.toggle()
	await wait(0.12)
	await shot("lower", 1)
	await wait(0.5)
	quit()
