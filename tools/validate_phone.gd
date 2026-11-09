extends SceneTree
# The phone handles like a real one: godot --path . --script tools/validate_phone.gd
# Drives it with synthetic mouse input: lift, unlock, drag and fling a chat, overscroll and
# spring back, a drag that must not tap, a swipe home, and putting it away.
var failures := 0
var home: Node3D
var phone: Control

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func frames(count: int) -> void:
	for i in range(count): await process_frame

# A point on the phone's screen, in window pixels (the project stretches its canvas).
func at(screen_point: Vector2) -> Vector2:
	return root.get_final_transform() * (phone.display.get_global_transform_with_canvas() * screen_point)

func button(where: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = where
	event.global_position = where
	Input.parse_input_event(event)
	await process_frame

func move(where: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = where
	event.global_position = where
	Input.parse_input_event(event)
	await process_frame

func drag(from: Vector2, to: Vector2, steps := 8) -> void:
	await button(at(from), true)
	for i in range(1, steps + 1):
		await move(at(from.lerp(to, float(i) / steps)))
	await button(at(to), false)

func run() -> void:
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await frames(3)
	home.fade.hide()
	phone = home.phone
	check(not phone.is_open(), "the phone starts in the pocket")
	home.story.toggle_phone()
	check(phone.is_open() and phone.locked, "Tab lifts it onto the lock screen")
	await wait(0.2)
	check(home.player.glance > 0.05, "the head bows to look at it")
	await wait(1.4)
	check(not phone.locked and phone.app == "home", "face unlock lets it in by itself")
	phone.add_thread("demo", "Nhóm", "A, B", Color.GRAY, "N")
	phone.open_thread("demo")
	for i in range(18):
		phone.receive("demo", "A: dòng %d" % i)
	await wait(0.8)
	var chat: Control = phone.tili.scroller
	var bottom: float = chat.max_offset()
	check(bottom > 200 and absf(chat.offset - bottom) < 2.0, "a long chat opens at its last message")
	await drag(Vector2(200, 400), Vector2(200, 600))
	check(chat.offset < bottom - 150, "dragging down scrolls back through the chat")
	var after_drag: float = chat.offset
	await wait(0.4)
	check(chat.offset < after_drag - 30, "a fling keeps gliding after the hand lets go")
	await wait(1.5)
	var settled: float = chat.offset
	await wait(0.3)
	check(absf(chat.offset - settled) < 1.0, "the glide comes to a stop")
	chat.scroll_to_top()
	await frames(2)
	await button(at(Vector2(200, 300)), true)
	for i in range(1, 9):
		await move(at(Vector2(200, 300 + i * 25)))
	check(chat.offset < -20, "pulling past the top stretches the list")
	await button(at(Vector2(200, 500)), false)
	await wait(0.9)
	check(absf(chat.offset) < 1.0, "and it springs back")
	phone.tili.show_list()
	await wait(0.2)
	var row: Control = phone.tili.thread_rows.get_child(0)
	var row_mid: Vector2 = phone.display.get_global_transform_with_canvas().affine_inverse() * row.get_global_transform_with_canvas() * (row.size * 0.5)
	await drag(row_mid, row_mid + Vector2(0, 120))
	await wait(0.1)
	check(not phone.tili.chat_page.visible, "a drag that starts on a chat does not open it")
	await wait(0.6)
	row_mid = phone.display.get_global_transform_with_canvas().affine_inverse() * row.get_global_transform_with_canvas() * (row.size * 0.5)
	await button(at(row_mid), true)
	await button(at(row_mid), false)
	await wait(0.1)
	check(phone.tili.chat_page.visible, "a tap on it does")
	await drag(Vector2(200, 850), Vector2(200, 600), 6)
	await wait(0.5)
	check(phone.app == "home", "a swipe up from the bottom bar goes home")
	home.story.toggle_phone()
	check(not phone.is_open(), "Tab puts it away")
	await wait(0.6)
	check(not phone.shell.visible and home.player.glance < 0.02, "it drops out of view and the head comes back up")
	home.story.toggle_phone()
	await wait(0.45)
	check(phone.locked, "it comes up locked again")
	await drag(Vector2(200, 700), Vector2(200, 380), 6)
	await wait(0.05)
	check(not phone.locked, "a swipe up on the lock screen unlocks at once")
	print("phone checks failed: %d" % failures)
	quit(1 if failures > 0 else 0)
