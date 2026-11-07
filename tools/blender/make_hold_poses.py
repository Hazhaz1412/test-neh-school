# Builds static "hold" actions for the PSX first-person arms and re-exports the GLB.
#
# Usage (from the project root):
#   blender --background assets/psx-first-person-arms-free-game-assets/arms_rig.orig.blend \
#       --python tools/blender/make_hold_poses.py
#
# Always starts from arms_rig.orig.blend (the untouched download), so running it
# again rebuilds the same actions instead of stacking edits. Writes arms_rig.blend
# (for hand tweaking in Blender) and arms_rig.glb (what the game loads).
import math
import os

import bpy

ASSET_DIR = os.path.join(os.getcwd(), "assets", "psx-first-person-arms-free-game-assets")
RIG = "ArmsRig"
MESH = "ArmsMesh"
# Arm placement and the closed hand come from the pack's knife grip; the left arm
# from a clip that keeps it lowered, out of the first-person view.
RIGHT_SOURCE = "knife_idle"
LEFT_SOURCE = "finger_gun_idle"
FINGERS = ("f_index", "f_middle", "f_ring", "f_pinky")

# Curl is the X rotation of each finger's first joint, in degrees; the rig copies
# it onto the second and third joints, so 75 is the pack's closed knife fist.
# thumb_01 / thumb_02 are (x, y, z) Euler degrees for the two thumb joints.
# Optional "place": move the wrist (the handIK.R target) to `wrist` and turn the
# hand so the knuckle row (pinky to index) runs along `knuckles` and the hand
# points along `fingers`. All in Blender world axes: the rig looks down -Y, +Z
# is up, -X is the player's right, the eye is at z 1.743. The palm then faces
# knuckles x fingers. Point `fingers` along the forearm to keep the wrist straight.
POSES = {
    "hold_torch": {
        # Arm reaching forward from the lower right with a straight wrist, hand
        # upright (thumb on top, palm facing left) and the flashlight lying across
        # the palm from its heel to the thumb web; fingers close round its ~4 cm body.
        "curl": {"f_index": 70, "f_middle": 74, "f_ring": 76, "f_pinky": 78},
        "thumb_01": (3, -1, 0), "thumb_02": (30, 0, 0),
        "place": {"wrist": (-0.27, -0.30, 1.603), "knuckles": (0, -0.75, 1), "fingers": (0.3, -1, -0.75)},
    },
    "hold_camera": {
        # Index rests on the shutter; the others wrap the grip side of the body.
        "curl": {"f_index": 18, "f_middle": 42, "f_ring": 46, "f_pinky": 50},
        "thumb_01": (10, -8, 0), "thumb_02": (12, 0, 0),
    },
    "hold_small": {
        # Pinch between thumb and index; the other fingers tucked into the palm.
        "curl": {"f_index": 40, "f_middle": 78, "f_ring": 82, "f_pinky": 85},
        "thumb_01": (12, -6, 0), "thumb_02": (30, 0, 0),
    },
}


def rotation_path(bone):
    if bone.rotation_mode == "QUATERNION":
        return "rotation_quaternion"
    if bone.rotation_mode == "AXIS_ANGLE":
        return "rotation_axis_angle"
    return "rotation_euler"


def snapshot(rig, action_name):
    """Pose values of every bone at frame 1 of an existing action."""
    rig.animation_data.action = bpy.data.actions[action_name]
    bpy.context.scene.frame_set(1)
    values = {}
    for bone in rig.pose.bones:
        values[bone.name] = (
            bone.location.copy(),
            getattr(bone, rotation_path(bone)).copy(),
            bone.scale.copy(),
        )
    return values


def set_rotation(bone, degrees):
    euler = tuple(math.radians(a) for a in degrees)
    if bone.rotation_mode == "QUATERNION":
        from mathutils import Euler
        bone.rotation_quaternion = Euler(euler, "XYZ").to_quaternion()
    else:
        bone.rotation_euler = euler


def frame_of(first, second):
    """Orthonormal basis whose X follows `first` and Y lies in the first/second plane."""
    from mathutils import Matrix
    x = first.normalized()
    z = x.cross(second).normalized()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def place_hand(rig, wrist, knuckles, fingers):
    from mathutils import Matrix, Vector
    bpy.context.view_layer.update()
    bones = rig.pose.bones
    current = frame_of(bones["f_index.01.R"].head - bones["f_pinky.01.R"].head,
                       bones["f_middle.01.R"].head - bones["hand.R"].head)
    target = frame_of(Vector(knuckles), Vector(fingers))
    turn = (target @ current.transposed()).to_4x4()
    # handIK.R has no parent and sits on the wrist, so its matrix is in the same
    # armature space as the bone heads.
    ik = bones["handIK.R"]
    ik.matrix = Matrix.Translation(Vector(wrist)) @ turn @ Matrix.Translation(-ik.head) @ ik.matrix
    bpy.context.view_layer.update()


def build(rig, name, settings, right, left):
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for bone in rig.pose.bones:
        source = left if bone.name.endswith(".L") else right
        location, rotation, scale = source[bone.name]
        bone.location = location
        setattr(bone, rotation_path(bone), rotation)
        bone.scale = scale
    for finger in FINGERS:
        set_rotation(rig.pose.bones[finger + ".01.R"], (settings["curl"][finger], 0, 0))
    set_rotation(rig.pose.bones["thumb.01.R"], settings["thumb_01"])
    set_rotation(rig.pose.bones["thumb.02.R"], settings["thumb_02"])
    if "place" in settings:
        place = settings["place"]
        place_hand(rig, place["wrist"], place["knuckles"], place["fingers"])
    # Two identical keys give the clip a length, so it loops as a still pose.
    for frame in (1, 2):
        for bone in rig.pose.bones:
            for path in ("location", rotation_path(bone), "scale"):
                bone.keyframe_insert(path, frame=frame, group=bone.name)
    return action


def main():
    rig = bpy.data.objects[RIG]
    mesh = bpy.data.objects[MESH]
    original_action = rig.animation_data.action
    right = snapshot(rig, RIGHT_SOURCE)
    left = snapshot(rig, LEFT_SOURCE)
    for name, settings in POSES.items():
        build(rig, name, settings, right, left)
        print("Built action", name)
    rig.animation_data.action = original_action
    bpy.context.scene.frame_set(1)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET_DIR, "arms_rig.blend"))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in (rig, mesh):
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ASSET_DIR, "arms_rig.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
    )
    print("Exported", os.path.join(ASSET_DIR, "arms_rig.glb"))


main()
