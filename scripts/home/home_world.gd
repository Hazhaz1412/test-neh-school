extends Node3D
# Peter's house: living room, kitchen, dining table and bathroom below, bedroom above.
# The first quiet place in the game, and where the phone and the web come alive.
const Builder := preload("res://scripts/town/town_builder.gd")
const Door := preload("res://scripts/home/home_door.gd")
const WIDTH := 6.4
const DEPTH := 13.0
const STOREY := 2.9
const WALL := 0.16
const REACH := 2.1
const STAIR_LEFT := 5.2
const STAIR_FOOT := 12.4
const STAIR_TOP := 7.9
const WARM := Color(0.93, 0.92, 0.88)
# The front door, in the street-side wall beside the living room window.
const FRONT_DOOR := [3.7, 4.65]
const DOOR_HEIGHT := 2.1
var builder: RefCounted
var batch: RefCounted
var solids: StaticBody3D
var player: CharacterBody3D
var sky: Node3D
var hud: CanvasLayer
var prompt: Label
var goal: Label
var thought: Label
var fade: ColorRect
var phone: Control
var story: Node
var bridge: Node
var interactions: Array = []
var current := {}
var thought_time := 0.0
var card: Label
var front_door: Node3D
var front_touch: Dictionary
# Set by the story when Peter is meant to leave; until then the front door stays shut.
var exit_action: Callable

func _ready() -> void:
	sky = preload("res://scripts/town/town_sky.gd").new()
	add_child(sky)
	# One in the morning: moonlight through the windows, the rest comes from the lamps indoors.
	sky.apply(3)
	sky.environment.background_energy_multiplier = 0.05
	sky.sun.rotation_degrees = Vector3(-34, 150, 0)
	sky.sun.light_energy = 0.12
	sky.sun.light_color = Color(0.62, 0.70, 0.95)
	sky.environment.ambient_light_energy = 0.24
	sky.environment.fog_enabled = false
	builder = Builder.new()
	builder.rng.seed = 11
	builder._make_materials()
	batch = builder.batch
	builder.materials.floorboard = builder._texture("laminate_floor_02", 0.5)
	builder.materials.floorboard.vertex_color_use_as_albedo = true
	builder.materials.tile.uv1_scale = Vector3.ONE * 1.5
	solids = StaticBody3D.new()
	add_child(solids)
	_build_shell()
	_build_doors()
	_build_stairs()
	_furnish()
	var meshes := Node3D.new()
	add_child(meshes)
	batch.bake(meshes, builder.materials, {})
	_add_lights()
	_build_hud()
	player = preload("res://scripts/home/home_player.gd").new()
	player.world = self
	add_child(player)
	player.global_position = Vector3(2.4, 0.05, 11.8)
	player.yaw = 0.0
	bridge = preload("res://scripts/arg_bridge.gd").new()
	bridge.name = "ArgBridge"
	bridge.world = self
	add_child(bridge)
	story = preload("res://scripts/home/home_story.gd").new()
	add_child(story)
	story.setup(self)

func _floor(from: Vector2, to: Vector2, y: float, material: String, tint: Color) -> void:
	batch.at(Vector3(3, 0, 6))
	batch.box(material, Transform3D.IDENTITY, Vector3((from.x + to.x) * 0.5, y - 0.06, (from.y + to.y) * 0.5), Vector3(to.x - from.x, 0.12, to.y - from.y), tint, false)
	_solid(Vector3((from.x + to.x) * 0.5, y - 0.15, (from.y + to.y) * 0.5), Vector3(to.x - from.x, 0.3, to.y - from.y))

func _solid(centre: Vector3, size: Vector3, turn := Basis.IDENTITY) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(turn, centre)
	solids.add_child(shape)

# A wall along X or Z. Openings are [start, end, bottom, top] measured along the wall.
func _wall(from: Vector2, to: Vector2, base: float, material: String, tint: Color, openings := []) -> void:
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var cursor := 0.0
	batch.at(Vector3(3, 0, 6))
	for cut in cuts + [[length, length, 0.0, 0.0]]:
		if cut[0] > cursor:
			_wall_piece(from, along, cursor, cut[0], base, base + STOREY, material, tint)
		if cut[1] > cut[0]:
			if cut[2] > 0.0:
				_wall_piece(from, along, cut[0], cut[1], base, base + cut[2], material, tint)
			_wall_piece(from, along, cut[0], cut[1], base + cut[3], base + STOREY, material, tint)
		cursor = cut[1]

func _wall_piece(from: Vector2, along: Vector2, start: float, end: float, low: float, high: float, material: String, tint: Color) -> void:
	var middle := from + along * (start + end) * 0.5
	var run := end - start
	var size := Vector3(run if absf(along.x) > 0.5 else WALL, high - low, WALL if absf(along.x) > 0.5 else run)
	var centre := Vector3(middle.x, (low + high) * 0.5, middle.y)
	batch.box(material, Transform3D.IDENTITY, centre, size, tint)
	_solid(centre, size)

func _pane(at: Vector3, width: float, height: float, along_x: bool) -> void:
	var size := Vector3(width, height, 0.03) if along_x else Vector3(0.03, height, width)
	batch.box("glass", Transform3D.IDENTITY, at, size, Color.WHITE)
	var bars := Vector3(0.05, height, 0.06) if along_x else Vector3(0.06, height, 0.05)
	batch.box("paint", Transform3D.IDENTITY, at, bars, Color(0.86, 0.85, 0.82))
	batch.box("paint", Transform3D.IDENTITY, at, Vector3(width, 0.05, 0.06) if along_x else Vector3(0.06, 0.05, width), Color(0.86, 0.85, 0.82))

func _build_shell() -> void:
	_floor(Vector2(0, 3.2), Vector2(WIDTH, DEPTH), 0.0, "floorboard", Color(0.86, 0.76, 0.62))
	_floor(Vector2(2.4, 0), Vector2(WIDTH, 3.2), 0.0, "tile", Color(0.86, 0.86, 0.84))
	_floor(Vector2(0, 0), Vector2(2.4, 3.2), 0.0, "tile", Color(0.72, 0.84, 0.86))
	_floor(Vector2(0, 0), Vector2(STAIR_LEFT, DEPTH), STOREY, "floorboard", Color(0.78, 0.66, 0.52))
	_floor(Vector2(STAIR_LEFT, 0), Vector2(WIDTH, STAIR_TOP), STOREY, "floorboard", Color(0.78, 0.66, 0.52))
	_floor(Vector2(STAIR_LEFT, STAIR_FOOT + 0.25), Vector2(WIDTH, DEPTH), STOREY, "floorboard", Color(0.78, 0.66, 0.52))
	batch.box("paint", Transform3D.IDENTITY, Vector3(WIDTH * 0.5, STOREY * 2 + 0.05, DEPTH * 0.5), Vector3(WIDTH, 0.1, DEPTH), Color(0.95, 0.94, 0.91), false)
	# Painted ceiling under the upper floor; the stairwell stays open.
	batch.box("paint", Transform3D.IDENTITY, Vector3(STAIR_LEFT * 0.5, STOREY - 0.13, DEPTH * 0.5), Vector3(STAIR_LEFT, 0.02, DEPTH), Color(0.95, 0.94, 0.91), false)
	batch.box("paint", Transform3D.IDENTITY, Vector3((STAIR_LEFT + WIDTH) * 0.5, STOREY - 0.13, STAIR_TOP * 0.5), Vector3(WIDTH - STAIR_LEFT, 0.02, STAIR_TOP), Color(0.95, 0.94, 0.91), false)
	# The bedroom is its own room; the landing and stairs stay outside it.
	_wall(Vector2(0, 6.8), Vector2(WIDTH, 6.8), STOREY, "paint", Color(0.86, 0.90, 0.88), [[3.6, 4.5, 0.0, DOOR_HEIGHT]])
	for run in [[Vector2(0.08, 0.1), Vector2(0.08, DEPTH - 0.1)], [Vector2(WIDTH - 0.08, 0.1), Vector2(WIDTH - 0.08, DEPTH - 0.1)]]:
		for storey in [0.0, STOREY]:
			var mid: Vector2 = (run[0] + run[1]) * 0.5
			batch.box("paint", Transform3D.IDENTITY, Vector3(mid.x, storey + 0.05, mid.y), Vector3(0.03, 0.1, DEPTH), Color(0.42, 0.31, 0.22))
	for storey in [0.0, STOREY]:
		var south := [[1.2, 3.0, 0.9, 2.2], [FRONT_DOOR[0], FRONT_DOOR[1], 0.0, DOOR_HEIGHT + 0.05]] if storey == 0.0 else [[1.4, 4.2, 0.85, 2.3]]
		_wall(Vector2(0, DEPTH), Vector2(WIDTH, DEPTH), storey, "paint", WARM, south)
		_wall(Vector2(0, 0), Vector2(WIDTH, 0), storey, "paint", WARM, [[3.6, 5.2, 1.1, 2.2]] if storey == 0.0 else [[2.0, 4.0, 1.0, 2.2]])
		_wall(Vector2(0, 0), Vector2(0, DEPTH), storey, "paint", WARM)
		_wall(Vector2(WIDTH, 0), Vector2(WIDTH, DEPTH), storey, "paint", WARM)
	_pane(Vector3(2.1, 1.55, DEPTH), 1.8, 1.3, true)
	_pane(Vector3(2.8, STOREY + 1.57, DEPTH), 2.8, 1.45, true)
	_pane(Vector3(4.4, 1.65, 0.0), 1.6, 1.1, true)
	_pane(Vector3(3.0, STOREY + 1.6, 0.0), 2.0, 1.2, true)
	# Bathroom partition with its doorway.
	_wall(Vector2(0, 3.2), Vector2(2.4, 3.2), 0.0, "paint", Color(0.80, 0.88, 0.90), [[1.3, 2.15, 0.0, DOOR_HEIGHT]])
	_wall(Vector2(2.4, 0), Vector2(2.4, 3.2), 0.0, "paint", Color(0.80, 0.88, 0.90))
	_rail(Vector3(STAIR_LEFT, STOREY, STAIR_TOP), Vector3(STAIR_LEFT, STOREY, STAIR_FOOT + 0.25))
	_rail(Vector3(STAIR_LEFT, STOREY, STAIR_FOOT + 0.25), Vector3(WIDTH, STOREY, STAIR_FOOT + 0.25))

# Real doors in the three openings. All swing into the room they close off.
func _build_doors() -> void:
	var inward := Vector3(0, 0, -1)
	front_door = Door.fit(Vector3(FRONT_DOOR[1], 0, DEPTH), Vector3(FRONT_DOOR[0], 0, DEPTH), DOOR_HEIGHT + 0.05, WALL, inward)
	add_child(front_door)
	front_touch = {"position": front_door.touch_point(), "label": "Cửa chính", "action": _front_door}
	interactions.append(front_touch)
	var bathroom := Door.fit(Vector3(2.15, 0, 3.2), Vector3(1.3, 0, 3.2), DOOR_HEIGHT, WALL, inward)
	add_child(bathroom)
	_door_touch(bathroom, "cửa phòng tắm")
	# The bedroom door is left open: coming home at night, Peter walks straight in.
	var bedroom := Door.fit(Vector3(4.5, STOREY, 6.8), Vector3(3.6, STOREY, 6.8), DOOR_HEIGHT, WALL, inward, true)
	add_child(bedroom)
	_door_touch(bedroom, "cửa phòng ngủ")

func _door_touch(door: Node3D, door_name: String) -> void:
	var entry := {"position": door.touch_point(), "label": ("Đóng " if door.is_open else "Mở ") + door_name, "action": door.toggle}
	door.toggled.connect(func(open: bool): entry.label = ("Đóng " if open else "Mở ") + door_name)
	interactions.append(entry)

func _front_door() -> void:
	if not exit_action.is_valid():
		think("Tối rồi. Mai hẵng ra ngoài." if story.prologue else "Chưa có lý do ra ngoài lúc này.")
		return
	front_door.set_open(true)
	exit_action.call()

func set_exit(action: Callable) -> void:
	exit_action = action
	front_touch.label = "Ra khỏi nhà"

func _rail(from: Vector3, to: Vector3) -> void:
	var middle := (from + to) * 0.5
	var run := to - from
	var size := Vector3(absf(run.x) + 0.05, 0.05, absf(run.z) + 0.05)
	batch.box("paint", Transform3D.IDENTITY, middle + Vector3.UP * 0.98, size, Color(0.32, 0.22, 0.15))
	_solid(middle + Vector3.UP * 0.6, Vector3(absf(run.x) + 0.1, 1.3, absf(run.z) + 0.1))
	batch.quad("rail", from, to, to + Vector3.UP * 0.95, from + Vector3.UP * 0.95, Color(0.5, 0.36, 0.24), Vector2(run.length() * 2.0, 1.0))

func _build_stairs() -> void:
	var run := STAIR_FOOT - STAIR_TOP
	var count := 15
	for n in range(count):
		var t := float(n) / count
		var z := STAIR_FOOT - run * t
		var top := STOREY * (t + 1.0 / count)
		batch.box("floorboard", Transform3D.IDENTITY, Vector3((STAIR_LEFT + WIDTH) * 0.5, top * 0.5, z - run / count * 0.5), Vector3(WIDTH - STAIR_LEFT, top, run / count), Color(0.70, 0.56, 0.42), false)
	# One smooth ramp under the steps, so walking up never catches on a tread.
	var length := Vector2(run, STOREY).length()
	var tilt := Basis(Vector3.RIGHT, atan2(STOREY, run))
	_solid(Vector3((STAIR_LEFT + WIDTH) * 0.5, STOREY * 0.5 - 0.1, (STAIR_FOOT + STAIR_TOP) * 0.5), Vector3(WIDTH - STAIR_LEFT, 0.2, length), tilt)

func _prop(path: String, at: Vector3, tall: float, turn := 0.0, solid := true) -> Node3D:
	var model: Node3D = load(path).instantiate()
	add_child(model)
	var bounds := AABB()
	var first := true
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var piece: AABB = part.global_transform * part.mesh.get_aabb()
		bounds = piece if first else bounds.merge(piece)
		first = false
	var size := tall / bounds.size.y
	model.scale = Vector3.ONE * size
	model.rotation.y = turn
	var offset: Vector3 = (Basis(Vector3.UP, turn) * Vector3(bounds.get_center().x, 0, bounds.get_center().z)) * size
	model.position = at - offset - Vector3.UP * bounds.position.y * size
	if solid:
		var flat := Vector3(bounds.size.x, 0, bounds.size.z) * size
		var quarter: bool = absf(sin(turn)) > 0.7
		_solid(at + Vector3.UP * tall * 0.5, Vector3(flat.z if quarter else flat.x, tall, flat.x if quarter else flat.z))
	return model

func _add_touch(at: Vector3, label: String, action: Callable) -> void:
	interactions.append({"position": at, "label": label, "action": action})

func _furnish() -> void:
	var haven := "res://assets/polyhaven_town/models/%s/%s.gltf"
	_prop(haven % ["Sofa_01", "Sofa_01"], Vector3(1.0, 0, 10.6), 0.85, PI * 0.5)
	_prop(haven % ["television_02", "television_02"], Vector3(4.3, 0.55, 9.4), 0.6, -PI * 0.5, false)
	batch.at(Vector3(3, 0, 6))
	batch.box("paint", Transform3D.IDENTITY, Vector3(4.4, 0.27, 9.4), Vector3(0.5, 0.55, 1.5), Color(0.34, 0.25, 0.18))
	_solid(Vector3(4.4, 0.3, 9.4), Vector3(0.5, 0.6, 1.5))
	batch.box("paint", Transform3D.IDENTITY, Vector3(2.6, 0.012, 10.6), Vector3(2.2, 0.02, 2.6), Color(0.46, 0.24, 0.20))
	_prop(haven % ["dining_table", "dining_table"], Vector3(2.6, 0, 5.1), 0.76, PI * 0.5)
	for spot in [[Vector3(1.9, 0, 4.3), 0.0], [Vector3(3.3, 0, 4.3), 0.0], [Vector3(1.9, 0, 5.9), PI], [Vector3(3.3, 0, 5.9), PI]]:
		_prop(haven % ["dining_chair_02", "dining_chair_02"], spot[0], 0.95, spot[1], false)
	# Kitchen run along the back wall.
	batch.box("paint", Transform3D.IDENTITY, Vector3(4.4, 0.44, 0.42), Vector3(4.0, 0.88, 0.62), Color(0.58, 0.42, 0.30))
	batch.box("steel", Transform3D.IDENTITY, Vector3(4.4, 0.9, 0.42), Vector3(4.0, 0.04, 0.66), Color(0.75, 0.75, 0.74))
	batch.box("paint", Transform3D.IDENTITY, Vector3(3.2, 0.905, 0.42), Vector3(0.55, 0.02, 0.4), Color(0.32, 0.34, 0.36))
	_solid(Vector3(4.4, 0.45, 0.42), Vector3(4.0, 0.9, 0.66))
	_prop(haven % ["electric_stove", "electric_stove"], Vector3(5.45, 0.92, 0.45), 0.14, 0.0, false)
	_prop(haven % ["vintage_microwave", "vintage_microwave"], Vector3(4.3, 0.92, 0.4), 0.3, 0.0, false)
	_prop("res://assets/home/fridge.glb", Vector3(5.95, 0, 1.6), 1.75, -PI * 0.5)
	_add_touch(Vector3(5.5, 1.0, 1.6), "Mở tủ lạnh", func(): think("Nửa chai nước mắm người thuê trước để lại. Hạn dùng 2009." if story.prologue else "Nửa chai nước mắm và một quả trứng. Đúng là nhà của mình."))
	_add_touch(Vector3(3.2, 1.0, 0.8), "Rửa mặt ở bồn", func(): think("Nước lạnh, có mùi gỉ." if story.prologue else "Nước lạnh. Tay vẫn còn run."))
	# Bathroom.
	_prop("res://assets/home/toilet.glb", Vector3(0.5, 0, 0.6), 0.75, PI * 0.5)
	_prop("res://assets/home/basin.glb", Vector3(1.9, 0, 0.32), 0.85, 0.0)
	batch.box("steel", Transform3D.IDENTITY, Vector3(0.35, 2.1, 2.5), Vector3(0.05, 0.05, 0.3), Color.WHITE)
	batch.box("paint", Transform3D.IDENTITY, Vector3(1.9, 1.5, 0.1), Vector3(0.6, 0.8, 0.02), Color(0.74, 0.82, 0.88))
	_add_touch(Vector3(0.9, 1.0, 2.5), "Tắm", func(): think("Nước chảy vàng một lúc rồi mới trong. Ống cũ thôi."))
	_add_touch(Vector3(1.9, 1.2, 0.8), "Soi gương", func(): think("Gương mờ, góc dưới có ai vẽ một quân cờ." if story.prologue else "Sau lưng không có ai. Mình đã nhìn hai lần."))
	_add_touch(Vector3(3.6, 4.4, 6.8), "Khung cửa có vạch bút chì", func(): think("Những vạch đo chiều cao, chữ A nhỏ xíu: 2006, 2007, 2008. Không có 2009."))
	_add_touch(Vector3(0.5, 3.9, 0.9), "Khe đầu giường", func(): think("Một quân hậu trắng, sứt đầu. Ai để quên từ đời nào."))
	batch.box("tile", Transform3D.IDENTITY, Vector3(4.4, 1.25, 0.1), Vector3(4.0, 0.65, 0.03), Color(0.88, 0.90, 0.88))
	batch.box("paint", Transform3D.IDENTITY, Vector3(3.0, 1.9, 0.26), Vector3(1.0, 0.65, 0.34), Color(0.58, 0.42, 0.30))
	# Living room details: a family photo, a low shelf, a fan.
	batch.box("paint", Transform3D.IDENTITY, Vector3(0.1, 1.7, 10.6), Vector3(0.03, 0.6, 0.9), Color(0.30, 0.22, 0.16))
	batch.box("paint", Transform3D.IDENTITY, Vector3(0.12, 1.7, 10.6), Vector3(0.02, 0.5, 0.8), Color(0.74, 0.70, 0.60))
	_prop("res://assets/kenney_furniture/bookcaseOpen.glb", Vector3(0.3, 0, 7.6), 1.5, PI * 0.5)
	_prop("res://assets/kenney_furniture/ceilingFan.glb", Vector3(2.5, STOREY - 0.42, 10.2), 0.28, 0.0, false)
	_prop("res://assets/kenney_furniture/ceilingFan.glb", Vector3(2.5, STOREY * 2 - 0.42, 3.4), 0.28, 0.0, false)
	_prop("res://assets/polyhaven_town/models/potted_plant_04/potted_plant_04.gltf", Vector3(0.45, 0, 12.5), 0.75, 0.0, false)
	# Bedroom.
	_prop("res://assets/home/bed.glb", Vector3(1.0, STOREY, 1.3), 0.82, 0.0)
	batch.box("paint", Transform3D.IDENTITY, Vector3(1.9, STOREY + 0.01, 3.75), Vector3(2.4, 0.015, 1.6), Color(0.27, 0.34, 0.40))
	batch.box("paint", Transform3D.IDENTITY, Vector3(2.5, STOREY + 0.28, 0.45), Vector3(0.5, 0.56, 0.45), Color(0.40, 0.30, 0.22))
	_solid(Vector3(2.5, STOREY + 0.28, 0.45), Vector3(0.5, 0.56, 0.45))
	batch.box("paint", Transform3D.IDENTITY, Vector3(5.7, STOREY + 1.1, 2.3), Vector3(0.9, 2.2, 2.2), Color(0.52, 0.40, 0.30))
	batch.box("paint", Transform3D.IDENTITY, Vector3(5.24, STOREY + 1.1, 2.3), Vector3(0.02, 2.1, 0.02), Color(0.28, 0.2, 0.15))
	_solid(Vector3(5.7, STOREY + 1.1, 2.3), Vector3(0.9, 2.2, 2.2))
	batch.box("paint", Transform3D.IDENTITY, Vector3(0.1, STOREY + 1.6, 4.4), Vector3(0.02, 0.8, 0.56), Color(0.16, 0.28, 0.36))
	_prop("res://assets/kenney_furniture/desk.glb", Vector3(4.0, STOREY, 0.55), 0.76, PI)
	_prop("res://assets/kenney_furniture/computerScreen.glb", Vector3(4.0, STOREY + 0.76, 0.42), 0.42, 0.0, false)
	_prop("res://assets/kenney_furniture/computerKeyboard.glb", Vector3(4.0, STOREY + 0.77, 0.8), 0.04, 0.0, false)
	_prop("res://assets/kenney_furniture/chairDesk.glb", Vector3(4.0, STOREY, 1.55), 0.9, 0.0, false)
	_prop("res://assets/kenney_furniture/bookcaseOpen.glb", Vector3(0.35, STOREY, 6.0), 1.8, PI * 0.5)

func _add_lights() -> void:
	for spot in [[Vector3(2.4, 2.6, 10.0), 8.0, 0.55], [Vector3(3.2, 2.6, 3.8), 7.0, 0.5], [Vector3(1.2, 2.6, 1.6), 4.5, 0.45], [Vector3(2.8, 5.4, 10.0), 6.0, 0.35], [Vector3(2.6, 5.4, 3.4), 7.0, 0.6]]:
		var light := OmniLight3D.new()
		light.position = spot[0]
		light.omni_range = spot[1]
		light.light_energy = spot[2]
		light.light_color = Color(1.0, 0.93, 0.84)
		add_child(light)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root_control)
	goal = _label(root_control, 19, Color(0.97, 0.95, 0.88))
	goal.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	goal.offset_top = 28
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = _label(root_control, 22, Color(1.0, 0.92, 0.68))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.offset_top = -130
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought = _label(root_control, 22, Color(0.95, 0.93, 0.86))
	thought.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	thought.offset_left = -560
	thought.offset_right = 560
	thought.offset_top = -92
	thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone = preload("res://scripts/home/home_phone.gd").new()
	root_control.add_child(phone)
	phone.raised_changed.connect(_on_phone_raised)
	phone.dismiss_requested.connect(func(): story.toggle_phone())
	fade = ColorRect.new()
	fade.color = Color(0.012, 0.014, 0.018)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(fade)

# The head bows to the phone as it comes up and lifts again as it goes away.
func _on_phone_raised(up: bool) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "glance", 0.32 if up else 0.0, 0.5 if up else 0.35)
	tween.tween_property(player.camera, "fov", 64.0 if up else 72.0, 0.5 if up else 0.35)

func _label(parent: Control, size_px: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size_px >= 40:
		preload("res://scripts/horror_type.gd").title(label)
	parent.add_child(label)
	return label

# The one line shown over the black between scenes; each new one replaces the last.
func show_card(text: String) -> void:
	if card == null:
		card = _label(fade, 40, Color(0.97, 0.94, 0.86))
		card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.text = text

func think(text: String, seconds := 4.0) -> void:
	thought.text = text
	thought_time = seconds

func hub_state() -> Dictionary:
	return {"evidence": [], "stage": "HOME_" + story.step_name()}

func on_hub_message(message: Dictionary) -> void:
	story.on_hub_message(message)

func _process(delta: float) -> void:
	thought_time -= delta
	thought.modulate.a = clampf(thought_time, 0.0, 1.0)
	current = {}
	var eye: Vector3 = player.camera.global_position
	var best := REACH
	if player.enabled and not phone.is_open():
		for entry in interactions:
			var gap: float = eye.distance_to(entry.position)
			if gap < best and absf(entry.position.y - eye.y) < 1.5:
				best = gap
				current = entry
	prompt.text = "" if current.is_empty() else "E · " + current.label

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and player.enabled and not phone.is_open() and not story.blocking():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_E:
			if not current.is_empty() and player.enabled:
				current.action.call()
		KEY_TAB:
			story.toggle_phone()
		KEY_ESCAPE:
			if phone.is_open():
				story.toggle_phone()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
