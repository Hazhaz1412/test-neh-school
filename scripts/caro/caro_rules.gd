extends RefCounted
# Free-style gomoku on 15x15: five or more in a row wins. Cell = row * SIZE + col.
# Stones are signed: the player is 1 (X), Bảy Rô is -1 (O).
const SIZE := 15
const CELLS := SIZE * SIZE
const WIN := 5
const DIRECTIONS := [[0, 1], [1, 0], [1, 1], [1, -1]]
var board := PackedInt32Array()
var turn := 1
var history: Array = []

func _init() -> void:
	board.resize(CELLS)
	board.fill(0)

static func cell_of(row: int, col: int) -> int:
	return row * SIZE + col

static func inside(row: int, col: int) -> bool:
	return row >= 0 and row < SIZE and col >= 0 and col < SIZE

# "H8" style name, columns A..O left to right, rows 1..15 top to bottom.
static func name_of(cell: int) -> String:
	return "%s%d" % [char(65 + cell % SIZE), cell / SIZE + 1]

func is_empty(cell: int) -> bool:
	return cell >= 0 and cell < CELLS and board[cell] == 0

func play(cell: int) -> void:
	assert(is_empty(cell), "caro: cell %d is not free" % cell)
	board[cell] = turn
	history.append(cell)
	turn = -turn

func full() -> bool:
	return history.size() >= CELLS

func clone() -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy.board = board.duplicate()
	copy.turn = turn
	copy.history = history.duplicate()
	return copy

# Stones of the same side through `cell` along one direction, including itself.
func run_through(cell: int, direction: Array) -> Array:
	var side: int = board[cell]
	var row := cell / SIZE
	var col := cell % SIZE
	var line := [cell]
	for way in [1, -1]:
		var r: int = row + direction[0] * way
		var c: int = col + direction[1] * way
		while inside(r, c) and board[cell_of(r, c)] == side:
			line.append(cell_of(r, c))
			r += direction[0] * way
			c += direction[1] * way
	return line

func winning_line(cell: int) -> Array:
	if cell < 0 or board[cell] == 0:
		return []
	for direction in DIRECTIONS:
		var line := run_through(cell, direction)
		if line.size() >= WIN:
			return line
	return []

func winner_at(cell: int) -> int:
	return board[cell] if not winning_line(cell).is_empty() else 0
