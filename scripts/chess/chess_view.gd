extends Control
# A game at Góc Cờ: opponent picker, then the board seen from the player's chair.
const Rules := preload("res://scripts/chess/chess_rules.gd")
const Bot := preload("res://scripts/chess/chess_bot.gd")
const People := preload("res://scripts/chess/chess_people.gd")
const Person := preload("res://scripts/town/town_person.gd")
enum State {PICK, PLAYER, THINKING, MOVING, CHEATING, OVER}
const BLITZ_SECONDS := 300.0
const PANEL_WIDTH := 340.0
const FINE := 5
const CHEAT_FROM_PLY := 6
const CHEAT_CHANCE := 0.3
const EYE := Vector3(0, 0.56, -0.56)
const GAZE := Vector3(0, 0.05, 0.07)
const SHIFT := 0.11
const SELECTED := Color(0.95, 0.80, 0.25, 0.55)
const TARGET := Color(0.30, 0.85, 0.45, 0.45)
const LAST := Color(0.55, 0.65, 0.95, 0.35)
const GHOST := Color(0.75, 0.9, 1.0, 0.6)
var world: Node3D
var story: Node
var table: Node3D
var game: RefCounted
var foe: Dictionary
var state := State.PICK
var picked := -1
var targets: Array = []
var last_move := -1
var ply := 0
var clock := BLITZ_SECONDS
var thread: Thread
var bot := Bot.new()
var thinking_for := ""
var camera: Camera3D
var rival: Node3D
var cheated := false
var cheat_back: RefCounted
var cheat_used := false
var accused := false
var whispered := false
var settled := false
var lore_line := 0
var title: Label
var says: Label
var status: Label
var timer: Label
var buttons: HBoxContainer
var picker: VBoxContainer
var catch_button: Button
var backing: ColorRect
var listen_button: Button

func setup(town: Node3D, owner_story: Node, board: Node3D) -> void:
	world = town
	story = owner_story
	table = board
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	_show_picker()

func _label(size_px: int, color: Color, parent: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _build_panel() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	shade.offset_left = -PANEL_WIDTH
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -330
	side.offset_right = -24
	side.offset_top = 24
	side.offset_bottom = -24
	side.add_theme_constant_override("separation", 10)
	add_child(side)
	title = _label(26, Color(1.0, 0.86, 0.5), side)
	timer = _label(34, Color(0.98, 0.96, 0.9), side)
	says = _label(19, Color(0.96, 0.94, 0.88), side)
	says.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status = _label(17, Color(0.82, 0.9, 0.82), side)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	side.add_child(buttons)
	catch_button = _button("Bắt quả tang", _accuse, buttons)
	listen_button = _button("Lắng nghe", _listen, buttons)
	_button("Đầu hàng", _resign, buttons)
	buttons.hide()
	shade.hide()
	backing = shade
	picker = VBoxContainer.new()
	picker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	picker.custom_minimum_size = Vector2(640, 0)
	picker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	picker.grow_vertical = Control.GROW_DIRECTION_BOTH
	picker.add_theme_constant_override("separation", 10)
	add_child(picker)

func _button(text: String, press: Callable, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = 40
	button.pressed.connect(press)
	parent.add_child(button)
	return button

func _show_picker() -> void:
	var head := _label(30, Color(1.0, 0.86, 0.5), picker)
	head.text = "Góc Cờ"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for id in People.OPPONENTS:
		var who: Dictionary = People.OPPONENTS[id]
		var row := _button("%s · thắng %d$ · %d phút\n%s" % [who.name, who.pay, who.minutes, who.rule], start.bind(id), picker)
		row.custom_minimum_size.y = 72
	_button("Thôi · Esc", story.close, picker)

func start(id: String) -> void:
	foe = People.OPPONENTS[id].duplicate()
	foe.id = id
	picker.hide()
	backing.show()
	game = Rules.new()
	table.lay(game.board)
	var spare: Camera3D = Camera3D.new()
	table.add_child(spare)
	spare.fov = 40.0
	spare.h_offset = SHIFT
	spare.position = EYE
	spare.look_at(table.to_global(GAZE))
	spare.make_current()
	camera = spare
	rival = Person.new()
	rival.look = foe.look
	rival.height = foe.height
	rival.motion = "sit"
	world.add_child(rival)
	var seat: Vector3 = table.to_global(Vector3(0, 0, 0.52))
	rival.global_position = Vector3(seat.x, world.plan.ground(Vector2(seat.x, seat.z)) + foe.get("lift", 0.0), seat.z)
	rival.global_rotation.y = table.global_rotation.y + PI
	title.text = foe.name
	says.text = foe.open
	buttons.show()
	catch_button.visible = id == "kid"
	listen_button.visible = id == "hard"
	timer.visible = id == "mid"
	state = State.PLAYER
	status.text = "Anh cầm Trắng. Bấm quân rồi bấm ô đến."

func _process(delta: float) -> void:
	if state == State.PLAYER and foe.id == "mid":
		clock -= delta
		timer.text = "%d:%02d" % [int(clock) / 60, int(clock) % 60]
		if clock <= 0.0:
			says.text = "Cờ rớt rồi nha!"
			_finish("lose")
	if thread != null and not thread.is_alive():
		var move: int = thread.wait_to_finish()
		thread = null
		if state == State.THINKING:
			if thinking_for == "whisper":
				_reveal(move)
			else:
				_bot_moves(move)

# Read before the GUI: the side panel owns its own strip, everything left of it is the board.
func _input(event: InputEvent) -> void:
	if state == State.PLAYER and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.x < size.x - PANEL_WIDTH:
		# The UI is stretched from 1280x720; the camera counts real pixels.
		var pixels: Vector2 = event.position * Vector2(get_viewport().size) / size
		_click(table.square_at(camera, pixels))

func _click(square: int) -> void:
	if square < 0:
		_unpick()
		return
	for move in targets:
		if Rules.to_of(move) == square:
			player_moves(move)
			return
	_unpick()
	if game.board[square] > 0:
		picked = square
		table.lift(square, true)
		table.mark(square, SELECTED)
		for move in game.legal_moves():
			if Rules.from_of(move) == square and (Rules.promo_of(move) == 0 or Rules.promo_of(move) == Rules.QUEEN):
				targets.append(move)
				table.mark(Rules.to_of(move), TARGET)

func _unpick() -> void:
	if picked >= 0:
		table.lift(picked, false)
	picked = -1
	targets.clear()
	table.clear_marks()
	_mark_last()

func _mark_last() -> void:
	if last_move >= 0:
		table.mark(Rules.from_of(last_move), LAST)
		table.mark(Rules.to_of(last_move), LAST)

func player_moves(move: int) -> void:
	_unpick()
	state = State.MOVING
	await _animate(move)
	if _ended():
		return
	if ply > 2 and randf() < 0.25:
		says.text = foe.taunt[randi() % foe.taunt.size()]
	if game.in_check(game.turn):
		says.text = foe.check[randi() % foe.check.size()]
	_ask_bot("move")

func _ask_bot(kind: String) -> void:
	thinking_for = kind
	state = State.THINKING
	status.text = "%s đang nghĩ..." % foe.name
	var position_now: RefCounted = game.clone()
	var level: String = "whisper" if kind == "whisper" else foe.level
	thread = Thread.new()
	thread.start(bot.choose.bind(position_now, level))

func _bot_moves(move: int) -> void:
	state = State.MOVING
	await _animate(move)
	if _ended():
		return
	if foe.id == "kid" and not cheat_used and ply >= CHEAT_FROM_PLY and randf() < CHEAT_CHANCE:
		await _sneak()
	state = State.PLAYER
	status.text = "Tới lượt anh." + (" Anh đang bị chiếu!" if game.in_check(1) else "")

func _animate(move: int) -> void:
	await table.slide(Rules.from_of(move), Rules.to_of(move))
	game.play(move)
	ply += 1
	last_move = move
	table.lay(game.board)
	table.clear_marks()
	_mark_last()
	world.street_click()

# Looks away with the player, then one of his pieces is somewhere it never walked to.
func _sneak() -> void:
	var line: String = People.CATCHES[randi() % People.CATCHES.size()]
	says.text = line
	state = State.CHEATING
	var from_angle: Vector3 = camera.rotation
	var away := create_tween()
	away.tween_property(camera, "rotation:y", from_angle.y + 1.3, 0.35)
	await away.finished
	cheat_back = game.clone()
	var mine: Array = []
	var free: Array = []
	for square in range(24, 64):
		if game.board[square] < 0 and absi(game.board[square]) in [Rules.BISHOP, Rules.KNIGHT, Rules.ROOK]:
			mine.append(square)
		if game.board[square] == 0 and square < 56:
			free.append(square)
	var moved := false
	mine.shuffle()
	free.shuffle()
	for square in mine:
		for goal in free:
			var trial: RefCounted = game.clone()
			trial.board[goal] = trial.board[square]
			trial.board[square] = 0
			if not trial.in_check(1) and not trial.legal_moves().is_empty():
				game.board = trial.board
				moved = true
				break
		if moved:
			break
	table.lay(game.board)
	cheat_used = true
	cheated = moved
	await get_tree().create_timer(0.5).timeout
	var back := create_tween()
	back.tween_property(camera, "rotation:y", from_angle.y, 0.35)
	await back.finished
	says.text = "Hông có gì đâu anh. Tới anh đó."

func _accuse() -> void:
	if state != State.PLAYER or accused:
		return
	accused = true
	catch_button.disabled = true
	if not cheated:
		says.text = "Đâu có! Anh vu oan em!"
		return
	game = cheat_back
	cheated = false
	table.lay(game.board)
	table.clear_marks()
	_mark_last()
	story.pay(FINE)
	says.text = "Ơ... sao anh biết. Thôi em trả lại, đừng méc má em."
	status.text = "Phạt Tí Sún %d$." % FINE

func _listen() -> void:
	if state != State.PLAYER or whispered:
		return
	whispered = true
	listen_button.disabled = true
	_unpick()
	says.text = "...đi đúng luật..."
	_ask_bot("whisper")

func _reveal(move: int) -> void:
	state = State.PLAYER
	status.text = "Có ai đó vừa thở sau gáy anh."
	table.mark(Rules.from_of(move), GHOST)
	table.mark(Rules.to_of(move), GHOST)

func _resign() -> void:
	if state == State.PLAYER:
		says.text = foe.lose
		_finish("lose")

func _ended() -> bool:
	var result: String = game.outcome()
	if result.is_empty():
		return false
	if result == "mate":
		_finish("win" if game.turn < 0 else "lose")
	else:
		_finish("draw")
	return true

func _finish(result: String) -> void:
	state = State.OVER
	settled = true
	_unpick()
	buttons.hide()
	var pay := 0
	match result:
		"win":
			pay = foe.pay
			says.text = foe.win
			status.text = "Thắng! +%d$ · Mất %d phút." % [pay, foe.minutes]
		"draw":
			says.text = foe.draw
			status.text = "Hòa. Mất %d phút." % foe.minutes
		_:
			if says.text != foe.lose and not says.text.begins_with("Cờ rớt"):
				says.text = foe.lose
			status.text = "Thua. Mất %d phút." % foe.minutes
	if pay > 0:
		story.pay(pay)
	world.spend(foe.minutes)
	if result == "win" and foe.id == "hard" and not story.gear.get("heard_khai", false):
		story.gear.heard_khai = true
		story.pay(0)
		_button("Nghe thầy kể", _hear_lore, get_child(0))
	_button("Rời bàn cờ", story.close, get_child(0))

func _hear_lore() -> void:
	if lore_line < People.LORE.size():
		title.text = People.LORE[lore_line][0]
		says.text = People.LORE[lore_line][1]
		lore_line += 1

func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()
	if not settled and foe.has("id") and ply > 0:
		world.spend(foe.minutes)
	if camera != null:
		camera.queue_free()
	if rival != null:
		rival.queue_free()
	if table != null and game != null:
		table.lay(Rules.new().board)
		table.clear_marks()
