extends SceneTree
# Day 1 and Bảy Rô at Góc Cờ, with real clicks: he blocks, remembers losses
# and guards the way to the school.
# Runs offline on purpose, so every line comes from the written fallback.
# godot --headless --path . --script tools/validate_caro_play.gd
const Gear := preload("res://scripts/night_gear.gd")
const Rules := preload("res://scripts/caro/caro_rules.gd")
const Bot := preload("res://scripts/caro/caro_bot.gd")
const People := preload("res://scripts/caro/caro_people.gd")
var failures := 0
var town: Node3D

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func at(row: int, col: int) -> int:
	return Rules.cell_of(row, col)

func click(view: Control, cell: int) -> void:
	# The UI is stretched from 1280x720; pushed input counts window pixels.
	var point: Vector2 = root.get_final_transform() * view.cell_centre(cell)
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

func open() -> Control:
	town.story.open_caro()
	await process_frame
	var view: Control = town.story.view
	view.ai_url = ""
	# The greeting asked the real bridge before ai_url was cleared; let it fail over first.
	var left := 3.0
	while left > 0.0 and view.says.text == "…":
		await process_frame
		left -= 1.0 / 60.0
	return view

# Puts a prepared position on the board, the player to move.
func lay(view: Control, player: Array, baro: Array) -> void:
	var game: RefCounted = Rules.new()
	for spot in player:
		game.board[at(spot[0], spot[1])] = 1
		game.history.append(at(spot[0], spot[1]))
	for spot in baro:
		game.board[at(spot[0], spot[1])] = -1
		game.history.append(at(spot[0], spot[1]))
	view.game = game
	view.board.queue_redraw()
	view.state = view.State.PLAYER

func label_of(prefix: String) -> Dictionary:
	for entry in town.interactions:
		if entry.label.ends_with("Bảy Rô") and entry.label.begins_with(prefix):
			return entry
	return {}

func run() -> void:
	var backup := FileAccess.get_file_as_bytes(Gear.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	town = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await create_timer(3.6).timeout
	var story: Node = town.story
	check(not label_of("Chơi caro").is_empty(), "Bảy Rô waits at Góc Cờ for a game")
	check(story.objective().text.contains("Bảy Rô"), "the objective sends the player to Bảy Rô first")
	story._gate()
	check(not story.finished_day, "the school gate stays shut before beating him")

	var view: Control = await open()
	check(view.state == view.State.PLAYER and view.says.text in People.LINES.open_first, "he greets a newcomer")
	await click(view, at(7, 7))
	check(view.game.board[at(7, 7)] == 1, "a click places X")
	check(await wait_state(view, view.State.PLAYER, 6.0), "Bảy Rô answers")
	check(view.game.history.size() == 2 and view.source.text.ends_with("offline"), "he played one stone, offline")
	# A four closed on one side: he must take the other end.
	lay(view, [[7, 3], [7, 4], [7, 5]], [[7, 2], [0, 0], [14, 14]])
	await click(view, at(7, 6))
	await wait_state(view, view.State.PLAYER, 6.0)
	check(view.game.board[at(7, 7)] == -1, "he blocks the four")
	# Ignoring his open three is noticed by the engine, and he says so.
	lay(view, [[0, 0], [14, 14]], [[5, 5], [5, 6], [5, 7]])
	view.cooldown_until = {}
	await click(view, at(12, 0))
	await wait_state(view, view.State.PLAYER, 6.0)
	check(not view.missed_note.is_empty(), "the engine notices the missed block")
	# He answers by making four from his open three: a strong move, so he cries out.
	check(view.says.text.contains(People.SIU), "a strong move of his ends in SIU: " + view.says.text)
	view.resign()
	await process_frame
	check(view.state == view.State.OVER and story.gear.caro_losses == 1, "resigning counts a loss")
	await process_frame
	check(view.says.text.contains(People.SIU), "winning, he cries out: " + view.says.text)
	check(Gear.read().caro_losses == 1 and not Gear.read().caro_last_decisive.is_empty(), "the loss and its decisive move are saved")
	view.new_game()
	await process_frame
	check(view.says.text in People.LINES.open_again, "he greets a returning player")
	check(Bot.depth_for(story.gear.caro_losses) < Bot.depth_for(0), "he searches shallower after a loss")
	story.close()
	await process_frame
	check(town.player.enabled, "leaving returns to the street")

	view = await open()
	lay(view, [[7, 3], [7, 4], [7, 5], [7, 6]], [[0, 0], [14, 14], [0, 14]])
	await click(view, at(7, 7))
	check(view.state == view.State.OVER and view.win_cells.size() == 5, "five in a row wins")
	check(story.gear.caro_won and Gear.read().caro_won, "the win is saved")
	check(view.says.text in People.LINES.win and not view.says.text.contains("SIU"), "losing, he admits it without the cry")
	for i in range(People.REVEAL.size()):
		view.reveal_next()
	check(view.says.text == People.REVEAL.back()[1], "he tells what he knows, word for word")
	story.close()
	await process_frame
	check(not label_of("Nói chuyện").is_empty(), "afterwards he is someone to talk to")
	check(not story.objective().text.contains("Bảy Rô"), "the objective moves on to the school gate")
	story.open_caro()
	await process_frame
	check(story.talking_now() and story.talking == "baro", "talking to him replays what he said")
	story.close()
	await process_frame
	story._gate()
	var moved := false
	for i in range(420):
		await process_frame
		if current_scene != town and current_scene != null:
			moved = true
			break
	check(moved and current_scene.scene_file_path == "res://scenes/school_runtime.tscn" and has_meta("night_one"), "after winning, the gate opens Night 1")

	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	else:
		FileAccess.open(Gear.PATH, FileAccess.WRITE).store_buffer(backup)
	print("failures ", failures)
	quit(failures)
