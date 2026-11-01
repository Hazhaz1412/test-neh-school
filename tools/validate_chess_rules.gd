extends SceneTree
# Perft against published counts, plus the bots: godot --headless --path . --script tools/validate_chess_rules.gd
const Rules := preload("res://scripts/chess/chess_rules.gd")
const Bot := preload("res://scripts/chess/chess_bot.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func perft(fen: String, depth: int, want: int) -> void:
	var got: int = Rules.new(fen).perft(depth)
	check(got == want, "perft %d = %d (want %d) %s" % [depth, got, want, fen.left(24)])

func square(text: String) -> int:
	return text.unicode_at(0) - 97 + (int(text[1]) - 1) * 8

func match_up(white: String, black: String, games: int) -> int:
	var bot := Bot.new()
	var wins := 0
	for g in range(games):
		var game: RefCounted = Rules.new()
		for ply in range(160):
			if not game.outcome().is_empty():
				break
			game.play(bot.choose(game, white if game.turn > 0 else black))
		if game.outcome() == "mate" and game.turn < 0:
			wins += 1
	return wins

func _initialize() -> void:
	perft(Rules.START, 3, 8902)
	perft("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0", 2, 2039)
	perft("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0", 3, 2812)
	perft("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0", 2, 264)
	perft("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1", 2, 1486)
	var mate: RefCounted = Rules.new("7k/5Q2/6K1/8/8/8/8/8 b - - 0")
	check(mate.outcome() == "stalemate", "stalemate is seen")
	mate = Rules.new("7k/6Q1/6K1/8/8/8/8/8 b - - 0")
	check(mate.outcome() == "mate", "mate is seen")
	var repeat: RefCounted = Rules.new()
	for i in range(2):
		for pair in [["g1", "f3"], ["g8", "f6"], ["f3", "g1"], ["f6", "g8"]]:
			repeat.play(Rules.make_move(square(pair[0]), square(pair[1])))
	check(repeat.outcome() == "draw", "threefold repetition is a draw")
	check(Rules.new("8/8/8/8/8/8/8/K1k5 w - - 0").outcome() == "draw", "bare kings draw")
	var hanging: RefCounted = Rules.new("rnb1kbnr/pppp1ppp/8/4p3/4P1q1/5P2/PPPP2PP/RNBQKBNR w KQkq - 0")
	var taken := Bot.new().choose(hanging, "whisper")
	check(Rules.to_of(taken) == square("g4"), "the search takes a hanging queen")
	var started := Time.get_ticks_msec()
	var strong := Bot.new().choose(Rules.new(), "hard")
	print("hard opening move in ", Time.get_ticks_msec() - started, " ms ", strong)
	check(Time.get_ticks_msec() - started < 4000, "the hard bot answers within its budget")
	var games := 4
	print("mid beats kid ", match_up("mid", "kid", games), "/", games)
	print("hard beats mid ", match_up("hard", "mid", 2), "/2")
	print("failures ", failures)
	quit(failures)
