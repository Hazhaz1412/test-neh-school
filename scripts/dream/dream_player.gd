extends CharacterBody3D
# The main character in the dream: slow first person, wading through ankle-deep water.
# Every step splashes (wet footstep), starts a ring on the water and bobs the head a little.
# Space jumps. Ledges up to STEP high are walked up without a jump: a board put down a hand's
# width above or below an island's edge used to stop the capsule dead against it.
# Every jump in the dream is light, nearly weightless: low gravity, a long slow hang. Before the
# school gate the air barely carries you sideways (AIR_DRIFT), so no gap of the photo puzzles
# can be jumped. Once the dream goes lucid (past the gate) the jump is higher, the air carries
# you along, and holding Space while coming down floats.
const WALK := 2.3
const LUCID_WALK := 3.2
const GRAVITY := 7.0
const JUMP := 3.6
const AIR_DRIFT := 1.6
const LUCID_GRAVITY := 5.5
const LUCID_JUMP := 5.2
const FLOAT_FALL := 1.1
const STEP := 0.4
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
var lucid := false
# Tests steer with these instead of the keyboard: `drive` is a wish in local axes (x right, y back).
var drive := Vector2.ZERO
var drive_jump := false
var drive_float := false
var jump_buffer := 0.0
var coyote := 0.0
var was_on_floor := true
var dry_steps: AudioStreamPlayer
# Set by a scene with its own ground (the meadow's grass): every step plays this instead.
var ground_steps: AudioStreamPlayer
signal landed(at: Vector3, fall_speed: float)

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
	dry_steps = AudioStreamPlayer.new()
	dry_steps.stream = load("res://assets/audio/footstep.wav")
	dry_steps.volume_db = -22
	dry_steps.pitch_scale = 1.15
	add_child(dry_steps)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		jump_buffer = 0.15
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

func jump() -> void:
	jump_buffer = 0.15

func _physics_process(delta: float) -> void:
	var wish := drive
	var float_held := drive_float
	if drive_jump:
		drive_jump = false
		jump_buffer = 0.15
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and drive == Vector2.ZERO:
		wish = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		float_held = float_held or Input.is_physical_key_pressed(KEY_SPACE)
	if not enabled:
		wish = Vector2.ZERO
		jump_buffer = 0.0
	var direction := Vector3(wish.x, 0, wish.y).limit_length().rotated(Vector3.UP, yaw)
	var on_floor := is_on_floor()
	var walk := LUCID_WALK if lucid else WALK
	# Water drags: speed comes up and dies away softly. In the air there is less to push against.
	var grip := 5.0 if on_floor else (3.0 if lucid else 2.0)
	if not on_floor and not lucid:
		walk = AIR_DRIFT
	velocity.x = move_toward(velocity.x, direction.x * walk, delta * grip)
	velocity.z = move_toward(velocity.z, direction.z * walk, delta * grip)
	coyote = 0.12 if on_floor else maxf(coyote - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	if on_floor:
		velocity.y = 0.0
	else:
		velocity.y -= (LUCID_GRAVITY if lucid else GRAVITY) * delta
		if lucid and float_held and velocity.y < -FLOAT_FALL:
			velocity.y = move_toward(velocity.y, -FLOAT_FALL, delta * 30.0)
		velocity.y = maxf(velocity.y, -14.0)
	if jump_buffer > 0.0 and coyote > 0.0:
		jump_buffer = 0.0
		coyote = 0.0
		velocity.y = LUCID_JUMP if lucid else JUMP
		floor_snap_length = 0.0
		stepped.emit(global_position)
	var fall_speed := -velocity.y
	var before := global_position
	move_and_slide()
	if velocity.y <= 0.0:
		floor_snap_length = 0.3
	if on_floor and is_on_wall() and direction.length() > 0.1:
		_step_up(before, direction)
	var now_on_floor := is_on_floor()
	if now_on_floor and not was_on_floor and fall_speed > 2.0:
		landed.emit(global_position, fall_speed)
		_step_sound()
		step_clock = 0.3
	was_on_floor = now_on_floor
	var speed := Vector2(velocity.x, velocity.z).length()
	bob += delta * speed * 3.2
	if speed > 0.5 and now_on_floor:
		step_clock -= delta
		if step_clock <= 0.0:
			step_clock = 0.62 * WALK / walk
			_step_sound()
			stepped.emit(global_position + direction * 0.3)
	else:
		step_clock = minf(step_clock, 0.15)

# Ankle-deep water splashes; anything standing up out of it (a desk, a book, a cloud) does not.
func _step_sound() -> void:
	if ground_steps != null:
		ground_steps.play()
	elif global_position.y < 0.3:
		steps.play()
	else:
		dry_steps.play()

# Blocked by something low: try the same move from up to STEP higher and settle back down on top.
func _step_up(from: Vector3, direction: Vector3) -> void:
	var start := Transform3D(global_basis, from)
	var up := Vector3.UP * STEP
	if test_move(start, up):
		return
	var raised := start.translated(up)
	var ahead := direction.normalized() * 0.25
	if test_move(raised, ahead):
		return
	var over := raised.translated(ahead)
	var hit := KinematicCollision3D.new()
	if not test_move(over, -up, hit):
		return
	if hit.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return
	global_position = over.origin + hit.get_travel()
	velocity.y = 0.0
	apply_floor_snap()
