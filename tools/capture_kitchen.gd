extends SceneTree
# Look check for the mì net breakfast, one shot per step:
# godot --path . --script tools/capture_kitchen.gd --resolution 1280x720 -- <output folder>
var home: Node3D
var kitchen: Node3D
var folder := "res://docs"

func _initialize() -> void:
	call_deferred("run")

func shot(title: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/kitchen-%s.png" % [folder, title])

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func until_step(title: String) -> void:
	while kitchen.step_title.text != title:
		await process_frame

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		folder = OS.get_cmdline_user_args()[0]
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	home.fade.hide()
	kitchen = home.kitchen
	# Only this script drives the cooking: a stray click on the window must not count.
	kitchen.set_process_unhandled_input(false)
	var story: Node = home.story
	story.step = "hungry"
	home.player.global_position = Vector3(4.6, 0.05, 2.2)
	home.player.yaw = 0.0
	home._open_fridge()
	await until_step("Bắc nồi nước")
	await wait(0.8)
	await shot("1-stove")
	kitchen.acted.emit()
	await until_step("Xé gói mì")
	await wait(0.8)
	kitchen.tear = 0.5
	await shot("2-pack")
	kitchen.tear = 1.0
	await until_step("Nấu mì")
	await wait(2.6)
	await shot("3-boil")
	kitchen.acted.emit()
	await until_step("Chắt nước")
	kitchen.holding = true
	await wait(1.4)
	await shot("3b-drain")
	while kitchen.water_left > 0.0:
		await process_frame
	kitchen.holding = false
	await until_step("Trộn gia vị")
	for i in range(kitchen.STIRS):
		await wait(0.4)
		kitchen.acted.emit()
	await wait(0.3)
	await shot("3c-mix")
	await until_step("Đập trứng")
	await wait(0.8)
	await shot("4-egg")
	await wait(0.1)
	kitchen.acted.emit()
	await until_step("Chiên")
	await wait(3.2)
	await shot("5-fry")
	kitchen.acted.emit()
	await until_step("Thái hành")
	await wait(0.6)
	for i in range(6):
		kitchen.acted.emit()
		await wait(0.15)
	await shot("6-chop")
	for i in range(kitchen.CHOPS - 6):
		kitchen.acted.emit()
		await wait(0.15)
	await until_step("Xịt tương ớt")
	await wait(0.8)
	for i in range(40):
		var angle := i * 0.5
		kitchen.squirt(kitchen.bowl.position + Vector3(cos(angle) * 0.0012 * i, 0.088, sin(angle) * 0.0012 * i))
	kitchen.chili.scale = Vector3.ONE * 0.55
	kitchen.chili.position = kitchen.bowl.position + Vector3(0.02, 0.102 + 0.08, -0.054)
	kitchen.chili.rotation.x = 2.6
	await shot("7-sauce")
	kitchen.acted.emit()
	await until_step("Khui lon Xiteen")
	await wait(0.6)
	await shot("8-can")
	kitchen.acted.emit()
	while story.step != "carry":
		await process_frame
	await wait(0.2)
	home.player.global_position = Vector3(3.9, 0.05, 3.3)
	home.player.yaw = PI * 0.8
	home.player.pitch = -0.3
	await shot("9-carry")
	kitchen.table_touch.action.call()
	await until_step("Ăn mì")
	await wait(0.5)
	await shot("10-table")
	kitchen.acted.emit()
	while kitchen.chopsticks.global_position.distance_to(kitchen._mouth()) > 0.01:
		await process_frame
	await wait(0.05)
	await shot("11-bite")
	await wait(0.8)
	await shot("12-after-bite")
	while story.step != "go_out":
		kitchen.acted.emit()
		await wait(0.9)
	await wait(0.3)
	await shot("13-done")
	quit()
