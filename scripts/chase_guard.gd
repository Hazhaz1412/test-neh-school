extends Node3D

# The pursuer of the scripted chases: the school's night guard, running with his torch up.
# The tunnel drives it through appear / animate / vanish.
var model: Node3D
var face: Node3D
var torch: SpotLight3D
var phase := 0.0
var ferocity := 0.0
var owner_entry = null

func _ready() -> void:
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "guard"
	model.target_height = 1.72
	model.rotation.y = PI
	add_child(model)
	face = model.bone_frame("Head", "GuardHead")
	face.add_child(preload("res://scripts/security_guard.gd").guard_cap())
	var hand: Node3D = model.bone_frame("Fist.R", "GuardTorch")
	hand.add_child(preload("res://scripts/security_guard.gd").torch_mesh())
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.92, 0.75)
	torch.light_energy = 2.4
	torch.spot_range = 14
	torch.spot_angle = 24
	torch.shadow_enabled = false
	torch.position = Vector3(0.25, 1.35, -0.4)
	torch.rotation.x = -0.12
	add_child(torch)
	vanish()

func appear(at: Vector3, observer: Vector3) -> void:
	global_position = at
	if global_position.distance_squared_to(observer) > 0.01: look_at(Vector3(observer.x, at.y, observer.z))
	show()
	torch.show()
	model.animation.play("sprint")
	model.animation.speed_scale = 1.2
	model.set_process(true)

func vanish() -> void:
	hide()
	if torch != null: torch.hide()
	model.animation.speed_scale = 0
	model.set_process(false)

func animate(delta: float, danger: float) -> void:
	phase += delta
	ferocity = danger
	model.head_pitch = 0.05
	# An old man flat out: the faster the clip, the closer he is.
	model.animation.speed_scale = 1.05 + danger * 0.35
	model.hand_target = global_position + Vector3.UP * 1.45 - global_basis.z * 0.9
	torch.rotation.y = sin(phase * 7.0) * 0.08
