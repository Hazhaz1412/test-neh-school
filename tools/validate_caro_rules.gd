extends SceneTree
# Caro rules and Bảy Rô's engine: godot --headless --path . --script tools/validate_caro_rules.gd
const Rules := preload("res://scripts/caro/caro_rules.gd")
const Bot := preload("res://scripts/caro/caro_bot.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

# Builds a position from cells of each side; `turn` is who moves next.
func position(player: Array, baro: Array, turn: int) -> RefCounted:
	var game: RefCounted = Rules.new()
	for spot in player:
		game.board[Rules.cell_of(spot[0], spot[1])] = 1
		game.history.append(Rules.cell_of(spot[0], spot[1]))
	for spot in baro:
		game.board[Rules.cell_of(spot[0], spot[1])] = -1
		game.history.append(Rules.cell_of(spot[0], spot[1]))
	game.turn = turn
	return game

func at(row: int, col: int) -> int:
	return Rules.cell_of(row, col)

func rules() -> void:
	for direction in Rules.DIRECTIONS:
		var game: RefCounted = Rules.new()
		var last := -1
		for i in range(5):
			last = at(7 + direction[0] * i, 5 + direction[1] * i)
			game.board[last] = 1
		check(game.winner_at(last) == 1 and game.winning_line(last).size() == 5, "five in direction %s wins" % [direction])
	var four: RefCounted = position([[7, 3], [7, 4], [7, 5], [7, 6]], [], -1)
	check(four.winner_at(at(7, 6)) == 0, "four in a row does not win")
	var played: RefCounted = Rules.new()
	played.play(at(7, 7))
	check(played.turn == -1 and played.history == [at(7, 7)] and not played.is_empty(at(7, 7)), "play places a stone and passes the turn")
	var copy: RefCounted = played.clone()
	copy.play(at(0, 0))
	check(played.is_empty(at(0, 0)), "clone does not share the board")
	check(Rules.name_of(at(7, 7)) == "H8", "cell names read like H8")

func engine() -> void:
	var bot := Bot.new()
	var win: RefCounted = position([[0, 0], [0, 2]], [[7, 3], [7, 4], [7, 5], [7, 6]], -1)
	var picks := bot.candidates(win, 0)
	check(picks.size() == 1 and picks[0].cell in [at(7, 2), at(7, 7)], "takes five when it can")
	check(picks[0].wins and picks[0].strong, "a winning move is marked as winning and strong")
	var block: RefCounted = position([[5, 3], [5, 4], [5, 5], [5, 6]], [[9, 9], [10, 10], [0, 14]], -1)
	picks = bot.candidates(block, 0)
	check(picks.size() == 1 and picks[0].cell in [at(5, 2), at(5, 7)], "always blocks a four")
	check(not picks[0].wins and not picks[0].strong, "a plain block is neither winning nor strong")
	picks = bot.candidates(block, 9)
	check(picks.size() == 1 and picks[0].cell in [at(5, 2), at(5, 7)], "still blocks a four after many losses")
	var open_three: RefCounted = position([[6, 5], [6, 6], [6, 7]], [[8, 8], [9, 9]], -1)
	picks = bot.candidates(open_three, 0)
	check(not picks.is_empty() and picks[0].cell in [at(6, 4), at(6, 8), at(6, 3), at(6, 9)], "blocks an open three at full strength")
	check(picks.size() == Bot.CANDIDATE_COUNT, "offers %d candidates when nothing is forced" % Bot.CANDIDATE_COUNT)
	var empty_picks := bot.candidates(Rules.new(), 0)
	check(empty_picks.size() == 1 and empty_picks[0].cell == at(7, 7), "opens in the centre")
	check(Bot.depth_for(0) == 3 and Bot.depth_for(5) == 1, "depth falls with losses, never below 1")
	check(Bot.shuffle_chance(0) == 0.0 and Bot.shuffle_chance(10) == Bot.SHUFFLE_CAP, "shuffle chance grows and is capped")
	var started := Time.get_ticks_msec()
	var busy: RefCounted = position([[7, 7], [8, 8], [6, 8], [9, 6], [7, 9]], [[7, 8], [8, 7], [6, 6], [9, 9], [5, 7]], -1)
	bot.candidates(busy, 0)
	var spent := Time.get_ticks_msec() - started
	print("full strength answer in ", spent, " ms")
	check(spent < 3000, "answers within its time budget")

func events() -> void:
	# Player makes an open three out of an open two.
	var making: RefCounted = position([[7, 6], [7, 7]], [[3, 3], [3, 4]], 1)
	var read := Bot.analyse_player_move(making, at(7, 8))
	check("threat_created" in read.events, "an open three is a created threat")
	check("good_move" in read.events, "the best attacking move counts as good")
	# Bảy Rô has an open three; the player blocks it.
	var defend: RefCounted = position([[0, 0], [14, 14]], [[7, 5], [7, 6], [7, 7]], 1)
	read = Bot.analyse_player_move(defend, at(7, 8))
	check("good_move" in read.events and not "missed_block" in read.events, "blocking an open three is good, not missed")
	read = Bot.analyse_player_move(defend, at(0, 1))
	check("missed_block" in read.events and not "good_move" in read.events, "ignoring an open three is a missed block")
	var quiet: RefCounted = position([[7, 7]], [[7, 8]], 1)
	read = Bot.analyse_player_move(quiet, at(0, 14))
	check(read.events.is_empty(), "a quiet move raises no event")
	var builder: RefCounted = position([[0, 0], [14, 14]], [[7, 6], [7, 7]], -1)
	check(Bot.is_strong(builder, at(7, 8), -1) and not Bot.is_strong(builder, at(0, 7), -1), "an open three is strong, a stray stone is not")
	var winning: RefCounted = position([[7, 4], [7, 5], [7, 6], [6, 6], [5, 6]], [[0, 0]], 1)
	check(Bot.analyse_player_move(winning, at(7, 7)).advantage == "player", "advantage leans to the player who is ahead")

func _initialize() -> void:
	rules()
	engine()
	events()
	print("failures ", failures)
	quit(failures)
