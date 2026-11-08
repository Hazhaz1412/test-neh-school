extends Node3D
# Night 1's kiting loops, one in each open stretch of the yards (the places were found by a
# collision scan, so none sits inside a planter or lamp post). Each loop is a stack of crates to run
# circles round, boxed in by half-built walls. Local plan (x along the loop, z across):
#
#        north wall:  [shelf gap x=-OPEN]          [window x=+OPEN]
#   west end OPEN      ===== crates (run round) =====      east end WALL with a LOW GAP
#        south wall:  [window x=-OPEN]             [low gap x=+OPEN]
#
# A student has five ways out of the ring; the guard walks in only by the open west end or an
# unfallen shelf gap. Window (SPACE): quick for a student, slow for him. Shelf (E): tip it into its
# gap; students vault it, he must drag it clear. Low gap (C to crawl, sprint + C to slide): he cannot
# follow at all and must go round the whole wall. Each climb or clearing also resets his speed.
# The guard's walkable map is baked with them into hunt_navigation.tres by
# tools/bake_hunt_navigation.gd. Models: assets/polyhaven_kiting (CC0, Poly Haven).
const Pallet := preload("res://scripts/kiting_pallet.gd")
const NAVIGATION := "res://scenes/hunt_navigation.tres"
# Its cells (tools/bake_hunt_navigation.gd); the navigation map must use the same.
const NAV_CELL := 0.125
const NAV_CELL_HEIGHT := 0.125
const TILES := [
	[Vector3(-11, 0, 34), PI / 2],
	[Vector3(11, 0, 34), PI / 2],
	[Vector3(0, 0, 54), 0.0],
	[Vector3(-46, 0, 31), PI / 2],
	[Vector3(-38, 0, 67), 0.0],
	[Vector3(35, 0, 67), PI / 2],
	[Vector3(50, 0, -50), PI / 2],
	[Vector3(-45, 0, -67), 0.0],
]
# Tile layout, local metres: walls at z = ±WALL_Z from x = -HALF to HALF, openings at x = ±OPEN.
const HALF := 7.0
const WALL_Z := 3.2
const OPEN := 2.8
# Under a low gap's boards: a crouch (1.1 m) or a slide fits, a standing man (1.75 m) does not.
const LOW_CLEAR := 1.25
const LOW_DEPTH := 1.2
# Navigation layer only students walk: the low gaps.
const STUDENT_LAYER := 2
const GAP := 1.6
const THICK := 0.3
const HEIGHT := 2.4
const SILL := 0.9
const LINTEL := 2.05
# How far either side of a wall a crossing starts and lands.
const REACH := 0.9
const CRATE := "res://assets/polyhaven_kiting/wooden_crate_02/wooden_crate_02_1k.gltf"
const SMALL_CRATE := "res://assets/polyhaven_kiting/wooden_crate_01/wooden_crate_01_1k.gltf"
const DESK := "res://assets/polyhaven_kiting/SchoolDesk_01/SchoolDesk_01_1k.gltf"
const RACK := "res://assets/polyhaven_kiting/steel_frame_shelves_02/steel_frame_shelves_02_1k.gltf"
var world: Node3D
var concrete: StandardMaterial3D
var scenes := {}
# The guard boards up low gaps he has seen students use. A boarded gap: hold E for UNBOARD_SECONDS,
# or slide straight through it and lose BREAK_COST of health.
const UNBOARD_SECONDS := 5.0
const BREAK_COST := 25.0
const BOARD_NOISE := 14.0
var boards := {}
var seen_used := {}
var unboarding := 0.0
var unboard_gap: Node3D
var break_sound: AudioStreamPlayer3D

static func build(school: Node3D, with_links := true) -> Node3D:
	var course: Node3D = load("res://scripts/kiting_course.gd").new()
	course.name = "KitingCourse"
	course.world = school
	school.add_child(course)
	course._lay_out(with_links)
	return course

func _lay_out(with_links: bool) -> void:
	concrete = StandardMaterial3D.new()
	concrete.albedo_texture = load("res://assets/polyhaven_school/dirty_concrete_diff_1k.jpg")
	concrete.normal_enabled = true
	concrete.normal_texture = load("res://assets/polyhaven_school/dirty_concrete_nor_1k.jpg")
	concrete.roughness_texture = load("res://assets/polyhaven_school/dirty_concrete_rough_1k.jpg")
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3(0.45, 0.45, 0.45)
	for i in range(TILES.size()):
		var tile := Node3D.new()
		tile.name = "Loop%d" % i
		tile.position = _ground(TILES[i][0])
		tile.rotation.y = TILES[i][1]
		add_child(tile)
		_clear_decor(tile)
		_crates(tile, i)
		var north := -WALL_Z
		var south := WALL_Z
		# North wall: shelf gap west, window east. South wall: window west, low gap east.
		_wall_with(tile, north, [-OPEN, OPEN])
		_wall_with(tile, south, [-OPEN, OPEN])
		var pallet := Pallet.new()
		pallet.world = world
		pallet.position = Vector3(-OPEN, 0, north)
		pallet.inward = 1.0
		pallet.beside = -1.0
		tile.add_child(pallet)
		pallet.build(self)
		_window(tile, Vector3(OPEN, 0, north), 0.0, with_links)
		_window(tile, Vector3(-OPEN, 0, south), 0.0, with_links)
		_low_gap(tile, Vector3(OPEN, 0, south), 0.0, with_links)
		# The east end is shut, but for a low gap in its middle.
		for z_range in [[north, -GAP * 0.5], [GAP * 0.5, south]]:
			var length: float = z_range[1] - z_range[0]
			solid(tile, Vector3(HALF, HEIGHT * 0.5, (z_range[0] + z_range[1]) * 0.5), Vector3(THICK, HEIGHT, length + THICK), concrete)
		_low_gap(tile, Vector3(HALF, 0, 0), PI * 0.5, with_links)
		# A steel rack against the outside of the north wall, for something to read in the dark.
		var rack := fitted(RACK, 2.1)
		rack.position = Vector3(0.0, 0, north - 0.55)
		tile.add_child(rack)
		solid(tile, rack.position + Vector3(0, 1.05, 0), Vector3(0.62, 2.1, 0.55))

# A long wall along x at `z`, cut by GAP-wide openings at the given x positions.
func _wall_with(tile: Node3D, z: float, cuts: Array) -> void:
	var from := -HALF
	for cut in cuts:
		_wall(tile, from, cut - GAP * 0.5, z)
		from = cut + GAP * 0.5
	_wall(tile, from, HALF, z)

# A short tunnel of scaffold boards: crouch or slide under, the guard has to go round.
func _low_gap(tile: Node3D, at: Vector3, yaw: float, with_links: bool) -> void:
	var gap := Node3D.new()
	gap.position = at
	gap.rotation.y = yaw
	gap.add_to_group("kiting_low")
	tile.add_child(gap)
	solid(gap, Vector3(0, (LOW_CLEAR + HEIGHT) * 0.5, 0), Vector3(GAP, HEIGHT - LOW_CLEAR, THICK), concrete)
	var wood := _wood()
	# Boards on top, posts at the corners, a plank on each side of the wall.
	solid(gap, Vector3(0, LOW_CLEAR + 0.04, 0), Vector3(GAP + 0.3, 0.08, LOW_DEPTH), wood)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			solid(gap, Vector3(x * (GAP * 0.5 + 0.08), LOW_CLEAR * 0.5, z * (LOW_DEPTH * 0.5 - 0.05)), Vector3(0.1, LOW_CLEAR, 0.1), wood)
	if with_links:
		var link := NavigationLink3D.new()
		link.bidirectional = true
		link.start_position = Vector3(0, 0, -(LOW_DEPTH * 0.5 + REACH))
		link.end_position = Vector3(0, 0, LOW_DEPTH * 0.5 + REACH)
		link.navigation_layers = STUDENT_LAYER
		link.travel_cost = 1.2
		gap.add_child(link)

var wood_material: StandardMaterial3D
func _wood() -> StandardMaterial3D:
	if wood_material == null:
		wood_material = StandardMaterial3D.new()
		wood_material.albedo_texture = load("res://assets/polyhaven_school/rough_wood_diff_1k.jpg")
		wood_material.normal_enabled = true
		wood_material.normal_texture = load("res://assets/polyhaven_school/rough_wood_nor_1k.jpg")
		wood_material.roughness_texture = load("res://assets/polyhaven_school/rough_wood_rough_1k.jpg")
		wood_material.uv1_triplanar = true
		wood_material.uv1_scale = Vector3(0.7, 0.7, 0.7)
	return wood_material

# Yard stones, bushes and grass tufts that would sit in a loop's running lanes are put away.
const DECOR := ["stone", "rock", "grass", "plant", "flower", "bush"]
func _clear_decor(tile: Node3D) -> void:
	var batches := world.get_node_or_null("RuntimeGeometry")
	if batches == null:
		return
	for batch in batches.get_children():
		if not batch is MultiMeshInstance3D or batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var label: String = batch.multimesh.mesh.resource_name.to_lower()
		if not DECOR.any(func(word): return label.contains(word)):
			continue
		var many: MultiMesh = batch.multimesh
		for i in range(many.instance_count):
			var at: Vector3 = tile.to_local(batch.global_transform * many.get_instance_transform(i).origin)
			if absf(at.x) < HALF + 1.0 and absf(at.z) < WALL_Z + 1.0 and absf(at.y) < 1.5:
				if batch.multimesh == many and not batch.has_meta("kiting_cleared"):
					batch.multimesh = many.duplicate()
					batch.set_meta("kiting_cleared", true)
					many = batch.multimesh
				many.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), many.get_instance_transform(i).origin))

# Paving is not at y = 0 everywhere (the courtyard sits higher): stand on what is really there.
func _ground(at: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 2.0, 1)
	var hit := space.intersect_ray(ray)
	return hit.position if not hit.is_empty() else at

# The model's bounds, scaled to `height` and set on its base at the wrapper's origin.
func fitted(path: String, height: float) -> Node3D:
	if not scenes.has(path):
		scenes[path] = load(path)
	var model: Node3D = scenes[path].instantiate()
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = _relative(model, mesh)
		var bounds: AABB = local * mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	var scale_by := height / maxf(box.size.y, 0.01)
	var wrapper := Node3D.new()
	wrapper.add_child(model)
	model.scale = Vector3.ONE * scale_by
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale_by
	var scaled := AABB((box.position - Vector3(box.get_center().x, box.position.y, box.get_center().z)) * scale_by, box.size * scale_by)
	wrapper.set_meta("box", scaled)
	wrapper.set_meta("size", scaled.size)
	return wrapper

func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var chain := Transform3D.IDENTITY
	var at: Node = node
	while at != root and at is Node3D:
		chain = (at as Node3D).transform * chain
		at = at.get_parent()
	return chain

func solid(parent: Node3D, centre: Vector3, size: Vector3, material: Material = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if material != null:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = size
		mesh.mesh = cube
		mesh.material_override = material
		body.add_child(mesh)
	return body

func _wall(tile: Node3D, from: float, to: float, z: float) -> void:
	if to - from > 0.05:
		solid(tile, Vector3((from + to) * 0.5, HEIGHT * 0.5, z), Vector3(to - from, HEIGHT, THICK), concrete)

# Two old desks pushed into a hole in the wall: the sill to vault.
func _window(tile: Node3D, at: Vector3, yaw: float, with_links: bool) -> void:
	var window := Node3D.new()
	window.position = at
	window.rotation.y = yaw
	window.add_to_group("kiting_vault")
	tile.add_child(window)
	solid(window, Vector3(0, SILL * 0.5, 0), Vector3(GAP, SILL, 0.55))
	solid(window, Vector3(0, (LINTEL + HEIGHT) * 0.5, 0), Vector3(GAP, HEIGHT - LINTEL, THICK), concrete)
	for x in [-0.4, 0.4]:
		var desk := fitted(DESK, SILL)
		desk.position = Vector3(x, 0, 0)
		desk.rotation.y = PI * 0.5 if x < 0.0 else -PI * 0.5
		window.add_child(desk)
	if with_links:
		var link := NavigationLink3D.new()
		link.bidirectional = true
		link.start_position = Vector3(0, 0, -REACH)
		link.end_position = Vector3(0, 0, REACH)
		# Climbing over costs the guard time; his paths only use it when going round is longer.
		link.travel_cost = 3.0
		window.add_child(link)

# A stack of crates three high to run circles round, with a few on top for a ragged outline.
func _crates(tile: Node3D, seed_from: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_from * 7919 + 13
	var probe := fitted(CRATE, 0.6)
	var size: Vector3 = probe.get_meta("size")
	probe.free()
	var long_side := size.x >= size.z
	var along := maxf(size.x, size.z)
	var deep := minf(size.x, size.z)
	for layer in range(3):
		for i in range(3):
			for j in range(2):
				if layer == 2 and rng.randf() < 0.35:
					continue
				var crate := fitted(CRATE, 0.6)
				crate.position = Vector3((i - 1) * (along + 0.03), layer * 0.6, (j - 0.5) * (deep + 0.03))
				crate.rotation.y = (0.0 if long_side else PI * 0.5) + rng.randf_range(-0.04, 0.04)
				tile.add_child(crate)
	var top := fitted(SMALL_CRATE, 0.45)
	top.position = Vector3(rng.randf_range(-1.0, 1.0), 1.8, 0)
	top.rotation.y = rng.randf_range(-0.6, 0.6)
	tile.add_child(top)
	solid(tile, Vector3(0, 0.9, 0), Vector3(3 * along + 0.06, 1.8, 2 * deep + 0.03))

# A window or a fallen shelf a body near `feet` could vault, or null. Both run across in local z.
static func vault_near(school: Node3D, feet: Vector3, reach := 1.3) -> Node3D:
	var best: Node3D = null
	var nearest := reach
	var crossings: Array = school.get_tree().get_nodes_in_group("kiting_vault")
	for pallet in school.get_tree().get_nodes_in_group("kiting_pallet"):
		if pallet.is_down():
			crossings.append(pallet)
	for crossing in crossings:
		var local: Vector3 = crossing.to_local(feet)
		if absf(local.x) > GAP * 0.5 + 0.15 or absf(local.y) > 1.0:
			continue
		if absf(local.z) < nearest:
			nearest = absf(local.z)
			best = crossing
	return best

static func pallet_near(school: Node3D, feet: Vector3, reach := 1.8) -> Node3D:
	for pallet in school.get_tree().get_nodes_in_group("kiting_pallet"):
		if pallet.standing() and pallet.global_position.distance_to(feet) < reach:
			return pallet
	return null

# A fallen shelf in the way of something at `feet` heading along `heading`.
static func blocking_pallet(school: Node3D, feet: Vector3, heading: Vector3, reach := 1.3) -> Node3D:
	for pallet in school.get_tree().get_nodes_in_group("kiting_pallet"):
		if not pallet.is_down():
			continue
		var local: Vector3 = pallet.to_local(feet)
		if absf(local.x) > GAP * 0.5 + 0.4 or absf(local.z) > reach:
			continue
		var across: Vector3 = pallet.global_position - feet
		across.y = 0.0
		if heading.length() < 0.05 or across.length() < 0.05 or heading.normalized().dot(across.normalized()) > -0.2:
			return pallet
	return null

# A window right in front of a body whose path runs across it: time to climb over.
static func crossing_ahead(school: Node3D, feet: Vector3, toward: Vector3) -> Node3D:
	for window in school.get_tree().get_nodes_in_group("kiting_vault"):
		var here: Vector3 = window.to_local(feet)
		if absf(here.x) > GAP * 0.5 or absf(here.z) > REACH + 0.25 or absf(here.y) > 1.0:
			continue
		var there: Vector3 = window.to_local(toward)
		if signf(here.z) != signf(there.z):
			return window
	return null

# Where a body on one side lands on the other.
static func far_side(crossing: Node3D, feet: Vector3) -> Vector3:
	var side := signf(crossing.to_local(feet).z)
	if side == 0.0:
		side = 1.0
	return crossing.to_global(Vector3(0, 0.05, -side * (REACH + 0.25)))

# A low gap a body near `feet` is about to go under, or null.
static func low_near(school: Node3D, feet: Vector3, reach := 1.6) -> Node3D:
	for gap in school.get_tree().get_nodes_in_group("kiting_low"):
		var local: Vector3 = gap.to_local(feet)
		if absf(local.x) < GAP * 0.5 + 0.2 and absf(local.z) < LOW_DEPTH * 0.5 + reach and absf(local.y) < 1.0:
			return gap
	return null

static func low_far_side(gap: Node3D, feet: Vector3) -> Vector3:
	var side := signf(gap.to_local(feet).z)
	if side == 0.0:
		side = 1.0
	return gap.to_global(Vector3(0, 0.05, -side * (LOW_DEPTH * 0.5 + REACH)))

func is_boarded(gap: Node3D) -> bool:
	return boards.has(gap)

# Seen being used with him close by: he will remember to board it.
func note_use(gap: Node3D, by: Node3D) -> void:
	var guard: Node3D = world.envy.demon if world.envy != null else null
	if guard != null and guard.global_position.distance_to(by.global_position) < 18.0:
		seen_used[gap] = true

func wants_boarding(gap: Node3D) -> bool:
	return seen_used.get(gap, false) and not boards.has(gap)

# Planks nailed across both mouths of the gap; the students' path through it closes.
func board(gap: Node3D) -> void:
	if boards.has(gap):
		return
	seen_used.erase(gap)
	var planks := Node3D.new()
	gap.add_child(planks)
	for z in [-1.0, 1.0]:
		for y in [0.3, 0.75]:
			var plank := solid(planks, Vector3(0, y, z * (LOW_DEPTH * 0.5 + 0.05)), Vector3(GAP + 0.25, 0.22, 0.06), _wood())
			plank.rotation.z = 0.06 if y < 0.5 else -0.05
	boards[gap] = planks
	for link in gap.get_children():
		if link is NavigationLink3D:
			link.enabled = false
	world.emit_noise(gap.global_position, BOARD_NOISE, "boards")

func unboard(gap: Node3D) -> void:
	if not boards.has(gap):
		return
	boards[gap].queue_free()
	boards.erase(gap)
	for link in gap.get_children():
		if link is NavigationLink3D:
			link.enabled = true
	if break_sound == null:
		break_sound = AudioStreamPlayer3D.new()
		break_sound.stream = load("res://assets/audio/chair_impact.wav")
		break_sound.unit_size = 10.0
		break_sound.max_distance = 50.0
		add_child(break_sound)
	break_sound.global_position = gap.global_position + Vector3.UP * 0.5
	break_sound.play()
	world.emit_noise(gap.global_position, BOARD_NOISE, "boards")

# A boarded gap right ahead of a body moving along `heading`.
static func boarded_ahead(school: Node3D, feet: Vector3, heading: Vector3, reach := 1.4) -> Node3D:
	var course: Node3D = school.get("kiting")
	if course == null:
		return null
	for gap in course.boards:
		var local: Vector3 = gap.to_local(feet)
		if absf(local.x) > GAP * 0.5 + 0.3 or absf(local.z) > LOW_DEPTH * 0.5 + reach:
			continue
		var into: Vector3 = gap.global_position - feet
		into.y = 0.0
		if heading.length() > 0.1 and into.length() > 0.05 and heading.normalized().dot(into.normalized()) > 0.3:
			return gap
	return null

func _physics_process(delta: float) -> void:
	var player: CharacterBody3D = world.player
	if player == null or not world.simulation_active():
		return
	# Students seen going under: remember for him.
	for gap in get_tree().get_nodes_in_group("kiting_low"):
		if absf(gap.to_local(player.global_position).z) < LOW_DEPTH * 0.5 and absf(gap.to_local(player.global_position).x) < GAP * 0.5:
			note_use(gap, player)
	# Hold E at a boarded gap to pull the planks off.
	var near := _boarded_near(player.global_position)
	if near != null and not player.seized and Input.is_physical_key_pressed(KEY_E):
		if near != unboard_gap:
			unboard_gap = near
			unboarding = 0.0
		unboarding += delta
		if int(unboarding * 2.0) != int((unboarding - delta) * 2.0):
			world.emit_noise(near.global_position, 8.0, "boards")
		if unboarding >= UNBOARD_SECONDS:
			unboard(near)
			unboarding = 0.0
			unboard_gap = null
	else:
		unboarding = maxf(0.0, unboarding - delta * 2.0)

func _boarded_near(feet: Vector3) -> Node3D:
	for gap in boards:
		var local: Vector3 = gap.to_local(feet)
		if absf(local.x) < GAP * 0.5 + 0.4 and absf(local.z) < LOW_DEPTH * 0.5 + 1.2:
			return gap
	return null

func prompt() -> String:
	var player: CharacterBody3D = world.player
	if player.seized or player.is_hidden():
		return ""
	var boarded := _boarded_near(player.global_position)
	if boarded != null:
		if unboarding > 0.05 and unboard_gap == boarded:
			return "Đang gỡ ván %d%%" % int(unboarding / UNBOARD_SECONDS * 100.0)
		return "Bị đóng ván · Giữ E 5 giây để gỡ · Trượt vào để phá (mất 25% máu)"
	if pallet_near(world, player.global_position) != null:
		return "E · Gạt đổ kệ chặn lối"
	if vault_near(world, player.global_position, 1.2) != null:
		return "SPACE · Leo qua"
	if low_near(world, player.global_position) != null and not player.crouching:
		return "C · Bò qua khe · Đang chạy + C · Trượt qua"
	return ""

# E beside a standing shelf tips it. Handled before the player's own E (doors, lockers).
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		return
	var player: CharacterBody3D = world.player
	if player.seized or player.is_hidden() or not world.simulation_active():
		return
	var pallet: Node3D = pallet_near(world, player.global_position)
	if pallet != null and pallet.drop(player):
		get_viewport().set_input_as_handled()
