extends Node3D
signal toggled(opened: bool)

# A physical hinged classroom door that swings into the room. Navigation bakes
# the doorway itself; pursuers open the leaf when they reach it instead of
# passing through it.
@export var start_open := false
@export var room_label := "LỚP HỌC"
@export var swing_angle := deg_to_rad(100.0)
@export var slide_duration := 0.6
var is_open := false
var slide := 0.0 # How far open the leaf is, 0 shut to 1 fully swung.
var proximity_clock := 0.0
@onready var leaf: AnimatableBody3D = $Leaf

func _ready() -> void:
	add_to_group("classroom_doors")
	is_open = start_open and not is_locked()
	slide = 1.0 if is_open else 0.0
	_pose_leaf()
	proximity_clock = float(int(get_meta("room_number", 0)) % 5) * 0.04

# Put the leaf straight into its open or shut pose, without animating.
func snap(open: bool) -> void:
	is_open = open
	slide = 1.0 if open else 0.0
	_pose_leaf()

func _pose_leaf() -> void:
	leaf.rotation.y = -float(get_meta("swing_side", 1.0)) * smoothstep(0.0, 1.0, slide) * swing_angle

func doorway_occupied() -> bool:
	# Covers the threshold and the quarter circle the leaf sweeps in the room.
	var width: float = get_meta("doorway_width", 1.3)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 2.7, width + 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform.translated_local(Vector3(0, 1.35, float(get_meta("swing_side", 1.0)) * width * 0.5))
	query.collision_mask = 3
	query.exclude = [leaf.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		if hit.collider is CharacterBody3D:
			return true
	return false

func set_open(value: bool) -> bool:
	if value and is_locked():
		return false
	if not value and doorway_occupied():
		return false
	if is_open != value and get_parent().get_parent().get("soundscape") != null:
		get_parent().get_parent().soundscape.at("door", global_position, -18)
	var changed := is_open != value
	is_open = value
	if changed:
		toggled.emit(value)
	return true

func is_locked() -> bool:
	# Story classrooms open in order; the remaining rooms use Lan's key.
	var world := get_parent().get_parent()
	var number := int(get_meta("room_number", 0))
	if world.get("progression") != null and world.progression.room_available(number):
		return false
	return number != 990 and (world.get("has_master_key") != true or world.get("progression") != null and world.progression.door_locked(number))

func interaction_text() -> String:
	if is_locked():
		return "E · Cửa khóa · " + room_label
	return ("E / Đóng cửa · " if is_open else "E / Mở cửa · ") + room_label

func interact(_actor: CharacterBody3D) -> bool:
	var changed := request_toggle()
	if changed:
		get_parent().get_parent().emit_noise(global_position, 9, "door")
	return changed

func request_toggle() -> bool:
	if is_locked():
		get_parent().get_parent().soundscape.cue("lock", -20)
		var world := get_parent().get_parent()
		world.notify("Cửa đóng kín.")
		return false
	return set_open(not is_open)

func _physics_process(delta: float) -> void:
	var world := get_parent().get_parent()
	if not world.has_method("simulation_active") or not world.simulation_active():
		return
	proximity_clock -= delta
	if not is_open:
		if slide > 0.0 and doorway_occupied():
			is_open = true
		if proximity_clock <= 0 and not is_locked():
			proximity_clock = 0.2
			for ghost in world.enemies:
				if is_instance_valid(ghost) and ghost.global_position.distance_squared_to(global_position) < 5.76 and Vector2(ghost.velocity.x, ghost.velocity.z).length_squared() > 0.01:
					set_open(true)
					break
	slide = move_toward(slide, 1.0 if is_open else 0.0, delta / slide_duration)
	_pose_leaf()
