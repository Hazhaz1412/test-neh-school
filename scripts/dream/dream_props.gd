extends Node3D
# The bits of school life the dream has kept, scattered through the water. All Poly Haven (CC0),
# the same photographed look as the rest of the dream (ASSETS.md, "Giấc mơ — mặt nước").
# Near the classroom: ceiling fans and tube lights hanging from a ceiling that is not there, the
# teacher's desk with an old TV, a broom left against the board, exam sheets floating face up,
# books on the desks, a football nobody came back for, a second row of desks sinking into the
# water, and pencils as tall as the poles. Down in the rift a few desks and chairs drift in the
# haze. In the schoolyard: chairs stacked for the Monday assembly, a camera on the gate pillar,
# fans along the corridors and a clock on the block, stopped at the same minute as the big one.
const D := "res://assets/polyhaven_dream/%s/%s_1k.gltf"
const DESK := "res://assets/polyhaven_corridor/SchoolDesk_01/SchoolDesk_01.gltf"
const CHAIR := "res://assets/polyhaven_corridor/SchoolChair_01/SchoolChair_01.gltf"
const TEACHER_DESK := "res://assets/polyhaven_corridor/metal_office_desk/metal_office_desk.gltf"
const TV := "res://assets/polyhaven_town/models/television_02/television_02.gltf"
const PLASTIC_CHAIR := "res://assets/polyhaven_town/models/plastic_monobloc_chair_01/plastic_monobloc_chair_01.gltf"
const SINK := 0.12
var spinning: Array[Node3D] = []
var drifting: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var clock := 0.0

func build(gate_at: Vector3, rift_near: float, rift_far: float, block_front: float) -> void:
	rng.seed = 914
	_classroom_extras()
	_floating_sheets()
	_sinking_row()
	_pencils()
	_football(Vector3(-11.0, 0, -3.0))
	_rift_drift(rift_near, rift_far)
	_schoolyard(gate_at, block_front)

func _scene(file: String) -> Node3D:
	return load(file).instantiate()

# One named part of a pack (a single book, a single sheet, a single pencil), moved to the origin.
func _part(pack: String, part: String) -> Node3D:
	var source := _scene(D % [pack, pack])
	var found: Node3D = source.find_child(part, true, false)
	var copy: Node3D = found.duplicate()
	copy.position = Vector3.ZERO
	source.free()
	var holder := Node3D.new()
	holder.add_child(copy)
	return holder

func _put(node: Node3D, at: Vector3, turn := Vector3.ZERO, size := 1.0) -> Node3D:
	node.position = at
	node.rotation_degrees = turn
	node.scale = Vector3.ONE * size
	add_child(node)
	return node

func _solid(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at + Vector3(0, size.y / 2, 0)
	add_child(body)

func _fan(at: Vector3, size := 1.0) -> void:
	var fan := _put(_scene(D % ["ceiling_fan", "ceiling_fan"]), at, Vector3.ZERO, size)
	spinning.append(fan.find_child("ceiling_fan_blades", true, false))

func _tube(at: Vector3, turn := 0.0) -> void:
	var tube := _put(_part("mounted_fluorescent_lights", "mounted_fluorescent_lights_a"), at, Vector3(0, turn, 0), 1.3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.95, 0.97, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.85, 0.92, 1.0)
	glow.emission_energy_multiplier = 0.6
	for mesh: MeshInstance3D in tube.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = glow

# Set a clock's hands (rest pose pointing at 12, turning about the face's Z) to 05:52.
func _stop_at_552(clock_node: Node3D) -> void:
	var minute: Node3D = clock_node.find_child("wall_clock_minute_hand", true, false)
	var hour: Node3D = clock_node.find_child("wall_clock_hours_hand", true, false)
	var second: Node3D = clock_node.find_child("wall_clock_second_hand", true, false)
	if minute: minute.rotation.z = -deg_to_rad(52.0 * 6.0)
	if hour: hour.rotation.z = -deg_to_rad((5.0 + 52.0 / 60.0) * 30.0)
	if second: second.rotation.z = -deg_to_rad(0.0)

func _classroom_extras() -> void:
	# The teacher's desk between the front row and the board, an old TV on it facing the class.
	_put(_scene(TEACHER_DESK), Vector3(0.2, -SINK, -5.75), Vector3(0, 0, 0), 0.85)
	_solid(Vector3(0.2, 0, -5.75), Vector3(1.7, 0.7, 0.8))
	_put(_scene(TV), Vector3(-0.35, 0.67 - SINK, -5.85), Vector3(0, 0, 0), 1.4)
	var books := ["book_encyclopedia_set_01_book02", "book_encyclopedia_set_01_book05", "book_encyclopedia_set_01_book09"]
	for i in range(books.size()):
		_put(_part("book_encyclopedia_set_01", books[i]), Vector3(0.55, 0.67 - SINK + i * 0.04, -5.7), Vector3(0, 0, 90), 1.0)
	_put(_part("stationery_supplies", "stationery_supplies_pencilcup"), Vector3(0.85, 0.71 - SINK, -5.6), Vector3.ZERO, 1.2)
	# A broom left leaning on the board, and a small easel board to one side.
	_put(_scene(D % ["plastic_broom", "plastic_broom"]), Vector3(1.95, -SINK, -6.4), Vector3(-18, 20, 0))
	_put(_scene(D % ["standing_chalkboard_01", "standing_chalkboard_01"]), Vector3(-2.8, -SINK, -6.0), Vector3(0, 25, 0))
	# A wall clock with no wall, hanging over the board.
	var wall_clock := _put(_scene(D % ["wall_clock", "wall_clock"]), Vector3(0, 3.15, -6.62), Vector3.ZERO, 1.6)
	_stop_at_552(wall_clock)
	# Ceiling fans and tube lights under a ceiling that is not there.
	_fan(Vector3(-0.8, 3.7, -1.2))
	_fan(Vector3(0.8, 3.7, -3.6))
	for z in [-0.4, -2.4, -4.4]:
		_tube(Vector3(-1.6, 3.55, z), 90.0)
		_tube(Vector3(1.6, 3.55, z), 90.0)
	# Books left on some desks.
	var desk_tops := [Vector3(-1.6, 0, 0), Vector3(1.6, 0, -1.5), Vector3(0, 0, -3.0), Vector3(1.6, 0, -4.5)]
	for top in desk_tops:
		var book := _part("book_encyclopedia_set_01", "book_encyclopedia_set_01_book0%d" % rng.randi_range(1, 9))
		_put(book, top + Vector3(rng.randf_range(-0.15, 0.15), 0.76 - SINK, rng.randf_range(-0.05, 0.05)), Vector3(0, rng.randf_range(-40, 40), 90))

# Exam sheets floating face up around the classroom and along the way to the desk at the lip.
func _floating_sheets() -> void:
	var parts := ["office_notepads_a4_a", "office_notepads_a4_b", "office_notepads_a4_c"]
	for i in range(26):
		var t := rng.randf()
		var at := Vector3(rng.randf_range(-6, 6), 0.006, rng.randf_range(4, -8))
		if i > 14:
			at = Vector3(lerpf(-1.0, -7.0, t) + rng.randf_range(-2.5, 2.5), 0.006, lerpf(-8.0, -26.0, t))
		_put(_part("office_notepads", parts[i % parts.size()]), at, Vector3(0, rng.randf_range(0, 360), 0), 1.15)

# A second row of desks off to the right, each one further under than the last.
func _sinking_row() -> void:
	for i in range(8):
		var z := 2.0 - i * 3.0
		var down := i * 0.11
		_put(_scene(DESK), Vector3(12.0 + i * 0.15, -SINK - down, z), Vector3(0, 180 + rng.randf_range(-6, 6), rng.randf_range(-3, 3)))
		_put(_scene(CHAIR), Vector3(12.0 + i * 0.15, -SINK - down * 1.2, z + 0.62), Vector3(0, 180 + rng.randf_range(-8, 8), 0))
		if down < 0.5:
			_solid(Vector3(12.0 + i * 0.15, 0, z), Vector3(0.75, 0.8, 0.6))

# Pencils as tall as the power poles, stuck upright in the water.
func _pencils() -> void:
	var spots := [[Vector3(-30, 0, -12), "stationery_supplies_pencil_new_a", Vector3(0, 30, -82)],
		[Vector3(-26, 0, -17), "stationery_supplies_pencil_used", Vector3(0, -50, -97)],
		[Vector3(24, 0, -10), "stationery_supplies_pencil_new_b", Vector3(0, 10, -76)]]
	for spot in spots:
		_put(_part("stationery_supplies", spot[1]), spot[0] + Vector3(0, 2.0, 0), spot[2], 48.0)
		_solid(spot[0], Vector3(0.6, 6.0, 0.6))

func _football(at: Vector3) -> void:
	_put(_part("football", "football_inflated"), at + Vector3(0, 0.0, 0), Vector3(0, rng.randf_range(0, 360), 0), 1.0)

# Desks, chairs and books drifting slowly in the haze of the rift, well clear of the path.
func _rift_drift(near_z: float, far_z: float) -> void:
	for i in range(9):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(13, 26), rng.randf_range(-9, -2.5), rng.randf_range(far_z + 5, near_z - 5))
		var file: String = [DESK, CHAIR, DESK, CHAIR][i % 4]
		var node: Node3D
		if i % 5 == 4:
			node = _part("book_encyclopedia_set_01", "book_encyclopedia_set_01_book07")
			node.scale = Vector3.ONE * 6.0
		else:
			node = _scene(file)
		node.position = at
		node.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		node.visible = false
		add_child(node)
		drifting.append({"node": node, "home": at, "spin": Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.15, 0.15)), "phase": rng.randf() * TAU})

# The rift's drifters only exist once there is a rift.
func show_drift() -> void:
	for d in drifting:
		d.node.visible = true

func _schoolyard(gate_at: Vector3, block_front: float) -> void:
	# A camera watching the road from the left gate pillar.
	_put(_scene(D % ["security_camera_01", "security_camera_01"]), gate_at + Vector3(-2.2, 4.0, 0.35), Vector3(0, 160, 0), 1.6)
	# Plastic chairs stacked for the Monday assembly, by the flagpole.
	for s in range(2):
		for h in range(5):
			_put(_scene(PLASTIC_CHAIR), gate_at + Vector3(4.0 + s * 0.9, -SINK + h * 0.11, -20.0), Vector3(0, 180, 0))
	_solid(gate_at + Vector3(4.45, 0, -20.0), Vector3(1.6, 1.3, 0.7))
	# Desks carried out into the yard in a row, facing the flag.
	for i in range(5):
		var at := gate_at + Vector3(-9.0 + i * 1.5, 0, -27.0)
		_put(_scene(DESK), at - Vector3(0, SINK, 0), Vector3(0, 0, 0))
		_solid(at, Vector3(0.75, 0.8, 0.6))
	_football(gate_at + Vector3(7.0, 0, -9.0))
	var parts := ["office_notepads_a4_a", "office_notepads_a4_b", "office_notepads_a4_c"]
	for i in range(14):
		var at := gate_at + Vector3(rng.randf_range(-14, 14), 0.006, rng.randf_range(-4, -36))
		_put(_part("office_notepads", parts[i % parts.size()]), at, Vector3(0, rng.randf_range(0, 360), 0), 1.15)
	# Fans and tube lights along the corridors of the block, a clock on its face.
	var z := gate_at.z + block_front - 1.2
	for floor_y in [3.2, 6.7, 10.2]:
		for x in [-24.0, -12.0, 0.0, 12.0, 24.0]:
			_fan(Vector3(x, floor_y - SINK, z), 0.8)
			_tube(Vector3(x + 6.0, floor_y + 0.05 - SINK, z), 0.0)
	var face := _put(_scene(D % ["wall_clock", "wall_clock"]), Vector3(gate_at.x, 11.4, gate_at.z + block_front + 0.3), Vector3.ZERO, 6.0)
	_stop_at_552(face)

func _process(delta: float) -> void:
	clock += delta
	for blades in spinning:
		blades.rotation.y += delta * 2.4
	for d in drifting:
		var node: Node3D = d.node
		node.rotation += d.spin * delta
		node.position = d.home + Vector3(0, sin(clock * 0.4 + d.phase) * 0.6, 0)
