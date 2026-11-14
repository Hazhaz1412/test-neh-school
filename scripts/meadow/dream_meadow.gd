extends Node3D
# After Night 1 the main character goes home and sleeps, and dreams of a meadow.
# It starts in the dark: endless grass under a heavy night sky, and one place far ahead where the
# cloud has opened and shafts of light come down, faintly rainbow-edged, onto a lone tree and a
# bed standing in the grass. Walking into the light turns the whole dream: the sky clears to
# blue with fair-weather clouds, soap bubbles drift up, and fish swim through the air round the
# tree, a manta and a whale further up. Lying down on the bed ends the dream (the next morning).
# Nothing chases and nothing can be lost. Jumps are the dream's light, floating ones.
# Assets: ASSETS.md, "Giấc mơ — đồng cỏ".
signal brightened
const Player := preload("res://scripts/dream/dream_player.gd")
const SKY := preload("res://assets/materials/meadow_sky.gdshader")
const GRASS := preload("res://assets/materials/meadow_grass.gdshader")
const GROUND := preload("res://assets/materials/meadow_ground.gdshader")
const BEAM := preload("res://assets/materials/meadow_beam.gdshader")
const BUBBLE := preload("res://assets/materials/meadow_bubble.gdshader")
const M := "res://assets/polyhaven_meadow/"
const TREE := M + "island_tree_01/island_tree_01.gltf"
const BED := M + "GothicBed_01/GothicBed_01_1k.gltf"
const DANDELION := M + "dandelion_01/dandelion_01_1k.gltf"
const SHRUB := M + "shrub_01/shrub_01_1k.gltf"
const FISH := "res://assets/meadow/fish/%s.glb"
const POST := preload("res://assets/materials/dreamcore_post.gdshader")
const POLES := "res://assets/polyhaven_dream/modular_electricity_poles/modular_electricity_poles_1k.gltf"
const POLE_PRESETS := {"preset_01_": -2.5, "preset_02_": -4.5, "preset_03_": -6.5}
const NEXT_SCENE := "res://scenes/town.tscn"
# The one bright place is the origin; the player wakes this far away, facing it.
const START := Vector3(0, 0, 90)
const LIGHT_RADIUS := 7.0
const WALK_LIMIT := 150.0
const TREE_AT := Vector2(-2.2, -1.6)
const TREE_SCALE := 2.3
const BED_AT := Vector2(2.4, 1.2)
const BED_TURN := -25.0
const BED_REACH := 2.6
const BRIGHTEN_TIME := 7.0
# The Quaternius fish are modelled head towards -Z... set from the look check (tools/capture_meadow.gd).
const FISH_HEAD_MINUS_Z := false
const HEIGHT_SIZE := 401
const Settings := preload("res://scripts/game_settings.gd")
# Per graphics setting (Nhẹ, Cân bằng, Cao): how much grass, how far the dense grass reaches,
# and the costlier screen effects.
const GRASS_SHARE := [0.45, 0.75, 1.0]
const CLOSE_GRASS := [14.0, 18.0, 20.0]
const SHADOW_REACH := [35.0, 55.0, 80.0]
# Where the sun is in the clear-sky photo (pixel 1218, 240 of 2048 x 1024): turn the photo so it
# stands behind the player walking in, and put the DirectionalLight on the same line.
const SUN_ELEVATION := 47.8
const SUN_AZIMUTH := 2.61
const CLEAR_TURN := 0.595 - SUN_AZIMUTH

var player: CharacterBody3D
var environment: Environment
var sky_material: ShaderMaterial
var post: ShaderMaterial
var focus: CameraAttributesPractical
var sun: DirectionalLight3D
var shaft_light: SpotLight3D
var beams: Array[MeshInstance3D] = []
var beam_materials: Array[ShaderMaterial] = []
var bubbles: ShaderMaterial
var fishes: Array[Dictionary] = []
var hud: CanvasLayer
var fade: ColorRect
var hint: Label
var prompt: Label
var music: AudioStreamPlayer
var chime: AudioStreamPlayer
var state := "wake"
var state_time := 0.0
var clock := 0.0
var bright := 0.0
# Read from the settings unless set before the scene enters the tree (tools/bench_meadow.gd).
var quality := -1
var shown_bright := -1.0
var lit := false
var bright_from := 0.0
var hint_time := 0.0
var bed: Node3D
var lie_from: Transform3D
var lie_to: Transform3D

static func ground_height(x: float, z: float) -> float:
	# Must match ground_height() in meadow_grass.gdshader.
	var d := Vector2(x, z).length()
	var roll := 3.2 * sin(x * 0.026 + 0.3) * cos(z * 0.021) + 1.8 * sin(x * 0.047 - z * 0.033 + 1.0) \
		+ 0.35 * sin(x * 0.11 + 1.3) * sin(z * 0.09 + 0.4)
	roll *= smoothstep(12.0, 55.0, d)
	var a := atan2(z, x)
	var hills := smoothstep(140.0, 520.0, d)
	hills = hills * hills * (34.0 + 16.0 * sin(a * 3.0 + 0.7) + 8.0 * sin(a * 7.0 + 2.1))
	return roll + hills

static func on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, ground_height(x, z), z)

func _ready() -> void:
	preload("res://scripts/game_progress.gd").mark("meadow")
	if quality < 0:
		quality = int(Settings.read("quality"))
	quality = clampi(quality, 0, 2)
	# On the lightest setting draw the 3D at three quarters and let FSR scale it up.
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if quality == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 0.75 if quality == 0 else 1.0
	_sky()
	_ground()
	_grass()
	_light_shafts()
	_tree_and_bed()
	_flowers()
	_poles()
	_bubbles()
	_fish()
	_sound()
	_hud()
	player = Player.new()
	add_child(player)
	player.lucid = true
	player.global_position = on_ground(START.x, START.z) + Vector3(0, 0.05, 0)
	player.yaw = 0.0
	player.pitch = 0.08
	player.enabled = false
	player.camera.far = 3000.0
	var grass_steps := AudioStreamPlayer.new()
	var steps := AudioStreamRandomizer.new()
	for i in range(1, 7):
		steps.add_stream(-1, load("res://assets/audio/steps/grass_0%d.ogg" % i))
	steps.random_pitch = 1.08
	steps.random_volume_offset_db = 2.0
	grass_steps.stream = steps
	grass_steps.volume_db = -16
	player.add_child(grass_steps)
	player.ground_steps = grass_steps
	# Once everything that follows the light exists, set it all once.
	shown_bright = -1.0
	_apply_brightness()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 1.0

func _sky() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY
	sky_material.set_shader_parameter("dark_sky", load(M + "farm_field_puresky_2k.hdr"))
	sky_material.set_shader_parameter("clear_sky", load(M + "kloofendal_48d_partly_cloudy_puresky_2k.hdr"))
	sky_material.set_shader_parameter("clear_turn", CLEAR_TURN)
	environment.sky.sky_material = sky_material
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.ssao_enabled = quality == 2
	environment.ssao_radius = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.3
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_aerial_perspective = 0.8
	environment.fog_sky_affect = 0.0
	environment.adjustment_enabled = true
	preload("res://scripts/game_settings.gd").track(environment)
	var holder := WorldEnvironment.new()
	holder.environment = environment
	# Far things go soft, as if seen through sleep.
	focus = CameraAttributesPractical.new()
	focus.dof_blur_far_enabled = quality > 0
	focus.dof_blur_far_distance = 40.0
	focus.dof_blur_far_transition = 140.0
	focus.dof_blur_amount = 0.06
	holder.camera_attributes = focus
	add_child(holder)
	sun = DirectionalLight3D.new()
	var e := deg_to_rad(SUN_ELEVATION)
	var towards_sun := Vector3(sin(SUN_AZIMUTH) * cos(e), sin(e), -cos(SUN_AZIMUTH) * cos(e))
	sun.basis = Basis.looking_at(-towards_sun, Vector3.UP)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_REACH[quality]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	_apply_brightness()

# Dark night meadow at 0, clear blue day at 1.
func _apply_brightness() -> void:
	var b := smoothstep(0.0, 1.0, bright)
	# Every change to the sky's parameters re-renders its reflection map: only when it moved.
	if absf(b - shown_bright) < 0.0005:
		return
	shown_bright = b
	sky_material.set_shader_parameter("bright", b)
	environment.ambient_light_energy = lerpf(0.35, 1.0, b)
	environment.background_energy_multiplier = 1.0
	environment.tonemap_exposure = lerpf(1.0, 0.92, b)
	environment.fog_density = lerpf(0.007, 0.0045, b)
	environment.fog_light_color = Color(0.12, 0.15, 0.26).lerp(Color(0.86, 0.88, 0.98), b)
	environment.adjustment_saturation = lerpf(0.8, 1.05, b)
	if post != null:
		post.set_shader_parameter("lift", lerpf(0.04, 0.09, b))
		post.set_shader_parameter("lift_tint", Color(0.3, 0.34, 0.6).lerp(Color(0.86, 0.78, 0.92), b))
		post.set_shader_parameter("gain_tint", Color(0.92, 0.96, 1.0).lerp(Color(1.0, 0.97, 0.93), b))
		post.set_shader_parameter("halo", lerpf(0.45, 0.25, b))
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.95, 0.86), b)
	sun.light_energy = lerpf(0.12, 1.5, b)
	if shaft_light != null:
		shaft_light.light_energy = lerpf(14.0, 2.0, b)
	for m in beam_materials:
		m.set_shader_parameter("strength", lerpf(0.03, 0.008, b) * m.get_meta("weight", 1.0))
	if bubbles != null:
		bubbles.set_shader_parameter("appear", smoothstep(0.3, 1.0, bright))

# The ground: rings round the bright place, fine near it and coarse out on the hills, plus a
# height field the size of the walkable part for the player to stand on.
func _ground() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array[float] = [0.0]
	var r := 1.0
	while r < 2600.0:
		radii.append(r)
		r = r * 1.045 + 0.8
	const SEGMENTS := 160
	for i in range(radii.size() - 1):
		for s in range(SEGMENTS):
			var a0 := TAU * s / SEGMENTS
			var a1 := TAU * (s + 1) / SEGMENTS
			var p := [Vector2(cos(a0), sin(a0)) * radii[i], Vector2(cos(a1), sin(a1)) * radii[i],
				Vector2(cos(a0), sin(a0)) * radii[i + 1], Vector2(cos(a1), sin(a1)) * radii[i + 1]]
			var v: Array[Vector3] = []
			for q: Vector2 in p:
				v.append(on_ground(q.x, q.y))
			# Clockwise seen from above, so the faces point up.
			tool.add_vertex(v[0]); tool.add_vertex(v[2]); tool.add_vertex(v[1])
			tool.add_vertex(v[1]); tool.add_vertex(v[2]); tool.add_vertex(v[3])
	tool.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = GROUND
	material.set_shader_parameter("albedo_tex", load(M + "leafy_grass_diff_1k.jpg"))
	material.set_shader_parameter("normal_tex", load(M + "leafy_grass_nor_gl_1k.jpg"))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Ground"
	floor_mesh.mesh = tool.commit()
	floor_mesh.material_override = material
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
	var heights := PackedFloat32Array()
	heights.resize(HEIGHT_SIZE * HEIGHT_SIZE)
	var half := (HEIGHT_SIZE - 1) / 2
	for z in range(HEIGHT_SIZE):
		for x in range(HEIGHT_SIZE):
			heights[z * HEIGHT_SIZE + x] = ground_height(x - half, z - half)
	var field := HeightMapShape3D.new()
	field.map_width = HEIGHT_SIZE
	field.map_depth = HEIGHT_SIZE
	field.map_data = heights
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = field
	body.add_child(shape)
	add_child(body)

# Grass blades placed by the shader, chunk by chunk: a dense near layer and a sparse, taller far
# layer that takes over where the near one fades out.
func _grass() -> void:
	# chunk, blades per chunk, height, width, segments, reach, visible from, to.
	var share: float = GRASS_SHARE[quality]
	var near_end: float = CLOSE_GRASS[quality]
	var close := _blade_layer(8.0, int(4800 * share), 0.42, 0.032, 4, 165.0, 0.0, near_end)
	var mid := _blade_layer(16.0, int(5600 * share), 0.48, 0.06 / sqrt(share), 2, 170.0, near_end - 4.0, 75.0)
	var far := _blade_layer(32.0, int(3600 * share), 0.62, 0.15 / sqrt(share), 1, 245.0, 66.0, 235.0)
	for layer in [close, mid, far]:
		layer.material.set_shader_parameter("clear_a", Vector4(TREE_AT.x, 0, TREE_AT.y, 0.9))
		layer.material.set_shader_parameter("clear_b", Vector4(BED_AT.x, 0, BED_AT.y, 1.25))

func _blade_layer(chunk: float, count: int, height: float, width: float, segments: int, reach: float, from: float, to: float) -> Dictionary:
	var blade := SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in range(segments + 1):
		var t := i / float(segments)
		var w := 0.5 * pow(1.0 - t, 0.8)
		rows.append([Vector3(-w, t, 0), Vector3(w, t, 0), t])
	for i in range(segments):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for corner in [[a, 0], [a, 1], [b, 0], [a, 1], [b, 1], [b, 0]]:
			var row: Array = corner[0]
			blade.set_uv(Vector2(float(corner[1]), row[2]))
			blade.set_normal(Vector3.BACK)
			blade.add_vertex(row[corner[1]])
	var material := ShaderMaterial.new()
	material.shader = GRASS
	material.set_shader_parameter("chunk", chunk)
	material.set_shader_parameter("blade_height", height)
	material.set_shader_parameter("blade_width", width)
	var mesh := blade.commit()
	mesh.surface_set_material(0, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var identity := PackedFloat32Array()
	identity.resize(count * 12)
	for i in range(count):
		identity[i * 12] = 1.0
		identity[i * 12 + 5] = 1.0
		identity[i * 12 + 10] = 1.0
	multi.buffer = identity
	var holder := Node3D.new()
	holder.name = "Grass%d" % int(chunk)
	add_child(holder)
	var cells := int(ceil(reach / chunk))
	for cz in range(-cells, cells):
		for cx in range(-cells, cells):
			var centre := Vector2((cx + 0.5) * chunk, (cz + 0.5) * chunk)
			if centre.length() > reach:
				continue
			var patch := MultiMeshInstance3D.new()
			patch.multimesh = multi
			patch.position = Vector3(centre.x, 0, centre.y)
			patch.custom_aabb = AABB(Vector3(-chunk / 2 - 1, -3, -chunk / 2 - 1), Vector3(chunk + 2, 45, chunk + 2))
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			patch.visibility_range_begin = from
			patch.visibility_range_begin_margin = 4.0 if from > 0.0 else 0.0
			patch.visibility_range_end = to
			patch.visibility_range_end_margin = 4.0
			patch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			holder.add_child(patch)
	return {"material": material, "multimesh": multi}

# The hole in the cloud: a light straight down onto the tree and the bed, and open cylinders of
# light around it, the widest faintest, leaning a little apart like rays through a gap.
func _light_shafts() -> void:
	shaft_light = SpotLight3D.new()
	shaft_light.position = Vector3(0, 45, 0)
	shaft_light.rotation_degrees.x = -90
	shaft_light.spot_angle = 10.0
	shaft_light.spot_angle_attenuation = 0.6
	shaft_light.spot_range = 70.0
	shaft_light.light_color = Color(1.0, 0.95, 0.78)
	shaft_light.shadow_enabled = false
	add_child(shaft_light)
	# radius at the ground, brightness, offset, lean (degrees). They widen upwards, a fan of rays.
	var shafts := [[6.0, 0.55, Vector3(0, 0, 0), 0.0], [3.6, 0.9, Vector3(1.5, 0, -1.0), 5.0], [2.4, 0.9, Vector3(-1.2, 0, 1.4), -6.0],
		[8.5, 0.3, Vector3(0, 0, 0), 3.0], [1.5, 0.8, Vector3(2.5, 0, 2.0), -3.5], [2.0, 0.7, Vector3(-2.5, 0, -2.0), 7.5]]
	for i in range(shafts.size()):
		var plan: Array = shafts[i]
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = plan[0] * 2.4
		cylinder.bottom_radius = plan[0]
		cylinder.height = 150.0
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		cylinder.radial_segments = 48
		var material := ShaderMaterial.new()
		material.shader = BEAM
		material.set_meta("weight", plan[1])
		material.set_shader_parameter("phase", i * 0.21)
		var beam := MeshInstance3D.new()
		beam.mesh = cylinder
		beam.material_override = material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = plan[2] + Vector3(0, 74.5, 0)
		beam.rotation_degrees = Vector3(plan[3], i * 47.0, plan[3] * 0.6)
		add_child(beam)
		beams.append(beam)
		beam_materials.append(material)

func _tree_and_bed() -> void:
	var tree: Node3D = load(TREE).instantiate()
	tree.scale = Vector3.ONE * TREE_SCALE
	tree.position = on_ground(TREE_AT.x, TREE_AT.y) - Vector3(0, 0.1, 0)
	tree.rotation_degrees.y = 35.0
	add_child(tree)
	# Its 400k triangles drawn again into every shadow split is the dearest thing on the lightest setting.
	if quality == 0:
		for mesh: GeometryInstance3D in tree.find_children("*", "GeometryInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_solid_cylinder(on_ground(TREE_AT.x, TREE_AT.y), 0.75, 6.0)
	bed = load(BED).instantiate()
	bed.name = "Bed"
	bed.position = on_ground(BED_AT.x, BED_AT.y)
	bed.rotation_degrees.y = BED_TURN
	add_child(bed)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.45, 0.62, 2.0)
	shape.shape = box
	shape.position = Vector3(0, 0.31, 0)
	body.add_child(shape)
	bed.add_child(body)

func _solid_cylinder(at: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	body.position = at + Vector3(0, height / 2, 0)
	add_child(body)

# Dandelions and a few shrubs in the light round the tree.
func _flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in range(16):
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.5, 9.5)
		var at := Vector2(cos(a), sin(a)) * r
		if at.distance_to(BED_AT) < 1.8 or at.distance_to(TREE_AT) < 1.4:
			continue
		var flower: Node3D = load(DANDELION).instantiate()
		flower.position = on_ground(at.x, at.y)
		flower.rotation_degrees.y = rng.randf() * 360.0
		flower.scale = Vector3.ONE * rng.randf_range(1.6, 2.4)
		add_child(flower)
	for i in range(4):
		var a := TAU * i / 4.0 + 0.6
		var at := TREE_AT + Vector2(cos(a), sin(a)) * rng.randf_range(2.0, 3.2)
		var shrub: Node3D = load(SHRUB).instantiate()
		shrub.position = on_ground(at.x, at.y)
		shrub.rotation_degrees.y = rng.randf() * 360.0
		shrub.scale = Vector3.ONE * rng.randf_range(0.8, 1.1)
		add_child(shrub)

# A line of power poles crossing the meadow, wires sagging between them, going on into the haze
# both ways. Nothing they could be carrying power to.
func _poles() -> void:
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.05, 0.05, 0.06)
	wire.roughness = 0.6
	var line_x := -34.0
	var tops: Array = []
	var prefixes := POLE_PRESETS.keys()
	var i := 0
	var z := 260.0
	while z > -360.0:
		var x := line_x + sin(z * 0.01) * 6.0
		var at := on_ground(x, z)
		var pole := _pole(prefixes[i % prefixes.size()])
		pole.position = at - Vector3(0, 0.15, 0)
		pole.scale = Vector3.ONE * 1.5
		pole.rotation.y = -PI / 2
		pole.rotation_degrees.z = (i % 3 - 1) * 1.2
		add_child(pole)
		_solid_cylinder(at, 0.25, 9.0)
		var arm := Vector3(0, 0, 0.75)
		tops.append([at + Vector3(0, 8.58, 0) - arm.rotated(Vector3.UP, PI / 2), at + Vector3(0, 8.58, 0) + arm.rotated(Vector3.UP, PI / 2), at + Vector3(0, 6.83, 0)])
		z -= 46.0
		i += 1
	var wires := SurfaceTool.new()
	wires.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(tops.size() - 1):
		for w in range(3):
			_wire(wires, tops[k][w], tops[k + 1][w], 1.6 + w * 0.2)
	wires.generate_normals()
	var holder := MeshInstance3D.new()
	holder.name = "Wires"
	holder.mesh = wires.commit()
	holder.material_override = wire
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)

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

func _wire(tool: SurfaceTool, from: Vector3, to: Vector3, sag: float) -> void:
	const SEGMENTS := 20
	const R := 0.018
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

func _bubbles() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	bubbles = ShaderMaterial.new()
	bubbles.shader = BUBBLE
	sphere.material = bubbles
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	multi.instance_count = 160
	var holder := MultiMeshInstance3D.new()
	holder.name = "Bubbles"
	holder.multimesh = multi
	holder.custom_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 30, 60))
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)

# Fish in the air, each on its own slow loop. Small reef fish in schools round the tree, a few
# big silver ones wider out, two mantas higher, one whale far up crossing the whole sky.
func _fish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	var schools := [["fish1", 1.3, 7.5, 4.5, 8], ["fish2", 1.2, 12.0, 7.0, 7], ["fish3", 1.0, 6.0, 3.2, 9], ["fish1", 1.4, 15.0, 10.0, 6]]
	for school: Array in schools:
		var direction := 1.0 if rng.randf() < 0.5 else -1.0
		var base_phase := rng.randf() * TAU
		for k in range(school[4]):
			_add_fish(school[0], school[1] * rng.randf_range(0.85, 1.15), school[2] + rng.randf_range(-1.5, 1.5),
				school[3] + rng.randf_range(-1.0, 1.0), base_phase + k * 0.16 + rng.randf_range(-0.05, 0.05), 1.6 * direction, rng)
	for k in range(5):
		_add_fish("barramundi_fish", 2.2 * rng.randf_range(0.9, 1.2), rng.randf_range(16, 22), rng.randf_range(5, 11), rng.randf() * TAU, 2.4, rng)
	for k in range(2):
		_add_fish("manta_ray", 7.0, rng.randf_range(28, 36), rng.randf_range(15, 20), k * PI, -3.0, rng)
	_add_fish("whale", 34.0, 110.0, 55.0, 0.0, 3.6, rng)

func _add_fish(kind: String, length: float, radius: float, height: float, phase: float, speed: float, rng: RandomNumberGenerator) -> void:
	var model: Node3D = load(FISH % kind).instantiate()
	var holder := Node3D.new()
	holder.add_child(model)
	add_child(holder)
	# Scale to the wanted length from the model's own bounds.
	var box := AABB()
	var first := true
	for mesh: VisualInstance3D in model.find_children("*", "VisualInstance3D", true, false):
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	model.scale = Vector3.ONE * (length / maxf(box.size.z, 0.001))
	if not FISH_HEAD_MINUS_Z:
		model.rotation.y = PI
	for animation_player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		var names := animation_player.get_animation_list()
		if names.size() > 0:
			animation_player.get_animation(names[0]).loop_mode = Animation.LOOP_LINEAR
			animation_player.play(names[0])
			animation_player.speed_scale = rng.randf_range(0.8, 1.2)
			animation_player.seek(rng.randf() * 1.0, true)
	holder.visible = false
	fishes.append({"node": holder, "radius": radius, "height": height, "phase": phase, "speed": speed,
		"bob": rng.randf_range(0.3, 0.8), "wobble": rng.randf() * TAU})

func _tick_fish(delta: float) -> void:
	var arrive := 0.0 if not lit else smoothstep(0.0, 9.0, clock - bright_from)
	for fish in fishes:
		var node: Node3D = fish.node
		node.visible = arrive > 0.0
		if not node.visible:
			continue
		var radius: float = fish.radius * lerpf(3.5, 1.0, arrive)
		fish.phase += delta * fish.speed / radius
		var a: float = fish.phase
		var y: float = fish.height + sin(clock * 0.5 + fish.wobble) * fish.bob
		var at := Vector3(cos(a) * radius, y, sin(a) * radius)
		var tangent := Vector3(-sin(a), cos(clock * 0.5 + fish.wobble) * fish.bob * 0.05, cos(a)) * signf(fish.speed)
		node.position = at
		node.basis = Basis.looking_at(tangent, Vector3.UP)

func _sound() -> void:
	music = AudioStreamPlayer.new()
	var loop: AudioStreamOggVorbis = load("res://assets/music/dream_ambient.ogg")
	loop.loop = true
	music.stream = loop
	music.volume_db = -40
	add_child(music)
	music.play()
	chime = AudioStreamPlayer.new()
	chime.stream = load("res://assets/audio/memory.wav")
	chime.volume_db = -14
	add_child(chime)

func _hud() -> void:
	var look := CanvasLayer.new()
	look.layer = -1
	add_child(look)
	post = ShaderMaterial.new()
	post.shader = POST
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.material = post
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	look.add_child(screen)
	hud = CanvasLayer.new()
	add_child(hud)
	hint = _label(-80, 20)
	prompt = _label(-130, 22)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.0, 0.0, 0.02, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

func _label(lift: float, size: int) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.position.y += lift
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.modulate.a = 0.0
	hud.add_child(label)
	return label

func _say(text: String) -> void:
	hint.text = text
	hint.modulate.a = 1.0 if text != "" else 0.0
	hint_time = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and state != "leave":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if near_bed():
			lie_down()

func near_bed() -> bool:
	if state != "walk" or player == null:
		return false
	var flat := Vector2(player.global_position.x - bed.global_position.x, player.global_position.z - bed.global_position.z)
	return flat.length() < BED_REACH

func in_light() -> bool:
	return Vector2(player.global_position.x, player.global_position.z).length() < LIGHT_RADIUS

func _process(delta: float) -> void:
	clock += delta
	state_time += delta
	hint_time += delta
	if lit:
		bright = clampf((clock - bright_from) / BRIGHTEN_TIME, 0.0, 1.0)
	_apply_brightness()
	_tick_fish(delta)
	if hint.modulate.a > 0.0 and hint_time > 8.0:
		hint.modulate.a = move_toward(hint.modulate.a, 0.0, delta * 0.5)
	match state:
		"wake": _wake()
		"walk": _walk()
		"lie": _lie()
		"leave": _leave()

# Eyes opening in the dark grass.
func _wake() -> void:
	fade.color.a = 1.0 - smoothstep(0.5, 3.5, state_time)
	music.volume_db = lerpf(-40.0, -20.0, clampf(state_time / 5.0, 0, 1))
	if state_time > 3.0:
		state = "walk"
		state_time = 0.0
		player.enabled = true
		_say("Một đồng cỏ. Chỉ có một chỗ sáng.")

func _walk() -> void:
	var p := player.global_position
	# The meadow goes on for ever; past the limit the dream turns you gently back.
	var flat := Vector2(p.x, p.z)
	if flat.length() > WALK_LIMIT:
		var outward := flat.normalized()
		var move := Vector2(player.velocity.x, player.velocity.z)
		# No speed outwards, and a slow drift back in (set, never added up frame on frame).
		var along := move.dot(outward)
		move += outward * (minf(along, -clampf((flat.length() - WALK_LIMIT) * 0.5, 0.3, 1.5)) - along)
		player.velocity.x = move.x
		player.velocity.z = move.y
	if not lit and in_light():
		lit = true
		bright_from = clock
		chime.play()
		brightened.emit()
		_say("")
	music.volume_db = lerpf(-20.0, -11.0, bright)
	prompt.text = "E · Nằm xuống" if near_bed() else ""
	prompt.modulate.a = 1.0 if prompt.text != "" else 0.0

func lie_down() -> void:
	if state != "walk":
		return
	state = "lie"
	state_time = 0.0
	player.enabled = false
	player.set_physics_process(false)
	player.set_process(false)
	prompt.modulate.a = 0.0
	_say("")
	lie_from = player.camera.global_transform
	# Head on the pillow, looking up past the tree into the sky full of fish.
	var head := bed.global_transform * Vector3(0, 0.95, -0.65)
	var tree_at := on_ground(TREE_AT.x, TREE_AT.y)
	var up_at := head + (Vector3(tree_at.x, head.y, tree_at.z) - head).normalized() * 4.0 + Vector3(0, 9.0, 0)
	# Head turned a little towards the tree: its trunk rises from the bottom of the view.
	var crown := Vector3(tree_at.x - head.x, 0, tree_at.z - head.z).normalized()
	lie_to = Transform3D(Basis.looking_at(up_at - head, crown), head)

func _lie() -> void:
	var t := smoothstep(0.0, 3.0, state_time)
	player.camera.global_transform = Transform3D(lie_from.basis.slerp(lie_to.basis, t), lie_from.origin.lerp(lie_to.origin, t))
	if state_time > 9.0:
		state = "leave"
		state_time = 0.0

# Asleep in the dream: everything goes white, and it is the next morning.
func _leave() -> void:
	player.camera.global_transform = lie_to
	fade.color = Color(1.0, 0.98, 0.94, clampf(state_time / 3.0, 0, 1))
	music.volume_db = lerpf(-11.0, -40.0, clampf(state_time / 3.5, 0, 1))
	if state_time > 3.8 and not has_meta("left"):
		set_meta("left", true)
		get_tree().change_scene_to_file.call_deferred(NEXT_SCENE)
