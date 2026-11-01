extends RefCounted
# Full rules of chess. Squares run a1 = 0 to h8 = 63; pieces are signed, white positive.
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0"
const LETTERS := {"p": PAWN, "n": KNIGHT, "b": BISHOP, "r": ROOK, "q": QUEEN, "k": KING}
const KNIGHT_STEPS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const LINES := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
const QUIET_LIMIT := 100
var board := PackedInt32Array()
var turn := 1
var castle := 15
var ep := -1
var quiet := 0
var seen := {}

func _init(fen := START) -> void:
	load_fen(fen)

func load_fen(fen: String) -> void:
	var parts := fen.split(" ")
	board.resize(64)
	board.fill(0)
	var rank := 7
	var file := 0
	for letter in parts[0]:
		if letter == "/":
			rank -= 1
			file = 0
		elif letter.is_valid_int():
			file += int(letter)
		else:
			var kind: int = LETTERS[letter.to_lower()]
			board[rank * 8 + file] = kind if letter == letter.to_upper() else -kind
			file += 1
	turn = 1 if parts[1] == "w" else -1
	castle = 0
	for i in range(4):
		if parts[2].contains("KQkq"[i]):
			castle |= 1 << i
	ep = -1 if parts[3] == "-" else parts[3].unicode_at(0) - 97 + (int(parts[3][1]) - 1) * 8
	quiet = int(parts[4]) if parts.size() > 4 else 0
	seen = {}
	_remember()

func clone() -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy.board = board.duplicate()
	copy.turn = turn
	copy.castle = castle
	copy.ep = ep
	copy.quiet = quiet
	copy.seen = seen
	return copy

static func make_move(from: int, to: int, promote := 0) -> int:
	return from | to << 6 | promote << 12

static func from_of(move: int) -> int:
	return move & 63

static func to_of(move: int) -> int:
	return move >> 6 & 63

static func promo_of(move: int) -> int:
	return move >> 12

func king_square(side: int) -> int:
	return board.find(KING * side)

func attacked(square: int, by: int) -> bool:
	var file := square % 8
	var rank := square / 8
	for step in KNIGHT_STEPS:
		var f: int = file + step[0]
		var r: int = rank + step[1]
		if f >= 0 and f < 8 and r >= 0 and r < 8 and board[r * 8 + f] == KNIGHT * by:
			return true
	for i in range(8):
		var f: int = file + LINES[i][0]
		var r: int = rank + LINES[i][1]
		var distance := 1
		while f >= 0 and f < 8 and r >= 0 and r < 8:
			var piece: int = board[r * 8 + f]
			if piece != 0:
				if piece * by > 0:
					var kind: int = absi(piece)
					if kind == QUEEN or kind == (ROOK if i < 4 else BISHOP) or (kind == KING and distance == 1):
						return true
					if kind == PAWN and distance == 1 and i >= 4 and LINES[i][1] == -by:
						return true
				break
			f += LINES[i][0]
			r += LINES[i][1]
			distance += 1
	return false

func in_check(side: int) -> bool:
	return attacked(king_square(side), -side)

func pseudo_moves() -> PackedInt32Array:
	var moves := PackedInt32Array()
	for square in range(64):
		var piece: int = board[square]
		if piece * turn <= 0:
			continue
		var file := square % 8
		var rank := square / 8
		match absi(piece):
			PAWN:
				_pawn(moves, square, file, rank)
			KNIGHT:
				_steps(moves, square, file, rank, KNIGHT_STEPS)
			KING:
				_steps(moves, square, file, rank, LINES)
				_castling(moves, square)
			BISHOP:
				_slide(moves, square, file, rank, 4, 8)
			ROOK:
				_slide(moves, square, file, rank, 0, 4)
			QUEEN:
				_slide(moves, square, file, rank, 0, 8)
	return moves

func _pawn(moves: PackedInt32Array, square: int, file: int, rank: int) -> void:
	var ahead := square + 8 * turn
	var last := 7 if turn > 0 else 0
	if board[ahead] == 0:
		_advance(moves, square, ahead, rank + turn == last)
		if rank == (1 if turn > 0 else 6) and board[ahead + 8 * turn] == 0:
			moves.append(make_move(square, ahead + 8 * turn))
	for side in [-1, 1]:
		var f: int = file + side
		if f < 0 or f > 7:
			continue
		var target: int = ahead + side
		if board[target] * turn < 0 or target == ep:
			_advance(moves, square, target, rank + turn == last)

func _advance(moves: PackedInt32Array, from: int, to: int, promotes: bool) -> void:
	if promotes:
		for kind in [QUEEN, ROOK, BISHOP, KNIGHT]:
			moves.append(make_move(from, to, kind))
	else:
		moves.append(make_move(from, to))

func _steps(moves: PackedInt32Array, square: int, file: int, rank: int, steps: Array) -> void:
	for step in steps:
		var f: int = file + step[0]
		var r: int = rank + step[1]
		if f >= 0 and f < 8 and r >= 0 and r < 8 and board[r * 8 + f] * turn <= 0:
			moves.append(make_move(square, r * 8 + f))

func _slide(moves: PackedInt32Array, square: int, file: int, rank: int, first: int, last: int) -> void:
	for i in range(first, last):
		var f: int = file + LINES[i][0]
		var r: int = rank + LINES[i][1]
		while f >= 0 and f < 8 and r >= 0 and r < 8:
			var piece: int = board[r * 8 + f]
			if piece * turn > 0:
				break
			moves.append(make_move(square, r * 8 + f))
			if piece != 0:
				break
			f += LINES[i][0]
			r += LINES[i][1]

func _castling(moves: PackedInt32Array, square: int) -> void:
	var home := 4 if turn > 0 else 60
	if square != home or attacked(home, -turn):
		return
	var short_right := 1 if turn > 0 else 4
	var long_right := 2 if turn > 0 else 8
	if castle & short_right and board[home + 1] == 0 and board[home + 2] == 0 and board[home + 3] == ROOK * turn and not attacked(home + 1, -turn):
		moves.append(make_move(home, home + 2))
	if castle & long_right and board[home - 1] == 0 and board[home - 2] == 0 and board[home - 3] == 0 and board[home - 4] == ROOK * turn and not attacked(home - 1, -turn):
		moves.append(make_move(home, home - 2))

func legal_moves() -> PackedInt32Array:
	var legal := PackedInt32Array()
	for move in pseudo_moves():
		var next: RefCounted = clone()
		next.apply(move)
		if not next.in_check(turn):
			legal.append(move)
	return legal

# Moves without history bookkeeping; the search makes many and keeps none.
func apply(move: int) -> void:
	var from := move & 63
	var to := move >> 6 & 63
	var promote := move >> 12
	var piece: int = board[from]
	var kind := absi(piece)
	var taken: int = board[to]
	if kind == PAWN and to == ep:
		board[to - 8 * turn] = 0
		taken = 1
	board[to] = promote * turn if promote != 0 else piece
	board[from] = 0
	if kind == KING and absi(to - from) == 2:
		var rook_from := to + 1 if to > from else to - 2
		board[(from + to) / 2] = board[rook_from]
		board[rook_from] = 0
	ep = (from + to) / 2 if kind == PAWN and absi(to - from) == 16 else -1
	for corner in [[0, 2], [7, 1], [4, 3], [56, 8], [63, 4], [60, 12]]:
		if from == corner[0] or to == corner[0]:
			castle &= ~corner[1]
	quiet = 0 if kind == PAWN or taken != 0 else quiet + 1
	turn = -turn

func play(move: int) -> void:
	seen = seen.duplicate()
	apply(move)
	_remember()

func _remember() -> void:
	var key := _key()
	seen[key] = seen.get(key, 0) + 1

func _key() -> String:
	return "%s|%d|%d|%d" % [",".join(Array(board).map(func(p): return str(p))), turn, castle, ep]

# "" while the game goes on, else mate, stalemate or draw.
func outcome() -> String:
	if legal_moves().is_empty():
		return "mate" if in_check(turn) else "stalemate"
	if quiet >= QUIET_LIMIT or seen.get(_key(), 0) >= 3 or _bare():
		return "draw"
	return ""

func _bare() -> bool:
	var minors := 0
	for piece in board:
		var kind := absi(piece)
		if kind == PAWN or kind == ROOK or kind == QUEEN:
			return false
		if kind == KNIGHT or kind == BISHOP:
			minors += 1
	return minors <= 1

func perft(depth: int) -> int:
	if depth == 0:
		return 1
	var total := 0
	for move in legal_moves():
		var next: RefCounted = clone()
		next.apply(move)
		total += next.perft(depth - 1)
	return total
