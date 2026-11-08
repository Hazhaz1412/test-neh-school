extends Control
# The caro game with Bảy Rô: a 2D board over the darkened street, his words on the right.
# The engine decides what is legal, forced and true; the AI bridge only picks among the
# engine's candidates and gives him a voice. Any bridge failure falls back to written lines.
const Rules := preload("res://scripts/caro/caro_rules.gd")
const Bot := preload("res://scripts/caro/caro_bot.gd")
const People := preload("res://scripts/caro/caro_people.gd")
enum State {INTRO, PLAYER, THINKING, ASKING_AI, OVER, REVEAL}
const PANEL_WIDTH := 340.0
const BOARD_PIXELS := 600.0
const CELL_PIXELS := BOARD_PIXELS / Rules.SIZE
const AI_TIMEOUT := 6.0
# Bảy Rô reacts to the same kind of event at most once every few player moves.
const EVENT_COOLDOWN := 3
const EVENT_PRIORITY := ["good_move", "threat_created", "missed_block"]
const PAPER := Color(0.93, 0.89, 0.78)
const GRID := Color(0.45, 0.40, 0.32)
const CROSS := Color(0.78, 0.16, 0.12)
const RING := Color(0.13, 0.27, 0.62)
const LAST := Color(0.95, 0.80, 0.25, 0.45)
const WIN_LINE := Color(0.30, 0.85, 0.45, 0.45)
var ai_url := "http://127.0.0.1:8765/caro"
var world: Node3D
var story: Node
var game: RefCounted
var bot := Bot.new()
var state := State.INTRO
var thread: Thread
var last_cell := -1
var win_cells: Array = []
var events_now: Array = []
var advantage_now := "even"
var cooldown_until := {}
var player_moves := 0
var missed_note := ""
var request_serial := 0
var reveal_line := 0
var board: Control
var title: Label
var says: Label
var status: Label
var source: Label
var buttons: HBoxContainer

func setup(town: Node3D, owner_story: Node) -> void:
	world = town
	story = owner_story
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	new_game()

func _label(size_px: int, color: Color, parent: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(text: String, press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = 40
	button.pressed.connect(press)
	buttons.add_child(button)
	return button

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	board = Control.new()
	board.size = Vector2.ONE * BOARD_PIXELS
	board.position = Vector2((1280.0 - PANEL_WIDTH - BOARD_PIXELS) * 0.5, (720.0 - BOARD_PIXELS) * 0.5)
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	add_child(board)
	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -330
	side.offset_right = -24
	side.offset_top = 24
	side.offset_bottom = -24
	side.add_theme_constant_override("separation", 10)
	add_child(side)
	title = _label(26, Color(1.0, 0.86, 0.5), side)
	source = _label(13, Color(0.7, 0.7, 0.7), side)
	says = _label(19, Color(0.96, 0.94, 0.88), side)
	says.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status = _label(17, Color(0.82, 0.9, 0.82), side)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	side.add_child(buttons)

func _set_buttons(list: Array) -> void:
	for child in buttons.get_children():
		child.queue_free()
	for entry in list:
		_button(entry[0], entry[1])

func losses() -> int:
	return story.gear.caro_losses

func new_game() -> void:
	game = Rules.new()
	last_cell = -1
	win_cells = []
	cooldown_until = {}
	player_moves = 0
	missed_note = ""
	advantage_now = "even"
	title.text = People.BARO.name
	status.text = "Cậu cầm X, đi trước. Năm quân liền là thắng."
	_set_buttons([["Đầu hàng", resign]])
	board.queue_redraw()
	state = State.PLAYER
	says.text = "…"
	var fallback: String = _pick("open_again" if losses() > 0 else "open_first")
	_ask_ai("open", [], [], "", func(reply: Dictionary): says.text = _calm_or(reply, fallback))

# --- Board ------------------------------------------------------------------------------------

func _draw_board() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, board.size), PAPER)
	for i in range(Rules.SIZE + 1):
		var at := i * CELL_PIXELS
		board.draw_line(Vector2(at, 0), Vector2(at, BOARD_PIXELS), GRID, 1.0)
		board.draw_line(Vector2(0, at), Vector2(BOARD_PIXELS, at), GRID, 1.0)
	for cell in win_cells:
		board.draw_rect(_cell_rect(cell), WIN_LINE)
	if last_cell >= 0:
		board.draw_rect(_cell_rect(last_cell), LAST)
	for cell in game.history:
		var rect := _cell_rect(cell).grow(-CELL_PIXELS * 0.2)
		if game.board[cell] > 0:
			board.draw_line(rect.position, rect.end, CROSS, 3.0, true)
			board.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), CROSS, 3.0, true)
		else:
			board.draw_arc(rect.get_center(), rect.size.x * 0.5, 0.0, TAU, 32, RING, 3.0, true)

func _cell_rect(cell: int) -> Rect2:
	return Rect2(Vector2(cell % Rules.SIZE, cell / Rules.SIZE) * CELL_PIXELS, Vector2.ONE * CELL_PIXELS)

func cell_at(point: Vector2) -> int:
	var col := int(point.x / CELL_PIXELS)
	var row := int(point.y / CELL_PIXELS)
	return Rules.cell_of(row, col) if point.x >= 0 and point.y >= 0 and Rules.inside(row, col) else -1

func cell_centre(cell: int) -> Vector2:
	return board.global_position + _cell_rect(cell).get_center()

func _board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		player_plays(cell_at(event.position))

# --- Turns ------------------------------------------------------------------------------------

func player_plays(cell: int) -> void:
	if state != State.PLAYER or not game.is_empty(cell):
		return
	var before: RefCounted = game.clone()
	_place(cell)
	player_moves += 1
	if _ended(cell):
		return
	var read := Bot.analyse_player_move(before, cell)
	if "missed_block" in read.events:
		missed_note = "cậu bỏ lỡ một nước chặn ở nước thứ %d" % player_moves
	events_now = []
	for kind in EVENT_PRIORITY:
		if kind in read.events and player_moves >= cooldown_until.get(kind, 0):
			events_now.append(kind)
			cooldown_until[kind] = player_moves + EVENT_COOLDOWN
	state = State.THINKING
	status.text = "Bảy Rô đang nghĩ..."
	thread = Thread.new()
	thread.start(bot.candidates.bind(game.clone(), losses()))
	advantage_now = read.advantage

func _process(_delta: float) -> void:
	if thread == null or thread.is_alive():
		return
	var picks: Array = thread.wait_to_finish()
	thread = null
	if state != State.THINKING:
		return
	var events := events_now
	# His own strong moves share the event cooldown, so he does not cry out every turn.
	var may_celebrate: bool = player_moves >= cooldown_until.get("baro_strong", 0)
	var only: Dictionary = picks[0]
	# A winning stone goes straight down: the end of the game has its own line.
	if picks.size() == 1 and (only.wins or events.is_empty() and not (only.strong and may_celebrate)):
		_baro_plays(only.cell, "")
		return
	state = State.ASKING_AI
	var tags := picks.map(func(entry): return {"tag": entry.tag, "strong": entry.strong and may_celebrate})
	_ask_ai("turn", events, tags, "", func(reply: Dictionary): _turn_reply(reply, picks, events, may_celebrate))

func _turn_reply(reply: Dictionary, picks: Array, events: Array, may_celebrate: bool) -> void:
	if state != State.ASKING_AI:
		return
	var index: int = reply.get("move_index", 0)
	if index < 0 or index >= picks.size():
		index = 0
	var celebrate: bool = picks[index].strong and may_celebrate
	# Lines only follow facts the engine confirmed, so he never praises or celebrates out of thin air.
	var line := ""
	if celebrate:
		cooldown_until["baro_strong"] = player_moves + EVENT_COOLDOWN
		line = People.with_siu(_line_or(reply, _pick("baro_strong")))
	elif not events.is_empty():
		line = _calm_or(reply, _pick(events[0]))
	_baro_plays(picks[index].cell, line)

func _baro_plays(cell: int, line: String) -> void:
	_place(cell)
	if not line.is_empty():
		says.text = line
	if _ended(cell):
		return
	state = State.PLAYER
	status.text = "Tới lượt cậu."

func _place(cell: int) -> void:
	game.play(cell)
	last_cell = cell
	board.queue_redraw()
	world.street_click()

func _ended(cell: int) -> bool:
	var line: Array = game.winning_line(cell)
	if not line.is_empty():
		win_cells = line
		finish("win" if game.board[cell] > 0 else "lose")
		return true
	if game.full():
		finish("draw")
		return true
	return false

func resign() -> void:
	if state == State.PLAYER:
		finish("lose")

func finish(result: String) -> void:
	state = State.OVER
	board.queue_redraw()
	var gear: Dictionary = story.gear
	match result:
		"win":
			gear.caro_won = true
			status.text = "Cậu thắng!"
			_set_buttons([["Nghe Bảy Rô kể", reveal_next]])
		"lose":
			gear.caro_losses += 1
			gear.caro_last_decisive = missed_note if not missed_note.is_empty() else "tôi nối được năm quân ở %s" % Rules.name_of(last_cell)
			status.text = "Thua rồi."
			_set_buttons([["Chơi lại", new_game], ["Rời bàn", story.close]])
		_:
			status.text = "Hòa, bàn kín rồi."
			_set_buttons([["Chơi lại", new_game], ["Rời bàn", story.close]])
	story.pay(0)
	story.caro_finished()
	if result == "draw":
		says.text = "Kín bàn rồi. Ván nữa nhé?"
		return
	says.text = "…"
	var fallback: String = _pick(result)
	# Result "lose" means Bảy Rô won: that always ends in his cry.
	_ask_ai("end", [], [], result, func(reply: Dictionary):
		says.text = People.with_siu(_line_or(reply, fallback)) if result == "lose" else _calm_or(reply, fallback))

# Story text after a win; written, never generated.
func reveal_next() -> void:
	state = State.REVEAL
	if reveal_line < People.REVEAL.size():
		title.text = People.REVEAL[reveal_line][0]
		says.text = People.REVEAL[reveal_line][1]
		reveal_line += 1
	if reveal_line >= People.REVEAL.size():
		_set_buttons([["Rời bàn", story.close]])
	else:
		_set_buttons([["Tiếp", reveal_next]])

# --- AI bridge --------------------------------------------------------------------------------

func _pick(kind: String) -> String:
	var lines: Array = People.LINES[kind]
	return lines[randi() % lines.size()]

func _line_or(reply: Dictionary, fallback: String) -> String:
	var line: String = reply.get("line", "")
	return line if not line.is_empty() else fallback

# The cry belongs to his wins and strong moves only; a stray one falls back to a written line.
func _calm_or(reply: Dictionary, fallback: String) -> String:
	var line := _line_or(reply, fallback)
	return fallback if line.to_upper().contains("SIU") else line

# Calls back with the bridge reply, or {} on any failure so the caller uses written lines.
func _ask_ai(kind: String, events: Array, tags: Array, result: String, done: Callable) -> void:
	request_serial += 1
	if ai_url.is_empty():
		_ai_failed(done)
		return
	var request := HTTPRequest.new()
	request.timeout = AI_TIMEOUT
	add_child(request)
	var body := JSON.stringify({"request_id": str(request_serial), "kind": kind, "events": events, "advantage": advantage_now,
		"losses": mini(losses(), 99), "last_decisive": String(story.gear.caro_last_decisive).left(120), "candidates": tags, "result": result})
	request.request_completed.connect(_ai_replied.bind(request, done))
	var error := request.request(ai_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("caro: AI request not sent (%s)" % error_string(error))
		request.queue_free()
		_ai_failed(done)

func _ai_replied(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, done: Callable) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_ai_failed(done)
		return
	var reply = JSON.parse_string(body.get_string_from_utf8())
	if not reply is Dictionary or typeof(reply.get("move_index")) != TYPE_FLOAT or not reply.get("line") is String:
		_ai_failed(done)
		return
	source.text = "Bảy Rô · AI"
	reply.move_index = int(reply.move_index)
	done.call(reply)

func _ai_failed(done: Callable) -> void:
	source.text = "Bảy Rô · offline"
	done.call_deferred({})

func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()
