extends CharacterBody3D
# Peter on foot or on his scooter. Height comes from the plan, walls from physics, so riding
# never snags on a kerb. The scooter forgives everything: no falls, no damage, no fuel.
enum Mode {WALK, RIDE}
const WALK_SPEED := 3.2
const RUN_SPEED := 6.4
const TOP_SPEED := 15.0
const REVERSE_SPEED := 2.2
const ACCELERATION := 6.5
const BRAKING := 15.0
const COASTING := 2.0
const EYE := 1.58
const MOUNT_REACH := 3.2
const LOOK_SENSITIVITY := 0.0022
const CHASE_DISTANCE := 3.7
const CHASE_HEIGHT := 1.75
var world: Node3D
var mode := Mode.WALK
var heading := 0.0
var look_yaw := 0.0
var look_pitch := -0.05
var speed := 0.0
var steering := 0.0
var lean := 0.0
var free_look := 0.0
var first_person := false
var enabled := true
var scripted := false
var bike: Node3D
var rider: Node3D
var camera: Camera3D
var ray_query: PhysicsRayQueryParameters3D
var step_clock := 0.0
var steps: AudioStreamPlayer
var engine: AudioStreamPlayer
var horn: AudioStreamPlayer

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 72.0
	camera.far = 1100.0
	camera.near = 0.08
	add_child(camera)
	camera.make_current()
	steps = AudioStreamPlayer.new()
	steps.stream = preload("res://scripts/soundscape.gd").variations("step_0", 6)
	steps.volume_db = -20
	add_child(steps)
	engine = AudioStreamPlayer.new()
	engine.stream = load("res://assets/audio/town_engine.wav")
	engine.volume_db = -60
	add_child(engine)
	horn = AudioStreamPlayer.new()
	horn.stream = load("res://assets/audio/town_horn.wav")
	horn.volume_db = -12
	add_child(horn)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func forward() -> Vector3:
	return Vector3(sin(heading), 0, cos(heading)) * -1.0

func riding() -> bool:
	return mode == Mode.RIDE

func can_mount() -> bool:
	return mode == Mode.WALK and global_position.distance_to(bike.global_position) < MOUNT_REACH

func toggle_bike() -> void:
	if riding():
		if speed > 3.0:
			return
		_park()
	elif can_mount():
		mode = Mode.RIDE
		heading = bike.rotation.y
		speed = 0.0
		global_position = Vector3(bike.global_position.x, global_position.y, bike.global_position.z)
		look_yaw = heading
		free_look = 0.0
		rider.visible = true
		engine.play()
		world.hud.hint_once("W ga · S phanh · A/D lái · H còi · F xuống xe · V đổi góc nhìn")

func _park() -> void:
	mode = Mode.WALK
	speed = 0.0
	rider.visible = false
	lean = 0.0
	bike.rotation = Vector3(0, heading, 0)
	engine.stop()
	var side := Vector3(cos(heading), 0, -sin(heading)) * 1.0
	var aside := global_position + side
	if test_move(global_transform, side):
		aside = global_position - side
	global_position = aside
	look_yaw = heading
	look_pitch = -0.05

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if riding() and not first_person:
			free_look = clampf(free_look - event.relative.x * LOOK_SENSITIVITY, -2.6, 2.6)
		else:
			look_yaw -= event.relative.x * LOOK_SENSITIVITY
			look_pitch = clampf(look_pitch - event.relative.y * LOOK_SENSITIVITY, -1.3, 1.3)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				toggle_bike()
			KEY_H:
				if riding():
					horn.play()
			KEY_V:
				if riding():
					first_person = not first_person
					look_yaw = heading
					look_pitch = -0.05
			KEY_E:
				world.interact()

func _physics_process(delta: float) -> void:
	var active := enabled and (scripted or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if riding():
		_ride(delta, active)
	else:
		_walk(delta, active)
	var ground: float = world.plan.ground(Vector2(global_position.x, global_position.z))
	global_position.y = lerpf(global_position.y, ground, 1.0 - exp(-16.0 * delta))
	if riding():
		_pose_bike(delta)

func _walk(delta: float, active: bool) -> void:
	var wish := Vector2.ZERO
	if active:
		wish = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var pace := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	var direction := Vector3(wish.x, 0, wish.y).rotated(Vector3.UP, look_yaw)
	if direction.length() > 1.0:
		direction = direction.normalized()
	velocity = velocity.move_toward(direction * pace, 40.0 * delta)
	move_and_slide()
	if velocity.length() > 0.5:
		step_clock -= delta * velocity.length()
		if step_clock <= 0.0:
			step_clock = 2.1
			steps.play()

func _ride(delta: float, active: bool) -> void:
	var throttle := 0.0
	var turn := 0.0
	if active:
		throttle = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		turn = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
		if Input.is_physical_key_pressed(KEY_SPACE):
			speed = move_toward(speed, 0.0, BRAKING * delta)
			throttle = 0.0
	if throttle > 0.0:
		speed = move_toward(speed, TOP_SPEED, ACCELERATION * (1.0 - 0.6 * maxf(speed, 0.0) / TOP_SPEED) * delta) if speed >= 0.0 else move_toward(speed, 0.0, BRAKING * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -REVERSE_SPEED, BRAKING * delta if speed > 0.0 else 4.0 * delta)
	else:
		speed = move_toward(speed, 0.0, COASTING * delta)
	steering = move_toward(steering, turn, 4.5 * delta)
	var pace := absf(speed) / TOP_SPEED
	# Walking pace still turns, so a nose against a wall can be steered out of with the throttle held.
	var rate: float = lerpf(2.3, 0.95, pace) * clampf(absf(speed) / 2.5, 0.0 if throttle == 0.0 else 0.5, 1.0) * (-1.0 if speed < -0.1 else 1.0)
	heading = wrapf(heading + steering * rate * delta, -PI, PI)
	if turn == 0.0 and speed > 5.0:
		heading = _follow_road(heading, delta)
	velocity = forward() * speed
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var normal := get_slide_collision(i).get_normal()
		var head_on := absf(forward().dot(normal))
		speed *= 1.0 - minf(head_on * head_on * 8.0 * delta * 4.0, 1.0)
		var along := forward().slide(normal)
		if along.length() > 0.05:
			var target := atan2(-along.x, -along.z)
			heading = lerp_angle(heading, target, 1.0 - exp(-5.0 * delta))
	world.traffic.brush(self)
	var target_lean := -steering * pace * 0.42
	lean = lerpf(lean, target_lean, 1.0 - exp(-8.0 * delta))
	engine.pitch_scale = 0.75 + pace * 1.2
	engine.volume_db = lerpf(-20.0, -11.0, pace)

# A soft pull along the street when the player lets go of the bars. Never fights a turn.
func _follow_road(current: float, delta: float) -> float:
	var near: Dictionary = world.plan.nearest(Vector2(global_position.x, global_position.z))
	if near.is_empty():
		return current
	var tangent: Vector2 = world.plan.roads[near.road].tangents[near.at]
	var along := atan2(-tangent.x, -tangent.y)
	if absf(angle_difference(current, along)) > PI * 0.5:
		along = wrapf(along + PI, -PI, PI)
	var gap := absf(angle_difference(current, along))
	if gap > 0.45:
		return current
	return lerp_angle(current, along, 1.0 - exp(-1.6 * delta))

func _pose_bike(delta: float) -> void:
	var ahead := Vector2(global_position.x, global_position.z) + Vector2(forward().x, forward().z)
	var slope: float = atan2(world.plan.ground(ahead) - world.plan.ground(Vector2(global_position.x, global_position.z)), 1.0)
	bike.global_position = global_position
	bike.rotation = Vector3(slope, heading, lean)
	if world.traffic != null and absf(speed) > 1.0:
		free_look = lerpf(free_look, 0.0, 1.0 - exp(-1.2 * delta))

func _process(delta: float) -> void:
	var eye := global_position + Vector3.UP * EYE
	if not riding():
		camera.fov = lerpf(camera.fov, 72.0, 1.0 - exp(-6.0 * delta))
		camera.global_transform = Transform3D(Basis.from_euler(Vector3(look_pitch, look_yaw, 0)), eye)
		return
	var pace := absf(speed) / TOP_SPEED
	camera.fov = lerpf(camera.fov, 72.0 + pace * 12.0, 1.0 - exp(-4.0 * delta))
	if first_person:
		var seat := global_position + Vector3.UP * 1.42 + forward() * 0.12
		var tilt := Basis.from_euler(Vector3(look_pitch, look_yaw + heading - heading, lean * 0.4))
		camera.global_transform = Transform3D(tilt, seat)
		look_yaw = lerp_angle(look_yaw, heading, 1.0 - exp(-3.0 * delta))
		return
	var yaw := heading + free_look
	var behind := Vector3(sin(yaw), 0, cos(yaw))
	var focus := global_position + Vector3.UP * 1.15
	var wanted := focus + behind * CHASE_DISTANCE + Vector3.UP * (CHASE_HEIGHT - 1.15)
	wanted = _clear_view(focus, wanted)
	camera.global_position = camera.global_position.lerp(wanted, 1.0 - exp(-11.0 * delta))
	camera.look_at(focus - behind * 2.6, Vector3.UP)

# Keeps the chase camera out of walls in the alleys.
func _clear_view(from: Vector3, to: Vector3) -> Vector3:
	if ray_query == null:
		ray_query = PhysicsRayQueryParameters3D.create(from, to)
		ray_query.exclude = [get_rid()]
	ray_query.from = from
	ray_query.to = to
	var hit := get_world_3d().direct_space_state.intersect_ray(ray_query)
	return to if hit.is_empty() else hit.position + hit.normal * 0.25
