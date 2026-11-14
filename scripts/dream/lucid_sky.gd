extends Node3D
# Past the school gate the dream goes lucid: the main character knows it is a dream, and the
# dream lets go. Things in the yard lift off the water (a teacher's desk, a book as big as a bed,
# a sheet of exam paper, a blackboard) and hang in a slow spiral round the flagpole, up into a
# bank of cloud at dusk. On the cloud stands a classroom door with the light on; through it is
# waking up.
# Nothing here can be lost. Jumps are high and slow (dream_player.gd, `lucid`), holding Space
# floats, and a fall is only a long drift back down to the water.
# A few steps of the spiral have floated off (MISSING). Holding the left mouse button (or E) on
# anything floating pulls it in: it comes to hang a few metres in front of the eye, and where
# you look is where it goes. Let go and it stays. The thing you are standing on cannot be pulled.
signal reached_door
const CLOUD := preload("res://assets/materials/dream_cloud.gdshader")
const DESK := "res://assets/polyhaven_corridor/metal_office_desk/metal_office_desk.gltf"
const D := "res://assets/polyhaven_dream/%s/%s_1k.gltf"
const SINK := 0.12
const STEPS := 16
const RADIUS := 6.5
const TURN := 40.0
const FIRST := 1.3
const RISE := 1.8
# Each missing step leaves a climb of two RISEs, higher than the jump can reach.
const MISSING := [4, 8, 11, 14]
const HOLD := 3.4
const PICK_DEGREES := 9.0
const PICK_RANGE := 60.0
const RISE_TIME := 5.0
const KINDS := ["desk", "book", "paper", "board"]

var player: CharacterBody3D
var pieces: Array[Dictionary] = []
var held := {}
var hovered := {}
var glow: StandardMaterial3D
var clock := 0.0
var started := -1.0
var cloud_top := 0.0
var door: Node3D
var door_body: Node3D
var grab_sound: AudioStreamPlayer
var hum: AudioStreamPlayer
var pulling := false
var done := false
var island_dir := Vector3.ZERO

static func slot_at(i: int) -> Vector3:
	var a := deg_to_rad(i * TURN)
	return Vector3(sin(a) * RADIUS, FIRST + i * RISE, cos(a) * RADIUS)

# The way along the spiral at step i (pieces lie long-side along it).
static func slot_yaw(i: int) -> float:
	return deg_to_rad(i * TURN) + PI / 2

func build(who: CharacterBody3D) -> void:
	player = who
	glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.82, 0.55, 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2552
	for i in range(STEPS):
		var kind: String = KINDS[i % KINDS.size()]
		var home := slot_at(i)
		var yaw := slot_yaw(i)
		var drifting := MISSING.has(i)
		if drifting:
			# Floated off: further out, a little up or down, and turned any old way.
			var a := deg_to_rad(i * TURN + rng.randf_range(-35.0, 35.0))
			var r := rng.randf_range(13.0, 19.0)
			home = Vector3(sin(a) * r, home.y + rng.randf_range(-2.5, 2.5), cos(a) * r)
			# Not inside the cloud the spiral ends on.
			var last := slot_at(STEPS - 1)
			if Vector2(home.x, home.z).normalized().dot(Vector2(last.x, last.z).normalized()) > 0.3 and home.y > last.y - 6.0:
				home = Vector3(-home.x, home.y, -home.z)
			yaw = rng.randf_range(-PI, PI)
		pieces.append(_piece(kind, home, yaw, i, drifting, rng.randf() * TAU))
	var last := slot_at(STEPS - 1)
	cloud_top = last.y + 1.0
	island_dir = Vector3(last.x, 0, last.z).normalized()
	_clouds(rng)
	_island()
	_door()
	grab_sound = AudioStreamPlayer.new()
	grab_sound.stream = load("res://assets/audio/memory.wav")
	grab_sound.volume_db = -20
	add_child(grab_sound)

# A floating thing: an AnimatableBody3D (so whoever stands on it rides it) holding a model whose
# long side runs along local Z, with a box collider fitted to the model.
func _piece(kind: String, home: Vector3, yaw: float, index: int, drifting: bool, phase: float) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.name = "Piece%d" % index
	add_child(body)
	var visual := Node3D.new()
	body.add_child(visual)
	var model := Node3D.new()
	visual.add_child(model)
	match kind:
		"desk":
			model.add_child(load(DESK).instantiate())
		"book":
			var book := _part("book_encyclopedia_set_01", "book_encyclopedia_set_01_book0%d" % (1 + index % 9))
			book.rotation_degrees = Vector3(0, 0, 90)
			book.scale = Vector3.ONE * 9.0
			model.add_child(book)
		"paper":
			var sheet := _part("office_notepads", "office_notepads_a4_%s" % ["a", "b", "c"][index % 3])
			sheet.scale = Vector3.ONE * 9.0
			model.add_child(sheet)
		"board":
			_board(model)
	var box := _bounds(visual)
	# Long side along local Z, the way the spiral runs.
	if box.size.x > box.size.z:
		model.rotation.y = PI / 2
		box = _bounds(visual)
	# Centred on the body, its top at the body's origin: a slot's height is the height stood on.
	model.position -= Vector3(box.get_center().x, box.position.y + box.size.y, box.get_center().z)
	box = _bounds(visual)
	# Sheets of paper have no thickness of their own; give the collider a little.
	box.size.y = maxf(box.size.y, 0.06)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size
	shape.shape = cube
	shape.position = Vector3(0, -box.size.y / 2, 0)
	body.add_child(shape)
	body.position = home - Vector3(0, 8.0, 0)
	body.rotation.y = yaw
	body.visible = false
	return {"body": body, "visual": visual, "home": home, "anchor": home, "yaw": yaw, "kind": kind,
		"index": index, "drifting": drifting, "phase": phase, "size": box.size, "placed": false}

func _part(pack: String, part: String) -> Node3D:
	var source: Node3D = load(D % [pack, pack]).instantiate()
	var found: Node3D = source.find_child(part, true, false)
	var copy: Node3D = found.duplicate()
	copy.position = Vector3.ZERO
	source.free()
	var holder := Node3D.new()
	holder.add_child(copy)
	return holder

func _board(parent: Node3D) -> void:
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color(0.1, 0.19, 0.15)
	slate.roughness = 0.9
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.17)
	wood.roughness = 0.7
	_mesh(parent, Vector3(1.4, 0.07, 3.4), Vector3.ZERO, slate)
	for side in [-1.0, 1.0]:
		_mesh(parent, Vector3(0.07, 0.1, 3.54), Vector3(side * 0.735, 0.005, 0), wood)
		_mesh(parent, Vector3(1.4, 0.1, 0.07), Vector3(0, 0.005, side * 1.735), wood)

func _mesh(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node

# The model's bounds in its holder's space (the holder is not yet in the tree, so walk it by hand).
func _bounds(holder: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var node: Node = mesh
		while node != holder:
			t = (node as Node3D).transform * t
			node = node.get_parent()
		var b := t * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

# A sea of cloud just under the island, and a few banks higher up, all one MultiMesh of puffs.
func _clouds(rng: RandomNumberGenerator) -> void:
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fast := FastNoiseLite.new()
	fast.frequency = 0.012
	fast.fractal_octaves = 4
	noise.noise = fast
	var material := ShaderMaterial.new()
	material.shader = CLOUD
	material.set_shader_parameter("noise", noise)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	var spots: Array[Transform3D] = []
	var seeds: Array[float] = []
	var centre := island_dir * 20.0
	for i in range(520):
		var at: Vector3
		var size: float
		if i < 160:
			# The island itself: low puffs round the knees, none in front of the eye.
			at = centre + Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)).rotated(Vector3.UP, atan2(island_dir.x, island_dir.z))
			size = rng.randf_range(2.5, 4.5)
			at.y = cloud_top - size * 0.3 + rng.randf_range(-0.5, 0.15)
		elif i < 430:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 110.0 + 8.0
			at = Vector3(sin(a) * r, cloud_top + rng.randf_range(-3.5, 0.5), cos(a) * r)
			size = rng.randf_range(6.0, 14.0)
		else:
			var a := rng.randf() * TAU
			var r := rng.randf_range(20.0, 120.0)
			at = Vector3(sin(a) * r, cloud_top + rng.randf_range(7.0, 22.0), cos(a) * r)
			size = rng.randf_range(10.0, 22.0)
		spots.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 0.6, size)), at))
		seeds.append(rng.randf())
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = spots.size()
	for i in range(spots.size()):
		multi.set_instance_transform(i, spots[i])
		multi.set_instance_custom_data(i, Color(seeds[i], 0, 0, 0))
	var holder := MultiMeshInstance3D.new()
	holder.name = "Clouds"
	holder.multimesh = multi
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.visible = false
	add_child(holder)

# The cloud you can walk on: one wide body just under the puffs, beyond the top of the spiral.
func _island() -> void:
	var body := StaticBody3D.new()
	body.name = "CloudIsland"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1.0, 30)
	shape.shape = box
	body.add_child(shape)
	body.position = island_dir * (RADIUS + 1.6 + 15.0) + Vector3(0, cloud_top - 0.5, 0)
	body.rotation.y = atan2(island_dir.x, island_dir.z)
	add_child(body)

# A classroom door standing on its own in the cloud, open, the room's light spilling out.
func _door() -> void:
	door = Node3D.new()
	door.name = "Door"
	door.position = island_dir * (RADIUS + 13.0) + Vector3(0, cloud_top, 0)
	# Face back towards the spiral, so it is seen front-on on arrival.
	door.rotation.y = atan2(island_dir.x, island_dir.z)
	door.visible = false
	add_child(door)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_texture = load("res://assets/polyhaven_school/yellow_plaster_diff_1k.jpg")
	plaster.uv1_triplanar = true
	plaster.uv1_scale = Vector3.ONE * 0.5
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.27, 0.16)
	wood.roughness = 0.6
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color(1.0, 0.9, 0.7)
	_mesh(door, Vector3(0.35, 2.6, 0.3), Vector3(-0.72, 1.3, 0), plaster)
	_mesh(door, Vector3(0.35, 2.6, 0.3), Vector3(0.72, 1.3, 0), plaster)
	_mesh(door, Vector3(1.79, 0.4, 0.3), Vector3(0, 2.4, 0), plaster)
	var inside := _mesh(door, Vector3(1.1, 2.2, 0.02), Vector3(0, 1.1, 0.02), light)
	inside.name = "Light"
	# The leaf swung open on its hinge.
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.55, 0, -0.15)
	hinge.rotation_degrees.y = 105.0
	door.add_child(hinge)
	_mesh(hinge, Vector3(1.1, 2.2, 0.05), Vector3(0.55, 1.1, 0), wood)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.62)
	lamp.light_energy = 2.0
	lamp.omni_range = 7.0
	lamp.position = Vector3(0, 1.4, 1.0)
	door.add_child(lamp)
	for x in [-0.72, 0.72]:
		var post := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = Vector3(0.35, 2.6, 0.3)
		shape.shape = cube
		post.add_child(shape)
		post.position = Vector3(x, 1.3, 0)
		door.add_child(post)

# Called when the dream goes lucid: everything comes up out of the water, one after another.
func start() -> void:
	if started >= 0.0:
		return
	started = clock
	for piece in pieces:
		piece.body.visible = true
	get_node("Clouds").visible = true
	door.visible = true

func risen() -> bool:
	return started >= 0.0 and clock - started > RISE_TIME + STEPS * 0.2

func _rise_for(piece: Dictionary) -> float:
	if started < 0.0:
		return 0.0
	return smoothstep(0.0, RISE_TIME, clock - started - piece.index * 0.2)

func _physics_process(delta: float) -> void:
	clock += delta
	if started < 0.0:
		return
	var under := standing_on()
	for piece in pieces:
		var body: AnimatableBody3D = piece.body
		if not held.is_empty() and piece.index == held.index:
			continue
		var bob := sin(clock * 0.5 + piece.phase) * 0.05
		var wander := Vector3.ZERO
		if piece.drifting and not piece.placed:
			# Loose ones wander slowly round where they floated off to.
			wander = Vector3(sin(clock * 0.13 + piece.phase), sin(clock * 0.21 + piece.phase) * 0.6, cos(clock * 0.11 + piece.phase)) * 1.2
		var goal: Vector3 = piece.anchor + wander + Vector3(0, bob, 0)
		var rise := _rise_for(piece)
		goal.y -= (1.0 - rise) * 8.0
		body.position = goal
		body.rotation.y = lerp_angle(body.rotation.y, piece.yaw, delta * 0.5) if piece.drifting and not piece.placed else piece.yaw
	# Never carry the thing you are standing on (it would make a lift of anything).
	if not held.is_empty() and not under.is_empty() and under.index == held.index:
		release()
	if not held.is_empty():
		_carry(held, delta)
	_tick_hover()
	if not done and door.visible and player != null:
		var local := door.to_local(player.global_position)
		if absf(local.x) < 0.6 and absf(local.z) < 0.3 and local.y > -0.5 and local.y < 1.5:
			done = true
			reached_door.emit()

# Where the held thing should hang: HOLD metres out along the view (further for bigger things,
# so it never ends up inside the player), its top at the aim point.
func hold_point(piece: Dictionary) -> Vector3:
	var eye: Camera3D = player.camera
	var forward := -eye.global_basis.z
	var reach: float = HOLD + maxf(piece.size.x, piece.size.z) * 0.5
	return eye.global_position + forward * reach

func _carry(piece: Dictionary, delta: float) -> void:
	var body: AnimatableBody3D = piece.body
	var target := to_local(hold_point(piece))
	var to := target - body.position
	var speed := maxf(3.0, to.length() * 2.5)
	body.position = body.position.move_toward(target, speed * delta)
	# Turn it to lie long-side along the view: a bridge out from where you stand.
	piece.yaw = lerp_angle(body.rotation.y, player.yaw, delta * 3.0)
	body.rotation.y = piece.yaw
	piece.anchor = body.position

# The body under the player's feet, if it is one of the floating pieces.
func standing_on() -> Dictionary:
	if player == null or not player.is_on_floor():
		return {}
	for k in range(player.get_slide_collision_count()):
		var hit := player.get_slide_collision(k)
		if hit.get_normal().y < 0.7:
			continue
		for piece in pieces:
			if hit.get_collider() == piece.body:
				return piece
	return {}

# The floating thing nearest the middle of the view, within a few degrees (more for close ones).
func aimed() -> Dictionary:
	if player == null or not risen():
		return {}
	var eye: Camera3D = player.camera
	var forward := -eye.global_basis.z
	var under := standing_on()
	var best := {}
	var best_angle := INF
	for piece in pieces:
		if not under.is_empty() and piece.index == under.index:
			continue
		var centre: Vector3 = piece.body.global_position - Vector3(0, piece.size.y * 0.5, 0)
		var to := centre - eye.global_position
		var distance := to.length()
		if distance > PICK_RANGE or distance < 0.5:
			continue
		var angle := rad_to_deg(forward.angle_to(to))
		var allowance := PICK_DEGREES + rad_to_deg(atan(maxf(piece.size.x, piece.size.z) * 0.4 / distance))
		if angle < allowance and angle < best_angle:
			best_angle = angle
			best = piece
	return best

func grab() -> bool:
	var piece := aimed()
	if piece.is_empty():
		return false
	held = piece
	piece.placed = true
	grab_sound.pitch_scale = 1.0
	grab_sound.play()
	return true

func release() -> void:
	if held.is_empty():
		return
	held.anchor = held.body.position
	held = {}
	grab_sound.pitch_scale = 0.8
	grab_sound.play()

func set_pulling(on: bool) -> void:
	if on == pulling:
		return
	pulling = on
	if on:
		grab()
	else:
		release()

func _process(_delta: float) -> void:
	# The thing under the eye breathes a warm light, stronger while it is being pulled.
	var base := 0.55 if not held.is_empty() else 0.35
	glow.albedo_color.a = base + sin(clock * 4.0) * 0.12

func _tick_hover() -> void:
	var now := held if not held.is_empty() else aimed()
	if now.get("index", -1) == hovered.get("index", -1):
		return
	if not hovered.is_empty():
		_overlay(hovered, null)
	hovered = now
	if not hovered.is_empty():
		_overlay(hovered, glow)

func _overlay(piece: Dictionary, material: Material) -> void:
	for mesh: MeshInstance3D in piece.visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = material

# The first missing step ahead of the player, or -1 (for the hint).
func gap_ahead() -> int:
	var under := standing_on()
	if under.is_empty() or under.drifting:
		return -1
	var next: int = under.index + 1
	if MISSING.has(next):
		return next
	return -1
