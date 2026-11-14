extends Node3D
# After Night 1 the main character goes home and sleeps, and dreams of a meadow.
# It starts in the dark: endless grass under a heavy night sky, and one place far ahead where the
# cloud has opened and shafts of light come down, faintly rainbow-edged, onto a lone tree and a
# bed standing in the grass. Walking into the light turns the whole dream: the sky clears to
# blue with fair-weather clouds, soap bubbles drift up, and fish swim through the air round the
# tree, a manta and a whale further up. Lying down on the bed, the eyes close. Fairground music
# wakes them: the same meadow at night, fireflies in the grass, and it has become the floor of a
# box of meadow (land_fold.gd): a few steps on the ground bends up into a wall with the
# fairground on it, over the top into a ceiling with a path to a little house, and down the far
# wall back to the bed. Gravity turns with the ground, so there is no seam to feel; looking up is
# looking at the meadow on the other side. The fairground's games come later. The house's door
# opens on its inside (house_inside.gd): a giant room, a glass ball, a tiny planet. The planet's
# little house opens on this meadow as it first was, dark, and stepping through it starts over
# (`again`); this time lying down on the bed wakes the player for real.
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
const SELF := "res://scenes/dream_meadow.tscn"
# Set once through the planet house's door: the dream is the dark meadow from the start again,
# and this time lying down on its bed wakes the player for real.
var again := false
# The one bright place is the origin; the player wakes this far away, facing it.
const START := Vector3(0, 0, 46)
const LIGHT_RADIUS := 7.0
const WALK_LIMIT := 150.0
const TREE_AT := Vector2(-2.2, -1.6)
const TREE_SCALE := 2.3
const BED_AT := Vector2(2.4, 1.2)
const BED_TURN := -25.0
const BED_REACH := 2.6
const Fold := preload("res://scripts/meadow/land_fold.gd")
const Inside := preload("res://scripts/meadow/house_inside.gd")
const LID := preload("res://assets/materials/eyelids.gdshader")
# The blink after lying down: (seconds, how open the eyes are), eased between.
const BLINK := [[0.0, 1.0], [1.6, 0.0], [3.6, 0.0], [4.2, 0.45], [4.6, 0.0], [5.4, 0.8], [5.7, 0.05], [7.0, 1.0]]
const NIGHT_AT := 2.4
const RISE_FROM := 7.0
const RISE_TIME := 2.2
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
var pool: Decal
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
var fold: Node3D
var ground_material: ShaderMaterial
var night := false
var lids: ShaderMaterial
var fireflies: GPUParticles3D
var grass_layers: Array = []
var stand_to: Transform3D
var inside: Node3D
var where := "box"
var wood_steps: AudioStreamPlayer
var grass_steps: AudioStreamPlayer
var told_room := false
var told_planet := false
# Built without a player, hud or the box: the doorway's view of the meadow's start.
var preview := false
var speed_lines: ShaderMaterial
var reticle: Label
var shard_count: Label
var flash_rect: ColorRect
var shard_pop := 0.0
var first_meadow: Node3D

static func ground_height(x: float, z: float) -> float:
	# Must match ground_height() in meadow_grass.gdshader.
	var d := Vector2(x, z).length()
	var roll := 3.2 * sin(x * 0.026 + 0.3) * cos(z * 0.021) + 1.8 * sin(x * 0.047 - z * 0.033 + 1.0) \
		+ 0.35 * sin(x * 0.11 + 1.3) * sin(z * 0.09 + 0.4)
	roll *= smoothstep(12.0, 55.0, d)
	# Flat along both edges of the night box's floor (land_fold.gd), as in the shader.
	roll *= smoothstep(0.0, 20.0, minf(absf(z - Fold.BEND_Z), absf(z - Fold.FAR_Z)))
	var a := atan2(z, x)
	var outside := maxf(Fold.BEND_Z - z, z - Fold.FAR_Z)
	var hills := smoothstep(140.0, 520.0, d) * smoothstep(10.0, 60.0, outside)
	hills = hills * hills * (34.0 + 16.0 * sin(a * 3.0 + 0.7) + 8.0 * sin(a * 7.0 + 2.1))
	return roll + hills

static func on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, ground_height(x, z), z)

func _ready() -> void:
	if quality < 0:
		quality = int(Settings.read("quality"))
	quality = clampi(quality, 0, 2)
	if not preview:
		preload("res://scripts/game_progress.gd").mark("meadow")
		_scaling()
	_sky()
	_ground()
	_grass()
	_light_shafts()
	_tree_and_bed()
	_flowers()
	if not preview:
		fold = Fold.new()
		fold.name = "LandFold"
		add_child(fold)
		fold.build(blade_mesh, GRASS_SHARE[quality], CLOSE_GRASS[quality])
		fold.reached_fair.connect(func() -> void: _say("Khu vui chơi giữa đồng cỏ."))
		fold.reached_house.connect(func() -> void: _say("Một ngôi nhà nhỏ."))
		fold.wheel.ride_over.connect(_off_wheel)
		fold.coaster.ride_over.connect(_off_wheel)
		fold.coaster.flash.connect(func(strength: float) -> void: flash_rect.color.a = maxf(flash_rect.color.a, strength))
		fold.coaster.shard_taken.connect(_on_shard)
		fold.coaster.dream_changed.connect(_on_dream)
		inside = Inside.new()
		inside.name = "HouseInside"
		add_child(inside)
		inside.build(fold, blade_mesh, quality, GRASS_SHARE[quality])
	_poles()
	_bubbles()
	_fish()
	if preview:
		# Only the dark meadow as it first opens, for the planet house's doorway to look into.
		shown_bright = -1.0
		_apply_brightness()
		return
	_sound()
	_hud()
	_make_player(Transform3D(Basis.IDENTITY, on_ground(START.x, START.z) + Vector3(0, 0.05, 0)), 0.08)
	# Once everything that follows the light exists, set it all once.
	shown_bright = -1.0
	_apply_brightness()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# On the lightest setting draw the 3D at three quarters and let FSR scale it up.
func _scaling() -> void:
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if quality == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 0.75 if quality == 0 else 1.0

# The player at `at` (facing its -Z), head tilted `look_up`.
func _make_player(at: Transform3D, look_up: float) -> void:
	player = Player.new()
	add_child(player)
	player.lucid = true
	player.global_position = at.origin
	var ahead := -at.basis.z
	player.yaw = atan2(-ahead.x, -ahead.z)
	player.pitch = look_up
	player.camera.rotation.x = look_up
	player.enabled = false
	player.camera.far = 3000.0
	grass_steps = AudioStreamPlayer.new()
	var steps := AudioStreamRandomizer.new()
	for i in range(1, 7):
		steps.add_stream(-1, load("res://assets/audio/steps/grass_0%d.ogg" % i))
	steps.random_pitch = 1.08
	steps.random_volume_offset_db = 2.0
	grass_steps.stream = steps
	grass_steps.volume_db = -16
	player.add_child(grass_steps)
	player.ground_steps = grass_steps
	# The giant room's floorboards: Kenney's wooden footsteps (assets/audio/steps/wood_sources.json).
	wood_steps = AudioStreamPlayer.new()
	var boards := AudioStreamRandomizer.new()
	for i in range(5):
		boards.add_stream(-1, load("res://assets/audio/steps/wood_0%d.ogg" % i))
	boards.random_pitch = 1.06
	boards.random_volume_offset_db = 2.0
	wood_steps.stream = boards
	wood_steps.volume_db = -12
	player.add_child(wood_steps)
	player.floor_grip = 16.0
	player.air_grip = 5.0

# The planet house's doorway: a second meadow, as it is at the very start (dark, the one bright
# place far ahead), in a world of its own, built when the glass ball is touched.
func _build_first_meadow() -> void:
	if first_meadow != null:
		return
	first_meadow = load(SELF).instantiate()
	first_meadow.preview = true
	first_meadow.quality = quality
	var arrive := Node3D.new()
	arrive.name = "Arrive"
	# Stepping out of the doorway is stepping onto the start, facing the light.
	arrive.transform = Transform3D(Basis(Vector3.UP, PI), on_ground(START.x, START.z))
	first_meadow.add_child(arrive)
	inside.link_first_meadow(first_meadow, arrive, player)
	inside.portal_planet.crossed.connect(_into_first_meadow)

# Through the planet house's door: that meadow becomes the dream (no loading, the same frame),
# the walker stands where the doorway put it, and it is the meadow from the start again; this
# time its bed wakes the player.
func _into_first_meadow(door: Node3D) -> void:
	var move: Transform3D = door.mapping()
	var body := move * Transform3D(player.global_basis, player.global_position)
	var head: float = player.pitch
	var speed: Vector3 = move.basis * player.velocity
	var next := first_meadow
	next.get_parent().remove_child(next)
	var tree := get_tree()
	var root := tree.root
	root.remove_child(self)
	root.add_child(next)
	tree.current_scene = next
	next.begin_again(body, head, speed)
	queue_free()

func begin_again(body: Transform3D, head: float, speed: Vector3) -> void:
	preview = false
	again = true
	_scaling()
	_sound()
	_hud()
	var flat := Vector3(-body.basis.z.x, 0, -body.basis.z.z).normalized()
	_make_player(Transform3D(Basis.looking_at(flat, Vector3.UP), body.origin), head)
	player.velocity = Vector3(speed.x, 0, speed.z)
	player.enabled = true
	fade.color.a = 0.0
	music.volume_db = -20.0
	state = "walk"
	state_time = 0.0
	shown_bright = -1.0
	_apply_brightness()
	_say("Lại là đồng cỏ này…")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	if preview:
		return
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
	if night:
		return
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
		shaft_light.light_energy = lerpf(12.0, 2.0, b)
	if pool != null:
		pool.emission_energy = lerpf(0.35, 0.0, b)
	for m in beam_materials:
		m.set_shader_parameter("strength", lerpf(0.11, 0.025, b) * m.get_meta("weight", 1.0))
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
	ground_material = material
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
	grass_layers = [close, mid, far]
	for layer in [close, mid, far]:
		layer.material.set_shader_parameter("clear_a", Vector4(TREE_AT.x, 0, TREE_AT.y, 0.9))
		layer.material.set_shader_parameter("clear_b", Vector4(BED_AT.x, 0, BED_AT.y, 1.25))

# One grass blade, a tapering strip `segments` long, one unit tall; UV.y runs root to tip.
func blade_mesh(segments: int) -> ArrayMesh:
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
	return blade.commit()

func _blade_layer(chunk: float, count: int, height: float, width: float, segments: int, reach: float, from: float, to: float) -> Dictionary:
	var material := ShaderMaterial.new()
	material.shader = GRASS
	material.set_shader_parameter("chunk", chunk)
	material.set_shader_parameter("blade_height", height)
	material.set_shader_parameter("blade_width", width)
	Fold.box_uniforms(material)
	var mesh := blade_mesh(segments)
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
	# A wide, soft pool rather than a hard disc of light.
	shaft_light.spot_angle = 16.0
	shaft_light.spot_angle_attenuation = 1.6
	shaft_light.spot_range = 70.0
	shaft_light.light_color = Color(1.0, 0.95, 0.78)
	shaft_light.shadow_enabled = false
	add_child(shaft_light)
	# And a glow laid on the grass itself, bright in the middle and fading out to nothing, so the
	# place reads as lit from far off with no edge to the pool.
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 256
	glow.height = 256
	var ramp := Gradient.new()
	# Emission takes the colour, not the alpha: the fade has to go to black.
	ramp.set_color(0, Color(1.0, 0.95, 0.82))
	ramp.set_color(1, Color(0, 0, 0))
	ramp.add_point(0.35, Color(0.55, 0.52, 0.45))
	ramp.add_point(0.7, Color(0.12, 0.11, 0.1))
	glow.gradient = ramp
	pool = Decal.new()
	# Low, so it lights the grass and not the tree trunk or the bed standing in it.
	pool.size = Vector3(22, 1.6, 22)
	pool.texture_emission = glow
	pool.emission_energy = 0.35
	pool.upper_fade = 0.3
	pool.lower_fade = 0.3
	# Only the ground and grass (layer 1); the tree and the bed are on layer 2 (_tree_and_bed).
	pool.cull_mask = 1
	add_child(pool)
	pool.global_position = on_ground(0, 0)
	# Many soft rays of different widths round the hole's centre, leaning a little apart: width,
	# brightness, where it meets the ground, lean (degrees about x and z), bell sharpness.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var shafts := [[16.0, 0.45, Vector2(0, 0), Vector2(0, 0), 5.0], [9.0, 0.7, Vector2(0.5, -0.4), Vector2(1.5, -1.0), 7.0],
		[5.0, 0.9, Vector2(-1.2, 1.0), Vector2(-2.5, 1.5), 9.0], [24.0, 0.25, Vector2(0, 0), Vector2(0.5, 0.5), 4.0]]
	for i in range(8):
		shafts.append([rng.randf_range(1.2, 3.5), rng.randf_range(0.5, 0.9), Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)),
			Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)), rng.randf_range(8.0, 14.0)])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i in range(shafts.size()):
		var plan: Array = shafts[i]
		var material := ShaderMaterial.new()
		material.shader = BEAM
		material.set_meta("weight", plan[1])
		material.set_shader_parameter("phase", i * 0.21)
		material.set_shader_parameter("sharpness", plan[4])
		var beam := MeshInstance3D.new()
		beam.mesh = quad
		beam.material_override = material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.extra_cull_margin = 200.0
		# The quad's height runs along its local y: scale it to the ray's width and length.
		var lean := Basis.from_euler(Vector3(deg_to_rad(plan[3].x), 0, deg_to_rad(plan[3].y)))
		var length := 160.0
		var foot := Vector3(plan[2].x, 0, plan[2].y)
		beam.transform = Transform3D(lean * Basis.from_scale(Vector3(plan[0], length, 1.0)), foot + lean * Vector3(0, length / 2, 0))
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
	for node in [tree, bed]:
		for mesh: VisualInstance3D in (node as Node3D).find_children("*", "VisualInstance3D", true, false):
			mesh.layers = 2
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
		if at.distance_to(BED_AT) < 1.8 or at.distance_to(TREE_AT) < 1.4 or at.y < Fold.BEND_Z + 0.5:
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
	# One line along x, the way the night box runs, so at night it goes off down the box to the
	# horizon both ways; by day it crosses the meadow behind where the dream starts.
	var line_z := 34.0
	var tops: Array = []
	var prefixes := POLE_PRESETS.keys()
	var i := 0
	var x := -420.0
	while x < 420.0:
		var z := line_z + sin(x * 0.01) * 3.0
		var at := on_ground(x, z)
		var pole := _pole(prefixes[i % prefixes.size()])
		pole.position = at - Vector3(0, 0.15, 0)
		pole.scale = Vector3.ONE * 1.5
		pole.rotation_degrees.z = (i % 3 - 1) * 1.2
		add_child(pole)
		_solid_cylinder(at, 0.25, 9.0)
		var arm := Vector3(0, 0, 0.75)
		tops.append([at + Vector3(0, 8.58, 0) - arm, at + Vector3(0, 8.58, 0) + arm, at + Vector3(0, 6.83, 0)])
		x += 46.0
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
	lids = ShaderMaterial.new()
	lids.shader = LID
	lids.set_shader_parameter("open", 1.0)
	var eyelids := ColorRect.new()
	eyelids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyelids.material = lids
	eyelids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(eyelids)
	speed_lines = ShaderMaterial.new()
	speed_lines.shader = preload("res://assets/materials/speed_lines.gdshader")
	var streaks := ColorRect.new()
	streaks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	streaks.material = speed_lines
	streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(streaks)
	reticle = Label.new()
	reticle.text = "◦"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	reticle.grow_vertical = Control.GROW_DIRECTION_BOTH
	reticle.add_theme_font_size_override("font_size", 26)
	reticle.modulate = Color(1, 1, 1, 0)
	hud.add_child(reticle)
	shard_count = Label.new()
	shard_count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shard_count.position += Vector2(-260, 30)
	shard_count.size = Vector2(230, 40)
	shard_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shard_count.add_theme_font_size_override("font_size", 24)
	shard_count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	shard_count.modulate = Color(1, 1, 1, 0)
	hud.add_child(shard_count)
	hint = _label(-80, 20)
	prompt = _label(-130, 22)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.0, 0.0, 0.02, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.98, 0.95, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash_rect)

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
	if preview:
		return
	if event is InputEventMouseButton and event.pressed and state != "leave":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if near_bed():
			lie_down()
		elif night and state == "walk":
			var at := player.global_position
			if fold.near_door(at):
				open_house()
			elif fold.wheel.near_board(at):
				ride_wheel()
			elif fold.coaster.near_board(at):
				ride_coaster()
			elif inside.near_globe(at):
				touch_globe()
			elif inside.near_planet_door(at):
				inside.open_planet_door()

func near_bed() -> bool:
	if state != "walk" or player == null or night:
		return false
	var flat := Vector2(player.global_position.x - bed.global_position.x, player.global_position.z - bed.global_position.z)
	return flat.length() < BED_REACH

func in_light() -> bool:
	return Vector2(player.global_position.x, player.global_position.z).length() < LIGHT_RADIUS

func _process(delta: float) -> void:
	clock += delta
	state_time += delta
	if flash_rect != null and flash_rect.color.a > 0.0:
		flash_rect.color.a = move_toward(flash_rect.color.a, 0.0, delta * 1.4)
	hint_time += delta
	if lit:
		bright = clampf((clock - bright_from) / BRIGHTEN_TIME, 0.0, 1.0)
	_apply_brightness()
	_tick_fish(delta)
	if preview:
		return
	if hint.modulate.a > 0.0 and hint_time > 8.0:
		hint.modulate.a = move_toward(hint.modulate.a, 0.0, delta * 0.5)
	match state:
		"wake": _wake()
		"walk": _walk()
		"lie": _lie()
		"blink": _blink()
		"rise": _rise_up()
		"zoom": _zoom()
		"ride": _riding()
		"coaster": _coasting(delta)
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
	if night:
		_follow_zone()
	if night and where == "box":
		# The box goes on along x for ever; past WALK_X the dream turns you back the way you came.
		if absf(p.x) > Fold.WALK_X and player.velocity.x * signf(p.x) > -0.5:
			player.velocity.x = -signf(p.x) * 0.5
	elif not night and flat.length() > WALK_LIMIT:
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
	if night:
		fold.check_walker(player.global_position)
		fireflies.global_position = player.global_position
	prompt.text = "E · Nằm xuống" if near_bed() else ""
	if night:
		if fold.near_door(p) or inside.near_planet_door(p):
			prompt.text = "E · Mở cửa"
		elif fold.wheel.near_board(p):
			prompt.text = "E · Lên đu quay"
		elif fold.coaster.near_board(p):
			prompt.text = "E · Lên tàu lượn"
		elif inside.near_globe(p):
			prompt.text = "E · Chạm vào quả cầu"
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
	lie_to = _pillow_view()

# Head on the pillow, looking up past the tree into the sky full of fish.
func _pillow_view() -> Transform3D:
	var head := bed.global_transform * Vector3(0, 0.95, -0.65)
	var tree_at := on_ground(TREE_AT.x, TREE_AT.y)
	var up_at := head + (Vector3(tree_at.x, head.y, tree_at.z) - head).normalized() * 4.0 + Vector3(0, 9.0, 0)
	# Head turned a little towards the tree: its trunk rises from the bottom of the view.
	var crown := Vector3(tree_at.x - head.x, 0, tree_at.z - head.z).normalized()
	return Transform3D(Basis.looking_at(up_at - head, crown), head)

func _lie() -> void:
	var t := smoothstep(0.0, 3.0, state_time)
	player.camera.global_transform = Transform3D(lie_from.basis.slerp(lie_to.basis, t), lie_from.origin.lerp(lie_to.origin, t))
	if state_time > 5.0:
		state = "blink"
		state_time = 0.0

func eyes_open(t: float) -> float:
	for i in range(BLINK.size() - 1):
		var a: Array = BLINK[i]
		var b: Array = BLINK[i + 1]
		if t <= b[0]:
			return lerpf(a[1], b[1], smoothstep(a[0], b[0], t))
	return 1.0

# The eyes close on the day; while they are shut it turns night, and they blink open on stars.
func _blink() -> void:
	player.camera.global_transform = lie_to
	lids.set_shader_parameter("open", eyes_open(state_time))
	# The meadow's own music goes; behind closed eyes a fairground starts up, and the eyes open to it.
	music.volume_db = lerpf(-11.0, -40.0, clampf(state_time / 2.0, 0, 1))
	if state_time > NIGHT_AT and not night and not again:
		make_night()
	if night:
		fold.music.volume_db = lerpf(-30.0, 0.0, clampf((state_time - NIGHT_AT) / 2.5, 0, 1))
	if again and state_time > NIGHT_AT:
		# This time the eyes stay shut, and open on the real morning.
		again = false
		state = "leave"
		state_time = 0.0
		return
	if state_time > RISE_FROM:
		_get_up()

func _get_up() -> void:
	state = "rise"
	state_time = 0.0
	# Up off the bed, on the side towards the fold.
	var stand := bed.global_transform * Vector3(1.35, 0, 0.2)
	stand.y = ground_height(stand.x, stand.z)
	# Facing the way the music comes from: the fold, and the fair standing up on it.
	stand_to = Transform3D(Basis.from_euler(Vector3(0.38, 0.0, 0)), stand + Vector3(0, player.EYE, 0))

func _rise_up() -> void:
	var t := smoothstep(0.0, RISE_TIME, state_time)
	player.camera.global_transform = Transform3D(lie_to.basis.slerp(stand_to.basis, t), lie_to.origin.lerp(stand_to.origin, t))
	if state_time > RISE_TIME:
		state = "walk"
		state_time = 0.0
		player.global_position = stand_to.origin - Vector3(0, player.EYE, 0)
		player.velocity = Vector3.ZERO
		player.yaw = 0.0
		player.pitch = 0.38
		player.eye = player.EYE
		player.camera.position = Vector3(0, player.EYE, 0)
		player.camera.rotation = Vector3(0.38, 0, 0)
		player.gravity_field = inside.up_at
		player.set_physics_process(true)
		player.set_process(true)
		player.enabled = true
		_say("Tiếng nhạc… từ đâu vậy?\nShift · chạy")

# Night falls all at once behind closed eyes: stars, a low moon-blue light, fireflies, and the fold.
func make_night() -> void:
	night = true
	sky_material.set_shader_parameter("night", 1.0)
	sky_material.set_shader_parameter("night_sky", load(M + "qwantani_night_puresky_2k.hdr"))
	environment.ambient_light_energy = 0.55
	environment.tonemap_exposure = 1.25
	# A pale night haze: the far faces of the box melt into it, so it never ends anywhere.
	environment.fog_density = 0.0036
	environment.fog_aerial_perspective = 0.0
	environment.fog_light_color = Color(0.2, 0.25, 0.4)
	environment.fog_light_energy = 1.0
	environment.adjustment_saturation = 1.05
	# Moonlight with no shadows: inside the box every face would otherwise shade the others into
	# the dark. Slanted along the box so every face catches a little of it.
	sun.light_color = Color(0.62, 0.72, 1.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = false
	sun.basis = Basis.looking_at(Vector3(0.75, -0.45, 0.45).normalized(), Vector3.UP)
	shaft_light.visible = false
	pool.visible = false
	for beam in beams:
		beam.visible = false
	bubbles.set_shader_parameter("appear", 0.0)
	for fish in fishes:
		fish.node.queue_free()
	fishes.clear()
	post.set_shader_parameter("lift", 0.05)
	post.set_shader_parameter("lift_tint", Color(0.2, 0.22, 0.45))
	post.set_shader_parameter("gain_tint", Color(0.95, 0.95, 1.0))
	post.set_shader_parameter("halo", 0.6)
	# Only the box's floor is left of the meadow: no ground and no grass past its edges.
	ground_material.set_shader_parameter("keep_z", Vector2(Fold.BEND_Z, Fold.FAR_Z))
	for layer in grass_layers:
		layer.material.set_shader_parameter("keep_z", Vector2(Fold.BEND_Z + 0.3, Fold.FAR_Z - 0.3))
	fold.show_fold()
	# The moon lights only the box: the room and the planet have their own lamps.
	sun.light_cull_mask = 1 | 2 | Inside.Portal.SHELL
	inside.connect_portals(player, environment)
	_fireflies()

func _fireflies() -> void:
	fireflies = GPUParticles3D.new()
	fireflies.amount = 140
	fireflies.lifetime = 7.0
	fireflies.preprocess = 7.0
	fireflies.local_coords = false
	fireflies.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 15, 60))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(22, 1.2, 22)
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.35
	process.gravity = Vector3.ZERO
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	fireflies.process_material = process
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.vertex_color_use_as_albedo = true
	glow.albedo_color = Color(3.0, 2.6, 0.9)
	dot.material = glow
	fireflies.draw_pass_1 = dot
	add_child(fireflies)
	fireflies.global_position = player.global_position

# The Ferris wheel: sit in a cabin and go up, very slowly, into a sky full of stars (ferris_wheel.gd
# does the ride; the head still turns to look round).
func ride_wheel() -> void:
	state = "ride"
	state_time = 0.0
	prompt.modulate.a = 0.0
	_say("")
	fold.wheel.ride(player)

func _riding() -> void:
	if not has_meta("told_top") and fold.wheel.height_share() > 0.9:
		set_meta("told_top", true)
		_say("Trên này… thấy cả bầu trời.")
	_clear_view(smoothstep(0.3, 0.75, fold.wheel.height_share()))

# Up high on the wheel the dream's haze lifts: no soft edges, colour fringes, grain or far blur,
# so the stars are sharp. 0 is the dream's usual look, 1 the clearest.
func _clear_view(k: float) -> void:
	post.set_shader_parameter("aberration", lerpf(0.004, 0.0004, k))
	post.set_shader_parameter("soft_edges", lerpf(0.55, 0.05, k))
	post.set_shader_parameter("halo", lerpf(0.6, 0.12, k))
	post.set_shader_parameter("grain", lerpf(0.045, 0.012, k))
	post.set_shader_parameter("vignette", lerpf(0.32, 0.18, k))
	focus.dof_blur_far_enabled = quality > 0 and k < 0.05

# The roller coaster (roller_coaster.gd does the ride).
func ride_coaster() -> void:
	state = "coaster"
	state_time = 0.0
	prompt.modulate.a = 0.0
	_say("")
	fold.coaster.ride(player)

# On the roller coaster: the fair's music gone, streaks at the edges with speed, the white of the
# dream's gateways fading.
func _coasting(delta: float) -> void:
	fold.music.volume_db = move_toward(fold.music.volume_db, -80.0, delta * 40.0)
	var coaster: Node3D = fold.coaster
	speed_lines.set_shader_parameter("amount", clampf((coaster.speed - 25.0) / 45.0, 0.0, 1.0))
	# Crisper out in the open dream, never switched: it follows the cloud at the seams.
	var open: float = (1.0 - coaster.cloud) if coaster.phase == "dream" else 0.0
	_clear_view(0.5 * open)
	shard_pop = maxf(shard_pop - delta * 2.0, 0.0)
	shard_count.scale = Vector2.ONE * (1.0 + shard_pop * 0.35)

func _on_shard(count: int, total: int) -> void:
	shard_count.text = "✦ Mảnh ký ức %d/%d" % [count, total]
	shard_pop = 1.0
	if count == total:
		_say("Đủ cả rồi…")

func _on_dream(on: bool) -> void:
	reticle.modulate.a = 0.75 if on else 0.0
	shard_count.modulate.a = 1.0 if on else 0.0
	if on:
		shard_count.text = "✦ Mảnh ký ức 0/%d" % fold.coaster.dream.SHARDS.size()
		_say("Nhìn vào những mảnh sáng để nhặt.")

func _off_wheel() -> void:
	_clear_view(0.0)
	speed_lines.set_shader_parameter("amount", 0.0)
	fold.music.volume_db = 0.0
	state = "walk"
	state_time = 0.0

# The door swings in, and the doorway already shows what is inside: the walk goes on through it.
func open_house() -> void:
	fold.open_door()
	inside.start_music()
	prompt.modulate.a = 0.0

# Which world the player is in (the box, the room, the planet): that world's light, air and
# footsteps, and a word the first time.
func _follow_zone() -> void:
	var now: String = inside.zone(player.global_position)
	if now == where:
		return
	where = now
	var camera: Camera3D = player.camera
	match where:
		"box":
			camera.environment = null
			camera.far = 3000.0
			player.ground_steps = grass_steps
			fireflies.visible = true
			inside.music.volume_db = -80.0
		"room":
			camera.environment = inside.room_environment
			camera.far = 3000.0
			player.ground_steps = wood_steps
			fireflies.visible = false
			inside.music.pitch_scale = 0.62
			inside.music.volume_db = -24.0
			if not told_room:
				told_room = true
				_say("Bên trong… rộng quá.")
		"planet":
			camera.environment = inside.planet_environment
			camera.far = 7000.0
			player.ground_steps = grass_steps
			fireflies.visible = false
			inside.music.pitch_scale = 0.5
			inside.music.volume_db = -28.0
			if not told_planet:
				told_planet = true
				_say("Một hành tinh nhỏ xíu.")

# Touching the glass ball: the eye leaves the body and falls into it, down to the tiny planet,
# which turns out to be the real one.
func touch_globe() -> void:
	state = "zoom"
	state_time = 0.0
	player.enabled = false
	player.set_physics_process(false)
	player.set_process(false)
	prompt.modulate.a = 0.0
	_say("")
	inside.zoom_begin(player.camera.global_transform)
	_build_first_meadow()

func _zoom() -> void:
	var step: Dictionary = inside.zoom(state_time)
	var camera: Camera3D = player.camera
	camera.global_transform = step.camera
	camera.near = step.near
	inside.room_environment.fog_density = step.fog
	if state_time < inside.zoom_length():
		return
	inside.room_environment.fog_density = Inside.FOG
	camera.near = 0.05
	player.global_position = inside.landing()
	player.frame = Basis.IDENTITY
	player.up_direction = Vector3.UP
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = -0.05
	player.camera.position = Vector3(0, player.EYE, 0)
	player.camera.rotation = Vector3(-0.05, 0, 0)
	player.global_basis = Basis.IDENTITY
	player.set_physics_process(true)
	player.set_process(true)
	player.enabled = true
	state = "walk"
	state_time = 0.0
	_follow_zone()

# Asleep on the meadow's bed the second time: everything goes white, and it is the next morning.
func _leave() -> void:
	fade.color = Color(1.0, 0.98, 0.94, clampf(state_time / 3.0, 0, 1))
	music.volume_db = lerpf(-11.0, -40.0, clampf(state_time / 3.5, 0, 1))
	if state_time > 3.8 and not has_meta("left"):
		set_meta("left", true)
		get_tree().change_scene_to_file.call_deferred(NEXT_SCENE)
