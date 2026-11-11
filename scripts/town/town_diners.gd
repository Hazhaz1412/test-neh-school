extends Node
# People at the street's plastic tables: a bowl of noodles inside the food stalls, an iced tea on
# the pavement, now and then two old men over a game of chess. Seats come from the builder's list
# of table sets; the arms are posed by seat_pose.gd on top of Rocketbox's seated clip.
const Person := preload("res://scripts/town/town_person.gd")
const SeatPose := preload("res://scripts/town/seat_pose.gd")
const ChessTable := preload("res://scripts/chess/chess_table.gd")
const ChessRules := preload("res://scripts/chess/chess_rules.gd")
# Townsfolk the story does not already give a name and a place to.
const LOOKS := ["Female_Adult_05", "Female_Adult_11", "Male_Adult_02", "Male_Adult_06", "Female_Adult_05", "Male_Adult_06", "Male_Child_01", "Female_Child_01"]
const PLAYERS := ["Male_Adult_02", "Male_Adult_06"]
const MAX_TABLES := 26
const MAX_CHESS := 4
const AWAKE_RANGE := 45.0
# The seated clip has the hip joint about this far above the seat.
const HIP_OVER_SEAT := 0.1
# How far forward of the chair's centre the hips sit, onto the front of the seat.
const PERCH := 0.06
var world: Node3D
var builder: RefCounted
var rng := RandomNumberGenerator.new()
var tables: Array = []
var diners: Array = []
var games: Array = []
var bowl_mesh: Mesh
var glass_mesh: Mesh
var stick_mesh: Mesh

func setup(town: Node3D) -> void:
	world = town
	builder = town.builder
	rng.seed = 5150
	_make_props()
	var candidates: Array = builder.tables.duplicate()
	# Shuffled by hand so the choice follows this seed rather than the global one.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped: Dictionary = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swapped
	# Half the tables taken are in food stalls, half out on the pavement, where the chess is.
	var inside := candidates.filter(func(table): return table.inside)
	var outside := candidates.filter(func(table): return not table.inside)
	for table in inside.slice(0, MAX_TABLES / 2) + outside.slice(0, MAX_TABLES - MAX_TABLES / 2):
		_fill(table)

func _make_props() -> void:
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.075
	bowl.bottom_radius = 0.04
	bowl.height = 0.065
	bowl.material = _paint(Color(0.94, 0.94, 0.90), 0.3)
	bowl_mesh = bowl
	var glass := CylinderMesh.new()
	glass.top_radius = 0.035
	glass.bottom_radius = 0.03
	glass.height = 0.11
	# Iced tea: amber through clear glass.
	var tea := _paint(Color(0.80, 0.52, 0.18, 0.75), 0.1)
	tea.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material = tea
	glass_mesh = glass
	var stick := BoxMesh.new()
	stick.size = Vector3(0.007, 0.007, 0.23)
	stick.material = _paint(Color(0.55, 0.38, 0.20), 0.7)
	stick_mesh = stick

func _paint(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material

func _prop(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
	return node

# Seats the people of one table: eaters inside a food stall, tea drinkers or chess outside.
func _fill(table: Dictionary) -> void:
	if not table.inside and games.size() < MAX_CHESS and rng.randf() < 0.4:
		_chess(table)
		return
	var seats := [0, 1, 2, 3]
	for n in range(rng.randi_range(1, 3)):
		var seat: int = seats.pop_at(rng.randi() % seats.size())
		var kind := "eat" if table.inside and rng.randf() < 0.75 else ("drink" if rng.randf() < 0.85 else "sit")
		_add_diner(table, seat, kind, LOOKS[rng.randi() % LOOKS.size()])

func _seat(table: Dictionary, seat: int, look: String) -> Node3D:
	var out: Vector2 = table.along.rotated(seat * PI * 0.5)
	var body: Node3D = Person.new()
	body.look = look
	body.motion = "sit"
	if look.contains("Child"):
		body.height = 1.3
	world.add_child(body)
	# A townsperson looks along +Z; the chair is turned the same way, towards the table.
	var facing := Basis(Vector3.UP, atan2(-out.x, -out.y))
	var origin: Vector3 = table.frame.origin
	body.global_transform = Transform3D(facing, origin + Vector3(out.x, 0, out.y) * (builder.CHAIR_OFFSET - PERCH))
	# Lifts the clip's hips onto this chair's seat, whatever seat height the clip was made for.
	body.animation.advance(0.0)
	var skeleton: Skeleton3D = body.skeleton
	var pelvis := skeleton.find_bone(String(skeleton.get_bone_name(0)) + " Pelvis")
	var hips: Vector3 = body.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(pelvis).origin)
	body.visual.position += Vector3(-hips.x, builder.SEAT_HEIGHT + HIP_OVER_SEAT - hips.y, -hips.z)
	return body

func _add_diner(table: Dictionary, seat: int, kind: String, look: String) -> Dictionary:
	var body := _seat(table, seat, look)
	var pose: SkeletonModifier3D = SeatPose.new()
	pose.attach(body)
	var diner := {"body": body, "pose": pose, "kind": kind, "clock": rng.randf() * 4.0, "length": rng.randf_range(3.5, 6.0), "props": [], "rest_left": rng.randf() < 0.5}
	# The spread of the table in this person's space: its near edge and its top.
	diner.top = builder.TABLE_TOP
	diner.edge = builder.CHAIR_OFFSET - PERCH - builder.TABLE_SIZE * 0.5
	match kind:
		"eat":
			diner.props = [_prop(bowl_mesh), _prop(stick_mesh), _prop(stick_mesh)]
		"drink":
			diner.length = rng.randf_range(5.0, 9.0)
			diner.props = [_prop(glass_mesh)]
	diners.append(diner)
	return diner

# Two players face each other over a real game, played out by the rules one move at a time.
func _chess(table: Dictionary) -> void:
	var board: Node3D = ChessTable.new()
	world.add_child(board)
	var frame: Transform3D = table.frame
	board.global_transform = Transform3D(frame.basis, frame.origin + Vector3.UP * builder.TABLE_TOP)
	var rules: RefCounted = ChessRules.new()
	board.lay(rules.board)
	var game := {"board": board, "rules": rules, "players": [], "stage": "think", "clock": 0.0, "wait": rng.randf_range(2.0, 6.0), "move": 0, "plies": 0}
	for seat in [1, 3]:
		var player := _add_diner(table, seat, "chess", PLAYERS[0 if seat == 1 else 1])
		player.game = game
		game.players.append(player)
	# White moves first: whoever sits nearer the white king plays white.
	var king: Vector3 = board.to_global(board.spot(rules.king_square(1)))
	if game.players[1].body.global_position.distance_to(king) < game.players[0].body.global_position.distance_to(king):
		game.players.reverse()
	if rng.randf() < 0.5:
		_add_diner(table, 0 if rng.randf() < 0.5 else 2, "drink", LOOKS[rng.randi() % 6])
	games.append(game)

func _process(delta: float) -> void:
	if world.player == null:
		return
	var here: Vector3 = world.player.global_position
	for diner in diners:
		var body: Node3D = diner.body
		var near: bool = body.global_position.distance_squared_to(here) < AWAKE_RANGE * AWAKE_RANGE
		if body.visible != near:
			body.visible = near
			body.set_running(near)
			diner.pose.active = near
			for prop in diner.props:
				prop.visible = near
		if not near:
			continue
		diner.clock += delta
		match diner.kind:
			"eat":
				_eat(diner)
			"drink":
				_drink(diner)
	for game in games:
		if game.board.visible != game.players[0].body.visible:
			game.board.visible = game.players[0].body.visible
		if game.board.visible:
			_play(game, delta)

# 0 most of the cycle, rising to 1 near its end, holding, then falling back as the cycle restarts.
func _lift(t: float, length: float, rise: float, hold: float) -> float:
	var start := length - rise * 2.0 - hold
	if t < start:
		return 0.0
	var k := t - start
	if k < rise:
		return smoothstep(0.0, rise, k)
	if k < rise + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, rise, k - rise - hold)

func _to_world(diner: Dictionary, local: Vector3) -> Vector3:
	return diner.body.to_global(local)

# Chopsticks in the right hand, stirring the bowl and lifting a mouthful; the left hand holds
# the bowl and raises it to the chin for each bite.
func _eat(diner: Dictionary) -> void:
	var t: float = fmod(diner.clock, diner.length)
	var w := _lift(t, diner.length, 0.45, 0.5)
	var pose: SkeletonModifier3D = diner.pose
	var mouth: Vector3 = pose.mouth()
	var bowl_rest := Vector3(0.03, diner.top + 0.035, diner.edge + 0.14)
	var bowl: Vector3 = bowl_rest.lerp(Vector3(0.02, mouth.y - 0.2, diner.edge + 0.02), w * 0.8)
	var stir := Vector3(cos(diner.clock * 5.0), 0, sin(diner.clock * 5.0)) * 0.02
	var tip: Vector3 = (bowl + Vector3(0, 0.02, 0) + stir).lerp(mouth + Vector3(0, -0.02, 0.02), w)
	# Held low and back over the bowl, so the forearm lies flat; in front of the chin for a bite.
	var grip: Vector3 = tip + Vector3(-0.07, 0.07, -0.15).lerp(Vector3(-0.04, -0.07, 0.15), w)
	pose.goals = {"R": grip, "L": bowl + Vector3(0.1, 0.0, -0.03)}
	pose.aims = {"R": (tip - grip).normalized(), "L": Vector3(-1.0, -0.2, 0.3)}
	pose.lean = 0.12 + 0.08 * (1.0 - w)
	diner.props[0].global_position = _to_world(diner, bowl)
	diner.props[0].global_basis = diner.body.global_basis
	var direction: Vector3 = diner.body.global_basis * (tip - grip).normalized()
	for n in range(2):
		var stick: Node3D = diner.props[1 + n]
		var middle: Vector3 = _to_world(diner, (tip + grip) * 0.5 + Vector3(0.008 * n, 0, 0))
		stick.global_transform = Transform3D(Basis.looking_at(direction), middle)

# A glass of iced tea held on the table, lifted to the mouth every few seconds.
func _drink(diner: Dictionary) -> void:
	var t: float = fmod(diner.clock, diner.length)
	var w := _lift(t, diner.length, 0.6, 0.9)
	var pose: SkeletonModifier3D = diner.pose
	var mouth: Vector3 = pose.mouth()
	var glass_rest := Vector3(-0.12, diner.top + 0.055, diner.edge + 0.12)
	var glass: Vector3 = glass_rest.lerp(mouth + Vector3(-0.01, -0.05, 0.06), w)
	pose.goals = {"R": glass + Vector3(-0.06, -0.03, -0.05)}
	pose.aims = {"R": Vector3(0.6, 0.1, 0.8)}
	if diner.rest_left:
		pose.goals.L = Vector3(0.16, diner.top + 0.03, diner.edge + 0.06)
		pose.aims.L = Vector3(-0.3, -0.2, 1.0)
	var tilt := Basis(Vector3.RIGHT, -1.1 * w)
	diner.props[0].global_transform = Transform3D(diner.body.global_basis * tilt, _to_world(diner, glass))

# Think with a hand to the chin, reach for a piece, carry it over, sit back; then it is the
# other player's turn. A finished game is set up again.
func _play(game: Dictionary, delta: float) -> void:
	var board: Node3D = game.board
	var rules: RefCounted = game.rules
	var mover: Dictionary = game.players[0] if rules.turn == 1 else game.players[1]
	var waiting: Dictionary = game.players[1] if rules.turn == 1 else game.players[0]
	_rest(waiting, false)
	game.clock += delta
	match game.stage:
		"think":
			_rest(mover, game.wait > 4.0)
			if game.clock > game.wait:
				var moves: PackedInt32Array = rules.legal_moves()
				if moves.is_empty() or game.plies > 140 or rules.outcome() != "":
					game.rules = ChessRules.new()
					board.lay(game.rules.board)
					game.plies = 0
					game.clock = 0.0
					return
				game.move = moves[rng.randi() % moves.size()]
				_next(game, "reach")
		"reach":
			var w := smoothstep(0.0, 0.5, game.clock)
			_hand_to(mover, _rest_hand(mover).lerp(_square(mover, board, ChessRules.from_of(game.move)), w), w)
			if game.clock > 0.5:
				board.slide(ChessRules.from_of(game.move), ChessRules.to_of(game.move), 0.4)
				_next(game, "carry")
		"carry":
			var w := smoothstep(0.0, 0.4, game.clock)
			_hand_to(mover, _square(mover, board, ChessRules.from_of(game.move)).lerp(_square(mover, board, ChessRules.to_of(game.move)), w), 1.0)
			if game.clock > 0.45:
				rules.play(game.move)
				# Lays the board from the rules, so captures, castling and promotion all show.
				board.lay(rules.board)
				game.plies += 1
				_next(game, "back")
		"back":
			var w := 1.0 - smoothstep(0.0, 0.5, game.clock)
			_hand_to(mover, _rest_hand(mover).lerp(_square(mover, board, ChessRules.to_of(game.move)), w), w)
			if game.clock > 0.5:
				game.wait = rng.randf_range(2.0, 8.0)
				_next(game, "think")

func _next(game: Dictionary, stage: String) -> void:
	game.stage = stage
	game.clock = 0.0

func _rest_hand(player: Dictionary) -> Vector3:
	return Vector3(-0.14, player.top + 0.04, player.edge + 0.05)

# Both forearms on the table edge, or the right hand propping the chin while thinking.
func _rest(player: Dictionary, chin: bool) -> void:
	var pose: SkeletonModifier3D = player.pose
	pose.lean = 0.15
	pose.goals = {"R": _rest_hand(player), "L": Vector3(0.14, player.top + 0.04, player.edge + 0.05)}
	pose.aims = {"R": Vector3(0.3, -0.2, 1.0), "L": Vector3(-0.3, -0.2, 1.0)}
	if chin:
		pose.goals.R = pose.mouth() + Vector3(-0.02, -0.16, -0.02)
		pose.aims.R = Vector3(0.2, 1.0, 0.1)

# The wrist just above and behind the piece being picked, leaning in for the far squares.
func _hand_to(player: Dictionary, local: Vector3, reach: float) -> void:
	var pose: SkeletonModifier3D = player.pose
	pose.goals = {"R": local, "L": Vector3(0.14, player.top + 0.04, player.edge + 0.05)}
	pose.aims = {"R": Vector3(0.0, -0.8, 0.6), "L": Vector3(-0.3, -0.2, 1.0)}
	pose.lean = 0.15 + 0.35 * reach * clampf((local.z - player.edge) / 0.4, 0.0, 1.0)

func _square(player: Dictionary, board: Node3D, square: int) -> Vector3:
	return player.body.to_local(board.to_global(board.spot(square))) + Vector3(0, 0.07, -0.05)
