extends Node3D
# The floor gives way between NEAR and FAR (world z), right across the dream.
# Before: one solid floor. collapse() starts the fall: the water shader stops drawing the floor in
# the band (spreading out from x = 0), and the slabs that covered it, drawn with the same water
# material, break loose and tumble into the haze. Two thick walls of broken concrete give the
# edges depth, water pours over both lips, and the colliders change from one floor to two banks.
signal settled
const CONCRETE := "res://assets/polyhaven_horror/cracked_concrete_diff_1k.jpg"
const SLAB := 3.0
const REACH := 27.0
var near_z: float
var far_z: float
var water: ShaderMaterial
var slab_water: ShaderMaterial
var bridge_floor: StaticBody3D
var falling: Array[Dictionary] = []
var stay: Array[MeshInstance3D] = []
var opened_at := -1.0
var clock := 0.0
var pour: Array[GPUParticles3D] = []
var rumble: AudioStreamPlayer
var crash: AudioStreamPlayer
var shake := 0.0
var islands: Array = []

# `stand` lists the islands left standing in the rift, as Rect2(x_min, z_min, width, depth) on
# the floor. They must sit on the 3 m slab grid: the slabs inside them simply never fall.
func setup(near: float, far: float, floor_material: ShaderMaterial, stand: Array = []) -> void:
	islands = stand
	near_z = near
	far_z = far
	water = floor_material
	water.set_shader_parameter("rift_near", near_z)
	water.set_shader_parameter("rift_far", far_z)
	slab_water = water.duplicate()
	slab_water.set_shader_parameter("rift_open", 1e9)
	_banks()
	_walls()
	_slabs()
	_pour()
	# Kept soft and far away: the dream stays calm even as the floor goes. The water pouring over
	# the lips is only seen, not heard (its looping hiss was too loud for the scene).
	rumble = _sound("res://assets/audio/floor_thud.wav", -20)
	crash = _sound("res://assets/audio/mirror_crash_muffled.wav", -26)

func _sound(path: String, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = db
	add_child(player)
	return player

func _box_body(size: Vector3, centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	add_child(body)
	return body

func _banks() -> void:
	_box_body(Vector3(3000, 1, 1500), Vector3(0, -0.5, near_z + 750))
	_box_body(Vector3(3000, 1, 1500), Vector3(0, -0.5, far_z - 750))
	bridge_floor = _box_body(Vector3(3000, 1, near_z - far_z), Vector3(0, -0.5, (near_z + far_z) / 2))
	for island: Rect2 in islands:
		var centre := island.get_center()
		_box_body(Vector3(island.size.x, 1, island.size.y), Vector3(centre.x, -0.5, centre.y))

func on_island(x: float, z: float) -> bool:
	for island: Rect2 in islands:
		if island.has_point(Vector2(x, z)):
			return true
	return false

func _walls() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = load(CONCRETE)
	rock.albedo_color = Color(0.62, 0.58, 0.66)
	rock.uv1_triplanar = true
	rock.uv1_scale = Vector3.ONE * 0.25
	rock.roughness = 0.95
	for edge in [[near_z, 1.0], [far_z, -1.0]]:
		var wall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3000, 60, 1.6)
		wall.mesh = mesh
		wall.material_override = rock
		wall.position = Vector3(0, -30.03, edge[0] + edge[1] * 0.8)
		add_child(wall)
	# Each island is the top of a pillar of the same broken concrete going down into the haze.
	for island: Rect2 in islands:
		var pillar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(island.size.x - 0.1, 60, island.size.y - 0.1)
		pillar.mesh = mesh
		pillar.material_override = rock
		var centre := island.get_center()
		pillar.position = Vector3(centre.x, -30.4, centre.y)
		add_child(pillar)

func _slabs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 552
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SLAB, 0.45, SLAB)
	var columns := int(REACH * 2 / SLAB)
	var rows := int(ceil((near_z - far_z) / SLAB))
	for c in range(columns):
		for r in range(rows):
			var x := -REACH + (c + 0.5) * SLAB
			var z := near_z - (r + 0.5) * SLAB
			var slab := MeshInstance3D.new()
			slab.mesh = mesh
			slab.material_override = slab_water
			slab.position = Vector3(x, -0.23, z)
			slab.visible = false
			add_child(slab)
			if on_island(x, z):
				stay.append(slab)
				continue
			falling.append({"node": slab, "delay": absf(x) * 0.025 + 0.15 + rng.randf() * 0.5 + (0.3 if r == 0 or r == rows - 1 else 0.0),
				"spin": Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)) * 0.9, "speed": 0.0})

func _pour() -> void:
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.4)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	white.albedo_color = Color(0.92, 0.9, 1.0, 0.22)
	white.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = white
	for edge in [[near_z, -1.0], [far_z, 1.0]]:
		var sheet := GPUParticles3D.new()
		sheet.amount = 900
		sheet.lifetime = 1.4
		sheet.emitting = false
		sheet.draw_pass_1 = drop
		sheet.visibility_aabb = AABB(Vector3(-60, -30, -6), Vector3(120, 32, 12))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(28, 0.02, 0.05)
		process.direction = Vector3(0, -0.2, edge[1])
		process.spread = 6.0
		process.initial_velocity_min = 0.4
		process.initial_velocity_max = 0.9
		process.gravity = Vector3(0, -9.8, 0)
		sheet.process_material = process
		sheet.position = Vector3(0, -0.02, edge[0] + edge[1] * 0.1)
		add_child(sheet)
		pour.append(sheet)

func collapse() -> void:
	if opened_at >= 0.0:
		return
	opened_at = clock
	water.set_shader_parameter("rift_open", water.get_shader_parameter("clock"))
	for slab in falling:
		slab.node.visible = true
	for slab in stay:
		slab.visible = true
	rumble.play()
	shake = 0.35
	bridge_floor.queue_free()

func _process(delta: float) -> void:
	clock += delta
	slab_water.set_shader_parameter("clock", water.get_shader_parameter("clock"))
	slab_water.set_shader_parameter("ripples", water.get_shader_parameter("ripples"))
	shake = maxf(shake - delta * 0.35, 0.0)
	if opened_at < 0.0:
		return
	var t := clock - opened_at
	if t > 0.5 and not crash.playing and t < 0.6:
		crash.play()
	if t > 0.4 and not pour[0].emitting:
		for sheet in pour:
			sheet.emitting = true
	var still := 0
	for slab in falling:
		if slab.has("gone"):
			continue
		var node: MeshInstance3D = slab.node
		if t < slab.delay:
			still += 1
			continue
		slab.speed += 9.8 * delta
		node.position.y -= slab.speed * delta
		node.rotation += slab.spin * delta
		if node.position.y < -40.0:
			slab.gone = true
			node.queue_free()
		else:
			still += 1
	if still == 0 and not has_meta("settled"):
		set_meta("settled", true)
		settled.emit()
