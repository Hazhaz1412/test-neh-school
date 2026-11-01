extends RefCounted
# Negamax with alpha-beta. Skill comes from depth, noise on the scores and outright blunders.
const VALUE := [0, 100, 320, 330, 500, 900, 0]
const MATE := 100000
const LEVELS := {
	"kid": {"depth": 1, "noise": 220, "blunder": 0.3, "seconds": 0.4},
	"mid": {"depth": 2, "noise": 45, "blunder": 0.06, "seconds": 1.2},
	"hard": {"depth": 4, "noise": 6, "blunder": 0.0, "seconds": 3.0},
	"whisper": {"depth": 3, "noise": 0, "blunder": 0.0, "seconds": 2.0},
}
var deadline := 0
var out_of_time := false
var rng := RandomNumberGenerator.new()

static func score(game: RefCounted) -> int:
	var total := 0
	for square in range(64):
		var piece: int = game.board[square]
		if piece == 0:
			continue
		var kind := absi(piece)
		var side := signi(piece)
		var file := square % 8
		var rank: int = square / 8 if side > 0 else 7 - square / 8
		var value: int = VALUE[kind]
		var centre: int = 7 - absi(2 * file - 7) + 7 - absi(2 * rank - 7)
		if kind == game.PAWN:
			value += rank * 6 + centre
		elif kind == game.KNIGHT or kind == game.BISHOP:
			value += centre * 3
		elif kind == game.KING:
			value -= centre * 3
		total += value * side
	return total * game.turn

func _ordered(game: RefCounted) -> Array:
	var moves := Array(game.pseudo_moves())
	moves.sort_custom(func(a, b): return absi(game.board[a >> 6 & 63]) > absi(game.board[b >> 6 & 63]))
	return moves

func _search(game: RefCounted, depth: int, alpha: int, beta: int) -> int:
	if depth == 0:
		return score(game)
	if Time.get_ticks_msec() > deadline:
		out_of_time = true
		return 0
	var best := -MATE - depth
	var any := false
	for move in _ordered(game):
		var next: RefCounted = game.clone()
		next.apply(move)
		if next.in_check(game.turn):
			continue
		any = true
		var value := -_search(next, depth - 1, -beta, -alpha)
		if out_of_time:
			return 0
		best = maxi(best, value)
		alpha = maxi(alpha, value)
		if alpha >= beta:
			break
	if not any:
		return -MATE - depth if game.in_check(game.turn) else 0
	return best

func choose(game: RefCounted, level: String) -> int:
	var setting: Dictionary = LEVELS[level]
	var moves := Array(game.legal_moves())
	if moves.is_empty():
		return -1
	if rng.randf() < setting.blunder:
		return moves[rng.randi() % moves.size()]
	deadline = Time.get_ticks_msec() + int(setting.seconds * 1000.0)
	out_of_time = false
	var chosen: int = moves[0]
	for depth in range(1, setting.depth + 1):
		var best := -MATE * 2
		var pick := -1
		for move in moves:
			var next: RefCounted = game.clone()
			next.apply(move)
			var value := -_search(next, depth - 1, -MATE * 2, MATE * 2)
			if out_of_time:
				break
			value += rng.randi_range(-setting.noise, setting.noise)
			if value > best:
				best = value
				pick = move
		if out_of_time:
			break
		chosen = pick
	return chosen
