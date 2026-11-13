extends Node3D
# The school on the far side of the rift, as the dream keeps it: a yard gone under water behind an
# iron-and-plaster fence, a guard booth by the gate, a flagpole, and the three-storey classroom
# block at the back. The gate exists twice. Now (render layer PRESENT) it is shut and chained.
# Back then (layer PAST, seen only through the camera) it stood open, with the new school year's
# banner up on the block. Pressing a photo of then into now (memory_camera.gd) swaps them.
const Camera := preload("res://scripts/dream/memory_camera.gd")
const GATE := "res://assets/polyhaven_dream/large_iron_gate/large_iron_gate_1k.gltf"
const PLASTER := "res://assets/polyhaven_school/yellow_plaster_%s_1k.jpg"
const CONCRETE := "res://assets/polyhaven_school/painted_concrete_02_%s_1k.jpg"
const SINK := 0.12
const HALF := 42.0
const DEPTH := 66.0
const GATE_HALF := 1.75
const STOREY := 3.5
const BLOCK_WIDTH := 60.0
var plaster: StandardMaterial3D
var concrete: StandardMaterial3D
var iron: StandardMaterial3D
var glass: StandardMaterial3D
var bars := PackedVector3Array()
var opened := false

func build() -> void:
	plaster = _textured(PLASTER, 0.5)
	concrete = _textured(CONCRETE, 0.4)
	iron = StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.07, 0.08)
	iron.metallic = 0.6
	iron.roughness = 0.45
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.13)
	glass.metallic = 0.3
	glass.roughness = 0.08
	_fence()
	_gate()
	_booth()
	_flagpole()
	_block()
	_bars()

func _textured(path: String, scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path % "diff")
	material.normal_enabled = true
	material.normal_texture = load(path % "nor")
	material.roughness_texture = load(path % "rough")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	return material

func _box(size: Vector3, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node

func _solid(size: Vector3, at: Vector3, parent: Node3D = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	parent.add_child(body)
	return body

# A straight run of fence: low plaster wall, square posts every 3 m, iron bars and a top rail.
func _run(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var dir := (to - from) / length
	var mid := (from + to) / 2
	_box(Vector3(0.3, 0.7, length) if absf(dir.z) > 0.5 else Vector3(length, 0.7, 0.3), mid + Vector3(0, 0.35 - SINK, 0), plaster)
	_box(Vector3(0.06, 0.06, length) if absf(dir.z) > 0.5 else Vector3(length, 0.06, 0.06), mid + Vector3(0, 2.15 - SINK, 0), iron)
	var posts := int(length / 3.0)
	for i in range(posts + 1):
		_box(Vector3(0.42, 2.5, 0.42), from + dir * (length * i / maxf(posts, 1)) + Vector3(0, 1.25 - SINK, 0), plaster)
	var count := int(length / 0.16)
	for i in range(count):
		bars.append(from + dir * (0.08 + i * 0.16) + Vector3(0, 1.43 - SINK, 0))
	var size := Vector3(0.4, 2.6, length) if absf(dir.z) > 0.5 else Vector3(length, 2.6, 0.4)
	_solid(size, mid + Vector3(0, 1.3, 0))

func _fence() -> void:
	var z0 := 0.0
	var z1 := -DEPTH
	_run(Vector3(-HALF, 0, z0), Vector3(-2.6, 0, z0))
	_run(Vector3(2.6, 0, z0), Vector3(HALF, 0, z0))
	_run(Vector3(-HALF, 0, z0), Vector3(-HALF, 0, z1))
	_run(Vector3(HALF, 0, z0), Vector3(HALF, 0, z1))
	_run(Vector3(-HALF, 0, z1), Vector3(HALF, 0, z1))

func _bars() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.016
	mesh.bottom_radius = 0.016
	mesh.height = 1.46
	mesh.radial_segments = 6
	mesh.material = iron
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = bars.size()
	for i in range(bars.size()):
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, bars[i]))
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = multi
	add_child(holder)

func _gate_doors(open: bool) -> Node3D:
	var gate: Node3D = load(GATE).instantiate()
	gate.scale = Vector3.ONE * 1.2
	gate.position.y = -SINK
	if open:
		# Swing each door on its outer hinge.
		for door_name in ["large_iron_gate_left_door", "large_iron_gate_right_door"]:
			var door: Node3D = gate.find_child(door_name, true, false)
			var side := -1.0 if door_name.contains("left") else 1.0
			var hinge := Node3D.new()
			hinge.position = Vector3(side * 1.43, 0, 0)
			gate.add_child(hinge)
			door.owner = null
			door.get_parent().remove_child(door)
			hinge.add_child(door)
			door.position = Vector3(-side * 1.43, 0, 0)
			hinge.rotation_degrees.y = side * 78.0
		gate.find_child("large_iron_gate_bolt", true, false).queue_free()
		gate.find_child("large_iron_gate", true, false).queue_free()
	return gate

func _gate() -> void:
	for side in [-1.0, 1.0]:
		_box(Vector3(0.9, 4.3, 0.9), Vector3(side * 2.2, 2.15 - SINK, 0), plaster)
		_box(Vector3(1.1, 0.22, 1.1), Vector3(side * 2.2, 4.3 - SINK, 0), plaster)
		_solid(Vector3(0.9, 4.3, 0.9), Vector3(side * 2.2, 2.15, 0))
	_box(Vector3(5.4, 0.75, 0.3), Vector3(0, 4.85 - SINK, 0), plaster)
	var title := Label3D.new()
	title.text = "TRƯỜNG NEH"
	title.font = load("res://assets/fonts/Grenze-Variable.ttf")
	title.font_size = 96
	title.pixel_size = 0.004
	title.modulate = Color(0.6, 0.1, 0.08)
	title.outline_size = 0
	title.position = Vector3(0, 4.85 - SINK, 0.16)
	add_child(title)
	# Now: shut, with a chain wound round the middle bars and a padlock hanging off it.
	var shut := Node3D.new()
	shut.name = "GateShut"
	add_child(shut)
	shut.add_child(_gate_doors(false))
	var link := TorusMesh.new()
	link.inner_radius = 0.03
	link.outer_radius = 0.06
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.45, 0.44, 0.42)
	steel.metallic = 0.9
	steel.roughness = 0.35
	link.material = steel
	for i in range(14):
		var piece := MeshInstance3D.new()
		piece.mesh = link
		var a := i / 14.0 * TAU
		piece.position = Vector3(cos(a) * 0.16, 1.15 + i * 0.012, sin(a) * 0.1 + 0.05)
		piece.rotation = Vector3(PI / 2 * (i % 2), a, 0)
		shut.add_child(piece)
	var lock := _box(Vector3(0.14, 0.18, 0.07), Vector3(0.02, 0.92, 0.14), steel, shut)
	lock.name = "Padlock"
	var blocked := _solid(Vector3(3.6, 3.0, 0.4), Vector3(0, 1.5, 0), shut)
	blocked.name = "GateBody"
	shut.set_meta("anchor", Vector3(0, 1.5, 0))
	shut.add_to_group("dream_present")
	Camera.put_on_layer(shut, Camera.PRESENT)
	# Then: wide open.
	var open := Node3D.new()
	open.name = "GateOpen"
	add_child(open)
	open.add_child(_gate_doors(true))
	open.set_meta("anchor", Vector3(0, 1.5, 0))
	open.add_to_group("dream_past")
	Camera.put_on_layer(open, Camera.PAST)

# A small guard booth just inside the gate, its window dark.
func _booth() -> void:
	var at := Vector3(-6.0, 0, -4.0)
	_box(Vector3(2.6, 2.7, 2.6), at + Vector3(0, 1.35 - SINK, 0), plaster)
	_box(Vector3(3.0, 0.18, 3.0), at + Vector3(0, 2.78 - SINK, 0), concrete)
	_box(Vector3(1.4, 0.9, 0.04), at + Vector3(0.2, 1.55 - SINK, 1.31), glass)
	_box(Vector3(0.04, 0.9, 1.0), at + Vector3(1.31, 1.55 - SINK, 0.2), glass)
	_box(Vector3(0.8, 1.9, 0.04), at + Vector3(-0.6, 0.95 - SINK, -1.31), glass)
	_solid(Vector3(2.6, 2.8, 2.6), at + Vector3(0, 1.4, 0))

func _flagpole() -> void:
	var pole := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.08
	mesh.height = 12.0
	pole.mesh = mesh
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.85, 0.85, 0.83)
	white.metallic = 0.5
	white.roughness = 0.3
	pole.material_override = white
	pole.position = Vector3(0, 6.0 - SINK, -22.0)
	add_child(pole)
	_box(Vector3(2.2, 0.4, 2.2), Vector3(0, 0.2 - SINK, -22.0), concrete)
	_solid(Vector3(2.2, 0.5, 2.2), Vector3(0, 0.25, -22.0))

# Three storeys of classrooms, an open corridor along the front of each with a railing wall,
# square columns, a door and two windows per room.
func _block() -> void:
	var front := -DEPTH + 16.0
	var back := front - 9.0
	var floors := 3
	var bays := 10
	var bay := BLOCK_WIDTH / bays
	var room_wall := front - 2.6
	var body := Node3D.new()
	body.name = "Block"
	add_child(body)
	_box(Vector3(BLOCK_WIDTH, STOREY * floors, room_wall - back), Vector3(0, STOREY * floors / 2 - SINK, (room_wall + back) / 2), plaster, body)
	for f in range(floors + 1):
		var y := f * STOREY - SINK
		_box(Vector3(BLOCK_WIDTH + 0.6, 0.28, front - back + 0.4), Vector3(0, y + 0.14 if f > 0 else y + 0.05, (front + back) / 2), concrete, body)
	# Roof parapet.
	_box(Vector3(BLOCK_WIDTH + 0.6, 0.9, 0.25), Vector3(0, floors * STOREY + 0.6 - SINK, front + 0.1), plaster, body)
	for f in range(floors):
		var base := f * STOREY - SINK
		if f > 0:
			_box(Vector3(BLOCK_WIDTH, 1.0, 0.18), Vector3(0, base + 0.78, front - 0.05), plaster, body)
		for i in range(bays + 1):
			_box(Vector3(0.45, STOREY, 0.45), Vector3(-BLOCK_WIDTH / 2 + i * bay, base + STOREY / 2, front - 0.2), plaster, body)
		for i in range(bays):
			var x := -BLOCK_WIDTH / 2 + (i + 0.5) * bay
			_box(Vector3(1.0, 2.2, 0.08), Vector3(x - bay * 0.32, base + 1.25, room_wall + 0.03), glass, body)
			for w in [-0.02, 0.26]:
				_box(Vector3(1.5, 1.3, 0.06), Vector3(x + bay * w, base + 1.75, room_wall + 0.03), glass, body)
	# A stair tower at each end, a shade taller.
	for side in [-1.0, 1.0]:
		_box(Vector3(5.0, STOREY * floors + 1.6, 9.4), Vector3(side * (BLOCK_WIDTH / 2 + 2.5), (STOREY * floors + 1.6) / 2 - SINK, (front + back) / 2), plaster, body)
	_solid(Vector3(BLOCK_WIDTH + 10.0, STOREY * floors, front - back), Vector3(0, STOREY * floors / 2, (front + back) / 2))
	# Back then: the start-of-year banner hung along the second-floor railing.
	var banner := Node3D.new()
	banner.name = "Banner"
	add_child(banner)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.72, 0.08, 0.07)
	cloth.roughness = 0.9
	_box(Vector3(18.0, 1.1, 0.05), Vector3(0, STOREY + 0.75 - SINK, front + 0.07), cloth, banner)
	var words := Label3D.new()
	words.text = "CHÀO MỪNG NĂM HỌC MỚI"
	words.font = load("res://assets/fonts/Grenze-Variable.ttf")
	words.font_size = 128
	words.pixel_size = 0.006
	words.modulate = Color(1.0, 0.86, 0.3)
	words.outline_size = 0
	words.position = Vector3(0, STOREY + 0.75 - SINK, front + 0.11)
	banner.add_child(words)
	banner.set_meta("anchor", Vector3(0, STOREY + 0.75, front))
	banner.add_to_group("dream_past")
	Camera.put_on_layer(banner, Camera.PAST)
