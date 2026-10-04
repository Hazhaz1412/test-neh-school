extends Node3D

# A physical sliding classroom door. Navigation bakes the doorway itself;
# pursuers open the leaf when they reach it instead of passing through it.
@export var start_open := false
@export var room_label := "LỚP HỌC"
@export var slide_distance := 2.05
@export var slide_duration := 0.45
var is_open := false
var slide := 0.0
var proximity_clock := 0.0
@onready var leaf: AnimatableBody3D = $Leaf

func _ready() -> void:
	add_to_group("classroom_doors")
	is_open = start_open and not is_locked()
	slide = 1.0 if is_open else 0.0
	leaf.position.x = slide * slide_distance
	proximity_clock = float(int(get_meta("room_number", 0)) % 5) * 0.04

func doorway_occupied() -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 2.7, 0.8)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform.translated_local(Vector3(0, 1.35, 0))
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
	is_open = value
	return true

func is_locked() -> bool:
	# The service warehouse is the only door usable before acquiring its key.
	var world := get_parent().get_parent()
	var number := int(get_meta("room_number", 0))
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
		if not world.has_master_key:
			world.notify("Chìa tổng · Nhà kho")
		else:
			world.notify("≋ Sân dịch vụ / ↗ Hành lang A")
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
	leaf.position.x = smoothstep(0.0, 1.0, slide) * slide_distance
