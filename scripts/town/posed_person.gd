extends Node3D
# A character from a Sketchfab rig with no clips of its own (Bảy Rô, Mười Gió). Rocketbox clips copy
# local rotations, which only works between identical rest poses, so each pose is built by aiming
# bones along directions in this node's space (+Y up, +Z the way they face, like the townsfolk).
# Each rig only needs a table from shared part names to its own bone names.
const RIGS := {
	"valve": {
		"prefix": "ValveBiped_Bip01_", "sides": {"R": "R_", "L": "L_"},
		"parts": {"Pelvis": "Pelvis", "Head": "Head1", "Thigh": "{s}Thigh", "Calf": "{s}Calf", "Foot": "{s}Foot", "Toe": "{s}Toe0",
			"UpperArm": "{s}UpperArm", "Forearm": "{s}Forearm", "Hand": "{s}Hand"},
		# Measured at rest, in the model's units: crown 71.56, head bone 65.44, foot bone 4.31.
		"crown_ratio": (71.56 - 65.44) / (65.44 - 4.31), "sole_ratio": 4.31 / (65.44 - 4.31),
	},
	"mixamo": {
		"prefix": "", "sides": {"R": "Right", "L": "Left"},
		"parts": {"Pelvis": "Hips", "Head": "Head", "Thigh": "{s}UpLeg", "Calf": "{s}Leg", "Foot": "{s}Foot", "Toe": "{s}ToeBase",
			"UpperArm": "{s}Arm", "Forearm": "{s}ForeArm", "Hand": "{s}Hand"},
		# This rig carries bones at the crown and the toe tips, so size is read straight off them.
		"crown": "HeadTop_End", "sole": "{s}Toe_End",
	},
}
const CHARACTERS := {
	"bayro": {"scene": "res://assets/models/characters/3d_rigged_cristiano_ronaldo_al_nassr.glb", "rig": "valve"},
	"muoigio": {"scene": "res://assets/models/characters/model_messi.glb", "rig": "mixamo"},
}
# [part, child part it points at, direction]; x is mirrored per side, so +x means "outward".
const POSES := {
	"sit": [
		["Thigh", "Calf", Vector3(0.12, -0.05, 1.0)],
		["Calf", "Foot", Vector3(0.0, -1.0, 0.12)],
		["UpperArm", "Forearm", Vector3(0.12, -1.0, 0.45)],
		["Forearm", "Hand", Vector3(-0.25, -0.2, 1.0)],
	],
	"stand": [
		["UpperArm", "Forearm", Vector3(0.14, -1.0, 0.0)],
		["Forearm", "Hand", Vector3(0.04, -1.0, 0.18)],
	],
	# Arms folded across the chest: someone waiting where they should not be seen.
	"fold": [
		["UpperArm", "Forearm", Vector3(0.05, -1.0, 0.5)],
		["Forearm", "Hand", Vector3(-1.0, 0.45, 0.12)],
	],
}
var who := "bayro"
var height := 1.75
var motion := "sit"
var visual: Node3D
var skeleton: Skeleton3D
# The dialogue portrait looks for an AnimationPlayer; these poses are static, so there is none.
var animation: AnimationPlayer = null
var rig: Dictionary
var bones := {}
var ankle := 0.0

func _ready() -> void:
	var character: Dictionary = CHARACTERS[who]
	rig = RIGS[character.rig]
	visual = load(character.scene).instantiate()
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	for i in range(skeleton.get_bone_count()):
		# "ValveBiped_Bip01_R_Thigh_045" -> "R_Thigh", "LeftUpLeg_063" -> "LeftUpLeg"
		var short_name := skeleton.get_bone_name(i).trim_prefix(rig.prefix)
		bones[short_name.left(short_name.rfind("_"))] = i
	var ahead := _point(_bone("Toe", "R")) - _point(_bone("Foot", "R"))
	visual.rotate_y(-atan2(ahead.x, ahead.z))
	if rig.has("crown"):
		var sole := minf(_point(rig.sole.format({"s": rig.sides.R})).y, _point(rig.sole.format({"s": rig.sides.L})).y)
		visual.scale *= height / (_point(rig.crown).y - sole)
		sole = minf(_point(rig.sole.format({"s": rig.sides.R})).y, _point(rig.sole.format({"s": rig.sides.L})).y)
		ankle = _point(_bone("Foot", "R")).y - sole
	else:
		var span := _point(_bone("Head")).y - _point(_bone("Foot", "R")).y
		var whole: float = 1.0 + rig.crown_ratio + rig.sole_ratio
		visual.scale *= height / (span * whole)
		ankle = height * rig.sole_ratio / whole
	play(motion)

# The rig's own name for a shared part, on side "R" or "L".
func _bone(part: String, side := "") -> String:
	return String(rig.parts[part]).format({"s": rig.sides.get(side, "")})

func play(title: String) -> void:
	motion = title
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	for entry in POSES.get(title, []):
		for side in ["R", "L"]:
			var outward := signf((_point(_bone("UpperArm", side)) - _point(_bone("Pelvis"))).x)
			var direction: Vector3 = entry[2] * Vector3(outward, 1, 1)
			_aim(_bone(entry[0], side), _bone(entry[1], side), direction)
	# Whatever the pose, the lower foot rests on the ground.
	visual.position.y -= minf(_point(_bone("Foot", "R")).y, _point(_bone("Foot", "L")).y) - ankle

# A bone's current position in this node's space.
func _point(bone_name: String) -> Vector3:
	return to_local(skeleton.global_transform * skeleton.get_bone_global_pose(bones[bone_name]).origin)

# Turns `bone` so the segment towards `child` points along `direction` (this node's space).
func _aim(bone_name: String, child_name: String, direction: Vector3) -> void:
	var bone: int = bones[bone_name]
	var pose := skeleton.get_bone_global_pose(bone)
	var now := (skeleton.get_bone_global_pose(bones[child_name]).origin - pose.origin).normalized()
	var to_skeleton := (skeleton.global_basis.inverse() * global_basis).orthonormalized()
	var wanted := (to_skeleton * direction).normalized()
	var turn := Quaternion(now, wanted)
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local := parent_basis.inverse() * Basis(turn) * pose.basis.orthonormalized()
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
