extends Node3D
# The dream after the red corridor. The main character sinks in the reservoir and comes up
# standing in an endless sheet of shallow water at dusk: a school floor gone under, with the
# pieces of a school left standing in it. A row of desks with nobody in them, a blackboard, an
# alarm clock the size of a house stopped at 05:52, and power poles carrying their wires towards
# the school on the horizon.
# A few steps past the classroom the floor gives way (dream_rift.gd) into a rift a hundred metres
# across with three islands left standing. Getting over it is five puzzles, each a different
# way of thinking with the same two tools, a place to stand and a camera (memory_camera.gd):
#  1. bridge1: the broken path only joins up seen from beside the desk standing alone at the lip
#     (anamorphic_bridge.gd); a photo from there makes it real.
#  2. board: on island A a long blackboard exists only in the past. A photo carries it, and it
#     lands the way it was photographed, so it has to be shot end-on to land across the gap.
#  3. leap: the next gap is longer than two boards. They have to be leapfrogged: stand on one,
#     photograph the other behind you, put it down ahead.
#  4. bridge2: another broken path, but its viewpoint (a desk hanging in the air) is out over the
#     void. The island's one board has to become a pier to stand on.
#  5. gate: chained now, open back then. A photo of then, pressed into the same view, opens it.
# R puts the current island's boards back.
#  6. lucid: through the gate the main character knows it is a dream, and the yard lets go of
#     its things (lucid_sky.gd). Weightless jumps, floating, pulling floating things into place,
#     up a spiral round the flagpole to a door standing in the clouds. Through it is waking up.
# Everything is built here from licensed assets (ASSETS.md, "Giấc mơ — mặt nước").
const Player := preload("res://scripts/dream/dream_player.gd")
const WATER := preload("res://assets/materials/dream_water.gdshader")
const SKY := "res://assets/polyhaven_dream/qwantani_dusk_2_puresky_2k.hdr"
const DESK := "res://assets/polyhaven_corridor/SchoolDesk_01/SchoolDesk_01.gltf"
const CHAIR := "res://assets/polyhaven_corridor/SchoolChair_01/SchoolChair_01.gltf"
const GATE := "res://assets/polyhaven_dream/large_iron_gate/large_iron_gate_1k.gltf"
const POLES := "res://assets/polyhaven_dream/modular_electricity_poles/modular_electricity_poles_1k.gltf"
const CLOCK := "res://assets/polyhaven_dream/alarm_clock_01/alarm_clock_01_1k.gltf"
const Rift := preload("res://scripts/dream/dream_rift.gd")
const Bridge := preload("res://scripts/dream/anamorphic_bridge.gd")
const School := preload("res://scripts/dream/dream_school.gd")
const MemoryCamera := preload("res://scripts/dream/memory_camera.gd")
const Props := preload("res://scripts/dream/dream_props.gd")
const Lucid := preload("res://scripts/dream/lucid_sky.gd")
# The flagpole the lucid spiral turns round.
const FLAGPOLE := Vector3(0, 0, -188)
# Everything stands this far into the water (the depth the floor shader draws the tiles at).
const SINK := 0.12
const GATE_AT := Vector3(0, 0, -166)
const RIFT_NEAR := -30.0
const RIFT_FAR := -129.0
# Islands A, B, C as Rect2(x_min, z_min, width, depth), on the rift's 3 m slab grid.
const ISLANDS := [Rect2(-9, -63, 18, 12), Rect2(-9, -81, 18, 12), Rect2(-9, -111, 18, 12)]
const COLLAPSE_AT := -17.0
# The one place the broken path joins up from, at standing eye height beside the lone desk.
const EYE := Vector3(-7.5, 1.6, -24.5)
# The second viewpoint hangs over the void east of island C.
const EYE2 := Vector3(12.5, 1.6, -104.0)
const POLE_Z := [-12.0, -26.0, -42.0, -57.0, -79.0, -90.0, -105.0, -120.0, -136.0, -150.0]
const POLE_X := 3.2
const SAFE_NEAR := Vector3(-6.0, 0, -25.0)
const ROUTE := [Vector3(0, 0, 6), Vector3(0, 0, -24), Vector3(0, 0, -166), Vector3(0, 0, -215)]
# The puzzles in order, the z the player has to be past (on solid ground) for each to begin,
# and where a fall puts them back.
const STAGES := ["bridge1", "board", "leap", "bridge2", "gate", "open", "lucid"]
const STAGE_FROM := {"board": -51.8, "leap": -69.8, "bridge2": -99.8, "gate": -130.0}
const SAFE := {"bridge1": Vector3(-6.0, 0.1, -25.0), "board": Vector3(0, 0.1, -53.0), "leap": Vector3(0, 0.1, -71.0),
	"bridge2": Vector3(0, 0.1, -101.0), "gate": Vector3(0, 0.1, -133.0), "open": Vector3(0, 0.1, -133.0), "lucid": Vector3(0, 0.1, -171.0)}
const BOARD_LENGTH := 8.0
const BOARD_WIDTH := 1.4
# Blackboards that can be carried in a photo: which puzzle they belong to, where they lie
# (x, z), which way their length runs (degrees from the z axis) and whether they are a memory.
const BOARDS := [
	{"stage": "board", "at": Vector2(-2.0, -57.0), "turn": 90.0, "past": true, "text": "Thứ hai · Tiết 1 · Chào cờ"},
	{"stage": "leap", "at": Vector2(-4.5, -75.0), "turn": 25.0, "past": false, "text": "Kiểm tra 15 phút"},
	{"stage": "leap", "at": Vector2(3.0, -73.0), "turn": -70.0, "past": true, "text": "Nội quy lớp học"},
	{"stage": "bridge2", "at": Vector2(-4.0, -105.0), "turn": 0.0, "past": false, "text": "Sĩ số: 42   Vắng: 1"},
]
# Where the poles in the source file stand (x) for each of its three ready-made poles.
const POLE_PRESETS := {"preset_01_": -2.5, "preset_02_": -4.5, "preset_03_": -6.5}

var player: CharacterBody3D
var environment: Environment
var water: ShaderMaterial
var ripples: Array[Vector4] = []
var next_ripple := 0
var clock := 0.0
var drop_clock := 1.0
var hud: CanvasLayer
var fade: ColorRect
var hint: Label
var music: AudioStreamPlayer
var state := "rise"
var state_time := 0.0
var rift: Node3D
var bridge: Node3D
var bridge2: Node3D
var boards: Array[Dictionary] = []
var school: Node3D
var camera: CanvasLayer
var props: Node3D
var stage := "walk"
var stage_time := 0.0
var poles: Array[Node3D] = []
var pole_bodies: Array[StaticBody3D] = []
var spans: Array[MeshInstance3D] = []
var wire_material: StandardMaterial3D
var tops: Array = []
var falling_poles: Array[Dictionary] = []
var hint_time := 0.0
var sky: Node3D
var pull_input := false
var reticle: ColorRect

func _ready() -> void:
	preload("res://scripts/game_progress.gd").mark("dream")
	ripples.resize(12)
	ripples.fill(Vector4.ZERO)
	_sky()
	_water()
	_classroom()
	_blackboard()
	_viewpoint(EYE, Vector3(0, 0, -41), false)
	_poles()
	_clock()
	rift = Rift.new()
	add_child(rift)
	rift.setup(RIFT_NEAR, RIFT_FAR, water, ISLANDS)
	rift.settled.connect(_on_settled)
	bridge = Bridge.new()
	add_child(bridge)
	var tiles: Texture2D = load("res://assets/polyhaven_school/floor_tiles_08_diff_1k.jpg")
	bridge.setup(EYE, Vector3(0, 0, RIFT_NEAR + 0.6), Vector3(0, 0, -51.6), RIFT_NEAR, -51.0, tiles)
	bridge.joined.connect(_on_joined.bind(bridge))
	bridge2 = Bridge.new()
	add_child(bridge2)
	bridge2.setup(EYE2, Vector3(0, 0, -110.4), Vector3(0, 0, RIFT_FAR - 0.6), -111.0, RIFT_FAR, tiles)
	bridge2.joined.connect(_on_joined.bind(bridge2))
	_viewpoint(EYE2, Vector3(0, 0, -120), true)
	for plan in BOARDS:
		_board(plan)
	school = School.new()
	school.position = GATE_AT
	add_child(school)
	school.build()
	props = Props.new()
	add_child(props)
	props.build(GATE_AT, RIFT_NEAR, RIFT_FAR, -School.DEPTH + 16.0)
	_sound()
	_hud()
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 0, 6)
	player.yaw = 0.0
	player.enabled = false
	player.eye = 0.25
	player.pitch = 0.9
	player.stepped.connect(func(at: Vector3) -> void:
		if at.y < 0.4: ripple(at, 1.0))
	player.landed.connect(func(at: Vector3, speed: float) -> void:
		if at.y < 0.4: ripple(at, clampf(speed / 3.0, 1.0, 3.0)))
	ripple(player.global_position, 2.5)
	sky = Lucid.new()
	sky.position = FLAGPOLE
	add_child(sky)
	sky.build(player)
	sky.reached_door.connect(_on_door)
	camera = MemoryCamera.new()
	add_child(camera)
	camera.setup(player.camera)
	camera.enabled = false
	camera.meter_source = _closeness
	camera.photo_taken.connect(_on_photo)
	camera.photo_placed.connect(_on_placed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sky() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load(SKY)
	environment.sky.sky_material = panorama
	# Turn the glow of the set sun to sit straight behind the gate.
	environment.sky_rotation = Vector3(0, deg_to_rad(-130.0), 0)
	environment.background_energy_multiplier = 0.2
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0
	environment.ssr_enabled = true
	environment.ssr_max_steps = 96
	environment.ssr_fade_in = 0.05
	environment.ssr_fade_out = 1.5
	environment.ssr_depth_tolerance = 0.6
	environment.ssao_enabled = true
	environment.ssao_radius = 0.8
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.4
	# The haze takes the colour of the sky behind it, so things fade into the horizon instead of grey.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0026
	environment.fog_aerial_perspective = 1.0
	environment.fog_sky_affect = 0.0
	# Below the floor the haze thickens fast, so the rift has no bottom.
	environment.fog_height = -1.5
	environment.fog_height_density = 0.22
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	preload("res://scripts/game_settings.gd").track(environment)
	var holder := WorldEnvironment.new()
	holder.environment = environment
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-7, 180, 0)
	sun.light_color = Color(1.0, 0.72, 0.62)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	# The sun sits behind the school; a weak warm fill from the player's back keeps its faces readable.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 20, 0)
	fill.light_color = Color(1.0, 0.8, 0.72)
	fill.light_energy = 0.45
	fill.light_specular = 0.0
	add_child(fill)

func _water() -> void:
	water = ShaderMaterial.new()
	water.shader = WATER
	water.set_shader_parameter("tile_albedo", load("res://assets/polyhaven_school/floor_tiles_08_diff_1k.jpg"))
	water.set_shader_parameter("depth", SINK)
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	var surface := MeshInstance3D.new()
	surface.mesh = plane
	surface.material_override = water
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

func ripple(at: Vector3, strength: float) -> void:
	ripples[next_ripple] = Vector4(at.x, at.z, clock, strength)
	next_ripple = (next_ripple + 1) % ripples.size()

func _place(file: String, at: Vector3, turn_deg := 0.0, size := 1.0, sink := SINK) -> Node3D:
	var node: Node3D = load(file).instantiate()
	node.position = at - Vector3(0, sink, 0)
	node.rotation_degrees.y = turn_deg
	node.scale = Vector3.ONE * size
	add_child(node)
	return node

func _solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at + Vector3(0, size.y / 2, 0)
	add_child(body)
	return body

# Four rows of three, facing a blackboard, every seat empty. The last row has a gap.
func _classroom() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	for row in range(4):
		for column in range(3):
			if row == 3 and column == 0:
				continue
			var at := Vector3((column - 1) * 1.6, 0, -row * 1.5)
			var skew := rng.randf_range(-4.0, 4.0)
			_place(DESK, at, 180.0 + skew)
			_solid(at, Vector3(0.75, 0.8, 0.6))
			var chair := _place(CHAIR, at + Vector3(rng.randf_range(-0.08, 0.08), 0, 0.62), 180.0 + skew + rng.randf_range(-8.0, 8.0))
			if row == 1 and column == 2:
				# Pushed back hard and left on its side.
				chair.position += Vector3(0.3, 0.2, 0.55)
				chair.rotation_degrees = Vector3(0, 140, 82)

func _blackboard() -> void:
	var board := Node3D.new()
	board.position = Vector3(0, 0, -6.6)
	add_child(board)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.36, 0.25, 0.17)
	frame.roughness = 0.7
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color(0.12, 0.2, 0.16)
	slate.roughness = 0.92
	_box(board, Vector3(3.4, 1.3, 0.06), Vector3(0, 1.75, 0), slate)
	_box(board, Vector3(3.56, 0.08, 0.1), Vector3(0, 2.44, 0), frame)
	_box(board, Vector3(3.56, 0.08, 0.16), Vector3(0, 1.06, 0.03), frame)
	for side in [-1.0, 1.0]:
		_box(board, Vector3(0.08, 2.5, 0.1), Vector3(side * 1.74, 1.2 - SINK, 0), frame)
	var chalk := Label3D.new()
	chalk.text = "Sĩ số: 42\nVắng: 1"
	chalk.font = load("res://assets/fonts/Grenze-Variable.ttf")
	chalk.font_size = 64
	chalk.pixel_size = 0.0035
	chalk.modulate = Color(0.92, 0.92, 0.88, 0.85)
	chalk.outline_size = 0
	chalk.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chalk.position = Vector3(-0.9, 1.85, 0.035)
	chalk.rotation_degrees.y = 0.0
	board.add_child(chalk)
	_solid(board.position, Vector3(3.6, 2.5, 0.2))

# A desk and chair standing alone mark a viewpoint: beside it, at standing eye height, is where
# a broken path lines up. The first is the desk missing from the classroom's last row, at the
# lip of the rift. The second hangs in the air over the void and cannot be walked to.
func _viewpoint(eye: Vector3, target: Vector3, in_air: bool) -> void:
	var facing := atan2(target.x - eye.x, target.z - eye.z)
	# Desks face their local +Z. Put it to the side of the eye and a step back from it.
	# on the side away from the path, so it never stands in the view.
	var right := Vector3(-cos(facing), 0, sin(facing))
	var at := eye + right * (-0.9 if eye.x < target.x else 0.9) - Vector3(sin(facing), 0, cos(facing)) * 0.9
	at.y = 0.0
	_place(DESK, at, rad_to_deg(facing), 1.0, 0.0 if in_air else SINK)
	_place(CHAIR, at + Vector3(0, 0, -0.62).rotated(Vector3.UP, facing), rad_to_deg(facing), 1.0, 0.0 if in_air else SINK)
	if not in_air:
		_solid(at, Vector3(0.75, 0.8, 0.75))

# A long classroom blackboard lying flat, its length along local Z. It is the one kind of thing
# a photo can carry (group "dream_movable", only while its puzzle is the current one).
func _board(plan: Dictionary) -> void:
	var board := Node3D.new()
	board.position = Vector3(plan.at.x, 0.0, plan.at.y)
	board.rotation_degrees.y = plan.turn
	add_child(board)
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color(0.1, 0.19, 0.15)
	slate.roughness = 0.9
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.17)
	wood.roughness = 0.7
	_box(board, Vector3(BOARD_WIDTH, 0.07, BOARD_LENGTH), Vector3(0, 0.005, 0), slate)
	for side in [-1.0, 1.0]:
		_box(board, Vector3(0.07, 0.1, BOARD_LENGTH + 0.14), Vector3(side * (BOARD_WIDTH / 2 + 0.035), 0.01, 0), wood)
		_box(board, Vector3(BOARD_WIDTH, 0.1, 0.07), Vector3(0, 0.01, side * (BOARD_LENGTH / 2 + 0.035)), wood)
	var chalk := Label3D.new()
	chalk.text = plan.text
	chalk.font = load("res://assets/fonts/Grenze-Variable.ttf")
	chalk.font_size = 72
	chalk.pixel_size = 0.005
	chalk.modulate = Color(0.92, 0.92, 0.88, 0.8)
	chalk.outline_size = 0
	chalk.rotation_degrees = Vector3(-90, 90, 0)
	chalk.position = Vector3(0, 0.045, 0)
	board.add_child(chalk)
	# Generous at the ends, so a board put down a hand's width short of a lip still carries.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BOARD_WIDTH + 0.14, 0.08, BOARD_LENGTH + 0.9)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 0.0
	board.add_child(body)
	board.set_meta("footprint", Vector2(BOARD_WIDTH / 2 + 0.3, BOARD_LENGTH / 2 + 0.5))
	if plan.past:
		MemoryCamera.make_past(board)
	boards.append({"node": board, "home": board.transform, "past": plan.past, "stage": plan.stage})

# Only the current puzzle's boards can be carried; R puts them back as they were.
func _arm_boards() -> void:
	for board in boards:
		var node: Node3D = board.node
		if board.stage == stage:
			node.add_to_group("dream_movable")
		elif node.is_in_group("dream_movable"):
			node.remove_from_group("dream_movable")

func reset_boards() -> void:
	for board in boards:
		if board.stage != stage:
			continue
		var node: Node3D = board.node
		node.transform = board.home
		if board.past:
			MemoryCamera.make_past(node)
		else:
			MemoryCamera.make_real(node)
	camera.photo = {}
	camera.holding = false
	# Never leave the player standing on a board that just went home.
	player.velocity = Vector3.ZERO
	player.global_position = SAFE[stage]
	_say("Mọi thứ trở về chỗ cũ.")

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node

# A pole from the source file: the whole file is loaded once per pole and only the parts of one
# ready-made pole are kept, moved to stand at the origin.
func _pole(prefix: String) -> Node3D:
	var source: Node3D = load(POLES).instantiate()
	var pole := Node3D.new()
	for child in source.find_children(prefix + "*", "Node3D", true, false):
		var copy: Node3D = child.duplicate()
		copy.transform = child.transform
		copy.position.x -= POLE_PRESETS[prefix]
		pole.add_child(copy)
	source.free()
	return pole

# One line of poles from the classroom to the school. The two that stand where the rift opens
# go down with the floor, and the wires to them are left hanging over the edge.
func _poles() -> void:
	var prefixes := POLE_PRESETS.keys()
	wire_material = StandardMaterial3D.new()
	wire_material.albedo_color = Color(0.04, 0.04, 0.05)
	wire_material.roughness = 0.5
	var side := Vector3.RIGHT
	for i in range(POLE_Z.size()):
		var at := Vector3(POLE_X, 0, POLE_Z[i])
		var pole := _pole(prefixes[i % prefixes.size()])
		pole.position = at - Vector3(0, SINK, 0)
		# The cross-arm runs across the line, so the wires run along it.
		pole.rotation.y = atan2(side.x, side.z) - PI / 2
		pole.rotation_degrees.z = (i % 3 - 1) * 1.5
		add_child(pole)
		poles.append(pole)
		pole_bodies.append(_solid(at, Vector3(0.2, 6.0, 0.2)))
		var arm := Vector3(0, 0, 0.5)
		tops.append([at + Vector3(0, 5.72, 0) - arm, at + Vector3(0, 5.72, 0) + arm, at + Vector3(0, 4.55, 0)])
	for i in range(POLE_Z.size() - 1):
		spans.append(_span(tops[i], tops[i + 1], false))

func _span(from: Array, to: Array, hanging: bool) -> MeshInstance3D:
	var wires := SurfaceTool.new()
	wires.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		if hanging:
			# Snapped at the far end: hangs down the face of the rift.
			_wire(wires, from[k], from[k] + (to[k] - from[k]).normalized() * 2.5 + Vector3(0, -14.0 - k * 2.0, 0), 0.4)
		else:
			_wire(wires, from[k], to[k], 0.9 + k * 0.15)
	wires.generate_normals()
	var holder := MeshInstance3D.new()
	holder.mesh = wires.commit()
	holder.material_override = wire_material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)
	return holder

func _in_void(z: float) -> bool:
	return z < RIFT_NEAR and z > RIFT_FAR and not rift.on_island(POLE_X, z)

func _drop_poles() -> void:
	for i in range(POLE_Z.size()):
		if _in_void(POLE_Z[i]):
			falling_poles.append({"pole": poles[i], "delay": 0.6 + falling_poles.size() * 0.5, "speed": 0.0, "tilt": 0.0})
			pole_bodies[i].queue_free()
	for i in range(spans.size()):
		var a: float = POLE_Z[i]
		var b: float = POLE_Z[i + 1]
		var a_gone := _in_void(a)
		var b_gone := _in_void(b)
		if a_gone or b_gone:
			spans[i].queue_free()
			if not a_gone:
				_span(tops[i], tops[i + 1], true)
			elif not b_gone:
				_span(tops[i + 1], tops[i], true)

# A sagging cable as a thin four-sided tube.
func _wire(tool: SurfaceTool, from: Vector3, to: Vector3, sag: float) -> void:
	const SEGMENTS := 18
	const R := 0.012
	var points: Array[Vector3] = []
	for s in range(SEGMENTS + 1):
		var t := s / float(SEGMENTS)
		points.append(from.lerp(to, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	var along := (to - from).normalized()
	var across := along.cross(Vector3.UP).normalized()
	var offsets := [Vector3.UP * R, across * R, -Vector3.UP * R, -across * R]
	for s in range(SEGMENTS):
		for k in range(4):
			var a: Vector3 = offsets[k]
			var b: Vector3 = offsets[(k + 1) % 4]
			tool.add_vertex(points[s] + a)
			tool.add_vertex(points[s + 1] + a)
			tool.add_vertex(points[s + 1] + b)
			tool.add_vertex(points[s] + a)
			tool.add_vertex(points[s + 1] + b)
			tool.add_vertex(points[s] + b)

# An alarm clock as tall as a house, fallen on its back and half drowned, hands on 05:52.
func _clock() -> void:
	var clock_node := _place(CLOCK, Vector3(-30, 0, -146), 35.0, 34.0, 0.9)
	clock_node.rotation_degrees.x = -14.0
	# The source glass is a dark tinted texture; blown up to this size it hides the dial completely.
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(1, 1, 1, 0.06)
	glass.roughness = 0.04
	glass.metallic_specular = 0.8
	var body: MeshInstance3D = clock_node.find_child("alarm_clock_01", true, false)
	body.set_surface_override_material(1, glass)
	# Stop the hands at 05:52, the minute the main character wakes up. The source pose reads 4:50
	# (hour hand on 5, minute hand on 10); turn each about the dial's axis by the difference.
	var axis := (body.basis * Vector3.RIGHT).normalized()
	var turns := {"houd_hand": deg_to_rad(5.0 / 6.0 * 30.0 + 2.0 * 0.5), "minute_hand": deg_to_rad(12.0), "second_hand": 0.0}
	for hand_name in turns:
		var hand: Node3D = clock_node.find_child(hand_name, true, false)
		hand.basis = Basis(axis, -turns[hand_name]) * hand.basis
	_solid(Vector3(-30, 0, -146), Vector3(5.0, 4.0, 3.5))
	# The sun is behind it; a faint glow from the dial keeps the time readable against the light.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.9, 0.78)
	glow.light_energy = 2.5
	glow.omni_range = 9.0
	glow.light_specular = 0.0
	add_child(glow)
	glow.global_position = clock_node.global_position + clock_node.global_basis.z.normalized() * 5.0 + Vector3(0, 3.0, 0)

func _sound() -> void:
	music = AudioStreamPlayer.new()
	var loop: AudioStreamOggVorbis = load("res://assets/music/dream_ambient.ogg")
	loop.loop = true
	music.stream = loop
	music.volume_db = -40
	add_child(music)
	music.play()

func _hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 80
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.add_theme_font_size_override("font_size", 20)
	hint.modulate.a = 0.0
	hud.add_child(hint)
	# A small soft dot to aim pulls with, shown only once the dream is lucid.
	reticle = ColorRect.new()
	reticle.color = Color(1, 0.95, 0.85, 0.55)
	reticle.size = Vector2(5, 5)
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = -reticle.size / 2
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.visible = false
	hud.add_child(reticle)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.02, 0.03, 0.05, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and state != "leave":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		if state == "walk" and stage in ["board", "leap", "bridge2"]:
			reset_boards()

func _process(delta: float) -> void:
	clock += delta
	state_time += delta
	stage_time += delta
	water.set_shader_parameter("clock", clock)
	water.set_shader_parameter("ripples", ripples)
	_drops(delta)
	_tick_poles(delta)
	# While a photo is held up the head eases to the tilt it was taken at, so the photo lies
	# exactly over where its contents will land.
	player.pitch_locked = camera.holding
	if camera.holding:
		player.pitch = move_toward(player.pitch, camera.photo.pitch, delta * 2.5)
	var shake: float = rift.shake
	# The floor going is felt as a slow sway, not a jolt.
	player.camera.h_offset = sin(clock * 7.0) * 0.03 * shake
	player.camera.v_offset = sin(clock * 9.0 + 1.0) * 0.02 * shake
	match state:
		"rise": _rise()
		"walk": _walk()
		"fall": _fall()
		"leave": _leave()
	hint_time += delta
	if hint.modulate.a > 0.0 and hint_time > 9.0 and state == "walk":
		hint.modulate.a = move_toward(hint.modulate.a, 0.0, delta * 0.5)

# Coming up out of the reservoir: black, then the water, then sitting up and standing.
func _rise() -> void:
	var t := state_time
	fade.color.a = 1.0 - clampf((t - 0.5) / 2.5, 0, 1)
	music.volume_db = lerpf(-40.0, -12.0, clampf(t / 6.0, 0, 1))
	var up := smoothstep(2.5, 6.0, t)
	player.eye = lerpf(0.25, player.EYE, up)
	player.pitch = lerpf(0.9, -0.05, smoothstep(2.0, 5.5, t))
	if t > 6.0:
		state = "walk"
		state_time = 0.0
		player.enabled = true
		_say("Đi tới cổng trường")

func _walk() -> void:
	var p := player.global_position
	_keep_in(p)
	if p.y < -2.0:
		state = "fall"
		state_time = 0.0
		player.enabled = false
		camera.enabled = false
		camera.raised = false
		camera.holding = false
		return
	if stage == "walk":
		if p.z < COLLAPSE_AT:
			_set_stage("collapse")
			rift.collapse()
			_drop_poles()
			_say("")
		return
	if stage == "collapse":
		return
	# Standing on solid ground past a puzzle's line begins it; stages only ever go forward.
	if p.y > -0.3:
		for i in range(STAGES.size() - 1, STAGES.find(stage), -1):
			var next: String = STAGES[i]
			if STAGE_FROM.has(next) and p.z < STAGE_FROM[next]:
				_begin(next)
				break
	match stage:
		"bridge1":
			bridge.feedback(bridge.misalignment(player.camera))
		"bridge2":
			bridge2.feedback(bridge2.misalignment(player.camera))
		"gate":
			if p.distance_to(GATE_AT) < 9.0 and not has_meta("told_gate"):
				set_meta("told_gate", true)
				_say("Cổng khoá xích. Ngày ấy thì sao?")
		"open":
			if p.z < GATE_AT.z - 3.0 and absf(p.x - GATE_AT.x) < 3.0:
				_begin_lucid()
		"lucid":
			_lucid()

# The world is endless but the dream is not: far from the way the haze closes in and turns you back.
func _keep_in(p: Vector3) -> void:
	var nearest := 1e9
	for i in range(ROUTE.size() - 1):
		var a: Vector3 = ROUTE[i]
		var b: Vector3 = ROUTE[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var d := a.lerp(b, t) - p
		nearest = minf(nearest, Vector2(d.x, d.z).length())
	environment.fog_density = lerpf(0.0026, 0.05, smoothstep(60.0, 95.0, nearest))
	if nearest > 100.0:
		var back := ROUTE[1] - p
		back.y = 0
		player.velocity += back.normalized() * 0.4

func _set_stage(next: String) -> void:
	stage = next
	stage_time = 0.0

func _begin(next: String) -> void:
	_set_stage(next)
	_arm_boards()
	match next:
		"board":
			_say("Một hòn đảo, và lại một khoảng trống.\nNhìn quanh qua máy ảnh. Thứ gì chụp được thì mang theo được: F · giơ ảnh lên   Chuột trái · đặt xuống")
		"leap":
			_say("Hai tấm bảng, một quãng dài hơn cả hai cộng lại.\nR · xếp lại đồ vật")
		"bridge2":
			bridge2.reveal()
			_say("Lại những mảnh vỡ. Lần này cái bàn lẻ ở đâu?")
		"gate":
			_say("Đi tới cổng trường")

# Through the gate: the dream knows it is a dream. Gravity lets go, the yard's things rise.
func _begin_lucid() -> void:
	_set_stage("lucid")
	player.lucid = true
	camera.enabled = false
	camera.raised = false
	camera.holding = false
	sky.start()
	reticle.visible = true
	_say("Nhẹ bẫng. Mình biết đây là mơ.\nSpace · nhảy   Giữ Space khi rơi · lơ lửng")

func _lucid() -> void:
	# Hold the left mouse button (or E) to pull; only changes of the real input are passed on,
	# so tests can call sky.set_pulling() directly.
	var held := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_E))
	if held != pull_input:
		pull_input = held
		sky.set_pulling(held)
	if not has_meta("told_rise") and stage_time > 7.0:
		set_meta("told_rise", true)
		_say("Đồ đạc trong sân trôi lên thành bậc thang.\nLên mây thôi.")
	if not has_meta("told_pull") and sky.gap_ahead() >= 0:
		set_meta("told_pull", true)
		_say("Thiếu một bậc. Thứ gì đang trôi thì kéo lại được.\nGiữ chuột trái · kéo về chỗ mình nhìn   Thả ra · để nó ở đó")
	if not has_meta("told_cloud") and player.global_position.y > sky.cloud_top - 0.5 and player.is_on_floor():
		set_meta("told_cloud", true)
		_say("Đi trên mây.")

func _on_door() -> void:
	if state != "walk":
		return
	sky.set_pulling(false)
	state = "leave"
	state_time = 0.0
	player.enabled = false
	reticle.visible = false
	_say("")

# The floor has finished going: the pieces of the old path rise into view.
func _on_settled() -> void:
	_set_stage("bridge1")
	bridge.reveal()
	props.show_drift()
	camera.enabled = true
	_say("Lối đi vỡ thành từng mảnh. Phải đứng đúng chỗ thì chúng mới liền lại.\nChuột phải · máy ảnh   Chuột trái · chụp")

func _closeness() -> float:
	var active: Node3D = bridge if stage == "bridge1" else bridge2 if stage == "bridge2" else null
	if active == null or active.solid:
		return -1.0
	return clampf(1.0 - (active.misalignment(player.camera) - active.ALIGNED_PX) / 120.0, 0.0, 1.0)

func _on_photo(photo: Dictionary) -> void:
	var active: Node3D = bridge if stage == "bridge1" else bridge2 if stage == "bridge2" else null
	if active != null and not active.solid and active.aligned(player.camera):
		active.join()
		_say("")
	elif not photo.movables.is_empty():
		if not has_meta("told_carry"):
			set_meta("told_carry", true)
			_say("Tấm bảng nằm trong ảnh rồi.\nF · giơ ảnh lên   Chuột trái · đặt nó xuống đúng như trong ảnh")
	elif stage == "gate" and photo.fixed.has(school.get_node("GateOpen")):
		_say("Trong ảnh, cổng vẫn mở.\nF · giơ ảnh lên cho khớp với cảnh   Chuột trái · dán ảnh")
	elif active != null and not active.solid and active.joining < 0.0:
		_say("Các mảnh chưa liền. Thử đứng chỗ khác.")

func _on_joined(_which: Node3D) -> void:
	_say("Lối đi đã liền lại.")

func _on_placed(photo: Dictionary) -> void:
	if photo.matched and photo.fixed.has(school.get_node("GateOpen")):
		_set_stage("open")
		_say("Ngày ấy cổng trường vẫn mở.")

func _tick_poles(delta: float) -> void:
	for fall in falling_poles:
		if rift.opened_at < 0.0 or rift.clock - rift.opened_at < fall.delay:
			continue
		if fall.has("gone"):
			continue
		var pole: Node3D = fall.pole
		fall.tilt = minf(fall.tilt + delta * 0.9, 1.4)
		pole.rotation.x = -fall.tilt
		fall.speed += 9.8 * delta * 0.6
		pole.position.y -= fall.speed * delta
		if pole.position.y < -70.0:
			fall.gone = true
			pole.queue_free()

# Off the edge: down into the haze, black, and back at the start of the current puzzle.
func _fall() -> void:
	var t := state_time
	fade.color = Color(0.02, 0.03, 0.05, clampf(t / 0.8, 0, 1))
	if t > 1.0 and not has_meta("respawned"):
		set_meta("respawned", true)
		player.velocity = Vector3.ZERO
		player.global_position = SAFE.get(stage, SAFE_NEAR)
	if t > 1.2:
		fade.color.a = 1.0 - clampf((t - 1.2) / 0.8, 0, 1)
	if t > 2.0:
		remove_meta("respawned")
		state = "walk"
		state_time = 0.0
		player.enabled = true
		camera.enabled = stage != "walk" and stage != "collapse"

# Through the gate the light swells to white, and the main character wakes at home.
func _leave() -> void:
	var t := state_time
	fade.color = Color(1.0, 0.95, 0.9, clampf(t / 3.0, 0, 1))
	music.volume_db = lerpf(-12.0, -40.0, clampf(t / 3.5, 0, 1))
	if t > 3.8 and not has_meta("left"):
		set_meta("left", true)
		get_tree().change_scene_to_file.call_deferred("res://scenes/home.tscn")

# Now and then a drop falls from nowhere somewhere near and rings out.
func _drops(delta: float) -> void:
	drop_clock -= delta
	if drop_clock > 0.0 or player == null:
		return
	drop_clock = randf_range(0.8, 2.4)
	var near := player.global_position + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
	ripple(near, randf_range(0.6, 1.4))

func _say(text: String) -> void:
	hint.text = text
	hint.modulate.a = 1.0 if text != "" else 0.0
	hint_time = 0.0
