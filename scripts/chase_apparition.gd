extends Node3D

var model: Node3D
var face: Node3D
var phase := 0.0
var ferocity := 0.0
static var skin: ShaderMaterial
static var darkness: StandardMaterial3D
static var tooth: StandardMaterial3D

func _ready() -> void:
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "student"
	model.look = "b"
	model.target_height = 2.22
	model.rotation.y = PI
	add_child(model)
	if skin == null:
		skin = ShaderMaterial.new()
		skin.shader = preload("res://assets/materials/ghost_skin.gdshader")
		skin.set_shader_parameter("porcelain", Color(0.62, 0.66, 0.58))
		darkness = StandardMaterial3D.new()
		darkness.albedo_color = Color(0.004, 0.003, 0.006)
		tooth = StandardMaterial3D.new()
		tooth.albedo_color = Color(0.66, 0.57, 0.41)
	face = model.bone_frame("Head", "DistortedHead")
	var hand: Node3D = model.bone_frame("Fist.R", "BloodiedClub")
	var club := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.035
	stick.bottom_radius = 0.045
	stick.height = 1.1
	club.mesh = stick
	club.position.y = 0.4
	var stained := StandardMaterial3D.new()
	stained.albedo_color = Color(0.20, 0.014, 0.009)
	club.material_override = stained
	hand.add_child(club)
	for bone in ["UpperArm.R", "UpperArm.L"]:
		var index: int = model.skeleton.find_bone(model.bone(bone))
		if index >= 0: model.skeleton.set_bone_pose_scale(index, Vector3(1, 1.2, 1))
	vanish()

func oval(at: Vector3, size: Vector3, mat: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 12
	mesh.rings = 8
	part.mesh = mesh
	part.scale = size
	part.position = at
	part.material_override = mat
	face.add_child(part)

func appear(at: Vector3, observer: Vector3) -> void:
	global_position = at
	if global_position.distance_squared_to(observer) > 0.01: look_at(Vector3(observer.x, at.y, observer.z))
	show()
	model.animation.play("sprint")
	model.animation.speed_scale = 2.3
	model.set_process(true)

func vanish() -> void:
	hide()
	model.animation.speed_scale = 0
	model.set_process(false)

func animate(delta: float, danger: float) -> void:
	phase += delta
	ferocity = danger
	model.head_pitch = 0.4
	model.animation.speed_scale = 1.9 + danger * 1.4
	face.rotation.z = sin(phase * 2.3) * 0.28 + sin(phase * 29) * danger * 0.12
	model.rotation.z = sin(phase * 8) * 0.06
