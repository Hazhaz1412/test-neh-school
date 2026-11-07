extends Node3D

# PSX first-person arms (assets/psx-first-person-arms-free-game-assets). Only the
# right hand comes into view; held_item.gd hangs the selected item from `grip`.
const SOURCE := "res://assets/psx-first-person-arms-free-game-assets/arms_rig.glb"
# Height of the rig's own "camera" bone. The rig faces +Z, the Godot camera looks
# down -Z from its origin, so turn it around and lower it by this much.
const EYE_HEIGHT := 1.743
# Hand that closes around a handle, and a pose that keeps the other arm out of view.
const GRIP_POSE := "knife_idle"
const LOWERED_POSE := "finger_gun_idle"
# Still poses authored by tools/blender/make_hold_poses.py. This one pinches
# between thumb and index; the others close the whole hand.
const PINCH_POSE := "hold_small"
# The pack's finger-gun clips: aim (looping) and a single shot.
const FINGER_GUN_AIM := "finger_gun_idle"
const FINGER_GUN_FIRE := "finger_gun_fire"
# Both palms shoved forward: the pack's one-handed pushes played together.
const PUSH := "push_both"
# Right hand reaching out and closing on something, left arm kept down.
const GRAB := "grab_right"
# Each one-handed push aims at the middle of the screen, so played together the
# palms overlap; swing each arm out from the shoulder to put them side by side.
const PUSH_SPREAD := deg_to_rad(16.0)

var skeleton: Skeleton3D
var animation: AnimationPlayer
var grip: BoneAttachment3D

func _ready() -> void:
	var rig: Node3D = load(SOURCE).instantiate()
	rig.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -EYE_HEIGHT, 0))
	add_child(rig)
	skeleton = rig.find_child("Skeleton3D", true, false)
	animation = rig.find_child("AnimationPlayer", true, false)
	assert(skeleton != null and animation != null, "Arms rig is missing its skeleton or animations")
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var library := animation.get_animation_library("")
	library.add_animation("hold", _one_handed(library.get_animation(GRIP_POSE), library.get_animation(LOWERED_POSE)))
	# The GLB imports every clip as one-shot; the aiming idle has to keep going.
	library.get_animation(FINGER_GUN_AIM).loop_mode = Animation.LOOP_LINEAR
	var push := _one_handed(library.get_animation("push_R"), library.get_animation("push_L"))
	push.loop_mode = Animation.LOOP_NONE
	_swing_out(push, "shoulder.R", -PUSH_SPREAD)
	_swing_out(push, "shoulder.L", PUSH_SPREAD)
	library.add_animation(PUSH, push)
	var grab := _one_handed(library.get_animation("grab_R"), library.get_animation(LOWERED_POSE))
	grab.loop_mode = Animation.LOOP_NONE
	library.add_animation(GRAB, grab)
	animation.play("hold")
	animation.seek(0.0, true)
	grip = BoneAttachment3D.new()
	grip.name = "Grip"
	grip.bone_name = "hand.R"
	skeleton.add_child(grip)

# Right-arm tracks from one clip, left-arm tracks from another.
func _one_handed(right: Animation, left: Animation) -> Animation:
	var result: Animation = right.duplicate(true)
	for track in range(result.get_track_count() - 1, -1, -1):
		if _is_left(result.track_get_path(track)):
			result.remove_track(track)
	for track in range(left.get_track_count()):
		if _is_left(left.track_get_path(track)):
			left.copy_track(track, result)
	result.loop_mode = Animation.LOOP_LINEAR
	return result

# Switch straight to a pose (no blend) so anchor_in() reflects it at once.
# Falls back to the knife grip if the GLB was exported without the hold poses.
func hold(pose: String) -> void:
	if not animation.has_animation(pose):
		pose = "hold"
	animation.play(pose)
	animation.seek(0.0, true)

# Play one of the pack's own clips, blending in from the current pose.
func play_clip(clip: String, blend := 0.12) -> void:
	animation.play(clip, blend)

# Where an item belongs in the current pose: between the fingertips for a pinch,
# otherwise inside the closed hand.
func anchor_in(space: Node3D) -> Vector3:
	if animation.assigned_animation == PINCH_POSE:
		return (bone_transform_in(space, "thumb.03.R").origin + bone_transform_in(space, "f_index.03.R").origin) * 0.5
	return fist_centre_in(space)

# Turn a bone's rotation keys about the rig's vertical axis, which swings
# everything below it (arm, hand) sideways around that joint.
func _swing_out(clip: Animation, bone: String, angle: float) -> void:
	var parent := skeleton.get_bone_parent(skeleton.find_bone(bone))
	var up := skeleton.get_bone_global_rest(parent).basis.inverse() * Vector3.UP
	var turn := Quaternion(up.normalized(), angle)
	for track in range(clip.get_track_count()):
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and String(clip.track_get_path(track).get_concatenated_subnames()) == bone:
			for key in range(clip.track_get_key_count(track)):
				clip.track_set_key_value(track, key, turn * clip.track_get_key_value(track, key))

func _is_left(path: NodePath) -> bool:
	return String(path.get_concatenated_subnames()).ends_with(".L")

# Pose of a bone relative to `space`.
func bone_transform_in(space: Node3D, bone: String) -> Transform3D:
	return space.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))

# Directions for laying a long item in the hand, in `space`: across the palm
# from its heel (pinky side of the wrist) to the index knuckle, the palm normal
# (towards whatever the fingers close on), and the knuckle row (pinky to index).
func grip_axes_in(space: Node3D) -> Array[Vector3]:
	var index := bone_transform_in(space, "f_index.01.R").origin
	var knuckles := index - bone_transform_in(space, "f_pinky.01.R").origin
	var fingers := bone_transform_in(space, "f_middle.01.R").origin - bone_transform_in(space, "hand.R").origin
	var across := index - bone_transform_in(space, "palm.04.R").origin
	return [across.normalized(), knuckles.cross(fingers).normalized(), knuckles.normalized()]

# Centre of the closed fist: between the middle knuckle and the thumb.
func fist_centre_in(space: Node3D) -> Vector3:
	return (bone_transform_in(space, "f_middle.01.R").origin + bone_transform_in(space, "thumb.02.R").origin) * 0.5
