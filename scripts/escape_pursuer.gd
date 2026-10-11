extends CharacterBody3D

var world: Node3D
var story: Node3D
var model: Node3D
var agent: NavigationAgent3D
var age := 0.0
var attack_clock := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 1
	add_child(shape)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.8
	add_child(agent)
	model = preload("res://scripts/chase_apparition.gd").new()
	add_child(model)
	model.appear(global_position, world.player.global_position)
	# The visual is local to this moving body.
	model.position = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not world.simulation_active():
		model.model.animation.speed_scale = 0
		return
	age += delta
	attack_clock -= delta
	agent.target_position = world.player.global_position
	var next := agent.get_next_path_position()
	var toward := next - global_position
	toward.y = 0
	velocity = toward.normalized() * (0 if age < 1.4 else 3.45)
	velocity.y = -3
	move_and_slide()
	if toward.length_squared() > 0.01: model.look_at(global_position + toward)
	var separation := global_position.distance_to(world.player.global_position)
	model.animate(delta, clampf(1.0 - separation / 14, 0, 1))
	if separation < 1.65 and attack_clock <= 0:
		var sight := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, world.player.global_position + Vector3.UP, 5)
		if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			world.player.take_damage(25)
			world.player.startle = 1
			attack_clock = 1.1
