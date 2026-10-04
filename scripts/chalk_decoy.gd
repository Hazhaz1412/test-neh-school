extends CharacterBody3D

var world: Node3D
var lifetime := 0.0
var landed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 5
	add_collision_exception_with(world.player)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.14)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.79, 0.7)
	mesh.material_override = mat
	add_child(mesh)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.04
	collision.shape = sphere
	add_child(collision)

func _physics_process(delta: float) -> void:
	if not world.simulation_active():
		return
	lifetime += delta
	if not landed:
		velocity.y -= 15 * delta
		if move_and_collide(velocity * delta) != null:
			landed = true
			velocity = Vector3.ZERO
			world.emit_noise(global_position, 17, "decoy")
	if lifetime > 6:
		queue_free()
