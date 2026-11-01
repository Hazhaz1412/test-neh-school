extends CharacterBody3D
# Peter indoors: plain first person with real gravity, because the house has stairs.
const WALK := 3.0
const EYE := 1.6
const SENSITIVITY := 0.0022
var world: Node3D
var yaw := 0.0
var pitch := 0.0
var enabled := true
var scripted_move := Vector2.ZERO
var camera: Camera3D
var steps: AudioStreamPlayer
var step_clock := 0.0

func _ready() -> void:
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.45
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = EYE
	camera.fov = 72.0
	add_child(camera)
	camera.make_current()
	steps = AudioStreamPlayer.new()
	steps.stream = preload("res://scripts/soundscape.gd").variations("step_0", 6)
	steps.volume_db = -22
	add_child(steps)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	var wish := scripted_move
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		wish += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := Vector3(wish.x, 0, wish.y).limit_length().rotated(Vector3.UP, yaw)
	velocity.x = direction.x * WALK
	velocity.z = direction.z * WALK
	velocity.y = -3.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	rotation.y = yaw
	camera.rotation.x = pitch
	if is_on_floor() and direction.length() > 0.2:
		step_clock -= delta
		if step_clock <= 0.0:
			step_clock = 0.52
			steps.play()
