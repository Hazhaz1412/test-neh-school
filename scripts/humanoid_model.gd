extends Node3D

# MIT Rocketbox people, normalised once, behind stable animation names and bone frames.
var variant := "avatar"
var target_height := 1.85
var visual: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var head_pitch := 0.0
var reach := 0.0
var melee_swing := -1.0
var hand_target := Vector3(INF, INF, INF)
var look := "a"
var head_source: Node3D
var body_mesh: MeshInstance3D
static var clip_libraries := {}
# Avatars keep their own textures; students wear repainted uniforms. Clips target a sibling rig.
const STUDENT := "student"
const GUARD := "guard"
const BONES := {"Head": "Head", "UpperArm.R": "R UpperArm", "UpperArm.L": "L UpperArm", "LowerArm.R": "R Forearm", "Fist.R": "R Hand", "Fist.L": "L Hand"}
const MOTIONS := {
	"f": {"idle": "f_idle_neutral_01", "walk": "f_walk_slow_01", "sprint": "f_run_fast_01", "crouch": "f_crouch_idle"},
	"m": {"idle": "m_idle_neutral_01", "walk": "m_walk_slow_01", "sprint": "m_run_fast_01", "crouch": "m_idle_neutral_01"},
	STUDENT: {"idle": "m_idle_neutral_01", "walk": "m_walk_bruised", "sprint": "m_run_injured", "crouch": "m_idle_neutral_01"},
	# The school's night guard: patrol walk, a look round each room, an ear to the door and
	# the paperwork he clears away in 306.
	GUARD: {"idle": "m_idle_neutral_01", "walk": "m_walk_fast_01", "sprint": "m_run_fast_01", "crouch": "m_idle_neutral_01",
		"look_around": "m_idle_look_around_01", "listen": "m_listen_door", "documents": "m_documents_check", "take": "m_documents_take"},
}
const ONE_SHOTS := ["attack-melee-right", "pickup"]

func bone(label: String) -> String:
	return "%s %s" % [skeleton.get_bone_name(0), BONES.get(label, label)]

func _ready() -> void:
	process_priority = 3
	if variant == GUARD: look = "Security_Male_01"
	var folder := "res://assets/rocketbox/" if variant == STUDENT else "res://assets/rocketbox/townsfolk/"
	visual = load(folder + ("Male_Child_01.fbx" if variant == STUDENT else look + ".fbx")).instantiate()
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	body_mesh = visual.find_children("*", "MeshInstance3D", true, false)[0]
	_dress()
	var top := (skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone(bone("Head")))).origin
	var foot := (skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone(skeleton.get_bone_name(0) + " R Foot"))).origin
	var scale_by := target_height / ((top.y - foot.y) * (1.12 if variant == STUDENT else 1.14))
	visual.scale *= scale_by
	visual.position.y = global_position.y - foot.y * scale_by + 0.06
	animation = AnimationPlayer.new()
	visual.add_child(animation)
	var kind: String = variant if variant in [STUDENT, GUARD] else ("f" if look.begins_with("Female") else "m")
	var rig := visual.get_path_to(skeleton)
	var key := "%s|%s|%s" % [kind, rig, skeleton.get_bone_name(0)]
	if not clip_libraries.has(key):
		clip_libraries[key] = _library(kind, rig)
	animation.add_animation_library("", clip_libraries[key])
	animation.play("idle")

func _dress() -> void:
	for surface in range(2):
		var part: String = ["body", "head"][surface]
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.82
		if variant == STUDENT:
			mat.albedo_texture = load("res://assets/rocketbox/textures/student_%s_%s.jpg" % [look, part])
			mat.normal_enabled = true
			mat.normal_texture = load("res://assets/rocketbox/textures/student_%s_normal.jpg" % part)
		else:
			mat.albedo_texture = load("res://assets/rocketbox/townsfolk/textures/%s_%s.jpg" % [look, part])
		body_mesh.set_surface_override_material(surface, mat)
	# The third surface is eyelashes and hair cards; their texture is not shipped.
	if variant != STUDENT and body_mesh.mesh.get_surface_count() > 2:
		var unseen := StandardMaterial3D.new()
		unseen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		unseen.albedo_color = Color(0.03, 0.025, 0.02, 0.0)
		body_mesh.set_surface_override_material(2, unseen)

# Biped clips differ from the avatar only by rig name, so tracks are renamed, not retargeted.
func _library(kind: String, rig: NodePath) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for alias in MOTIONS[kind]:
		library.add_animation(alias, rocketbox_clip(MOTIONS[kind][alias], rig, skeleton))
	library.add_animation("carry", library.get_animation("walk"))
	for alias in ONE_SHOTS:
		var strike: Animation = library.get_animation("idle").duplicate()
		strike.loop_mode = Animation.LOOP_NONE
		strike.length = 0.8
		library.add_animation(alias, strike)
	return library

static func rocketbox_clip(title: String, rig: NodePath, target: Skeleton3D) -> Animation:
	var source: Node = load("res://assets/rocketbox/animations/%s.fbx" % title).instantiate()
	var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var from: Animation = player.get_animation(player.get_animation_list()[0])
	var clip := Animation.new()
	clip.length = from.length
	clip.loop_mode = Animation.LOOP_LINEAR
	var prefix := String(target.get_bone_name(0))
	for track in range(from.get_track_count()):
		var path := from.track_get_path(track)
		var type := from.track_get_type(track)
		if path.get_subname_count() == 0 or type != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(path.get_subname(0)).replace("Bip01", prefix)
		if target.find_bone(bone_name) < 0:
			continue
		var copy := clip.add_track(type)
		clip.track_set_path(copy, NodePath("%s:%s" % [rig, bone_name]))
		for key in range(from.track_get_key_count(track)):
			clip.rotation_track_insert_key(copy, from.track_get_key_time(track, key), from.track_get_key_value(track, key))
	source.free()
	return clip

func bone_frame(bone_name: String, label: String) -> Node3D:
	var bind := BoneAttachment3D.new()
	bind.name = label + "Bone"
	bind.bone_name = bone(bone_name)
	skeleton.add_child(bind)
	var index := skeleton.find_bone(bone(bone_name))
	bind.transform = skeleton.get_bone_global_rest(index)
	var frame := Node3D.new()
	frame.name = label
	# Compensate FBX's units and axes; callers use metres in the model's frame.
	frame.basis = (skeleton.global_basis * skeleton.get_bone_global_rest(index).basis).inverse() * global_basis
	bind.add_child(frame)
	return frame

func _process(_delta: float) -> void:
	if animation.speed_scale == 0:
		return
	if head_pitch != 0:
		var head := skeleton.find_bone(bone("Head"))
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) * Quaternion(Vector3.RIGHT, head_pitch))
	if head_source != null:
		var head := skeleton.find_bone(bone("Head"))
		var tilt := Quaternion(Vector3.FORWARD, head_source.rotation.z) * Quaternion(Vector3.RIGHT, head_source.rotation.x)
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) * tilt)
	if melee_swing >= 0:
		var arm := skeleton.find_bone(bone("UpperArm.R"))
		var elbow := skeleton.find_bone(bone("LowerArm.R"))
		var swing := sin(melee_swing * PI)
		# Biped limbs bend around their local Z.
		skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * Quaternion(Vector3.BACK, (-0.9 + swing * 1.7) * 2.0))
		if elbow >= 0:
			skeleton.set_bone_pose_rotation(elbow, skeleton.get_bone_pose_rotation(elbow) * Quaternion(Vector3.BACK, -0.5 * (1 - melee_swing)))
	if reach > 0:
		var arm := skeleton.find_bone(bone("UpperArm.R"))
		skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * Quaternion(Vector3.BACK, -reach))

	if hand_target.is_finite():
		aim_hand(hand_target)

func aim_hand(goal: Vector3) -> void:
	var arm := skeleton.find_bone(bone("UpperArm.R"))
	var hand := skeleton.find_bone(bone("Fist.R"))
	var arm_pose := skeleton.global_transform * skeleton.get_bone_global_pose(arm)
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	var local_wrist: Vector3 = arm_pose.basis.inverse() * (wrist.origin - arm_pose.origin)
	var local_goal: Vector3 = arm_pose.basis.inverse() * (goal - arm_pose.origin)
	if local_wrist.length_squared() > 0.000001 and local_goal.length_squared() > 0.000001:
		var aim := Quaternion(local_wrist.normalized(), local_goal.normalized())
		skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * aim)
