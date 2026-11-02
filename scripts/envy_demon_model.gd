extends Node3D
# The Envy demon, built by tools/build_envy_demon.py. It wears the medals it took from the
# students it hated; they knock together as it walks.
const MEDALS := [[-0.15, 0.0], [-0.05, 0.03], [0.05, 0.02], [0.15, 0.0], [-0.11, -0.11], [0.0, -0.12], [0.11, -0.1], [-0.15, -0.23], [-0.05, -0.24], [0.06, -0.23], [0.16, -0.2], [-0.09, -0.36], [0.03, -0.37], [0.12, -0.34], [-0.03, -0.5], [0.07, -0.52]]
var visual: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var medals: Array[Node3D] = []
var sway := 0.0
const GAZE_ARM := [["Bip01 R UpperArm", Vector3(0.0, -1.25, -0.5)], ["Bip01 R Forearm", Vector3(0.0, -0.3, -1.9)], ["Bip01 Head", Vector3(0.0, 0.0, 0.5)], ["Bip01 Spine1", Vector3(0.0, 0.0, 0.2)]]
var gaze := 0.0
var gazing := false
var prize: MeshInstance3D

func _ready() -> void:
	visual = load("res://assets/envy_demon/envy_demon.glb").instantiate()
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	animation = visual.find_children("*", "AnimationPlayer", true, false)[0]
	for title in animation.get_animation_list():
		animation.get_animation(title).loop_mode = Animation.LOOP_LINEAR
	_matte()
	_hang_medals()
	animation.play("idle")
	animation.mixer_applied.connect(_pose_gaze)
# It has to stay black under a torch, so the skin gives back almost no highlight.
func _matte() -> void:
	var body: MeshInstance3D = visual.find_children("*", "MeshInstance3D", true, false)[0]
	for surface in range(body.mesh.get_surface_count()):
		var material: StandardMaterial3D = body.mesh.surface_get_material(surface).duplicate()
		if material.resource_name == "EnvySkin":
			material.metallic_specular = 0.06
			material.roughness = 0.85
		elif material.resource_name == "EnvyEye":
			material.emission_energy_multiplier = 3.5
		body.set_surface_override_material(surface, material)

func move(title: String, pace := 1.0) -> void:
	if animation.current_animation != title:
		animation.play(title, 0.3)
	animation.speed_scale = pace

# Holds what it took up to its face. Layered over whatever clip is playing, so it blends away.
func admire(item: String) -> void:
	gazing = true
	if prize == null:
		var hand := BoneAttachment3D.new()
		hand.bone_name = "Bip01 R Hand"
		skeleton.add_child(hand)
		prize = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.08
		disc.bottom_radius = 0.08
		disc.height = 0.03
		prize.mesh = disc
		var gold := StandardMaterial3D.new()
		gold.metallic = 1.0
		gold.roughness = 0.3
		gold.emission_enabled = true
		gold.emission_energy_multiplier = 0.15
		prize.material_override = gold
		hand.add_child(prize)
		# The rig is authored at a tiny scale, so the medal cancels it out.
		prize.scale = Vector3.ONE / skeleton.global_basis.get_scale().x
	var shade := Color(0.95, 0.72, 0.2) if item == "medal" else Color(0.5, 0.56, 0.62)
	prize.material_override.albedo_color = shade
	prize.material_override.emission = shade
	prize.show()

func stop_admiring() -> void:
	gazing = false
	if prize != null:
		prize.hide()

func _pose_gaze() -> void:
	if gaze <= 0.0:
		return
	for joint in GAZE_ARM:
		var bone := skeleton.find_bone(joint[0])
		if bone >= 0:
			var turn := Quaternion.from_euler(joint[1] * gaze)
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * turn)

func _on_bone(bone_name: String, at: Vector3) -> Node3D:
	var bind := BoneAttachment3D.new()
	bind.bone_name = bone_name
	skeleton.add_child(bind)
	var holder := Node3D.new()
	bind.add_child(holder)
	var rest := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone(bone_name))
	holder.transform = rest.affine_inverse() * Transform3D(global_basis, to_global(at))
	return holder

func _hang_medals() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.46, 0.34, 0.13)
	gold.metallic = 1.0
	gold.roughness = 0.46
	var disc := CylinderMesh.new()
	disc.top_radius = 0.045
	disc.bottom_radius = 0.045
	disc.height = 0.01
	disc.radial_segments = 20
	var cloths := [Color(0.14, 0.015, 0.015), Color(0.02, 0.045, 0.12), Color(0.13, 0.11, 0.03)]
	var neck: Vector3 = to_local(skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Bip01 Neck")).origin)
	for i in range(MEDALS.size()):
		var at := neck + Vector3(MEDALS[i][0], MEDALS[i][1] - 0.22, 0.14)
		var pendulum := Node3D.new()
		_on_bone("Bip01 Spine1" if MEDALS[i][1] < -0.25 else "Bip01 Spine2", at).add_child(pendulum)
		var ribbon := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.028, 0.13, 0.004)
		ribbon.mesh = strip
		ribbon.position.y = 0.06
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = cloths[i % cloths.size()]
		ribbon.material_override = cloth
		pendulum.add_child(ribbon)
		var medal := MeshInstance3D.new()
		medal.mesh = disc
		medal.material_override = gold
		medal.rotation.x = PI * 0.5
		pendulum.add_child(medal)
		medals.append(pendulum)

func _process(delta: float) -> void:
	gaze = move_toward(gaze, 1.0 if gazing else 0.0, delta * 2.5)
	sway += delta * 7.0 * animation.speed_scale
	for i in range(medals.size()):
		medals[i].rotation.z = sin(sway + i * 1.3) * 0.16
		medals[i].rotation.x = cos(sway * 0.5 + i) * 0.1
