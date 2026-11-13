extends CharacterBody3D
# The main character in the dream: slow first person, wading through ankle-deep water.
# Every step splashes (wet footstep), starts a ring on the water and bobs the head a little.
const WALK := 2.3
const EYE := 1.6
const SENSITIVITY := 0.0022
signal stepped(at: Vector3)
var yaw := 0.0
var pitch := 0.0
var enabled := true
# While a photo is held up the head keeps the tilt the photo was taken at (memory_camera.gd).
var pitch_locked := false
# Eye height is driven by the wake-up rise in dream_world.gd before the player gets control.
var eye := EYE
var camera: Camera3D
var steps: AudioStreamPlayer
var step_clock := 0.0
var bob := 0.0

func _ready() -> void:
	# Stay glued to the floor instead of being pushed into it every tick and popped back out,
	# which read as the view bouncing up and down while walking.
	floor_snap_length = 0.3
	floor_constant_speed = true
	safe_margin = 0.01
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
	camera.far = 1500.0
	add_child(camera)
	camera.make_current()
	steps = AudioStreamPlayer.new()
	var wet := AudioStreamRandomizer.new()
	for i in range(1, 4):
		wet.add_stream(-1, load("res://assets/audio/steps/footstep_wet_0%d.ogg" % i))
	wet.random_pitch = 1.12
	wet.random_volume_offset_db = 2.0
	steps.stream = wet
	steps.volume_db = -14
	add_child(steps)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY
		if not pitch_locked:
			pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.35, 1.35)

# Looking is applied every drawn frame, not every physics tick, so turning stays smooth on
# screens faster than the physics rate. The head sways a little with each step.
func _process(_delta: float) -> void:
	rotation.y = yaw
	camera.rotation.x = pitch
	var speed := Vector2(velocity.x, velocity.z).length()
	camera.position.y = eye + sin(bob) * 0.012 * clampf(speed / WALK, 0, 1)

func _physics_process(delta: float) -> void:
	var wish := Vector2.ZERO
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		wish = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := Vector3(wish.x, 0, wish.y).limit_length().rotated(Vector3.UP, yaw)
	# Water drags: speed comes up and dies away softly.
	velocity.x = move_toward(velocity.x, direction.x * WALK, delta * 5.0)
	velocity.z = move_toward(velocity.z, direction.z * WALK, delta * 5.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	bob += delta * speed * 3.2
	if speed > 0.5:
		step_clock -= delta
		if step_clock <= 0.0:
			step_clock = 0.62
			steps.play()
			stepped.emit(global_position + direction * 0.3)
	else:
		step_clock = 0.15
