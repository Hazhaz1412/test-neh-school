extends Node3D
# A worn bookshelf standing beside a gap in a kiting wall. E tips it over into the gap: students
# vault the fallen shelf, the guard has to drag it out of the way (CLEAR_SECONDS), and if it lands
# on him he is knocked back for a moment. Each shelf falls once.
# Local frame: x runs along the wall, z across it; the shelf stands on the +z (`inward`) side.
enum State { STANDING, DOWN, CLEARED }
const GAP := 1.6
const FALL_SECONDS := 0.4
const CLEAR_SECONDS := 2.8
const STUN_SECONDS := 2.5
const STUN_REACH := 1.4
const DROP_NOISE := 18.0
const SHELF := "res://assets/polyhaven_kiting/wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf"
var world: Node3D
var course: Node3D
var down_size := Vector3.ZERO
var state := State.STANDING
var inward := 1.0
var beside := 1.0
var shelf: Node3D
var standing_body: StaticBody3D
var down_body: StaticBody3D
var stand_at := Transform3D.IDENTITY
var down_at := Transform3D.IDENTITY
var fall := 0.0
var crash: AudioStreamPlayer3D

func build(owner_course: Node3D) -> void:
	course = owner_course
	add_to_group("kiting_pallet")
	shelf = course.fitted(SHELF, 2.0)
	add_child(shelf)
	var size: Vector3 = shelf.get_meta("size")
	# Upright with its back to the wall, just beside the gap.
	stand_at = Transform3D(Basis(Vector3.UP, PI if inward < 0.0 else 0.0), Vector3(beside * (GAP * 0.5 + size.x * 0.5 + 0.05), 0, inward * (0.15 + size.z * 0.5)))
	shelf.transform = stand_at
	standing_body = course.solid(self, stand_at.origin + Vector3(0, 1.0, 0), Vector3(size.x, 2.0, size.z))
	# The fallen shelf's body only exists once it falls, so the baked map keeps the gap open.
	down_size = Vector3(size.y, size.z, size.x)
	crash = AudioStreamPlayer3D.new()
	crash.stream = load("res://assets/audio/floor_thud.wav")
	crash.unit_size = 10.0
	crash.max_distance = 60.0
	crash.position.y = 0.5
	add_child(crash)
	_settle_down_pose(size)

# Lie it flat across the gap, measured from the model's real bounds once turned: its height runs
# along the wall, its width across it, its depth is now its thickness.
func _settle_down_pose(_size: Vector3) -> void:
	var flat := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	var box: AABB = shelf.get_meta("box")
	var low := Vector3(INF, INF, INF)
	var high := -low
	for i in range(8):
		var corner := flat * box.get_endpoint(i)
		low = low.min(corner)
		high = high.max(corner)
	var centre := (low + high) * 0.5
	down_at = Transform3D(flat, Vector3(-centre.x, -low.y, -centre.z))

func is_down() -> bool:
	return state == State.DOWN

func standing() -> bool:
	return state == State.STANDING

func drop(by: Node3D) -> bool:
	if state != State.STANDING:
		return false
	state = State.DOWN
	fall = FALL_SECONDS
	standing_body.process_mode = Node.PROCESS_MODE_DISABLED
	down_body = course.solid(self, Vector3(0, down_size.y * 0.5, 0), down_size)
	crash.play()
	world.emit_noise(global_position, DROP_NOISE, "pallet")
	var guard: Node3D = world.hunt.hunter if world.hunt != null else null
	if guard != null and absf(to_local(guard.global_position).z) < STUN_REACH and absf(to_local(guard.global_position).x) < GAP:
		guard.knock_back(STUN_SECONDS, self)
		if by == world.player:
			world.notify("Kệ đổ trúng bác bảo vệ · Chạy!")
	return true

# The guard drags it aside: the gap is open again, for everyone, for good.
func clear() -> void:
	if state != State.DOWN:
		return
	state = State.CLEARED
	down_body.queue_free()
	crash.pitch_scale = 0.8
	crash.play()
	var aside := Transform3D(down_at.basis, down_at.origin + Vector3(0, 0, inward * 1.2))
	var tween := create_tween()
	tween.tween_property(shelf, "transform", aside, 0.5)

func _process(delta: float) -> void:
	if fall <= 0.0:
		return
	fall = maxf(0.0, fall - delta)
	var t := 1.0 - fall / FALL_SECONDS
	shelf.transform = stand_at.interpolate_with(down_at, t * t)
