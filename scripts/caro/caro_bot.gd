extends RefCounted
# Bảy Rô's engine. It owns every judgement that can be right or wrong: which moves are worth
# playing, which are forced, what the player's last move really did, and how much to go easy.
# The LLM only picks among the candidates this file returns, so it can never play an illegal
# or careless move, and it only praises moves the engine has confirmed.
const Rules := preload("res://scripts/caro/caro_rules.gd")
enum Shape {NONE, TWO, OPEN_TWO, THREE, OPEN_THREE, FOUR, OPEN_FOUR, FIVE}
const SHAPE_VALUE := [0, 20, 120, 400, 4000, 9000, 120000, 1000000]
const PATTERNS := [
	[Shape.FIVE, ["xxxxx"]],
	[Shape.OPEN_FOUR, ["_xxxx_"]],
	[Shape.FOUR, ["xxxx_", "_xxxx", "xxx_x", "x_xxx", "xx_xx"]],
	[Shape.OPEN_THREE, ["_xxx__", "__xxx_", "_xx_x_", "_x_xx_"]],
	[Shape.THREE, ["xxx__", "__xxx", "_xxx_", "xx_x_", "_x_xx", "x_xx_", "_xx_x", "x__xx", "xx__x", "x_x_x"]],
	[Shape.OPEN_TWO, ["_xx__", "__xx_", "_x_x_"]],
	[Shape.TWO, ["xx___", "___xx", "x_x__", "__x_x"]],
]
const WIN_SCORE := 10000000
const SEARCH_WIDTH := 8
const CANDIDATE_COUNT := 3
const SECONDS := 1.5
# Adaptive difficulty: each lost game makes Bảy Rô search shallower, defend a little less and
# more often put his 2nd/3rd best move first. Forced blocks are never given away.
const BASE_DEPTH := 3
const SHUFFLE_PER_LOSS := 0.15
const SHUFFLE_CAP := 0.6
const DEFENCE_BASE := 0.9
const DEFENCE_PER_LOSS := 0.1
const DEFENCE_FLOOR := 0.5
const GOOD_MOVE_SHARE := 0.9
const ADVANTAGE_MARGIN := 3000
var rng := RandomNumberGenerator.new()
var deadline := 0
var out_of_time := false

# --- Shapes -----------------------------------------------------------------------------------

# Nine cells through `cell` in one direction as if `side` stood on it: x own, _ empty, o blocked.
static func _line_text(game: RefCounted, cell: int, side: int, direction: Array) -> String:
	var row := cell / Rules.SIZE
	var col := cell % Rules.SIZE
	var text := ""
	for step in range(-4, 5):
		var r: int = row + direction[0] * step
		var c: int = col + direction[1] * step
		if step == 0:
			text += "x"
		elif not Rules.inside(r, c):
			text += "o"
		else:
			var stone: int = game.board[Rules.cell_of(r, c)]
			text += "x" if stone == side else ("_" if stone == 0 else "o")
	return text

# Only shapes that pass through the centre (index 4) belong to this cell.
static func _shape_of(text: String) -> int:
	for entry in PATTERNS:
		for pattern in entry[1]:
			var length: int = pattern.length()
			for start in range(maxi(0, 5 - length), mini(4, 9 - length) + 1):
				if text.substr(start, length) == pattern:
					return entry[0]
	return Shape.NONE

static func shapes_at(game: RefCounted, cell: int, side: int) -> Array:
	var found := []
	for direction in Rules.DIRECTIONS:
		found.append(_shape_of(_line_text(game, cell, side, direction)))
	return found

static func best_shape(shapes: Array) -> int:
	return shapes.max()

static func shape_score(shapes: Array) -> int:
	var total := 0
	var fours := 0
	var open_threes := 0
	for shape in shapes:
		total += SHAPE_VALUE[shape]
		if shape == Shape.FOUR or shape == Shape.OPEN_FOUR:
			fours += 1
		elif shape == Shape.OPEN_THREE:
			open_threes += 1
	# Double threats cannot both be answered, so they are worth almost an open four.
	if fours >= 2 or (fours >= 1 and open_threes >= 1):
		total += SHAPE_VALUE[Shape.OPEN_FOUR]
	elif open_threes >= 2:
		total += SHAPE_VALUE[Shape.FOUR] * 2
	return total

# --- Move generation --------------------------------------------------------------------------

static func nearby_cells(game: RefCounted) -> Array:
	if game.history.is_empty():
		return [Rules.cell_of(Rules.SIZE / 2, Rules.SIZE / 2)]
	var seen := {}
	for stone in game.history:
		var row: int = stone / Rules.SIZE
		var col: int = stone % Rules.SIZE
		for dr in range(-2, 3):
			for dc in range(-2, 3):
				var r := row + dr
				var c := col + dc
				if Rules.inside(r, c) and game.board[Rules.cell_of(r, c)] == 0:
					seen[Rules.cell_of(r, c)] = true
	return seen.keys()

static func move_value(game: RefCounted, cell: int, side: int, defence: float) -> int:
	return shape_score(shapes_at(game, cell, side)) + int(shape_score(shapes_at(game, cell, -side)) * defence)

# Cells where `side` would make five right now.
static func winning_cells(game: RefCounted, side: int) -> Array:
	var cells := []
	for cell in nearby_cells(game):
		if best_shape(shapes_at(game, cell, side)) == Shape.FIVE:
			cells.append(cell)
	return cells

# Cells where `side` would make five or an open four: the threats the other side must answer.
static func threat_cells(game: RefCounted, side: int) -> Array:
	var cells := []
	for cell in nearby_cells(game):
		if best_shape(shapes_at(game, cell, side)) >= Shape.OPEN_FOUR:
			cells.append(cell)
	return cells

static func _ranked(game: RefCounted, side: int, defence: float, width: int) -> Array:
	var scored := []
	for cell in nearby_cells(game):
		scored.append([move_value(game, cell, side, defence), cell])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored.slice(0, width)

# --- Search -----------------------------------------------------------------------------------

# Whole-board view for the side to move: sum of every run's shape, own minus opponent.
static func evaluate(game: RefCounted) -> int:
	var total := 0
	for cell in game.history:
		var side: int = game.board[cell]
		var row: int = cell / Rules.SIZE
		var col: int = cell % Rules.SIZE
		for direction in Rules.DIRECTIONS:
			var pr: int = row - direction[0]
			var pc: int = col - direction[1]
			if Rules.inside(pr, pc) and game.board[Rules.cell_of(pr, pc)] == side:
				continue
			var length := 0
			var r := row
			var c := col
			while Rules.inside(r, c) and game.board[Rules.cell_of(r, c)] == side:
				length += 1
				r += direction[0]
				c += direction[1]
			var open := 0
			if Rules.inside(pr, pc) and game.board[Rules.cell_of(pr, pc)] == 0:
				open += 1
			if Rules.inside(r, c) and game.board[Rules.cell_of(r, c)] == 0:
				open += 1
			if open == 0 and length < Rules.WIN:
				continue
			var value: int = [0, 10, 100, 1000, 10000, WIN_SCORE][mini(length, 5)] * (2 if open == 2 else 1)
			total += value * side
	return total * game.turn

func _search(game: RefCounted, depth: int, alpha: int, beta: int, defence: float) -> int:
	if depth == 0:
		return evaluate(game)
	if Time.get_ticks_msec() > deadline:
		out_of_time = true
		return 0
	var moves := _ranked(game, game.turn, defence, SEARCH_WIDTH)
	if moves.is_empty():
		return 0
	var best := -WIN_SCORE * 2
	for entry in moves:
		var next: RefCounted = game.clone()
		next.play(entry[1])
		var value: int
		if not next.winning_line(entry[1]).is_empty():
			value = WIN_SCORE + depth
		else:
			value = -_search(next, depth - 1, -beta, -alpha, defence)
		if out_of_time:
			return 0
		best = maxi(best, value)
		alpha = maxi(alpha, value)
		if alpha >= beta:
			break
	return best

static func depth_for(losses: int) -> int:
	return maxi(1, BASE_DEPTH - losses)

static func shuffle_chance(losses: int) -> float:
	return minf(SHUFFLE_PER_LOSS * losses, SHUFFLE_CAP)

static func defence_for(losses: int) -> float:
	return maxf(DEFENCE_FLOOR, DEFENCE_BASE - DEFENCE_PER_LOSS * losses)

static func tag_for(game: RefCounted, cell: int, side: int) -> String:
	var own := best_shape(shapes_at(game, cell, side))
	var theirs := best_shape(shapes_at(game, cell, -side))
	if own == Shape.FIVE:
		return "thắng ngay"
	if theirs == Shape.FIVE:
		return "chặn 4 bắt buộc"
	if own == Shape.OPEN_FOUR:
		return "tạo 4 mở"
	if theirs == Shape.OPEN_FOUR:
		return "chặn 3 mở"
	if own == Shape.FOUR:
		return "tạo 4"
	if own == Shape.OPEN_THREE:
		return "tạo 3 mở"
	if theirs >= Shape.THREE:
		return "chặn đường"
	if own >= Shape.OPEN_TWO:
		return "phát triển thế"
	return "giữ thế"

# A move that builds an open three or better: what Bảy Rô is allowed to celebrate.
static func is_strong(game: RefCounted, cell: int, side: int) -> bool:
	return best_shape(shapes_at(game, cell, side)) >= Shape.OPEN_THREE

static func _entry(game: RefCounted, cell: int, side: int, value: int, wins: bool) -> Dictionary:
	return {"cell": cell, "score": value, "tag": tag_for(game, cell, side), "strong": is_strong(game, cell, side), "wins": wins}

# Moves for the side to move, best first, as [{cell, score, tag, strong, wins}]. A single entry
# means the move is forced (win now, or block a five) and must be played whoever chooses.
func candidates(game: RefCounted, losses: int) -> Array:
	var side: int = game.turn
	for cell in winning_cells(game, side):
		return [_entry(game, cell, side, WIN_SCORE, true)]
	var blocks := winning_cells(game, -side)
	if not blocks.is_empty():
		return [_entry(game, blocks[0], side, 0, false)]
	var defence := defence_for(losses)
	var moves := _ranked(game, side, defence, SEARCH_WIDTH)
	deadline = Time.get_ticks_msec() + int(SECONDS * 1000.0)
	out_of_time = false
	var scored := []
	for depth in range(1, depth_for(losses) + 1):
		var layer := []
		for entry in moves:
			var next: RefCounted = game.clone()
			next.play(entry[1])
			var value: int = WIN_SCORE if not next.winning_line(entry[1]).is_empty() else -_search(next, depth - 1, -WIN_SCORE * 2, WIN_SCORE * 2, defence)
			if out_of_time:
				break
			layer.append([value, entry[1]])
		if out_of_time:
			break
		layer.sort_custom(func(a, b): return a[0] > b[0])
		scored = layer
	if scored.is_empty():
		scored = moves
	var top := scored.slice(0, CANDIDATE_COUNT)
	if top.size() > 1 and rng.randf() < shuffle_chance(losses):
		var pick := rng.randi_range(1, top.size() - 1)
		var chosen = top[pick]
		top.remove_at(pick)
		top.push_front(chosen)
	var out := []
	for entry in top:
		out.append(_entry(game, entry[1], side, entry[0], false))
	return out

# --- Reading the player's move ------------------------------------------------------------------

# `before` is the position the player moved from; returns facts the LLM may comment on.
static func analyse_player_move(before: RefCounted, cell: int) -> Dictionary:
	var side: int = before.turn
	var made := best_shape(shapes_at(before, cell, side))
	var blocked := best_shape(shapes_at(before, cell, -side))
	var best := 0
	for entry in _ranked(before, side, DEFENCE_BASE, 1):
		best = entry[0]
	var mine := move_value(before, cell, side, DEFENCE_BASE)
	var events := []
	var threat := made >= Shape.OPEN_THREE
	var defended := blocked >= Shape.OPEN_THREE
	if threat:
		events.append("threat_created")
	if (threat or defended) and mine >= best * GOOD_MOVE_SHARE:
		events.append("good_move")
	var after: RefCounted = before.clone()
	after.play(cell)
	if not threat_cells(before, -side).is_empty() and not threat_cells(after, -side).is_empty() and made < Shape.FOUR:
		events.append("missed_block")
	# `after` has the opponent to move, so its view is flipped back to the player's.
	var view := -evaluate(after)
	var advantage := "even"
	if view > ADVANTAGE_MARGIN:
		advantage = "player"
	elif view < -ADVANTAGE_MARGIN:
		advantage = "baro"
	return {"events": events, "advantage": advantage}
