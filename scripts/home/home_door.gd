extends Node3D
# A hinged house door built in code: frame, panelled leaf, handles on both faces, a swing and a
# sound. The leaf is solid, so a shut door really blocks the way.
# Local frame: origin at the hinge on the wall's centre line, +X runs along the opening towards
# the latch, +Z is the side the leaf swings into.
const JAMB := 0.06
const LEAF_THICK := 0.045
const SWING := deg_to_rad(95.0)
const SECONDS := 0.55
const WOOD := Color(0.42, 0.27, 0.17)
const PANEL := Color(0.50, 0.33, 0.21)
const FRAME_PAINT := Color(0.88, 0.86, 0.80)
const BRASS := Color(0.78, 0.64, 0.34)
signal toggled(open: bool)
var width := 0.8
var height := 2.05
var wall_depth := 0.16
var swing_sign := 1.0
var is_open := false
var busy := false
var leaf: AnimatableBody3D
var sound: AudioStreamPlayer3D

# Places a door in the wall opening from `start` to `end` (floor points on the wall's centre
# line), hinged at `start`, swinging towards `into`.
static func fit(start: Vector3, end: Vector3, opening_height: float, depth: float, into: Vector3, open := false) -> Node3D:
	var door: Node3D = load("res://scripts/home/home_door.gd").new()
	var along := (end - start).normalized()
	door.width = start.distance_to(end) - JAMB * 2.0
	door.height = opening_height - JAMB
	door.wall_depth = depth
	var side := along.cross(Vector3.UP)
	door.swing_sign = 1.0 if side.dot(into) > 0.0 else -1.0
	door.transform = Transform3D(Basis(along, Vector3.UP, side), start + along * JAMB)
	door.is_open = open
	return door

func _ready() -> void:
	_frame()
	leaf = AnimatableBody3D.new()
	add_child(leaf)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, LEAF_THICK)
	shape.shape = box
	shape.position = Vector3(width * 0.5, height * 0.5, 0)
	leaf.add_child(shape)
	_box(leaf, Vector3(width * 0.5, height * 0.5, 0), Vector3(width, height, LEAF_THICK), WOOD)
	# Two raised panels on each face read as a real door from across the room.
	for face in [-1.0, 1.0]:
		for row in [[0.30, 0.75], [1.10, 0.75]]:
			var panel_height: float = row[1] * height / 2.05
			var centre_y: float = row[0] * height / 2.05 + panel_height * 0.5
			_box(leaf, Vector3(width * 0.5, centre_y, face * (LEAF_THICK * 0.5 + 0.006)), Vector3(width * 0.66, panel_height, 0.012), PANEL)
		_box(leaf, Vector3(width - 0.09, 1.0, face * (LEAF_THICK * 0.5 + 0.03)), Vector3(0.12, 0.025, 0.025), BRASS)
		_box(leaf, Vector3(width - 0.07, 1.0, face * (LEAF_THICK * 0.5 + 0.012)), Vector3(0.05, 0.12, 0.02), BRASS)
	sound = AudioStreamPlayer3D.new()
	sound.stream = load("res://assets/audio/door.wav")
	sound.volume_db = -6.0
	sound.position = Vector3(width * 0.5, 1.2, 0)
	add_child(sound)
	leaf.rotation.y = _angle(1.0 if is_open else 0.0)

func _frame() -> void:
	var depth := wall_depth + 0.04
	var left := -JAMB * 0.5
	var right := width + JAMB * 0.5
	for x in [left, right]:
		_box(self, Vector3(x, (height + JAMB) * 0.5, 0), Vector3(JAMB, height + JAMB, depth), FRAME_PAINT)
	_box(self, Vector3(width * 0.5, height + JAMB * 0.5, 0), Vector3(width + JAMB * 2.0, JAMB, depth), FRAME_PAINT)

func _box(parent: Node3D, centre: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.35 if colour == BRASS else 0.7
	paint.metallic = 0.8 if colour == BRASS else 0.0
	mesh.material_override = paint
	mesh.position = centre
	parent.add_child(mesh)

func _angle(amount: float) -> float:
	return -swing_sign * amount * SWING

# Where a player reaches for it: the handle height, in the middle of the opening.
func touch_point() -> Vector3:
	return to_global(Vector3(width * 0.5, 1.2, 0))

func set_open(open: bool) -> void:
	if busy or open == is_open:
		return
	busy = true
	is_open = open
	sound.pitch_scale = 1.0 if open else 0.85
	sound.play()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(leaf, "rotation:y", _angle(1.0 if open else 0.0), SECONDS)
	await tween.finished
	busy = false
	toggled.emit(open)

func toggle() -> void:
	set_open(not is_open)
