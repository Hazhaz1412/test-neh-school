extends SceneTree
# Chess at Góc Cờ with real clicks, the three opponents, and the clock of the day.
const Gear := preload("res://scripts/night_gear.gd")
const Rules := preload("res://scripts/chess/chess_rules.gd")
var failures := 0
var town: Node3D

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func square(text: String) -> int:
	return text.unicode_at(0) - 97 + (int(text[1]) - 1) * 8

func click(view: Control, text: String) -> void:
	var point: Vector2 = view.camera.unproject_position(view.table.to_global(view.table.spot(square(text))))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	root.push_input(press)
	var off: InputEventMouseButton = press.duplicate()
	off.pressed = false
	root.push_input(off)
	await process_frame
	await process_frame

func wait_state(view: Control, wanted: int, seconds: float) -> bool:
	var left := seconds
	while left > 0.0 and view.state != wanted:
		await process_frame
		left -= 1.0 / 60.0
	return view.state == wanted

func open(id: String) -> Control:
	town.story.open_chess()
	await process_frame
	var view: Control = town.story.view
	view.start(id)
	await process_frame
	return view

func shot(title: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/chess-%s.png" % title)

func run() -> void:
	var backup := FileAccess.get_file_as_bytes(Gear.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	town = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await create_timer(3.6).timeout
	check(town.clock_text() == "07:00", "the day starts at seven")
	await create_timer(1.0).timeout
	check(town.minutes == town.DAY_START, "standing still costs no time")
	check(town.story.gear.money == 300, "the wallet opens at 300$")
	var view: Control = await open("kid")
	await shot("start")
	await click(view, "e2")
	check(view.picked == square("e2") and view.targets.size() == 2, "a click picks the pawn and shows its squares")
	await click(view, "e4")
	check(view.game.board[square("e4")] == Rules.PAWN or view.state != view.State.PLAYER, "a second click plays it")
	check(await wait_state(view, view.State.PLAYER, 8.0), "the kid answers")
	check(view.ply >= 2, "two plies were played")
	check(view.game.board[square("e4")] == Rules.PAWN, "the board kept the move")
	await shot("midgame")
	# His trick: looks away, moves a piece, and catching him puts it back and fines him.
	var before: PackedInt32Array = view.game.board.duplicate()
	var money: int = town.story.gear.money
	await view._sneak()
	view.state = view.State.PLAYER
	check(view.cheated and view.game.board != before, "while the player looks away a piece moves")
	await shot("cheat")
	view._accuse()
	check(view.game.board == before and town.story.gear.money == money + view.FINE, "catching him undoes it and pays the fine")
	view.game.load_fen("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0")
	view.table.lay(view.game.board)
	view.ply = 20
	var clock: int = town.minutes
	money = town.story.gear.money
	await click(view, "d1")
	await click(view, "d8")
	await wait_state(view, view.State.OVER, 3.0)
	check(view.state == view.State.OVER and town.story.gear.money == money + 10, "mating the kid pays 10$")
	check(town.minutes == clock + 30, "that game cost 30 minutes")
	town.story.close()
	await process_frame
	check(town.player.enabled and town.player.camera.current, "leaving returns to the street")
	view = await open("mid")
	check(view.timer.visible, "Bơ Tồ plays against a clock")
	clock = town.minutes
	view.clock = 0.05
	await create_timer(0.3).timeout
	check(view.state == view.State.OVER and town.minutes == clock + 60, "the flag falls and an hour is gone")
	town.story.close()
	await process_frame
	view = await open("hard")
	check(view.listen_button.visible and not view.catch_button.visible, "only Thầy Khải's table has the whisper")
	view._listen()
	await wait_state(view, view.State.PLAYER, 5.0)
	check(view.whispered and view.table.marks_used >= 2, "listening marks a move")
	await shot("whisper")
	view.game.load_fen("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0")
	view.table.lay(view.game.board)
	view.table.clear_marks()
	money = town.story.gear.money
	clock = town.minutes
	await click(view, "d1")
	await click(view, "d8")
	await wait_state(view, view.State.OVER, 3.0)
	check(town.story.gear.money == money + 140 and town.minutes == clock + 60, "beating the teacher pays 140$ for an hour")
	view._hear_lore()
	check(view.title.text == "Thầy Khải" and view.says.text.contains("10A6"), "he finally talks about An")
	await shot("lore")
	town.story.close()
	await process_frame
	var phase: int = town.sky.phase
	town.spend(5 * 60)
	check(town.sky.phase != phase, "the light follows the clock: " + town.clock_text())
	money = town.story.gear.money
	var pho: Dictionary = {}
	for entry in town.interactions:
		if entry.label.begins_with("Ăn tô phở"):
			pho = entry
	clock = town.minutes
	pho.action.call()
	check(town.story.gear.money == money - 5 and town.minutes == clock + 30 and town.story.gear.boosts == 1, "phở costs money, time and strengthens the night")
	check(town.interactions.size() >= 16, "the street has things to do: %d" % town.interactions.size())
	check(town.life.walkers.size() == 10, "people walk the street")
	town.spend(24 * 60)
	check(town.ending, "the day ends in the night at the school")
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	else:
		FileAccess.open(Gear.PATH, FileAccess.WRITE).store_buffer(backup)
	print("failures ", failures)
	quit(failures)
