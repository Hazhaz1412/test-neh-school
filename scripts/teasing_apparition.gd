extends Node3D

# A visual encounter, deliberately without a body, hitbox or combat controller.
var model: Node3D
var face: Node3D

func _ready() -> void:
	name = "LaughingStudent"
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "student"
	model.look = "a"
	model.target_height = 1.72
	model.rotation.y = PI
	add_child(model)
	face = model.bone_frame("Head", "LaughingMask")
	hide()
	set_process(false)
	model.set_process(false)
	model.animation.speed_scale = 0

func appear(at: Vector3, observer: Vector3) -> void:
	global_position = at
	look_at(Vector3(observer.x, at.y, observer.z))
	face.rotation.z = -0.40
	model.reach = 0.8
	model.animation.speed_scale = 0.8
	model.animation.play("idle")
	model.set_process(true)
	show()

func retreat(direction: Vector3) -> void:
	look_at(global_position + direction)
	model.reach = 0
	model.animation.speed_scale = 2.6
	model.animation.play("sprint")

func vanish() -> void:
	hide()
	model.set_process(false)
	model.animation.speed_scale = 0
