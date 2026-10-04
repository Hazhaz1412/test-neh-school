extends RefCounted

# State and validation are shared by the UI and world rewards. No UI button can
# grant a reward without satisfying the electrical/graph/flow/board constraints.
var circuits: Array[int] = [0, 0, 0, 0, 0, 0]
const LOADS := [4, 3, 2, 1, 3, 2]
var route: Array[int] = [10]
const WALLS := [7, 12, 17]
const COSTS := [1, 1, 3, 1, 1, 1, 3, 0, 2, 1, 1, 5, 0, 4, 1, 1, 2, 0, 2, 1, 1, 1, 1, 1, 1]
var pipes: Array[int] = [5, 3, 12, 5, 5, 6, 3, 3, 10, 12, 10, 5, 6, 3, 6, 5]
var board: Array[int] = []
var chess_result := 0
var nodes_searched := 0
var pruned_branches := 0
var trace: Array[int] = []

func _init() -> void:
	board.resize(25)
	board.fill(0)

func electrical_loads() -> Array[int]:
	var sums: Array[int] = [0, 0]
	for i in range(6):
		if circuits[i] > 0:
			sums[circuits[i] - 1] += LOADS[i]
	return sums

func electrical_valid() -> bool:
	var sums := electrical_loads()
	return circuits[0] > 0 and circuits[1] > 0 and circuits[2] > 0 and circuits[3] > 0 and sums[0] <= 5 and sums[1] <= 5

func neighbors(cell: int, width := 5) -> Array[int]:
	var result: Array[int] = []
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var at: Vector2i = Vector2i(cell % width, cell / width) + d
		if at.x >= 0 and at.y >= 0 and at.x < width and at.y < width:
			result.append(at.y * width + at.x)
	return result

func shortest_cost() -> int:
	# Dijkstra: frontier is tiny (25 nodes); linear minimum avoids heap overhead.
	var distances := {10: 0}
	var frontier: Array[int] = [10]
	trace.clear()
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return distances[a] < distances[b])
		var current: int = frontier.pop_front()
		trace.append(current)
		if current == 14:
			return distances[current]
		for other in neighbors(current):
			if WALLS.has(other):
				continue
			var cost: int = distances[current] + COSTS[other]
			if cost < int(distances.get(other, 999)):
				distances[other] = cost
				if not frontier.has(other):
					frontier.append(other)
	return 999

func route_cost() -> int:
	var cost := 0
	for i in range(1, route.size()):
		cost += COSTS[route[i]]
	return cost

func route_click(cell: int) -> void:
	if route.has(cell):
		route.resize(route.find(cell) + 1)
	elif not WALLS.has(cell) and neighbors(route[-1]).has(cell):
		route.append(cell)

func route_valid() -> bool:
	if route.is_empty() or route[0] != 10 or route[-1] != 14:
		return false
	for i in range(1, route.size()):
		if WALLS.has(route[i]) or not neighbors(route[i - 1]).has(route[i]):
			return false
	return route_cost() == shortest_cost()

func rotate_pipe(cell: int) -> void:
	pipes[cell] = ((pipes[cell] << 1) & 15) | (pipes[cell] >> 3)

func water_flow() -> Dictionary:
	var wet: Array[int] = []
	var queue: Array[int] = [0]
	var leaks := 0
	if pipes[0] & 8 == 0:
		return {"wet": wet, "leaks": 1, "reached": false}
	while not queue.is_empty():
		var cell: int = queue.pop_front()
		if wet.has(cell):
			continue
		wet.append(cell)
		for direction in range(4):
			var bit := 1 << direction
			if pipes[cell] & bit == 0:
				continue
			if cell == 0 and direction == 3 or cell == 15 and direction == 1:
				continue
			var offset: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][direction]
			var pos := Vector2i(cell % 4, cell / 4) + offset
			if pos.x < 0 or pos.x >= 4 or pos.y < 0 or pos.y >= 4:
				leaks += 1
				continue
			var other := pos.y * 4 + pos.x
			if pipes[other] & (1 << ((direction + 2) % 4)) == 0:
				leaks += 1
			elif not wet.has(other):
				queue.append(other)
	return {"wet": wet, "leaks": leaks, "reached": wet.has(15) and pipes[15] & 2 != 0}

func pipes_valid() -> bool:
	var flow := water_flow()
	return flow.reached and flow.leaks == 0

func winner() -> int:
	for cell in range(25):
		if board[cell] == 0:
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var end: Vector2i = Vector2i(cell % 5, cell / 5) + d * 3
			if end.x < 0 or end.y < 0 or end.x >= 5 or end.y >= 5:
				continue
			var match_line := true
			for step in range(1, 4):
				if board[cell + step * (d.x + d.y * 5)] != board[cell]:
					match_line = false
			if match_line:
				return board[cell]
	return 3 if not board.has(0) else 0

func board_score() -> int:
	var win := winner()
	if win == 1:
		return 100000
	if win == 2:
		return -100000
	var score := 0
	for cell in range(25):
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var end: Vector2i = Vector2i(cell % 5, cell / 5) + d * 3
			if end.x < 0 or end.y < 0 or end.x >= 5 or end.y >= 5:
				continue
			var own := 0
			var foe := 0
			for step in range(4):
				var mark: int = board[cell + step * (d.x + d.y * 5)]
				own += int(mark == 1)
				foe += int(mark == 2)
			if foe == 0:
				score += [0, 2, 12, 100, 10000][own]
			if own == 0:
				score -= [0, 2, 12, 100, 10000][foe]
	return score

func minimax(depth: int, turn: int, alpha: int, beta: int) -> int:
	nodes_searched += 1
	if depth == 0 or winner() != 0:
		return board_score()
	var value := -1000000 if turn == 1 else 1000000
	for cell in range(25):
		if board[cell] != 0:
			continue
		board[cell] = turn
		var score := minimax(depth - 1, 3 - turn, alpha, beta)
		board[cell] = 0
		if turn == 1:
			value = maxi(value, score)
			alpha = maxi(alpha, value)
		else:
			value = mini(value, score)
			beta = mini(beta, value)
		if beta <= alpha:
			pruned_branches += 1
			break
	return value

func best_move(turn: int) -> int:
	nodes_searched = 0
	pruned_branches = 0
	var best := -1
	var value := -1000001 if turn == 1 else 1000001
	# Center-first ordering improves pruning and produces natural opening moves.
	var order := range(25)
	order.sort_custom(func(a, b): return Vector2(a % 5 - 2, a / 5 - 2).length_squared() < Vector2(b % 5 - 2, b / 5 - 2).length_squared())
	for cell in order:
		if board[cell] != 0:
			continue
		board[cell] = turn
		var score := minimax(1, 3 - turn, value if turn == 1 else -1000000, value if turn == 2 else 1000000)
		board[cell] = 0
		if turn == 1 and score > value or turn == 2 and score < value:
			value = score
			best = cell
	return best

func chess_click(cell: int) -> void:
	if chess_result != 0 or board[cell] != 0:
		return
	board[cell] = 1
	chess_result = winner()
	if chess_result == 0:
		var move := best_move(2)
		if move >= 0:
			board[move] = 2
		chess_result = winner()
