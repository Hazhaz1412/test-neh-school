extends Node3D
# Night 1's hunter wears the night guard's body: the same Rocketbox guard, cap and torch as the
# prologue. It keeps the Envy demon's interface (move, admire, stop_admiring) so its AI is unchanged.
const Guard := preload("res://scripts/security_guard.gd")
# Speeds the guard's clips were recorded at, in m/s.
const WALK_PACE := 1.8
const RUN_PACE := 5.0
const RUN_FROM := 4.0
var body: Node3D
var prize: MeshInstance3D
var beam: SpotLight3D
var admiring := false

func _ready() -> void:
	body = preload("res://scripts/humanoid_model.gd").new()
	body.variant = "guard"
	body.target_height = 1.7
	add_child(body)
	body.bone_frame("Head", "GuardHead").add_child(Guard.guard_cap())
	body.bone_frame("Fist.R", "GuardTorch").add_child(Guard.torch_mesh())
	# His torch is what the player sees first down a dark corridor.
	beam = SpotLight3D.new()
	beam.name = "HunterTorch"
	beam.light_color = Color(1.0, 0.92, 0.75)
	beam.light_energy = 3.0
	beam.spot_range = 18.0
	beam.spot_angle = 28.0
	beam.spot_attenuation = 0.8
	beam.shadow_enabled = true
	beam.position = Vector3(-0.22, 1.38, 0.42)
	beam.rotation.y = PI
	beam.rotation.x = -0.12
	add_child(beam)

# The demon asks for "stalk" with pace = speed / 1.5; the guard walks, then breaks into a run.
func move(title: String, pace := 1.0) -> void:
	if body == null or body.animation == null or admiring and title == "idle":
		return
	var clip := "idle"
	var scale_by := 1.0
	if title == "stalk":
		var speed := pace * 1.5
		clip = "sprint" if speed >= RUN_FROM else "walk"
		scale_by = speed / (RUN_PACE if clip == "sprint" else WALK_PACE)
	if body.animation.current_animation != clip:
		body.animation.play(clip, 0.25)
	body.animation.speed_scale = scale_by

# What he took from the player, held up in his left hand.
func admire(item: String) -> void:
	if prize == null:
		prize = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.03, 0.14)
		prize.mesh = box
		prize.material_override = StandardMaterial3D.new()
		body.bone_frame("Fist.L", "GuardPrize").add_child(prize)
	var shade := Color(0.95, 0.72, 0.2) if item == "medal" else Color(0.5, 0.56, 0.62)
	prize.material_override.albedo_color = shade
	prize.show()
	admiring = true
	body.animation.play("documents", 0.3)
	body.animation.speed_scale = 1.0

func stop_admiring() -> void:
	admiring = false
	if prize != null:
		prize.hide()
