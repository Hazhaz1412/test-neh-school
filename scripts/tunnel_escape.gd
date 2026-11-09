extends Node3D

# Night 0 ends in a dream: the service tunnels under the school. Nobody but the
# guard, who knows these tunnels and the doors between them far better than the player does.
# - The tunnels are a small network of corridors with junctions and dead ends (NODES, EDGES).
#   Obstacles are already lying there (OBSTACLES): barriers to jump, pipes to slide under, crates
#   and carts to go round. Nothing moves by itself.
# - He chases along the shortest way through the tunnels to the player.
# - Twice he takes a door only he has the key to and steps out ahead (CUTOFFS): the player has to
#   turn back and take the other way.
# - Cracks run right across some corridors (CRACKS): jump them or drop into the pit.
# - On the lower level a crack has eaten the foot of a service stair (STAIRS): jump across onto
#   the stair and run up it to the higher tunnel.
# - North of C a door on the left can be shouldered open (ROOM): a pump room through to the west
#   tunnel, the other way out when he cuts the player off.
# - The floor of one corridor gives way into a drain (corridor_chute.gd) down to the lower level.
# - The last corridor opens on a ledge over a flooded reservoir and a broken walkway beyond the
#   gap. A cutscene takes over: the player stops at the edge, looks down, turns to the guard
#   coming, backs up and jumps, falls short onto a board sticking out of the walkway, and it
#   snaps. Into the water, dragged under, and they wake up at home.
const ORIGIN := Vector3(220, -300, 0)
const WIDTH := 4.0
const HEIGHT := 3.2
const WALK_SPEED := 5.0
const RUN_SPEED := 7.6
const SPRINT_DRAIN := 6.0
const SLIDE_MIN_SPEED := 4.0
# Clears a 0.8 m kerb without the head reaching the 3.2 m ceiling.
const JUMP_VELOCITY := 7.0
const GRAVITY := 22.0
const CATCH := 1.35
# His pace by how far along the tunnels he is: closing a long gap fast, easing off when close.
const GUARD_PACE := 7.2
const GUARD_RUSH := 9.0
const GUARD_EASE := 6.2
const RUSH_GAP := 16.0
const EASE_GAP := 6.0
const GUARD_CHARGE := 6.4
const CLIP_PACE := 5.0
const RUN_STRIDE := 1.6
const LOWER := -14.0
const WATER_DEPTH := 14.0
const DROWN_SECONDS := 9.0
const SINK_RATE := 0.7
# How far the stair on the lower level climbs: the far end of the tunnels sits this much higher.
const RISE := 2.4
const NODES := {
	"T": Vector3(0, 0, 12), "S": Vector3(0, 0, 0), "A": Vector3(0, 0, -34), "E": Vector3(24, 0, -34),
	"B": Vector3(-30, 0, -34), "C": Vector3(-30, 0, -76), "P1": Vector3(-30, 0, -90), "D": Vector3(-30, 0, -108),
	"G": Vector3(-64, 0, -76), "P2": Vector3(-64, 0, -90), "H": Vector3(-64, 0, -124),
	"L1": Vector3(-64, LOWER, -150), "L2": Vector3(-64, LOWER, -186), "L3": Vector3(-24, LOWER, -186),
	"L4": Vector3(-24, LOWER, -230), "L5": Vector3(16, LOWER + RISE, -186), "X": Vector3(16, LOWER + RISE, -240),
}
const EDGES := [["T", "S"], ["S", "A"], ["A", "E"], ["A", "B"], ["B", "C"], ["C", "P1"], ["P1", "D"], ["C", "G"],
	["G", "P2"], ["P2", "H"], ["P1", "P2"],
	["L1", "L2"], ["L2", "L3"], ["L3", "L4"], ["L3", "L5"], ["L5", "X"]]
# Edge, metres from its first node, kind, side (+1 right of travel, -1 left).
const OBSTACLES := [
	["S", "A", 12.0, "barrier", 0], ["S", "A", 24.0, "crates", 1],
	["A", "B", 14.0, "pipe", 0],
	["B", "C", 10.0, "crates", -1], ["B", "C", 21.0, "barrier", 0], ["B", "C", 32.0, "cart", 1],
	["C", "P1", 10.0, "crates", 1],
	["C", "G", 12.0, "pipe", 0], ["C", "G", 24.0, "crates", -1],
	["G", "P2", 8.0, "barrier", 0], ["P2", "H", 6.0, "crates", 1],
	["L1", "L2", 10.0, "crates", -1], ["L1", "L2", 19.0, "pipe", 0],
	["L2", "L3", 10.0, "barrier", 0], ["L2", "L3", 20.0, "cart", -1], ["L2", "L3", 30.0, "crates", 1],
	["L3", "L4", 16.0, "crates", -1],
	["L3", "L5", 22.0, "crates", 1], ["L3", "L5", 31.0, "barrier", 0],
	["L5", "X", 12.0, "crates", -1], ["L5", "X", 22.0, "barrier", 0], ["L5", "X", 32.0, "pipe", 0], ["L5", "X", 42.0, "cart", 1],
]
# Cracks right across the floor: edge, metres from its first node to the near lip, width.
const CRACKS := [["S", "A", 17.0, 1.8], ["A", "B", 21.0, 1.9], ["L1", "L2", 28.0, 2.0]]
const PIT_DEPTH := 6.0
# The service stair: edge, near lip of the crack at its foot, crack width, length of the flight.
# What is left of the flight starts STEP_UP above the floor, so the jump has to go up as well.
const STAIRS := ["L3", "L5", 8.0, 1.6, 5.0]
const STEP_UP := 0.6
# The pump room between the two west tunnels, with a door to shoulder open at each end.
const ROOM := ["P1", "P2"]
const ROOM_WIDTH := 9.0
const ROOM_HEIGHT := 3.8
const DOOR_REACH := 0.95
# The broken walkway past the ledge: the gap, how long the far piece is, the jump and the hang.
const LEAP_GAP := 3.0
const WALKWAY := 7.6
# A scaffold board left sticking out of the walkway's broken end, toward the ledge.
const PLANK_OUT := 1.3
# The beats of the cutscene, in seconds.
const BEATS := {"look_down": 1.6, "turn_back": 0.7, "watch": 1.5, "turn_front": 0.6, "back_up": 1.0, "run_up": 0.5, "leap": 0.6, "hang": 1.8}
# Where he steps out ahead of the player through a door only he can open.
const CUTOFFS := [
	{"edge": ["C", "P1"], "after": 7.0, "door": ["P1", "D", 13.0, 1], "line": "Tao thuộc hết đường dưới này! Quay lại đâu cho kịp!"},
	{"near": "L3", "reach": 7.0, "door": ["L3", "L4", 26.0, 1], "line": "Tưởng rơi xuống là thoát à? Tao đi đường tắt!"},
]
# The floor of P2→H gives way into the drain from here on.
const HOLE := ["P2", "H", 16.0]
const HOLE_LENGTH := 5.0
# The east arm from A is shut by a chained grille this far along.
const GRILLE := ["A", "E", 9.0]
const SHOUTS := ["Đứng lại!", "Mày chạy đâu cho thoát!", "Dừng lại ngay!", "Tao báo công an bây giờ!", "Đứng lại cho tao!"]
const DOOR_START := 3.0
# Checkpoints: where the player restarts, which way they face, where he is, which cut-offs are left.
const CHECKPOINTS := [
	{"at": Vector3(0, 0, -3), "toward": "A", "guard": Vector3(0, 0, 12), "door": true, "cutoffs": [0, 1]},
	{"at": Vector3(-64, 0, -79), "toward": "H", "guard": Vector3(-46, 0, -76), "cutoffs": [1]},
	{"at": Vector3(-64, LOWER, -152), "toward": "L2", "guard": null, "cutoffs": [1]},
	{"at": Vector3(16, LOWER + RISE, -189), "toward": "X", "guard": Vector3(0, LOWER + RISE, -186), "cutoffs": []},
]
var story: Node3D
var world: Node3D
var active := false
var built := false
var clock := 0.0
var speed := 0.0
var lane_x := 0.0
var looking_back := false
var slide_remaining := 0.0
var slide_cooldown := 0.0
var stumble_remaining := 0.0
var obstacle_cooldown := 0.0
var hit_count := 0
var held_keys := {}
var bodies: Array[PhysicsBody3D] = []
var lamp_points: Array[Vector3] = []
var lights: Array[OmniLight3D] = []
var obstacle_spots: Array[Dictionary] = []
var doors: Array[Node3D] = []
var hop := {}
var distances := {}
var next_hop := {}
var guard: Node3D
var guard_on := false
var guard_pos := Vector3.ZERO
var guard_speed := 0.0
var guard_wait := 0.0
var guard_side := 0.0
var guard_yaw := 0.0
var guard_gap := 99.0
var stride := 0.0
var shout_clock := 0.0
var cutoffs_left: Array = []
var checkpoint := 0
var door_clock := -1.0
var fade_clock := 0.0
var restarted := false
var state := "run"
var state_clock := 0.0
var drown_from := Vector3.ZERO
var depth := 0.0
var plunge := 0.0
var swim_push := 0.0
var reservoir_lamps: Array[Light3D] = []
var at_ledge := false
var chute: Node3D
var fx: Node
var music: AudioStreamPlayer
var music_bed: AudioStreamPlayer
var breathing: AudioStreamPlayer
var underwater: AudioStreamPlayer
var bubbles: AudioStreamPlayer
var splash: AudioStreamPlayer
var chase_steps: AudioStreamPlayer3D
var snarls: AudioStreamPlayer3D
var water_tint: ColorRect
var hint: Label
var water_y := 0.0
var surface: MeshInstance3D
var bubble_cloud: CPUParticles3D
var ledge_light: SpotLight3D
var splash_spray: CPUParticles3D
var underside: MeshInstance3D
var muffle_bus := -1
var saved_fog := []
# Every crack, the stair's included: near lip (local, on the floor), far lip, way across.
var gaps: Array[Dictionary] = []
var push_doors: Array[Dictionary] = []
var pit_fall := false
# The cutscene at the reservoir: which beat it is on, and how long it has been on it.
var leap_beat := ""
var beat_clock := 0.0
var leap_from := Vector3.ZERO
var leap_yaw := 0.0
var hanging := false
var climb_push := 0.0
var fall_drift := -2.0
var scripted_guard := false
var cut_guard := Vector3.ZERO
var plank: Node3D
var plank_rest := Transform3D.IDENTITY
var plank_tween: Tween
var splinters: CPUParticles3D
# Rippling water: two crossing swells in the vertices, finer ripples in the normals, and the
# fresnel that makes the surface a mirror at a glance and see-through from above.
const WATER_SHADER := preload("res://assets/materials/reservoir_water.gdshader")

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	position = ORIGIN
	name = "ServiceTunnels"
	music_bed = _music_layer("res://assets/music/dark_ambience_gabovitch.ogg", -12.0)
	music = _music_layer("res://assets/music/chase_wolfgang.ogg", -22.0)
	breathing = AudioStreamPlayer.new()
	breathing.stream = story.loop_wav("res://assets/audio/corridor/panting.wav")
	breathing.volume_db = -15
	add_child(breathing)
	chase_steps = AudioStreamPlayer3D.new()
	chase_steps.stream = preload("res://scripts/security_guard.gd").shoe_steps()
	chase_steps.unit_size = 9
	chase_steps.max_distance = 50
	add_child(chase_steps)
	snarls = AudioStreamPlayer3D.new()
	snarls.stream = load("res://assets/audio/guard_whistle.wav")
	snarls.unit_size = 14
	snarls.max_distance = 70
	snarls.volume_db = -6
	add_child(snarls)
	underwater = _music_layer("res://assets/audio/water/underwater_pad.ogg", -6.0)
	bubbles = AudioStreamPlayer.new()
	var froth: AudioStreamOggVorbis = load("res://assets/audio/water/bubbles_loop1.ogg").duplicate()
	froth.loop = true
	bubbles.stream = froth
	bubbles.volume_db = -10
	add_child(bubbles)
	splash = AudioStreamPlayer.new()
	splash.stream = load("res://assets/audio/water/ocean_splash.ogg")
	add_child(splash)
	fx = preload("res://scripts/tunnel_fx.gd").new()
	add_child(fx)
	fx.setup(self)
	chute = preload("res://scripts/corridor_chute.gd").new()
	add_child(chute)
	chute.setup(self)
	guard = preload("res://scripts/chase_guard.gd").new()
	add_child(guard)
	_build_graph()
	_build_overlay()
	hide()

func _music_layer(path: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(path).duplicate()
	stream.loop = true
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	water_tint = ColorRect.new()
	water_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	water_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_tint.color = Color(0.02, 0.13, 0.15, 0.0)
	water_tint.hide()
	layer.add_child(water_tint)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -420
	hint.offset_right = 420
	hint.offset_top = -150
	hint.offset_bottom = -110
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.75))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	hint.add_theme_constant_override("outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)

# --- Graph ---

func node_pos(id: String) -> Vector3:
	return NODES[id]

func flat_forward(a: String, b: String) -> Vector3:
	var along := node_pos(b) - node_pos(a)
	along.y = 0.0
	return along.normalized()

func edge_length(a: String, b: String) -> float:
	var along := node_pos(b) - node_pos(a)
	return Vector2(along.x, along.z).length()

func is_edge(edge: Array, a: String, b: String) -> bool:
	return edge[0] == a and edge[1] == b

# How far the floor is above node a's level, `metres` along from a. Only the stair edge climbs.
func lift(a: String, b: String, metres: float) -> float:
	if is_edge(STAIRS, b, a):
		return lift(b, a, edge_length(a, b) - metres) - RISE
	if not is_edge(STAIRS, a, b): return 0.0
	var foot: float = STAIRS[2] + STAIRS[3]
	if metres < foot: return 0.0
	return lerpf(STEP_UP, RISE, clampf((metres - foot) / float(STAIRS[4]), 0.0, 1.0))

func edge_point(a: String, b: String, metres: float, side := 0.0) -> Vector3:
	var forward := flat_forward(a, b)
	return node_pos(a) + forward * metres + forward.cross(Vector3.UP) * side + Vector3.UP * lift(a, b, metres)

# The crack `at` is over, if any.
func gap_at(at: Vector3, margin := 0.0) -> Dictionary:
	for gap in gaps:
		var rel: Vector3 = at - gap.near
		var s: float = rel.dot(gap.forward)
		if s > -margin and s < gap.width + margin and absf(rel.dot(gap.right)) < WIDTH * 0.5 and rel.y < 3.0 and rel.y > -PIT_DEPTH - 3.0:
			return gap
	return {}

# The floor under `at` (local). Over a crack, the level of its near lip.
func floor_under(at: Vector3) -> float:
	var here := project(at)
	if not here.has("a"): return at.y
	var gap := gap_at(at)
	if not gap.is_empty(): return gap.near.y
	return node_pos(here.a).y + lift(here.a, here.b, here.t)

# Where the guard's feet go: the floor, and over a crack the arc of his jump across it.
func ground(at: Vector3) -> float:
	var gap := gap_at(at)
	if gap.is_empty(): return floor_under(at)
	var s: float = clampf((at - gap.near).dot(gap.forward) / gap.width, 0.0, 1.0)
	return lerpf(gap.near.y, gap.far.y, s) + sin(PI * s) * 0.8

func _build_graph() -> void:
	for id in NODES:
		hop[id] = []
	for edge in EDGES:
		hop[edge[0]].append(edge[1])
		hop[edge[1]].append(edge[0])
	# All-pairs shortest routes; there are only a handful of junctions.
	for a in NODES:
		distances[a] = {}
		next_hop[a] = {}
		for b in NODES:
			distances[a][b] = 0.0 if a == b else INF
			next_hop[a][b] = b
		for b in hop[a]:
			distances[a][b] = node_pos(a).distance_to(node_pos(b))
	for k in NODES:
		for a in NODES:
			for b in NODES:
				if distances[a][k] + distances[k][b] < distances[a][b]:
					distances[a][b] = distances[a][k] + distances[k][b]
					next_hop[a][b] = next_hop[a][k]

# The closest point of the tunnels to `at` (local), with the edge it lies on.
func project(at: Vector3) -> Dictionary:
	var best := {"d": INF}
	for edge in EDGES:
		var a := node_pos(edge[0])
		var b := node_pos(edge[1])
		if absf(at.y - a.y) > 4.0: continue
		var axis := b - a
		var t := clampf((at - a).dot(axis) / axis.length_squared(), 0.0, 1.0)
		var point := a + axis * t
		var d := Vector2(at.x - point.x, at.z - point.z).length()
		if d < best.d: best = {"d": d, "a": edge[0], "b": edge[1], "point": point, "t": t * axis.length()}
	return best

# Corner points from one place in the tunnels to another, by the shortest way.
func route(from: Vector3, to: Vector3) -> Array:
	var start := project(from)
	var goal := project(to)
	if not start.has("a") or not goal.has("a"): return [to]
	if (start.a == goal.a and start.b == goal.b) or (start.a == goal.b and start.b == goal.a): return [goal.point]
	var best := INF
	var pick := []
	for s in [start.a, start.b]:
		for g in [goal.a, goal.b]:
			var cost: float = from.distance_to(node_pos(s)) + distances[s][g] + node_pos(g).distance_to(goal.point)
			if cost < best:
				best = cost
				pick = [s, g]
	if pick.is_empty() or best == INF: return [to]
	var points: Array = [node_pos(pick[0])]
	var at: String = pick[0]
	while at != pick[1]:
		at = next_hop[at][pick[1]]
		points.append(node_pos(at))
	points.append(goal.point)
	return points

static func path_length(points: Array, from: Vector3) -> float:
	var total := 0.0
	var at := from
	for point in points:
		total += at.distance_to(point)
		at = point
	return total

# --- Building ---

func material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	return mat

func _textured(path: String, tint: Color, scale_by: float) -> StandardMaterial3D:
	var mat := material(tint)
	mat.albedo_texture = load(path)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_by
	return mat

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material, solid := false, hazard := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	parent.add_child(part)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 0
		body.position = pos
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
		if hazard: body.set_meta("chase_hazard", true)
		parent.add_child(body)
		bodies.append(body)
	return part

func _axis_box(center: Vector3, along: Vector3, length: float, across: float, height: float) -> Vector3:
	return Vector3(length, height, across) if absf(along.x) > 0.5 else Vector3(across, height, length)

func build() -> void:
	if built: return
	built = true
	var wall := _textured("res://assets/polyhaven_corridor/textures/damaged_plaster_diff.jpg", Color(0.62, 0.52, 0.5), 0.3)
	var floor_mat := _textured("res://assets/polyhaven_corridor/textures/concrete_floor_painted_diff.jpg", Color(0.42, 0.38, 0.36), 0.25)
	var ceiling := material(Color(0.16, 0.14, 0.14))
	var lamp := material(Color(1.0, 0.12, 0.06), true)
	var pipe_mat := material(Color(0.32, 0.3, 0.28))
	pipe_mat.metallic = 0.6
	pipe_mat.roughness = 0.45
	# Junction squares: walls on every side that has no corridor.
	for id in NODES:
		var at := node_pos(id)
		var open: Array = []
		for other in hop[id]: open.append((node_pos(other) - at).normalized())
		if id == "X": open.append(Vector3.FORWARD)
		box(self, at + Vector3(0, -0.1, 0), Vector3(WIDTH, 0.2, WIDTH), floor_mat, true)
		box(self, at + Vector3(0, HEIGHT + 0.1, 0), Vector3(WIDTH, 0.2, WIDTH), ceiling, true)
		for side in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			if open.any(func(d): return d.dot(side) > 0.9): continue
			box(self, at + side * (WIDTH * 0.5 + 0.1) + Vector3(0, HEIGHT * 0.5, 0), _axis_box(at, side.cross(Vector3.UP), WIDTH + 0.4, 0.2, HEIGHT), wall, true)
		lamp_points.append(at + Vector3(0, HEIGHT - 0.1, 0))
	var looks := {"wall": wall, "floor": floor_mat, "ceiling": ceiling, "lamp": lamp, "pipe": pipe_mat}
	gaps.clear()
	push_doors.clear()
	for edge in EDGES:
		var a := node_pos(edge[0])
		var forward := flat_forward(edge[0], edge[1])
		var right := forward.cross(Vector3.UP)
		var total := edge_length(edge[0], edge[1])
		var start := WIDTH * 0.5
		var end := total - WIDTH * 0.5
		if is_edge(edge, ROOM[0], ROOM[1]):
			_build_room(a, forward, right, start, end, looks)
			continue
		if is_edge(edge, STAIRS[0], STAIRS[1]):
			_build_stair_edge(a, forward, right, start, end, looks)
			_doors_along(edge[0], edge[1])
			continue
		# The floor in pieces either side of the drain hole and the cracks.
		var cuts: Array = []
		if is_edge(HOLE, edge[0], edge[1]): cuts.append([HOLE[2], HOLE[2] + HOLE_LENGTH, "hole"])
		for crack in CRACKS:
			if is_edge(crack, edge[0], edge[1]): cuts.append([crack[2], crack[2] + crack[3], "crack"])
		cuts.sort_custom(func(x, y): return x[0] < y[0])
		var from := start
		for cut in cuts:
			_floor_piece(a, forward, from, cut[0], 0.0, floor_mat)
			if cut[2] == "hole": _build_hole(a + forward * float(cut[0]), forward, right)
			else: _build_crack(a, forward, right, cut[0], cut[1], 0.0, 0.0)
			from = cut[1]
		_floor_piece(a, forward, from, end, 0.0, floor_mat)
		_shell(a, forward, right, start, end, 0.0, HEIGHT, 0.0, looks, true)
		_doors_along(edge[0], edge[1])
	for spec in OBSTACLES:
		_build_obstacle(spec)
	_build_grille()
	_build_rubble("D")
	_build_rubble("L4")
	_build_rubble("H")
	for cut in CUTOFFS:
		doors.append(_build_door(cut.door))
	_build_signs()
	_build_start_door()
	_build_reservoir()
	for i in range(8):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.18, 0.1)
		light.light_energy = 2.4
		light.omni_range = 11.0
		light.shadow_enabled = i < 2
		add_child(light)
		lights.append(light)
	chute.build()

func _floor_piece(a: Vector3, forward: Vector3, from: float, to: float, level: float, mat: Material) -> void:
	if to - from < 0.01: return
	var at := a + forward * ((from + to) * 0.5)
	box(self, at + Vector3(0, level - 0.1, 0), _axis_box(at, forward, to - from, WIDTH, 0.2), mat, true)

# Ceiling, both walls, the pipes and cable tray, and the lamps of a stretch of corridor. The walls
# run from `bottom` up to the ceiling at `top`; pipes and lamps hang off the floor at `level`.
func _shell(a: Vector3, forward: Vector3, right: Vector3, from: float, to: float, bottom: float, top: float, level: float, looks: Dictionary, into_junctions: bool) -> void:
	var length := to - from
	var mid := a + forward * ((from + to) * 0.5)
	box(self, mid + Vector3(0, top + 0.1, 0), _axis_box(mid, forward, length, WIDTH, 0.2), looks.ceiling, true)
	for side in [-1.0, 1.0]:
		box(self, mid + right * side * (WIDTH * 0.5 + 0.1) + Vector3(0, (bottom + top) * 0.5, 0), _axis_box(mid, forward, length, 0.2, top - bottom), looks.wall, true)
	# Two pipes along one wall and a cable tray along the other, the whole way.
	var run := length + (WIDTH if into_junctions else 0.0)
	for k in range(2):
		box(self, mid + right * (WIDTH * 0.5 - 0.18) + Vector3(0, level + 2.55 + k * 0.28, 0), _axis_box(mid, forward, run, 0.16, 0.16), looks.pipe)
	box(self, mid - right * (WIDTH * 0.5 - 0.12) + Vector3(0, level + 2.75, 0), _axis_box(mid, forward, run, 0.22, 0.06), looks.pipe)
	var z := from + 4.0
	while z < to - 1.0:
		var spot := a + forward * z + Vector3.UP * level
		box(self, spot + Vector3(0, top - level - 0.04, 0), _axis_box(spot, forward, 0.9, 0.22, 0.06), looks.lamp)
		lamp_points.append(spot + Vector3(0, top - level - 0.2, 0))
		z += 9.0

# A crack right across the corridor: a closed pit with broken lips, a hazard strip on each side and
# a dull glow from the bottom so it reads from a distance in the dark.
func _build_crack(a: Vector3, forward: Vector3, right: Vector3, from: float, to: float, near_level: float, far_level: float) -> void:
	var width := to - from
	var mid := a + forward * ((from + to) * 0.5)
	var bottom := near_level - PIT_DEPTH
	var rock := material(Color(0.2, 0.18, 0.17))
	var raw := material(Color(0.36, 0.33, 0.31))
	box(self, mid + Vector3(0, bottom - 0.1, 0), _axis_box(mid, forward, width + 0.4, WIDTH + 0.4, 0.2), material(Color(0.05, 0.04, 0.04)), true)
	for side in [-1.0, 1.0]:
		box(self, mid + right * side * (WIDTH * 0.5 + 0.1) + Vector3(0, (bottom + near_level) * 0.5, 0), _axis_box(mid, forward, width + 0.4, 0.2, near_level - bottom), rock, true)
	var near := a + forward * from
	var far := a + forward * to
	box(self, near - forward * 0.1 + Vector3(0, (bottom + near_level) * 0.5 - 0.1, 0), _axis_box(near, forward, 0.2, WIDTH, near_level - bottom - 0.2), raw, true)
	box(self, far + forward * 0.1 + Vector3(0, (bottom + far_level) * 0.5 - 0.1, 0), _axis_box(far, forward, 0.2, WIDTH, far_level - bottom - 0.2), raw, true)
	var stripe := material(Color(0.95, 0.75, 0.1), true)
	stripe.emission_energy_multiplier = 0.45
	box(self, near - forward * 0.35 + Vector3(0, near_level + 0.005, 0), _axis_box(near, forward, 0.22, WIDTH - 0.2, 0.012), stripe)
	box(self, far + forward * 0.35 + Vector3(0, far_level + 0.005, 0), _axis_box(far, forward, 0.22, WIDTH - 0.2, 0.012), stripe)
	# Broken slab along both lips, and rubble down in the pit.
	var dice := RandomNumberGenerator.new()
	dice.seed = int(absf(mid.x) * 31.0 + absf(mid.z) * 7.0)
	for lip_at in [[near, -1.0, near_level], [far, 1.0, far_level]]:
		for i in range(5):
			var piece: Vector3 = lip_at[0] + forward * float(lip_at[1]) * dice.randf_range(0.0, 0.25) + right * dice.randf_range(-1.7, 1.7)
			var slab := box(self, piece + Vector3(0, float(lip_at[2]) - 0.12, 0), Vector3(dice.randf_range(0.3, 0.6), 0.16, dice.randf_range(0.3, 0.6)), raw)
			slab.rotation = Vector3(dice.randf_range(-0.4, 0.4), dice.randf() * TAU, dice.randf_range(-0.4, 0.4))
	for i in range(6):
		var chunk := box(self, mid + forward * dice.randf_range(-width * 0.4, width * 0.4) + right * dice.randf_range(-1.5, 1.5) + Vector3(0, bottom + 0.25, 0), Vector3.ONE * dice.randf_range(0.3, 0.7), raw)
		chunk.rotation = Vector3(dice.randf(), dice.randf(), dice.randf())
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.42, 0.16)
	glow.light_energy = 1.8
	glow.omni_range = PIT_DEPTH + 1.5
	glow.position = mid + Vector3(0, bottom + 0.8, 0)
	add_child(glow)
	gaps.append({"near": near + Vector3(0, near_level, 0), "far": far + Vector3(0, far_level, 0), "forward": forward, "right": right, "width": width})

# The stair edge: level floor, the crack at the foot of the stair, what is left of the flight (a
# ramp to walk on with steps drawn over it), and the corridor on at the top under a higher ceiling.
func _build_stair_edge(a: Vector3, forward: Vector3, right: Vector3, start: float, end: float, looks: Dictionary) -> void:
	var lip_near: float = STAIRS[2]
	var foot: float = lip_near + float(STAIRS[3])
	var top_at: float = foot + float(STAIRS[4])
	_floor_piece(a, forward, start, lip_near, 0.0, looks.floor)
	_build_crack(a, forward, right, lip_near, foot, 0.0, STEP_UP)
	_floor_piece(a, forward, top_at, end, RISE, looks.floor)
	_shell(a, forward, right, start, lip_near, 0.0, HEIGHT, 0.0, looks, false)
	_shell(a, forward, right, lip_near, end, 0.0, RISE + HEIGHT, RISE, looks, false)
	# Where the ceiling steps up over the stair.
	var step_face := a + forward * lip_near
	box(self, step_face + Vector3(0, HEIGHT + RISE * 0.5 + 0.1, 0), _axis_box(step_face, forward, 0.2, WIDTH, RISE), looks.wall, true)
	# The ramp under the steps.
	var rise_by := RISE - STEP_UP
	var run: float = STAIRS[4]
	var slope := Vector3(forward * run + Vector3.UP * rise_by)
	var middle := a + forward * ((foot + top_at) * 0.5) + Vector3.UP * (STEP_UP + rise_by * 0.5)
	var along := slope.normalized()
	var up := right.cross(along).normalized()
	if up.y < 0.0: up = -up
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 0
	ramp.collision_mask = 0
	ramp.transform = Transform3D(Basis(right, up, -along), middle - up * 0.15)
	var shape := CollisionShape3D.new()
	var plank := BoxShape3D.new()
	plank.size = Vector3(WIDTH, 0.3, slope.length() + 0.02)
	shape.shape = plank
	ramp.add_child(shape)
	add_child(ramp)
	bodies.append(ramp)
	# Concrete steps, half a riser proud of the ramp so feet neither float nor sink far.
	var concrete := _textured("res://assets/polyhaven_corridor/textures/concrete_floor_painted_diff.jpg", Color(0.5, 0.46, 0.43), 0.25)
	var count := 6
	for i in range(count):
		var t0: float = foot + run * i / count
		var t1: float = foot + run * (i + 1) / count
		var tread: float = STEP_UP + rise_by * (i + 0.5) / count
		var at := a + forward * ((t0 + t1) * 0.5)
		box(self, at + Vector3(0, tread * 0.5, 0), _axis_box(at, forward, t1 - t0, WIDTH, tread), concrete)
		var nosing := material(Color(0.95, 0.75, 0.1), true)
		nosing.emission_energy_multiplier = 0.2
		box(self, a + forward * (t0 + 0.04) + Vector3(0, tread + 0.004, 0), _axis_box(at, forward, 0.07, WIDTH - 0.3, 0.012), nosing)
	# A handrail up one side, bent where the bottom of the flight fell in.
	var rail := material(Color(0.3, 0.31, 0.3))
	rail.metallic = 0.7
	var rail_from := a + forward * foot + right * (WIDTH * 0.5 - 0.2) + Vector3.UP * (STEP_UP + 0.95)
	var rail_to := a + forward * top_at + right * (WIDTH * 0.5 - 0.2) + Vector3.UP * (RISE + 0.95)
	var bar := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.03
	tube.bottom_radius = 0.03
	tube.height = rail_from.distance_to(rail_to)
	bar.mesh = tube
	bar.material_override = rail
	add_child(bar)
	bar.look_at_from_position((rail_from + rail_to) * 0.5, rail_to, right)
	bar.rotate_object_local(Vector3.RIGHT, PI / 2)
	for k in range(3):
		var post := rail_from.lerp(rail_to, k / 2.0)
		box(self, post - Vector3(0, 0.47, 0), Vector3(0.05, 0.95, 0.05), rail)
	var bent := box(self, a + forward * (foot - 0.5) + right * (WIDTH * 0.5 - 0.2) + Vector3(0, -0.2, 0), _axis_box(a, forward, 1.3, 0.05, 0.05), rail)
	bent.rotation = Vector3(0.0, 0.0, 0.0)
	bent.rotate(right, 0.7)

# The pump room: wider and taller than the tunnels, two pumps, and a swing door at each end.
func _build_room(a: Vector3, forward: Vector3, right: Vector3, start: float, end: float, looks: Dictionary) -> void:
	var length := end - start
	var mid := a + forward * ((start + end) * 0.5)
	var tiles := _textured("res://assets/polyhaven_corridor/textures/concrete_floor_painted_diff.jpg", Color(0.36, 0.42, 0.4), 0.3)
	box(self, mid + Vector3(0, -0.1, 0), _axis_box(mid, forward, length, ROOM_WIDTH, 0.2), tiles, true)
	box(self, mid + Vector3(0, ROOM_HEIGHT + 0.1, 0), _axis_box(mid, forward, length, ROOM_WIDTH, 0.2), looks.ceiling, true)
	for side in [-1.0, 1.0]:
		box(self, mid + right * side * (ROOM_WIDTH * 0.5 + 0.1) + Vector3(0, ROOM_HEIGHT * 0.5, 0), _axis_box(mid, forward, length, 0.2, ROOM_HEIGHT), looks.wall, true)
	# End walls in line with the tunnel walls, each with a doorway.
	var leaf_half := 0.7
	for end_at in [[start, -1.0], [end, 1.0]]:
		var at: Vector3 = a + forward * (float(end_at[0]) - float(end_at[1]) * 0.1)
		var side_width := ROOM_WIDTH * 0.5 - leaf_half + 0.2
		for side in [-1.0, 1.0]:
			box(self, at + right * side * (leaf_half + side_width * 0.5) + Vector3(0, ROOM_HEIGHT * 0.5, 0), _axis_box(at, forward, 0.2, side_width, ROOM_HEIGHT), looks.wall, true)
		box(self, at + Vector3(0, (2.3 + ROOM_HEIGHT) * 0.5, 0), _axis_box(at, forward, 0.2, leaf_half * 2.0, ROOM_HEIGHT - 2.3), looks.wall, true)
		var outward: Vector3 = forward * float(end_at[1])
		push_doors.append(_push_door(at, forward, right, -outward))
	# A sign and a green lamp over the first door, seen from the tunnel.
	var entry := a + forward * (start - 0.25)
	_sign("PHÒNG BƠM 2\nTHÔNG SANG HẦM TÂY", entry + Vector3(0, 2.75, 0), -forward, Color(0.55, 1.0, 0.6))
	var green := OmniLight3D.new()
	green.light_color = Color(0.4, 1.0, 0.5)
	green.light_energy = 1.0
	green.omni_range = 4.5
	green.position = entry + Vector3(0, 2.5, 0) - forward * 0.4
	add_child(green)
	box(self, entry + Vector3(0, 2.42, 0), _axis_box(entry, forward, 0.05, 0.5, 0.12), material(Color(0.3, 1.0, 0.45), true))
	# Two pumps on opposite sides, pipes up into the ceiling, lamps the length of the room.
	var paint := material(Color(0.2, 0.32, 0.28))
	paint.metallic = 0.5
	paint.roughness = 0.5
	for pump in [[start + 9.0, 1.0], [start + 20.0, -1.0]]:
		var at: Vector3 = a + forward * float(pump[0]) + right * float(pump[1]) * 2.9
		box(self, at + Vector3(0, 0.75, 0), _axis_box(at, forward, 2.4, 2.5, 1.5), paint, true)
		var motor := MeshInstance3D.new()
		var drum := CylinderMesh.new()
		drum.top_radius = 0.45
		drum.bottom_radius = 0.45
		drum.height = 1.6
		motor.mesh = drum
		motor.material_override = looks.pipe
		motor.position = at + Vector3(0, 1.95, 0)
		motor.rotation = Vector3(0, 0, PI / 2) if absf(forward.x) > 0.5 else Vector3(PI / 2, 0, 0)
		add_child(motor)
		box(self, at + Vector3(0, (2.0 + ROOM_HEIGHT) * 0.5, 0) + right * float(pump[1]) * 0.6, Vector3(0.3, ROOM_HEIGHT - 2.0, 0.3), looks.pipe)
	var z := start + 3.0
	while z < end - 1.0:
		var spot := a + forward * z
		box(self, spot + Vector3(0, ROOM_HEIGHT - 0.04, 0), _axis_box(spot, forward, 0.9, 0.22, 0.06), looks.lamp)
		lamp_points.append(spot + Vector3(0, ROOM_HEIGHT - 0.2, 0))
		z += 8.0

# A swing door across a doorway at `at`. Run into it and it bangs open away from whoever hit it.
func _push_door(at: Vector3, forward: Vector3, right: Vector3, inward: Vector3) -> Dictionary:
	var hinge := Node3D.new()
	hinge.position = at - right * 0.66
	add_child(hinge)
	var size := _axis_box(at, forward, 0.06, 1.3, 2.25)
	var leaf := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = size
	leaf.mesh = plate
	leaf.material_override = material(Color(0.28, 0.36, 0.32))
	leaf.position = right * 0.66 + Vector3(0, 1.13, 0)
	hinge.add_child(leaf)
	# Push bar on both faces and a wired window.
	for face in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = _axis_box(at, forward, 0.05, 0.9, 0.06)
		bar.mesh = bar_mesh
		bar.material_override = material(Color(0.7, 0.68, 0.62))
		bar.position = leaf.position + forward * face * 0.06 + Vector3(0, -0.13, 0)
		hinge.add_child(bar)
	var pane := MeshInstance3D.new()
	var pane_mesh := BoxMesh.new()
	pane_mesh.size = _axis_box(at, forward, 0.07, 0.4, 0.5)
	pane.mesh = pane_mesh
	pane.material_override = material(Color(0.05, 0.08, 0.08))
	pane.position = leaf.position + Vector3(0, 0.5, 0)
	hinge.add_child(pane)
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = leaf.position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	hinge.add_child(body)
	return {"hinge": hinge, "body": body, "at": at, "forward": forward, "right": right, "inward": inward, "open": false, "tween": null}

func _shove(door: Dictionary, from: Vector3) -> void:
	if door.open: return
	door.open = true
	door.body.collision_layer = 0
	var side := signf((from - door.at).dot(door.forward))
	if side == 0.0: side = 1.0
	# Turning the hinge by +angle swings the leaf toward `turn`; it goes away from the pusher.
	var turn := signf(Vector3.UP.cross(door.right).dot(door.forward))
	if door.tween != null: door.tween.kill()
	var swing := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swing.tween_property(door.hinge, "rotation:y", -side * turn * 1.75, 0.3)
	door.tween = swing
	fx.impact(to_global(door.at + Vector3.UP), "door")

func _close_push_doors() -> void:
	for door in push_doors:
		if door.tween != null: door.tween.kill()
		door.tween = null
		door.open = false
		door.hinge.rotation.y = 0.0
		door.body.collision_layer = 1 if active else 0

func _doors_along(a_id: String, b_id: String) -> void:
	var steel := material(Color(0.2, 0.22, 0.22))
	var forward := flat_forward(a_id, b_id)
	var right := forward.cross(Vector3.UP)
	var z := 15.0
	var side := 1.0
	while z < edge_length(a_id, b_id) - 6.0:
		var spot := edge_point(a_id, b_id, z) + right * side * (WIDTH * 0.5 - 0.02)
		if gap_at(spot - right * side * 1.0, 1.0).is_empty():
			box(self, spot + Vector3(0, 1.05, 0), _axis_box(spot, forward, 1.1, 0.06, 2.1), steel)
		z += 17.0
		side = -side

func _build_obstacle(spec: Array) -> void:
	var forward := flat_forward(spec[0], spec[1])
	var right := forward.cross(Vector3.UP)
	var at := edge_point(spec[0], spec[1], float(spec[2]))
	var side := float(spec[4])
	match spec[3]:
		"barrier":
			# A concrete kerb block with hazard paint: jump it.
			var concrete := material(Color(0.55, 0.53, 0.5))
			box(self, at + Vector3(0, 0.38, 0), _axis_box(at, forward, 0.45, WIDTH - 0.1, 0.76), concrete, true, true)
			var stripe := material(Color(0.95, 0.75, 0.1), true)
			stripe.emission_energy_multiplier = 0.35
			box(self, at + Vector3(0, 0.77, 0), _axis_box(at, forward, 0.47, WIDTH - 0.1, 0.04), stripe)
		"pipe":
			# A burst water main across the corridor at head height: slide under it.
			var pipe := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.26
			tube.bottom_radius = 0.26
			tube.height = WIDTH
			pipe.mesh = tube
			var rust := material(Color(0.45, 0.26, 0.16))
			rust.metallic = 0.5
			pipe.material_override = rust
			pipe.position = at + Vector3(0, 1.28, 0)
			pipe.rotation = Vector3(0, 0, PI / 2) if absf(forward.z) > 0.5 else Vector3(PI / 2, 0, 0)
			add_child(pipe)
			var shadow := box(self, at + Vector3(0, 1.28, 0), _axis_box(at, forward, 0.5, WIDTH - 0.1, 0.5), rust, true, true)
			shadow.hide()
			var drip := CPUParticles3D.new()
			drip.amount = 24
			drip.lifetime = 0.7
			drip.direction = Vector3.DOWN
			drip.gravity = Vector3(0, -9.8, 0)
			drip.initial_velocity_min = 0.5
			drip.initial_velocity_max = 1.2
			var bead := SphereMesh.new()
			bead.radius = 0.015
			bead.height = 0.03
			drip.mesh = bead
			drip.position = at + Vector3(0, 1.05, 0)
			add_child(drip)
		"crates":
			var wood := material(Color(0.42, 0.3, 0.18))
			var cover := at + right * side * (WIDTH * 0.5 - 1.05)
			box(self, cover + Vector3(0, 0.55, 0), _axis_box(at, forward, 1.1, 2.0, 1.1), wood, true, true)
			box(self, cover + Vector3(0, 1.4, 0) + right * side * 0.3, _axis_box(at, forward, 0.9, 1.1, 0.6), wood, true, true)
			obstacle_spots.append({"at": at, "side": side, "forward": forward})
		"cart":
			var cover := at + right * side * (WIDTH * 0.5 - 1.0)
			_prop("industrial_storage_cart", cover, forward, 1.05)
			box(self, cover + Vector3(0, 0.55, 0), _axis_box(at, forward, 1.3, 1.9, 1.1), material(Color.BLACK), true, true).hide()
			obstacle_spots.append({"at": at, "side": side, "forward": forward})

func _prop(asset: String, at: Vector3, forward: Vector3, height: float) -> void:
	var path := "res://assets/polyhaven_corridor/%s/%s.gltf" % [asset, asset]
	if not ResourceLoader.exists(path): return
	var visual: Node3D = load(path).instantiate()
	add_child(visual)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var piece: AABB = mesh.get_aabb()
		piece = mesh.transform * piece
		bounds = piece if first else bounds.merge(piece)
		first = false
	var scale_by := height / maxf(0.01, bounds.size.y)
	visual.scale = Vector3.ONE * scale_by
	visual.position = at - Vector3(0, bounds.position.y * scale_by, 0)
	visual.rotation.y = atan2(-forward.x, -forward.z)

func _build_hole(start: Vector3, forward: Vector3, right: Vector3) -> void:
	var dark := material(Color(0.01, 0.01, 0.01))
	box(self, start + forward * HOLE_LENGTH * 0.5 + Vector3(0, -1.5, 0), _axis_box(start, forward, HOLE_LENGTH, WIDTH, 0.1), dark)
	var broken := material(Color(0.36, 0.33, 0.31))
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	for i in range(7):
		var piece := start + forward * dice.randf_range(-0.4, HOLE_LENGTH + 0.2) + right * dice.randf_range(-1.6, 1.6)
		var slab := box(self, piece + Vector3(0, -0.15 - dice.randf() * 0.4, 0), Vector3(dice.randf_range(0.4, 0.9), 0.18, dice.randf_range(0.4, 0.9)), broken)
		slab.rotation = Vector3(dice.randf_range(-0.6, 0.6), dice.randf() * TAU, dice.randf_range(-0.6, 0.6))

func _build_rubble(id: String) -> void:
	var at := node_pos(id)
	var stone := material(Color(0.4, 0.37, 0.34))
	var dice := RandomNumberGenerator.new()
	dice.seed = id.hash()
	for i in range(9):
		var chunk := box(self, at + Vector3(dice.randf_range(-1.6, 1.6), dice.randf_range(0.2, 1.4), dice.randf_range(-1.6, 1.6)), Vector3.ONE * dice.randf_range(0.5, 1.1), stone)
		chunk.rotation = Vector3(dice.randf(), dice.randf(), dice.randf())

func _build_grille() -> void:
	var a := node_pos(GRILLE[0])
	var forward := (node_pos(GRILLE[1]) - a).normalized()
	var right := forward.cross(Vector3.UP)
	var at := a + forward * float(GRILLE[2])
	var iron := material(Color(0.18, 0.18, 0.19))
	iron.metallic = 0.7
	for k in range(13):
		box(self, at + right * (-WIDTH * 0.5 + 0.15 + k * 0.31) + Vector3(0, HEIGHT * 0.5, 0), Vector3(0.05, HEIGHT, 0.05), iron)
	for y in [0.3, 1.6, 2.9]:
		box(self, at + Vector3(0, y, 0), _axis_box(at, forward, 0.06, WIDTH, 0.08), iron)
	box(self, at + Vector3(0, HEIGHT * 0.5, 0), _axis_box(at, forward, 0.2, WIDTH, HEIGHT), iron, true).hide()
	var chain := material(Color(0.7, 0.66, 0.55))
	chain.metallic = 0.9
	box(self, at - forward * 0.06 + Vector3(0, 1.15, 0), _axis_box(at, forward, 0.05, 0.9, 0.1), chain)
	box(self, at - forward * 0.1 + Vector3(0, 1.05, 0), Vector3(0.12, 0.16, 0.08), material(Color(0.75, 0.6, 0.2)))
	var exit := Label3D.new()
	exit.text = "LỐI THOÁT HIỂM"
	exit.font_size = 46
	exit.pixel_size = 0.006
	exit.modulate = Color(0.3, 1.0, 0.45)
	exit.position = node_pos("E") + Vector3(WIDTH * 0.5 - 0.15, 2.4, 0)
	exit.rotation.y = PI / 2
	add_child(exit)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.45)
	glow.light_energy = 1.2
	glow.omni_range = 6
	glow.position = node_pos("E") + Vector3(1.0, 2.4, 0)
	add_child(glow)

func _build_door(spec: Array) -> Node3D:
	var at := edge_point(spec[0], spec[1], spec[2])
	var forward := (node_pos(spec[1]) - node_pos(spec[0])).normalized()
	var right := forward.cross(Vector3.UP)
	var side := float(spec[3])
	var frame := material(Color(0.1, 0.1, 0.1))
	var hinge := Node3D.new()
	hinge.position = at + right * side * (WIDTH * 0.5 - 0.02) - forward * 0.55
	hinge.rotation.y = atan2(-forward.x, -forward.z)
	add_child(hinge)
	box(self, at + right * side * (WIDTH * 0.5 + 0.02) + Vector3(0, 1.1, 0), _axis_box(at, forward, 1.3, 0.08, 2.3), frame)
	var leaf := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.06, 2.1, 1.1)
	leaf.mesh = plate
	leaf.material_override = material(Color(0.3, 0.34, 0.3))
	leaf.position = Vector3(0, 1.05, -0.55)
	leaf.rotation.y = PI / 2
	hinge.add_child(leaf)
	var label := Label3D.new()
	label.text = "PHÒNG BƠM\nCHỈ NHÂN VIÊN"
	label.font_size = 28
	label.pixel_size = 0.005
	label.modulate = Color(0.95, 0.85, 0.5)
	label.position = at + right * side * (WIDTH * 0.5 - 0.06) + Vector3(0, 2.45, 0)
	label.rotation.y = atan2(-right.x * side, -right.z * side) + PI
	add_child(label)
	hinge.set_meta("side", side)
	return hinge

func _build_start_door() -> void:
	var at := node_pos("T") + Vector3(0, 0, -WIDTH * 0.5 + 0.08)
	box(self, at + Vector3(0, 1.1, 0.04), Vector3(1.3, 2.3, 0.05), material(Color(0.1, 0.1, 0.1)))
	var hinge := Node3D.new()
	hinge.name = "StairDoor"
	hinge.position = node_pos("T") + Vector3(-0.55, 0, WIDTH * 0.5 - 0.2)
	add_child(hinge)
	var leaf := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(1.1, 2.1, 0.06)
	leaf.mesh = plate
	leaf.material_override = material(Color(0.24, 0.28, 0.26))
	leaf.position = Vector3(0.55, 1.05, 0)
	hinge.add_child(leaf)
	doors.append(hinge)

func _sign(text: String, at: Vector3, facing: Vector3, color := Color(0.95, 0.88, 0.62)) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = color
	label.outline_size = 8
	label.position = at
	label.rotation.y = atan2(facing.x, facing.z)
	add_child(label)

func _build_signs() -> void:
	_sign("HẦM KỸ THUẬT · KHU A-B\n↑ BỂ CHỨA NƯỚC NGẦM", node_pos("S") + Vector3(0, 2.6, -WIDTH * 0.5 - 0.05) + Vector3(0, 0, -6), Vector3.BACK)
	_sign("← TRẠM BƠM        LỐI THOÁT HIỂM →", node_pos("A") + Vector3(0, 2.5, -WIDTH * 0.5 + 0.05), Vector3.BACK)
	_sign("LỐI LÊN SÂN SAU ↑", node_pos("C") + Vector3(-WIDTH * 0.5 + 0.05, 2.5, 0), Vector3.RIGHT)
	_sign("↑ CẦU THANG KỸ THUẬT", node_pos("L3") + Vector3(0, 2.5, WIDTH * 0.5 - 0.05), Vector3.FORWARD)
	_sign("BỂ CHỨA ↑\nNGUY HIỂM · NƯỚC SÂU", node_pos("L5") + Vector3(WIDTH * 0.5 - 0.05, 2.5, 0), Vector3.LEFT, Color(1.0, 0.5, 0.35))

# The flooded reservoir beyond X: a ledge, a long drop and black water.
func _build_reservoir() -> void:
	var x := node_pos("X")
	var rock := _textured("res://assets/polyhaven_horror/rubble_diff_1k.jpg", Color(0.32, 0.3, 0.3), 0.18)
	var floor_mat := _textured("res://assets/polyhaven_corridor/textures/concrete_floor_painted_diff.jpg", Color(0.42, 0.38, 0.36), 0.25)
	var mouth_z := x.z - WIDTH * 0.5
	var edge_z := mouth_z - 2.4
	# The ledge sticks out of the tunnel mouth over the water.
	box(self, Vector3(x.x, x.y - 0.1, mouth_z - 1.2), Vector3(WIDTH, 0.2, 2.4), floor_mat, true)
	box(self, Vector3(x.x, x.y - 0.8, edge_z - 0.05), Vector3(WIDTH, 1.4, 0.1), rock)
	water_y = x.y - WATER_DEPTH
	var hall := Vector3(x.x, water_y, mouth_z - 23.0)
	# A closed box of rock: from below the bed to above the roof, so no angle of the fall or of the
	# sink looks out past it at the tunnels hanging in the dark.
	var low := water_y - 9.0
	var high := x.y + 10.0
	var tall := high - low
	var middle := (low + high) * 0.5
	for side in [-1.0, 1.0]:
		box(self, Vector3(x.x + side * 24.0, middle, hall.z), Vector3(0.6, tall, 47.2), rock)
	box(self, Vector3(x.x, middle, mouth_z - 46.0), Vector3(48.6, tall, 0.6), rock)
	box(self, Vector3(x.x, x.y + 9.0, hall.z), Vector3(48.6, 0.6, 47.2), rock)
	# The cavern wall the tunnel opens out of: either side of the mouth, above it and below it.
	for side in [-1.0, 1.0]:
		box(self, Vector3(x.x + side * (WIDTH * 0.5 + 11.0), middle, mouth_z + 0.2), Vector3(22.0, tall, 0.4), rock)
	box(self, Vector3(x.x, (x.y + HEIGHT + high) * 0.5, mouth_z + 0.2), Vector3(WIDTH + 0.4, high - x.y - HEIGHT, 0.4), rock)
	box(self, Vector3(x.x, (low + x.y - 0.2) * 0.5, mouth_z + 0.2), Vector3(WIDTH + 0.4, x.y - 0.2 - low, 0.4), rock)
	box(self, Vector3(x.x, water_y - 8.0, hall.z), Vector3(48.6, 0.4, 47.2), material(Color(0.02, 0.03, 0.03)))
	_build_walkway(rock)
	surface = MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(48.0, 46.0)
	sheet.subdivide_width = 96
	sheet.subdivide_depth = 92
	surface.mesh = sheet
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	surface.material_override = water
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position = Vector3(x.x, water_y, hall.z)
	add_child(surface)
	underside = MeshInstance3D.new()
	underside.mesh = sheet
	var below := ShaderMaterial.new()
	below.shader = preload("res://assets/materials/reservoir_underside.gdshader")
	underside.material_override = below
	underside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underside.position = surface.position
	add_child(underside)
	splash_spray = _spray()
	add_child(splash_spray)
	for at in [Vector3(-12, 6, -10), Vector3(14, 8, -26), Vector3(0, 10, -40)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.2, 0.12)
		lamp.light_energy = 2.0
		lamp.omni_range = 22.0
		lamp.position = Vector3(x.x, water_y, edge_z) + at
		add_child(lamp)
		reservoir_lamps.append(lamp)
	# Moonlight through a drain grate high in the roof: a pale pool on the water to aim for.
	var grate := SpotLight3D.new()
	grate.light_color = Color(0.62, 0.76, 0.92)
	grate.light_energy = 5.0
	grate.spot_range = 40.0
	grate.spot_angle = 22.0
	grate.shadow_enabled = false
	grate.position = Vector3(x.x + 2.0, x.y + 8.6, mouth_z - 12.0)
	grate.rotation.x = -PI / 2
	add_child(grate)
	reservoir_lamps.append(grate)
	var shaft := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 5.5
	cone.height = WATER_DEPTH + 8.4
	cone.cap_top = false
	cone.cap_bottom = false
	shaft.mesh = cone
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.albedo_color = Color(0.5, 0.65, 0.8, 0.016)
	# Fogged, the faint cone turned into a solid pale wedge across the view.
	haze.disable_fog = true
	shaft.material_override = haze
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = Vector3(x.x + 2.0, water_y + cone.height * 0.5, mouth_z - 12.0)
	add_child(shaft)
	var bars := material(Color(0.05, 0.05, 0.05))
	for k in range(5):
		box(self, Vector3(x.x + 1.0 + k * 0.5, x.y + 8.7, mouth_z - 12.0), Vector3(0.08, 0.1, 1.8), bars)
	ledge_light = SpotLight3D.new()
	ledge_light.light_color = Color(1.0, 0.93, 0.78)
	ledge_light.light_energy = 6.0
	ledge_light.spot_range = 30.0
	ledge_light.spot_angle = 14.0
	ledge_light.hide()
	add_child(ledge_light)
	bubble_cloud = CPUParticles3D.new()
	bubble_cloud.amount = 60
	bubble_cloud.lifetime = 2.2
	bubble_cloud.emitting = false
	bubble_cloud.direction = Vector3.UP
	bubble_cloud.spread = 25
	bubble_cloud.gravity = Vector3(0, 2.5, 0)
	bubble_cloud.initial_velocity_min = 0.6
	bubble_cloud.initial_velocity_max = 1.6
	bubble_cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubble_cloud.emission_sphere_radius = 0.6
	var bead := SphereMesh.new()
	bead.radius = 0.018
	bead.height = 0.036
	var shine := StandardMaterial3D.new()
	shine.albedo_color = Color(0.7, 0.9, 1.0, 0.55)
	shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Bubbles right against the lens would be white blobs: fade them out close up.
	shine.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	shine.distance_fade_min_distance = 0.25
	shine.distance_fade_max_distance = 0.9
	bead.material = shine
	bubble_cloud.mesh = bead
	add_child(bubble_cloud)

# The spray thrown up when the player hits the water.
func _spray() -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	spray.emitting = false
	spray.one_shot = true
	spray.amount = 160
	spray.lifetime = 1.6
	spray.explosiveness = 0.92
	spray.direction = Vector3.UP
	spray.spread = 38.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 9.5
	spray.gravity = Vector3(0, -9.8, 0)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.7
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.6
	var drop := SphereMesh.new()
	drop.radius = 0.028
	drop.height = 0.056
	drop.radial_segments = 6
	drop.rings = 3
	# Opaque, so from under the water the surface hides them.
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.8, 0.87, 0.9)
	white.emission_enabled = true
	white.emission = Color(0.4, 0.45, 0.5)
	drop.material = white
	spray.mesh = drop
	return spray

func ledge_z() -> float:
	return node_pos("X").z - WIDTH * 0.5 - 2.4

# The near end of the broken walkway across the gap.
func far_z() -> float:
	return ledge_z() - LEAP_GAP

# Past the gap, what is left of a maintenance walkway runs on under the moonlit drain grate, where a
# ladder goes up to it: the way out the player jumps for. Its near end is the slab that breaks off.
func _build_walkway(rock: Material) -> void:
	var x := node_pos("X")
	var near := far_z()
	var deck := _textured("res://assets/polyhaven_corridor/textures/concrete_floor_painted_diff.jpg", Color(0.4, 0.37, 0.35), 0.25)
	var span := 2.6
	var rest := WALKWAY
	box(self, Vector3(x.x, x.y - 0.14, near - rest * 0.5), Vector3(span, 0.28, rest), deck)
	# Jagged end where the rest of the walkway fell, and the board left hanging out of it.
	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	for i in range(5):
		var chunk := box(self, Vector3(x.x + dice.randf_range(-1.1, 1.1), x.y - 0.2, near + dice.randf_range(-0.1, 0.15)), Vector3(dice.randf_range(0.3, 0.6), 0.2, dice.randf_range(0.2, 0.4)), deck)
		chunk.rotation = Vector3(dice.randf_range(-0.5, 0.5), dice.randf() * TAU, dice.randf_range(-0.3, 0.3))
	var wood := _textured("res://assets/polyhaven_kiting/wooden_crate_01/textures/wooden_crate_01_diff_1k.jpg", Color(0.62, 0.5, 0.38), 1.2)
	# The board: a stub lying on the deck, and the part out over the gap that bends and snaps off
	# at the edge (its pivot).
	box(self, Vector3(x.x - 0.3, x.y + 0.03, near - 0.45), Vector3(0.32, 0.06, 0.9), wood)
	plank = Node3D.new()
	plank.position = Vector3(x.x - 0.3, x.y + 0.03, near)
	add_child(plank)
	plank_rest = plank.transform
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.32, 0.06, PLANK_OUT)
	board.mesh = board_mesh
	board.material_override = wood
	board.position = Vector3(0, 0, PLANK_OUT * 0.5)
	plank.add_child(board)
	var steel := material(Color(0.22, 0.22, 0.21))
	steel.metallic = 0.7
	for z in [near - 2.8, near - 6.8]:
		box(self, Vector3(x.x, (water_y - 8.0 + x.y - 0.28) * 0.5, z), Vector3(0.7, x.y - 0.28 - water_y + 8.0, 0.7), rock)
	for side in [-1.0, 1.0]:
		for k in range(4):
			box(self, Vector3(x.x + side * (span * 0.5 - 0.06), x.y + 0.5, near - 1.6 - k * 2.0), Vector3(0.05, 1.0, 0.05), steel)
		box(self, Vector3(x.x + side * (span * 0.5 - 0.06), x.y + 1.0, near - 1.1 - rest * 0.5), Vector3(0.05, 0.05, rest), steel)
	# The ladder up to the grate.
	var foot_z := near - WALKWAY + 0.35
	var climb := 8.7
	for side in [-1.0, 1.0]:
		box(self, Vector3(x.x + side * 0.28, x.y + climb * 0.5, foot_z), Vector3(0.06, climb, 0.06), steel)
	for k in range(int(climb / 0.35)):
		box(self, Vector3(x.x, x.y + 0.3 + k * 0.35, foot_z), Vector3(0.56, 0.04, 0.04), steel)
	_sign("LỐI LÊN MẶT ĐẤT ↑", Vector3(x.x, x.y + 2.6, foot_z - 0.1), Vector3.BACK, Color(0.55, 1.0, 0.6))
	var green := OmniLight3D.new()
	green.light_color = Color(0.4, 1.0, 0.5)
	green.light_energy = 1.4
	green.omni_range = 6.0
	green.position = Vector3(x.x, x.y + 2.2, foot_z + 0.6)
	add_child(green)
	reservoir_lamps.append(green)
	splinters = CPUParticles3D.new()
	splinters.emitting = false
	splinters.one_shot = true
	splinters.amount = 22
	splinters.lifetime = 1.4
	splinters.explosiveness = 0.9
	splinters.direction = Vector3.DOWN
	splinters.spread = 60.0
	splinters.initial_velocity_min = 0.5
	splinters.initial_velocity_max = 2.4
	splinters.gravity = Vector3(0, -9.8, 0)
	splinters.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splinters.emission_box_extents = Vector3(0.16, 0.03, 0.1)
	var grit := BoxMesh.new()
	grit.size = Vector3(0.008, 0.008, 0.045)
	var chip := material(Color(0.6, 0.48, 0.34))
	# Right under the board a splinter would fill the screen: fade them out close to the eye.
	chip.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	chip.distance_fade_min_distance = 0.3
	chip.distance_fade_max_distance = 0.9
	grit.material = chip
	splinters.mesh = grit
	add_child(splinters)

# --- Run ---

func start() -> void:
	build()
	reset()
	active = true
	show()
	for body in bodies: body.collision_layer = 1
	_close_push_doors()
	var p: CharacterBody3D = world.player
	previous_flashlight = p.flashlight.visible
	p.flashlight.show()
	p.camera.far = 120
	p.stamina = p.MAX_STAMINA
	p.sprint_exhausted = false
	music_bed.play()
	music.play()
	breathing.play()
	_restart_at(0)

var previous_flashlight := false

func reset() -> void:
	active = false
	clock = 0.0
	speed = 0.0
	lane_x = 0.0
	slide_remaining = 0.0
	slide_cooldown = 0.0
	stumble_remaining = 0.0
	obstacle_cooldown = 0.0
	hit_count = 0
	held_keys.clear()
	fade_clock = 0.0
	state = "run"
	state_clock = 0.0
	checkpoint = 0
	at_ledge = false
	pit_fall = false
	hanging = false
	climb_push = 0.0
	fall_drift = -2.0
	scripted_guard = false
	guard_on = false
	door_clock = -1.0
	if guard != null: guard.vanish()
	if built:
		chute.reset()
		for body in bodies: body.collision_layer = 0
		for door in doors: door.rotation.y = atan2(-0.0, -1.0) if door.name == "StairDoor" else door.rotation.y
		_close_doors()
		_close_push_doors()
		_reset_plank()
		ledge_light.hide()
		bubble_cloud.emitting = false
	if fx != null: fx.hide_all()
	_go_under(false)
	if water_tint != null:
		water_tint.hide()
		water_tint.color.a = 0.0
	if hint != null: hint.text = ""
	for audio in [music, music_bed, breathing, chase_steps, snarls, underwater, bubbles, splash]:
		if audio != null: audio.stop()
	hide()

func _close_doors() -> void:
	for door in doors:
		if door.has_meta("open_from"): door.rotation.y = door.get_meta("open_from")
		else: door.set_meta("open_from", door.rotation.y)

func _open_door(index: int) -> void:
	var door: Node3D = doors[index]
	if not door.has_meta("open_from"): door.set_meta("open_from", door.rotation.y)
	var swing := -1.6 * float(door.get_meta("side", 1.0))
	create_tween().tween_property(door, "rotation:y", float(door.get_meta("open_from")) + swing, 0.25)
	fx.impact(to_global(door.position + Vector3.UP), "door")

func _restart_at(index: int) -> void:
	var p: CharacterBody3D = world.player
	var spot: Dictionary = CHECKPOINTS[index]
	checkpoint = index
	cutoffs_left = spot.cutoffs.duplicate()
	_close_doors()
	_close_push_doors()
	_reset_plank()
	restore_pose()
	p.global_position = to_global(spot.at + Vector3.UP * 0.05)
	var toward: Vector3 = node_pos(spot.toward) - spot.at
	p.rotation.y = atan2(-toward.x, -toward.z)
	p.velocity = Vector3.ZERO
	p.flashlight.show()
	p.camera.far = 120
	p.stamina = p.MAX_STAMINA
	speed = 0.0
	slide_remaining = 0.0
	stumble_remaining = 0.0
	state = "run"
	at_ledge = false
	pit_fall = false
	hanging = false
	scripted_guard = false
	fall_drift = -2.0
	hint.text = ""
	if spot.guard == null:
		_guard_off()
	elif spot.get("door", false):
		# He follows the player down: the stair door behind bursts open a moment in.
		_guard_off()
		# The first time he is a few seconds behind; after a catch he is straight through the door.
		door_clock = DOOR_START if clock < 1.0 else 0.8
	else:
		_guard_at(spot.guard, 0.6)

func _guard_off() -> void:
	guard_on = false
	guard.vanish()
	chase_steps.stop()

func _guard_at(at: Vector3, pause: float) -> void:
	guard_on = true
	guard_pos = at
	guard_wait = pause
	guard_side = 0.0
	var p: CharacterBody3D = world.player
	var to := to_local(p.global_position) - at
	guard_yaw = atan2(-to.x, -to.z)
	guard.appear(to_global(at), p.global_position)
	shout_clock = 1.5

func held(code: int) -> bool:
	return held_keys.get(code, Input.is_physical_key_pressed(code))

func jump() -> bool:
	if chute.active or state != "run" or not world.player.is_on_floor() or slide_remaining > 0: return false
	world.player.velocity.y = JUMP_VELOCITY
	return true

func slide() -> bool:
	if chute.active or state != "run" or speed < SLIDE_MIN_SPEED or not world.player.is_on_floor() or slide_remaining > 0 or slide_cooldown > 0: return false
	slide_remaining = 0.95
	slide_cooldown = 1.15
	world.soundscape.cue("paper", -18)
	return true

func obstacle_hit() -> void:
	if obstacle_cooldown > 0: return
	hit_count += 1
	obstacle_cooldown = 0.9
	stumble_remaining = 0.55
	world.player.invulnerable_time = 0
	world.player.take_damage(6)
	world.player.startle = 0.85
	world.soundscape.cue("chair_impact", -9)

func restore_pose() -> void:
	var p: CharacterBody3D = world.player
	p.get_node("Collision").shape.height = 1.75
	p.get_node("Collision").position.y = 0.9
	p.camera.position = Vector3(0, 1.62, 0)
	p.camera.fov = 73
	p.camera.far = 400
	p.camera.h_offset = 0
	p.camera.v_offset = 0
	p.camera.rotation = Vector3.ZERO
	p.rotation = Vector3.ZERO
	p.velocity = Vector3.ZERO

# Called by the drain slide once the rider comes out at the bottom.
func chute_landed(_index: int) -> void:
	var p: CharacterBody3D = world.player
	restore_pose()
	var spot: Dictionary = CHECKPOINTS[2]
	p.global_position = to_global(spot.at + Vector3.UP * 0.6)
	var toward: Vector3 = node_pos(spot.toward) - spot.at
	p.rotation.y = atan2(-toward.x, -toward.z)
	p.velocity = -p.global_basis.z * WALK_SPEED
	checkpoint = 2
	cutoffs_left = spot.cutoffs.duplicate()
	fx.flash.color = Color(0, 0, 0, 1)
	fx.impact(p.global_position, "topple")
	story.subtitle("Bác bảo vệ", "Tao biết ống đó chảy xuống đâu! Đợi đấy!", 2.6)

func tick(delta: float) -> void:
	if not active or not world.simulation_active(): return
	clock += delta
	fx.tick(delta)
	if fade_clock > 0.0:
		_tick_fade(delta)
		return
	match state:
		"drown":
			_tick_drown(delta)
			return
		"fall":
			_tick_fall(delta)
			return
		"leap":
			_tick_leap(delta)
			_tick_lights()
			return
	if chute.active:
		chute.tick(delta)
		return
	_move(delta)
	if state != "run" or chute.active: return
	_tick_story(delta)
	_tick_guard(delta)
	_tick_lights()
	_breathe(delta)

func _move(delta: float) -> void:
	var p: CharacterBody3D = world.player
	slide_cooldown = maxf(0, slide_cooldown - delta)
	slide_remaining = maxf(0, slide_remaining - delta)
	stumble_remaining = maxf(0, stumble_remaining - delta)
	obstacle_cooldown = maxf(0, obstacle_cooldown - delta)
	if held(KEY_CTRL) and slide_remaining <= 0 and slide_cooldown <= 0: slide()
	var direction := Vector2(float(held(KEY_D)) - float(held(KEY_A)), float(held(KEY_S)) - float(held(KEY_W)))
	var moving := direction.length() > 0
	if p.stamina <= 0.1: p.sprint_exhausted = true
	if p.stamina > 20: p.sprint_exhausted = false
	var sprinting: bool = held(KEY_SHIFT) and moving and not p.sprint_exhausted
	p.stamina = clampf(p.stamina + (-SPRINT_DRAIN if sprinting else 12.0) * delta, 0, p.MAX_STAMINA)
	var wanted := RUN_SPEED if sprinting else WALK_SPEED
	if slide_remaining > 0: wanted = maxf(wanted, RUN_SPEED)
	if stumble_remaining > 0: wanted *= 0.25
	var vector := p.basis * Vector3(direction.x, 0, direction.y).normalized() * wanted
	var grip := 26.0 if p.is_on_floor() else 5.0
	p.velocity.x = move_toward(p.velocity.x, vector.x, delta * grip)
	p.velocity.z = move_toward(p.velocity.z, vector.z, delta * grip)
	if not p.is_on_floor(): p.velocity.y -= GRAVITY * delta
	elif p.velocity.y < 0: p.velocity.y = -0.5
	var capsule: CollisionShape3D = p.get_node("Collision")
	if slide_remaining <= 0 and capsule.shape.height < 1 and not p.can_fit(p.global_position): slide_remaining = 0.05
	capsule.shape.height = 0.68 if slide_remaining > 0 else 1.75
	capsule.position.y = 0.36 if slide_remaining > 0 else 0.9
	p.move_and_slide()
	speed = Vector2(p.velocity.x, p.velocity.z).length()
	for i in range(p.get_slide_collision_count()):
		var collision: KinematicCollision3D = p.get_slide_collision(i)
		var body: Object = collision.get_collider()
		if body is Node and body.has_meta("chase_hazard") and collision.get_normal().y < 0.65: obstacle_hit()
	p.camera.position.y = 0.52 if slide_remaining > 0 else 1.62 + sin(clock * 15) * minf(1, speed / 8) * 0.035
	p.camera.fov = move_toward(p.camera.fov, (84 if sprinting else 75) + clampf(1 - guard_gap / 10, 0, 1) * 10, delta * 22)
	p.startle = maxf(0, p.startle - delta * 1.5)
	var feet := to_local(p.global_position)
	# Running into a closed door bangs it open.
	for door in push_doors:
		if door.open: continue
		var rel: Vector3 = feet - door.at
		var toward := Vector3(p.velocity.x, 0, p.velocity.z).dot(-rel.normalized())
		if absf(rel.y) < 1.5 and absf(rel.dot(door.right)) < 0.9 and absf(rel.dot(door.forward)) < DOOR_REACH and toward > 0.8:
			_shove(door, feet)
			p.held_visual.shove()
			stumble_remaining = maxf(stumble_remaining, 0.12)
	# Short of the far lip of a crack: down into the pit.
	var gap := gap_at(feet, 0.3)
	if not gap.is_empty() and feet.y < float(gap.near.y) - 1.0:
		_fell()

func _tick_story(delta: float) -> void:
	var p: CharacterBody3D = world.player
	var feet := to_local(p.global_position)
	var here := project(feet)
	if door_clock >= 0.0:
		door_clock -= delta
		if door_clock < 0.0:
			_open_door(doors.size() - 1)
			_guard_at(node_pos("T") + Vector3(0, 0, -1.0), 0.5)
			story.subtitle("Bác bảo vệ", "Đứng lại! Mày chạy đâu cho thoát!", 2.2)
	# The drain: the floor gives way under the player.
	if here.has("a") and here.a == HOLE[0] and here.b == HOLE[1] and here.t >= float(HOLE[2]) - 0.6 and feet.y > LOWER * 0.5:
		_guard_off()
		chute.enter(0)
		return
	for index in cutoffs_left.duplicate():
		var cut: Dictionary = CUTOFFS[index]
		var fire := false
		if cut.has("edge"):
			fire = here.has("a") and here.a == cut.edge[0] and here.b == cut.edge[1] and here.t >= cut.after
		else:
			fire = feet.distance_to(node_pos(cut.near)) < cut.reach
		if fire:
			cutoffs_left.erase(index)
			_open_door(index)
			var door: Array = cut.door
			_guard_at(edge_point(door[0], door[1], door[2], float(door[3]) * (WIDTH * 0.5 - 0.6)), 0.7)
			story.subtitle("Bác bảo vệ", cut.line, 2.6)
			world.player.startle = 1.0
			fx.shake = maxf(fx.shake, 0.6)
	if checkpoint == 0 and (feet.distance_to(node_pos("G")) < 5.0 or feet.distance_to(node_pos("P2")) < 5.0):
		checkpoint = 1
	if checkpoint == 2 and feet.distance_to(node_pos("L5")) < 4.0:
		checkpoint = 3
	# Near the mouth onto the reservoir the cutscene takes over.
	var x := node_pos("X")
	at_ledge = absf(feet.y - x.y) < 0.5 and Vector2(feet.x - x.x, feet.z - x.z).length() < 6.0 and feet.z < x.z + 1.0
	if at_ledge:
		_begin_leap()
		return
	hint.text = _hint_for(feet)

func _tick_guard(delta: float) -> void:
	var p: CharacterBody3D = world.player
	if not guard_on:
		guard_gap = 99.0
		return
	var feet := to_local(p.global_position)
	var points := route(guard_pos, feet)
	guard_gap = path_length(points, guard_pos)
	var pace := GUARD_PACE
	if guard_gap > RUSH_GAP: pace = GUARD_RUSH
	elif guard_gap < EASE_GAP: pace = GUARD_EASE
	if guard_wait > 0.0:
		guard_wait -= delta
		pace = 0.0
	elif guard_gap < 30.0 and shout_clock <= 0.0:
		shout_clock = randf_range(4.0, 7.0)
		story.subtitle("Bác bảo vệ", SHOUTS[randi() % SHOUTS.size()], 1.6)
		if randf() < 0.35:
			snarls.global_position = guard.global_position + Vector3.UP * 1.6
			snarls.play()
	shout_clock -= delta
	guard_speed = move_toward(guard_speed, pace, delta * 14.0)
	var left := guard_speed * delta
	var heading := Vector3.ZERO
	for point in points:
		if left <= 0.0: break
		var to: Vector3 = point - guard_pos
		to.y = point.y - guard_pos.y
		var length := to.length()
		if length < 0.001: continue
		heading = to / length
		var step := minf(left, length)
		guard_pos += heading * step
		left -= step
	if heading != Vector3.ZERO:
		guard_yaw = lerp_angle(guard_yaw, atan2(-heading.x, -heading.z), clampf(delta * 8.0, 0, 1))
	# Round crates and carts on the side they leave open.
	var dodge := 0.0
	for spot in obstacle_spots:
		if Vector2(guard_pos.x - spot.at.x, guard_pos.z - spot.at.z).length() < 2.6 and absf(guard_pos.y - spot.at.y) < 3.0: dodge = -float(spot.side) * 0.95
	guard_side = move_toward(guard_side, dodge, delta * 3.5)
	var right := Vector3(cos(guard_yaw), 0, -sin(guard_yaw))
	var body := guard_pos + right * guard_side
	# Up the stair, and over the cracks in one stride.
	body.y = ground(body)
	for door in push_doors:
		if not door.open and Vector2(body.x - door.at.x, body.z - door.at.z).length() < 1.5 and absf(body.y - door.at.y) < 1.5:
			_shove(door, body)
	guard.global_position = to_global(body)
	guard.rotation.y = guard_yaw
	var moving := guard_speed > 0.3
	guard.model.animation.play("sprint" if moving else "idle")
	guard.model.animation.speed_scale = guard_speed / CLIP_PACE if moving else 1.0
	guard.model.head_pitch = 0.05
	guard.model.hand_target = guard.global_position + Vector3.UP * 1.35 - guard.global_basis.z * 0.7 + guard.global_basis.x * 0.25
	guard.torch.rotation = Vector3(-0.1, sin(clock * 9.0) * 0.06 * minf(1.0, guard_speed / 6.0), 0)
	stride -= guard_speed * delta
	if moving and stride <= 0.0:
		stride = RUN_STRIDE
		chase_steps.global_position = guard.global_position + Vector3.UP * 0.1
		chase_steps.volume_db = -2.0
		chase_steps.play()
	if Vector2(feet.x - guard_pos.x, feet.z - guard_pos.z).length() < CATCH and absf(feet.y - body.y) < 1.5:
		_caught()

func _tick_lights() -> void:
	var feet := to_local(world.player.global_position)
	var near := lamp_points.duplicate()
	near.sort_custom(func(a, b): return a.distance_squared_to(feet) < b.distance_squared_to(feet))
	for i in range(lights.size()):
		if i < near.size():
			lights[i].position = near[i]
			lights[i].light_energy = 2.4 + sin(clock * 7.0 + i * 1.7) * 0.15

func _breathe(delta: float) -> void:
	var p: CharacterBody3D = world.player
	var strain := maxf(1.0 - p.stamina / p.MAX_STAMINA, clampf(1.0 - guard_gap / 14.0, 0, 1))
	breathing.volume_db = move_toward(breathing.volume_db, lerpf(-16, -3, strain), delta * 12)
	music.volume_db = move_toward(music.volume_db, lerpf(-20, -8, clampf(1.0 - guard_gap / 20.0, 0, 1)), delta * 12)

func _caught() -> void:
	if fade_clock > 0.0: return
	fade_clock = 1.0
	restarted = false
	world.player.startle = 1.0
	world.hit_flash = 0.6
	story.subtitle("Bác bảo vệ", "Bắt được rồi nhé!", 1.4)
	snarls.global_position = guard.global_position + Vector3.UP * 1.6
	snarls.play()

func _tick_fade(delta: float) -> void:
	fade_clock = maxf(0.0, fade_clock - delta)
	if pit_fall and not restarted:
		var p: CharacterBody3D = world.player
		p.velocity.y -= GRAVITY * delta
		p.move_and_slide()
	story.fear.fade = clampf(1.0 - absf(fade_clock - 0.5) / 0.5, 0, 1)
	if fade_clock < 0.5 and not restarted:
		restarted = true
		_restart_at(checkpoint)
	if fade_clock <= 0.0: story.fear.fade = 0.0

func _hint_for(feet: Vector3) -> String:
	var facing: Vector3 = -world.player.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	for gap in gaps:
		var centre: Vector3 = gap.near + gap.forward * gap.width * 0.5
		var rel: Vector3 = centre - feet
		var ahead := rel.dot(facing)
		if absf(rel.y) < 1.5 and ahead > 0.5 and ahead < 6.0 and absf(rel.dot(gap.right)) < WIDTH * 0.5 + 0.5 and absf(facing.dot(gap.forward)) > 0.5:
			return "SPACE · NHẢY QUA KHE NỨT"
	for door in push_doors:
		if door.open: continue
		var rel: Vector3 = door.at - feet
		if absf(rel.y) < 1.5 and rel.length() < 5.0 and rel.normalized().dot(facing) > 0.6:
			return "CHẠY THẲNG VÀO CỬA ĐỂ HÚC MỞ"
	return ""

# Short of the far lip: down into the pit, and back to the last checkpoint.
func _fell() -> void:
	if fade_clock > 0.0: return
	fade_clock = 1.0
	restarted = false
	pit_fall = true
	hint.text = ""
	world.player.startle = 1.0
	fx.impact(world.player.global_position, "topple")

# --- The cutscene at the reservoir ---
# Out to the edge and stop dead; look down at the water a long way below; turn round to him coming;
# turn back, back up for a run, run and jump; fall short and catch the board sticking out of the
# broken walkway; it bends, and snaps.

func _begin_leap() -> void:
	var p: CharacterBody3D = world.player
	state = "leap"
	leap_beat = "approach"
	beat_clock = 0.0
	hanging = false
	climb_push = 0.0
	hint.text = ""
	leap_from = to_local(p.global_position)
	leap_yaw = p.rotation.y
	p.velocity = Vector3.ZERO
	slide_remaining = 0.0
	restore_pose()
	p.global_position = to_global(leap_from)
	p.rotation.y = leap_yaw
	p.camera.far = 120
	# He is taken off the chase and walked in by hand: in sight when the player turns, never close enough to catch.
	var x := node_pos("X")
	var behind: Vector3 = guard_pos if guard_on else x + Vector3(0, 0, 16)
	cut_guard = Vector3(x.x + 0.4, x.y, clampf(behind.z, x.z + 9.0, x.z + 18.0))
	if not guard_on: guard.appear(to_global(cut_guard), p.global_position)
	guard_on = false
	scripted_guard = true

func _beat(next: String) -> void:
	leap_beat = next
	beat_clock = 0.0

func plank_tip() -> Vector3:
	return plank.transform * Vector3(0, 0, PLANK_OUT)

func _tick_leap(delta: float) -> void:
	var p: CharacterBody3D = world.player
	var x := node_pos("X")
	beat_clock += delta
	var edge_spot := Vector3(x.x, x.y, ledge_z() + 0.45)
	var run_from := Vector3(x.x, x.y, ledge_z() + 3.8)
	var length: float = BEATS.get(leap_beat, 1.0)
	var s := clampf(beat_clock / length, 0.0, 1.0)
	var smooth := smoothstep(0.0, 1.0, s)
	_tick_cut_guard(delta)
	match leap_beat:
		"approach":
			var here := to_local(p.global_position)
			var to := edge_spot - here
			to.y = 0.0
			var pace := clampf(to.length() * 3.0 + 1.5, 1.5, RUN_SPEED)
			here += to.limit_length(pace * delta)
			p.global_position = to_global(Vector3(here.x, x.y, here.z))
			p.rotation.y = lerp_angle(p.rotation.y, 0.0, clampf(delta * 7.0, 0, 1))
			p.camera.rotation.x = lerp_angle(p.camera.rotation.x, 0.0, clampf(delta * 5.0, 0, 1))
			p.camera.position.y = 1.62 + sin(clock * 15) * 0.03
			if to.length() < 0.05:
				p.rotation.y = 0.0
				p.startle = 0.7
				fx.shake = maxf(fx.shake, 0.3)
				world.soundscape.cue("paper", -12)
				_beat("look_down")
		"look_down":
			# Black water a long way down, and the gap to the broken walkway.
			p.camera.rotation.x = lerp_angle(p.camera.rotation.x, -1.0, clampf(delta * 3.0, 0, 1))
			p.camera.position.y = 1.62
			if s >= 1.0:
				story.subtitle("Bác bảo vệ", "Hết đường rồi! Đứng yên đó cho tao!", 2.4)
				_beat("turn_back")
		"turn_back":
			p.rotation.y = PI * smooth
			p.camera.rotation.x = lerpf(-1.0, -0.05, smooth)
			if s >= 1.0: _beat("watch")
		"watch":
			p.rotation.y = PI
			breathing.volume_db = move_toward(breathing.volume_db, -2.0, delta * 20.0)
			if s >= 1.0: _beat("turn_front")
		"turn_front":
			p.rotation.y = PI + PI * smooth
			p.camera.rotation.x = lerpf(-0.05, -0.12, smooth)
			if s >= 1.0:
				p.rotation.y = 0.0
				_beat("back_up")
		"back_up":
			# A few steps back from the edge to get a run at it.
			p.global_position = to_global(edge_spot.lerp(run_from, smooth))
			p.camera.position.y = 1.62 + sin(beat_clock * 9.0) * 0.02
			if s >= 1.0:
				story.subtitle("", "Phải nhảy thôi...", 1.2)
				_beat("run_up")
		"run_up":
			var takeoff := Vector3(x.x, x.y, ledge_z() + 0.1)
			p.global_position = to_global(run_from.lerp(takeoff, s * s * 0.4 + s * 0.6))
			p.camera.position.y = 1.62 + sin(beat_clock * 22.0) * 0.045
			p.camera.fov = move_toward(p.camera.fov, 86.0, delta * 30.0)
			if s >= 1.0:
				world.soundscape.cue("paper", -10)
				_beat("leap")
		"leap":
			# Out over the gap, short of the walkway: down onto the end of the board.
			var takeoff := Vector3(x.x, x.y, ledge_z() + 0.1)
			var grab := _hang_spot()
			var at := takeoff.lerp(grab, s)
			at.y = lerpf(takeoff.y, grab.y, s * s) + sin(PI * s) * 0.75
			p.global_position = to_global(at)
			p.camera.rotation.x = lerp_angle(-0.12, _hang_pitch(), smooth)
			p.camera.fov = move_toward(p.camera.fov, 78.0, delta * 20.0)
			if s >= 1.0:
				hanging = true
				p.startle = 1.0
				fx.impact(to_global(plank_tip()), "topple")
				fx.shake = maxf(fx.shake, 0.8)
				splinters.position = plank_tip()
				splinters.restart()
				splinters.emitting = true
				plank.rotation.x = 0.06
				p.held_visual.grab_with_right_hand()
				# His torch from the edge on the board and the hand on it.
				var torch_at := Vector3(x.x + 0.7, x.y + 1.5, ledge_z() + 1.2)
				ledge_light.look_at_from_position(to_global(torch_at), to_global(plank_tip()), Vector3.UP)
				ledge_light.light_energy = 4.0
				ledge_light.show()
				story.subtitle("Bác bảo vệ", "Đừng! Tấm ván đó mục rồi!", 2.0)
				_beat("hang")
		"hang":
			climb_push = move_toward(climb_push, 0.0, delta * 1.8)
			plank.rotation.x = 0.06 + beat_clock * 0.14 + sin(beat_clock * 31.0) * 0.012 * minf(1.0, beat_clock * 2.0)
			p.global_position = to_global(_hang_spot() + Vector3.UP * climb_push * 0.22)
			p.rotation.y = 0.0
			p.camera.rotation.x = lerp_angle(p.camera.rotation.x, _hang_pitch(), clampf(delta * 6.0, 0, 1))
			_hold_grip(true)
			hint.text = "SPACE · TRÈO LÊN!" if beat_clock < length - 0.3 else ""
			for creak in [0.55, 1.2]:
				if beat_clock >= creak and beat_clock - delta < creak:
					world.soundscape.cue("chair_impact", -14)
					fx.shake = maxf(fx.shake, 0.35)
					splinters.position = plank.transform * Vector3(0, 0, 0.05)
					splinters.restart()
					splinters.emitting = true
			if s >= 1.0: _snap_plank()

# Hanging off the end of the board, chin at the wood: the eye is put where the grab clip's hand,
# held at full reach, closes on the board's end, looking a little up along it to the walkway.
const HANG_EYE := Vector3(-0.07, -0.04, 0.35)
const HANG_PITCH := 0.32
const GRIP_HOLD := 0.45

func _hang_spot() -> Vector3:
	return plank_tip() + HANG_EYE - Vector3(0, 1.62, 0)

func _hang_pitch() -> float:
	return HANG_PITCH - plank.rotation.x

# Keeps the right hand closed on the board: the grab clip is held near its end until the board
# goes, then let run out so the flashlight comes back.
func _hold_grip(hold: bool) -> void:
	var arms: Node3D = world.player.held_visual.arms
	var player: AnimationPlayer = arms.animation
	if player.assigned_animation != arms.GRAB: return
	if not hold:
		if not player.is_playing(): player.play()
		return
	if player.is_playing() and player.current_animation_position >= player.current_animation_length * GRIP_HOLD:
		player.pause()

func climb_kick() -> void:
	if not hanging: return
	climb_push = minf(1.0, climb_push + 0.45)
	world.player.startle = maxf(world.player.startle, 0.3)

func _snap_plank() -> void:
	var p: CharacterBody3D = world.player
	hanging = false
	hint.text = ""
	_hold_grip(false)
	splinters.position = plank.transform * Vector3(0, 0, 0.05)
	splinters.restart()
	splinters.emitting = true
	fx.impact(to_global(plank.position), "topple")
	fx.shake = maxf(fx.shake, 0.9)
	if plank_tween != null: plank_tween.kill()
	plank_tween = create_tween().set_parallel()
	plank_tween.tween_property(plank, "position:y", plank.position.y - WATER_DEPTH - 3.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	plank_tween.tween_property(plank, "rotation:x", 2.4, 1.6)
	plank_tween.chain().tween_callback(plank.hide)
	p.velocity = Vector3(0, -0.5, 0.6)
	fall_drift = 0.3
	_begin_fall()

func _reset_plank() -> void:
	if plank == null: return
	if plank_tween != null: plank_tween.kill()
	plank_tween = null
	plank.transform = plank_rest
	plank.show()
	if splinters != null: splinters.emitting = false

# He comes in along the tunnel and stops a few metres off, torch on the player; when they hang
# he comes on to the edge.
func _tick_cut_guard(delta: float) -> void:
	var x := node_pos("X")
	var stop := Vector3(x.x + 0.4, x.y, x.z + 3.0)
	if leap_beat in ["leap", "hang"]: stop = Vector3(x.x + 0.7, x.y, ledge_z() + 1.4)
	var to := stop - cut_guard
	to.y = 0.0
	var pace := 4.6 if leap_beat in ["approach", "look_down", "turn_back"] else 3.6
	var moving := to.length() > 0.08
	cut_guard += to.limit_length(pace * delta)
	cut_guard.y = x.y
	var p: CharacterBody3D = world.player
	var look := to_local(p.global_position) - cut_guard
	guard_yaw = lerp_angle(guard_yaw, atan2(-look.x, -look.z), clampf(delta * 8.0, 0, 1))
	guard.global_position = to_global(cut_guard)
	guard.rotation.y = guard_yaw
	guard.model.animation.play("sprint" if moving else "idle")
	guard.model.animation.speed_scale = pace / CLIP_PACE if moving else 1.0
	guard.model.head_pitch = 0.05
	guard.model.hand_target = p.camera.global_position
	guard.torch.rotation = Vector3(-0.1, 0, 0)
	stride -= (pace if moving else 0.0) * delta
	if moving and stride <= 0.0:
		stride = RUN_STRIDE
		chase_steps.global_position = guard.global_position + Vector3.UP * 0.1
		chase_steps.play()

# --- The drop and the water ---

func _begin_fall() -> void:
	state = "fall"
	state_clock = 0.0
	hint.text = ""
	# He reaches the edge and puts his torch on the water.
	if guard_on or scripted_guard:
		guard_on = false
		scripted_guard = false
		var edge := Vector3(node_pos("X").x + 0.8, node_pos("X").y, ledge_z() + 0.6)
		guard.global_position = to_global(edge)
		guard.rotation.y = 0.0
		guard.model.animation.play("idle")
		guard.model.animation.speed_scale = 1.0
		ledge_light.position = edge + Vector3(0.2, 1.4, -0.4)
		ledge_light.look_at_from_position(to_global(ledge_light.position), to_global(ledge_light.position + Vector3(0, -1.0, -0.6)))
		ledge_light.light_energy = 6.0
		ledge_light.show()
		story.subtitle("Bác bảo vệ", "Ê!... Trời đất ơi!", 2.0)

func _tick_fall(delta: float) -> void:
	var p: CharacterBody3D = world.player
	state_clock += delta
	p.velocity.y -= GRAVITY * delta
	p.velocity.x = move_toward(p.velocity.x, 0.0, delta * 2.0)
	p.velocity.z = move_toward(p.velocity.z, fall_drift, delta * 2.0)
	p.global_position += p.velocity * delta
	# The water rushes up: the eye goes to it.
	p.camera.rotation.x = lerp_angle(p.camera.rotation.x, -0.75, clampf(delta * 2.2, 0, 1))
	p.camera.fov = move_toward(p.camera.fov, 88.0, delta * 20.0)
	if to_local(p.global_position).y <= water_y + 0.4:
		_begin_drown()

func _begin_drown() -> void:
	var p: CharacterBody3D = world.player
	state = "drown"
	state_clock = 0.0
	depth = 0.0
	swim_push = 0.0
	drown_from = to_local(p.global_position)
	drown_from.y = water_y - 1.0
	p.velocity = Vector3.ZERO
	p.flashlight.hide()
	for audio in [music, music_bed, breathing, chase_steps]: audio.stop()
	splash.volume_db = 0.0
	splash.play()
	var at_surface := to_local(p.global_position)
	at_surface.y = water_y
	splash_spray.position = at_surface
	splash_spray.restart()
	splash_spray.emitting = true
	plunge = 1.0
	p.camera.fov = 75.0
	_go_under(true)
	underwater.play()
	bubbles.play()
	water_tint.show()
	water_tint.color.a = 0.15
	fx.flash.color = Color(0.85, 0.95, 1.0, 0.85)
	fx.shake = 0.8
	bubble_cloud.emitting = true
	hint.text = "SPACE · BƠI LÊN"

# Under the water the player can still look round, and SPACE kicks for the surface, but every
# kick gains less than the water takes back: they sink slowly, the light above shrinks and dims,
# and it all goes black.
func swim_stroke() -> void:
	if state != "drown": return
	swim_push = maxf(swim_push, lerpf(0.9, 0.3, clampf(state_clock / 6.0, 0, 1)))
	bubble_cloud.restart()
	world.player.startle = maxf(world.player.startle, 0.25)

func _tick_drown(delta: float) -> void:
	var p: CharacterBody3D = world.player
	state_clock += delta
	var t := state_clock
	swim_push = move_toward(swim_push, 0.0, delta * 1.6)
	# The plunge: driven down hard by the fall for the first moment, then the slow sink.
	plunge = move_toward(plunge, 0.0, delta * 1.4)
	depth += (SINK_RATE + t * 0.04 - swim_push + plunge * 2.6) * delta
	depth = maxf(0.2, depth)
	var drift := Vector3(sin(t * 0.7) * 0.15, -depth + sin(t * 1.9) * 0.05, cos(t * 0.5) * 0.1)
	p.global_position = to_global(drown_from + drift)
	bubble_cloud.global_position = p.camera.global_position + Vector3(0, -0.9, 0) - p.camera.global_basis.z * 1.2
	# Just under, the eye goes up to the light; after that the player looks where they like.
	if t < 1.4: p.camera.rotation.x = lerp_angle(p.camera.rotation.x, 0.75, clampf(delta * 2.5, 0, 1))
	var fading := clampf((t - 1.5) / 6.0, 0, 1)
	water_tint.color.a = lerpf(0.15, 0.95, fading)
	story.fear.darkness = fading
	ledge_light.light_energy = lerpf(6.0, 0.0, fading)
	underside.material_override.set_shader_parameter("light", 1.0 - fading)
	for lamp in reservoir_lamps: lamp.light_energy = lerpf(2.0, 0.0, fading)
	if t > 6.2 and t - delta <= 6.2:
		var last := AudioStreamPlayer.new()
		last.stream = load("res://assets/audio/water/bubbles_single2.ogg")
		last.volume_db = 2.0
		add_child(last)
		last.play()
		last.finished.connect(last.queue_free)
	underwater.volume_db = lerpf(-6.0, -22.0, clampf((t - 5.0) / 3.5, 0, 1))
	bubbles.volume_db = lerpf(-10.0, -32.0, clampf((t - 4.0) / 3.0, 0, 1))
	hint.text = "SPACE · BƠI LÊN" if t < 5.5 else ""
	story.fear.fade = clampf((t - 7.6) / 0.8, 0, 1)
	if t >= DROWN_SECONDS:
		_finish()

# Under the water: thick green-black fog, the light gone dim, every sound through water.
func _go_under(under: bool) -> void:
	var environment: Environment = world.get_node("Atmosphere/MoonlitEnvironment").environment
	if under:
		saved_fog = [environment, environment.fog_enabled, environment.fog_light_color, environment.fog_density, environment.fog_light_energy, environment.fog_sky_affect, environment.fog_sun_scatter, environment.fog_aerial_perspective]
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.012, 0.06, 0.07)
		environment.fog_light_energy = 0.7
		environment.fog_density = 0.15
		environment.fog_sky_affect = 1.0
		environment.fog_sun_scatter = 0.0
		environment.fog_aerial_perspective = 0.0
		if muffle_bus < 0:
			var muffle := AudioEffectLowPassFilter.new()
			muffle.cutoff_hz = 520.0
			AudioServer.add_bus_effect(0, muffle)
			muffle_bus = AudioServer.get_bus_effect_count(0) - 1
	else:
		if not saved_fog.is_empty():
			var env: Environment = saved_fog[0]
			env.fog_enabled = saved_fog[1]
			env.fog_light_color = saved_fog[2]
			env.fog_density = saved_fog[3]
			env.fog_light_energy = saved_fog[4]
			env.fog_sky_affect = saved_fog[5]
			env.fog_sun_scatter = saved_fog[6]
			env.fog_aerial_perspective = saved_fog[7]
			saved_fog = []
		if muffle_bus >= 0 and muffle_bus < AudioServer.get_bus_effect_count(0):
			AudioServer.remove_bus_effect(0, muffle_bus)
		muffle_bus = -1

func _finish() -> void:
	_go_under(false)
	active = false
	state = "done"
	for audio in [underwater, bubbles]: audio.stop()
	world.player.flashlight.visible = previous_flashlight
	story.finish_dream()

func look(relative: Vector2) -> void:
	var p: CharacterBody3D = world.player
	if chute.active:
		chute.look(relative)
		return
	if state == "leap" and not hanging: return
	if state not in ["run", "drown", "fall", "leap"]: return
	p.rotate_y(-relative.x * p.LOOK_SENSITIVITY)
	p.camera.rotation.x = clampf(p.camera.rotation.x - relative.y * p.LOOK_SENSITIVITY, -1.2, 1.2)

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_CTRL, KEY_SPACE]:
			held_keys[code] = event.pressed
			if event.pressed and not event.echo and world.simulation_active():
				if code == KEY_SPACE:
					if state == "drown": swim_stroke()
					elif state == "leap": climb_kick()
					else: jump()
				if code == KEY_CTRL: slide()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and world.simulation_active():
		look(event.relative)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [music, music_bed, breathing, underwater, bubbles]:
		if audio != null: audio.stream_paused = paused
	if paused and guard != null and guard.visible: guard.model.animation.speed_scale = 0

func _exit_tree() -> void:
	_go_under(false)
	for audio in [music, music_bed, breathing, underwater, bubbles, splash]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null
