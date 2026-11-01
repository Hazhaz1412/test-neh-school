extends Node3D
# MIT Rocketbox adult. Clips are rotation only, so walkers stay where the script puts them.
const Humanoid := preload("res://scripts/humanoid_model.gd")
const CLIPS := {"f": {"idle": "f_idle_neutral_01", "walk": "f_walk_slow_01", "talk": "f_gestic_talk_neutral_01", "sit": "f_sit_chair_idle_neutral_01"}, "m": {"idle": "m_idle_neutral_01", "walk": "m_walk_slow_01", "talk": "m_gestic_talk_neutral_01", "sit": "m_sit_chair_idle_neutral_01"}}
const SEAT_DROP := 0.5
const BAR_WIDTH := 0.3
const BAR_HEIGHT := 0.5
const BAR_REACH := 0.62
static var libraries := {}
var look := "Male_Adult_06"
var height := 1.64
var motion := "idle"
var visual: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var standing_y := 0.0

func _ready() -> void:
	visual = load("res://assets/rocketbox/townsfolk/%s.fbx" % look).instantiate()
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	var body: MeshInstance3D = visual.find_children("*", "MeshInstance3D", true, false)[0]
	for surface in range(2):
		var skin := StandardMaterial3D.new()
		skin.albedo_texture = load("res://assets/rocketbox/townsfolk/textures/%s_%s.jpg" % [look, ["body", "head"][surface]])
		skin.roughness = 0.8
		body.set_surface_override_material(surface, skin)
	# The third surface is eyelashes and hair cards; their texture is not shipped.
	var hidden := StandardMaterial3D.new()
	hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hidden.albedo_color = Color(0.03, 0.025, 0.02, 0.0)
	if body.mesh.get_surface_count() > 2:
		body.set_surface_override_material(2, hidden)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var frame := global_transform.affine_inverse() * skeleton.global_transform
	var top: Vector3 = frame * skeleton.get_bone_global_rest(skeleton.find_bone("Bip01 Head")).origin
	var foot: Vector3 = frame * skeleton.get_bone_global_rest(skeleton.find_bone("Bip01 R Foot")).origin
	var scale_by := height / ((top.y - foot.y) * 1.26)
	visual.scale *= scale_by
	standing_y = -foot.y * scale_by + 0.06
	visual.position.y = standing_y
	animation = AnimationPlayer.new()
	visual.add_child(animation)
	var kind := "f" if look.begins_with("Female") else "m"
	var rig := visual.get_path_to(skeleton)
	var key := "%s|%s" % [kind, rig]
	if not libraries.has(key):
		var library := AnimationLibrary.new()
		for alias in CLIPS[kind]:
			library.add_animation(alias, Humanoid.rocketbox_clip(CLIPS[kind][alias], rig, skeleton))
		libraries[key] = library
	animation.add_animation_library("", libraries[key])
	play(motion)

func play(title: String) -> void:
	motion = title
	if animation != null:
		animation.play(title, 0.25)
		animation.seek(randf() * animation.current_animation_length)
		visual.position.y = standing_y - (SEAT_DROP if title == "sit" else 0.0)

# Riders hold one pose, so traffic costs no animation updates at all.
func hold_handlebars() -> void:
	animation.advance(0.01)
	animation.active = false
	_reach("R", Vector3(-BAR_WIDTH, BAR_HEIGHT, BAR_REACH))
	_reach("L", Vector3(BAR_WIDTH, BAR_HEIGHT, BAR_REACH))

func _reach(side: String, goal: Vector3) -> void:
	var arm := skeleton.find_bone("Bip01 %s UpperArm" % side)
	var fore := skeleton.find_bone("Bip01 %s Forearm" % side)
	var hand := skeleton.find_bone("Bip01 %s Hand" % side)
	skeleton.set_bone_pose_rotation(fore, skeleton.get_bone_rest(fore).basis.get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(hand, skeleton.get_bone_rest(hand).basis.get_rotation_quaternion())
	var shoulder := skeleton.global_transform * skeleton.get_bone_global_pose(arm)
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	var from: Vector3 = shoulder.basis.inverse() * (wrist.origin - shoulder.origin)
	var to: Vector3 = shoulder.basis.inverse() * (to_global(goal) - shoulder.origin)
	skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * Quaternion(from.normalized(), to.normalized()))

func set_running(on: bool) -> void:
	if animation != null:
		animation.active = on
		animation.speed_scale = 1.0 if on else 0.0
