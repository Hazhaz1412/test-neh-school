extends Node3D
# The menu backdrop: an empty classroom of the closed school at night, a chess game left
# unfinished, and the night guard at the far end of the room sweeping his torch.
const Rules := preload("res://scripts/chess/chess_rules.gd")
const Settings := preload("res://scripts/game_settings.gd")
const WALL := "res://assets/polyhaven_corridor/textures/%s_diff.jpg"
const GUARD_SPOT := Vector3(0.0, 0, -6.4)
const POSITION := "r1bqk2r/ppp2ppp/2n2n2/3pp3/1b1PP3/2N2N2/PPP2PPP/R1BQKB1R w KQkq - 0"
const DARK_EVERY := Vector2(7.0, 12.0)
const DARK_SECONDS := 0.5
const EYE := Vector3(2.9, 1.3, 2.9)
const GAZE := Vector3(-0.9, 0.95, -4.0)
var camera: Camera3D
var lamp: OmniLight3D
var guard: Node3D
var lamp_clock := 5.0
var dark_left := 0.0
var clock := 0.0
var snap: AudioStreamPlayer

func _ready() -> void:
	_sky()
	_room()
	_furniture()
	_guard()
	camera = Camera3D.new()
	camera.fov = 58.0
	add_child(camera)
	camera.look_at_from_position(EYE, GAZE)
	camera.current = true
	snap = AudioStreamPlayer.new()
	snap.stream = load("res://assets/audio/lamp_pop.wav")
	snap.volume_db = -20
	add_child(snap)

func _sky() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.014, 0.024)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.33, 0.45)
	environment.ambient_light_energy = 0.1
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.fog_enabled = true
	environment.fog_density = 0.035
	environment.fog_light_color = Color(0.1, 0.1, 0.16)
	Settings.track(environment)
	var holder := WorldEnvironment.new()
	holder.environment = environment
	add_child(holder)
	var moon := SpotLight3D.new()
	moon.position = Vector3(7.5, 3.4, -1.0)
	moon.rotation_degrees = Vector3(-24, 88, 0)
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 16.0
	moon.spot_range = 16.0
	moon.spot_angle = 34.0
	moon.shadow_enabled = true
	add_child(moon)
	lamp = OmniLight3D.new()
	lamp.position = Vector3(1.6, 2.75, -5.6)
	lamp.light_color = Color(1.0, 0.2, 0.12)
	lamp.light_energy = 1.7
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	add_child(lamp)

func _texture(name_of: String, tint: Color, scale_by: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = load(WALL % name_of)
	paint.albedo_color = tint
	paint.uv1_triplanar = true
	paint.uv1_world_triplanar = true
	paint.uv1_scale = Vector3.ONE * scale_by
	paint.roughness = 0.9
	return paint

func _box(at: Vector3, size: Vector3, paint: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = paint
	part.position = at
	add_child(part)
	return part

func _room() -> void:
	var wall := _texture("peeling_painted_wall", Color(0.62, 0.66, 0.6), 0.3)
	var floor_tile := _texture("floor_tiles_02", Color(0.42, 0.4, 0.38), 0.5)
	_box(Vector3(0, -0.1, -2), Vector3(11, 0.2, 14), floor_tile)
	_box(Vector3(0, 3.3, -2), Vector3(11, 0.2, 14), _texture("damaged_plaster", Color(0.5, 0.5, 0.48), 0.3))
	_box(Vector3(-5.4, 1.6, -2), Vector3(0.2, 3.4, 14), wall)
	_box(Vector3(0, 1.6, -8.4), Vector3(11, 3.4, 0.2), wall)
	_box(Vector3(0, 1.6, 4.6), Vector3(11, 3.4, 0.2), wall)
	# The window wall is posts and bars, so the moon can fall across the desks.
	for z in [-8.0, -5.0, -2.0, 1.0, 4.0]:
		_box(Vector3(5.4, 1.6, z), Vector3(0.25, 3.4, 0.8), wall)
	_box(Vector3(5.4, 0.45, -2), Vector3(0.25, 0.9, 14), wall)
	_box(Vector3(5.4, 3.0, -2), Vector3(0.25, 0.6, 14), wall)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.03, 0.03, 0.035)
	for z in range(-14, 8):
		_box(Vector3(5.4, 1.7, z * 0.5 + 0.1), Vector3(0.04, 1.8, 0.04), iron)
	var board := StandardMaterial3D.new()
	board.albedo_color = Color(0.05, 0.12, 0.09)
	board.roughness = 0.6
	_box(Vector3(-0.8, 1.7, -8.27), Vector3(6.0, 1.7, 0.06), board)
	var words := Label3D.new()
	words.text = "TÊN EM ĐÂU RỒI\ntên em đâu rồi\ntên em đâu"
	words.font = preload("res://scripts/horror_type.gd").WALL
	words.font_size = 130
	words.pixel_size = 0.0042
	words.modulate = Color(0.85, 0.85, 0.78, 0.9)
	words.shaded = true
	words.position = Vector3(-0.8, 1.7, -8.22)
	add_child(words)

func _model(asset: String, at: Vector3, tall: float, turn: Vector3) -> Node3D:
	var item: Node3D = load("res://assets/polyhaven_corridor/%s/%s.gltf" % [asset, asset]).instantiate()
	add_child(item)
	item.position = at
	item.rotation = turn
	item.scale = Vector3.ONE * tall
	return item

func _top_of(item: Node3D) -> float:
	var top := 0.0
	for part in item.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (part.global_transform * part.get_aabb()).end.y)
	return top

func _furniture() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 2009
	for x in [-3.6, -1.2, 1.2, 3.6]:
		for z in [-5.0, -3.0, -1.0, 1.0]:
			var spin: float = dice.randf_range(-0.25, 0.25)
			if dice.randf() < 0.25:
				_model("SchoolDesk_01", Vector3(x, 0.32, z), 1.0, Vector3(1.5, spin * 3.0, 0))
			else:
				_model("SchoolDesk_01", Vector3(x, 0, z), 1.0, Vector3(0, spin, 0))
			_model("SchoolChair_01", Vector3(x + dice.randf_range(-0.2, 0.2), 0, z + 0.75), 1.0, Vector3(0, PI + spin * 2.0, 0))
	var chess: Node3D = preload("res://scripts/chess/chess_table.gd").new()
	add_child(chess)
	var desk: Node3D = _model("SchoolDesk_01", Vector3(2.15, 0, 1.75), 1.0, Vector3(0, 0.5, 0))
	chess.position = Vector3(2.15, _top_of(desk), 1.75)
	chess.rotation.y = PI + 0.5
	chess.scale = Vector3.ONE * 0.8
	chess.lay(Rules.new(POSITION).board)

func _guard() -> void:
	guard = preload("res://scripts/guard_hunter_model.gd").new()
	add_child(guard)
	guard.position = GUARD_SPOT
	guard.rotation.y = 0.5

func _process(delta: float) -> void:
	clock += delta
	camera.position = EYE + Vector3(sin(clock * 0.13) * 0.22, sin(clock * 0.19) * 0.05, 0)
	camera.look_at(GAZE)
	guard.move("idle", 0.4)
	# He turns slowly from side to side, his torch sweeping the desks.
	guard.rotation.y = 0.5 + sin(clock * 0.35) * 0.45
	if dark_left > 0.0:
		dark_left -= delta
		lamp.light_energy = 0.0
		if dark_left <= 0.0:
			lamp_clock = randf_range(DARK_EVERY.x, DARK_EVERY.y)
		return
	lamp.light_energy = 1.7 + sin(clock * 19.0) * 0.12
	lamp_clock -= delta
	if lamp_clock <= 0.0:
		dark_left = DARK_SECONDS
		snap.play()
