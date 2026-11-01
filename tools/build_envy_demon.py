"""Builds the Envy demon from a Rocketbox avatar. Run: blender --background --python tools/build_envy_demon.py
Joints move but keep their orientation, so Rocketbox motion still fits the longer body."""
import math
import random

import bpy
import bmesh
from mathutils import Quaternion, Vector
from mathutils.geometry import intersect_point_line

SOURCE = "assets/rocketbox/townsfolk/Male_Adult_01.fbx"
CLIPS = {"idle": "m_idle_neutral_01", "stalk": "m_walk_bruised", "walk": "m_walk_slow_01", "rush": "m_run_fast_01"}
OUTPUT = "assets/envy_demon/envy_demon.glb"
GROW = 1.18
SIDES = ("L", "R")
# Offset of a joint from its parent is multiplied by this.
LENGTH = {"Spine1": 1.1, "Spine2": 1.15, "Neck": 1.05, "Head": 1.6}
for side in SIDES:
    LENGTH.update({f"{side} UpperArm": 1.6, f"{side} Forearm": 1.5, f"{side} Hand": 1.75, f"{side} Calf": 1.55, f"{side} Foot": 1.65})
    for finger in range(5):
        LENGTH[f"{side} Finger{finger}"] = 1.6
        LENGTH[f"{side} Finger{finger}1"] = 3.0
THIN = (("Finger", 0.55), ("Hand", 0.5), ("Forearm", 0.4), ("UpperArm", 0.42), ("Clavicle", 0.8), ("Calf", 0.42), ("Thigh", 0.45), ("Foot", 0.95), ("Spine2", 0.72), ("Spine1", 0.58), ("Spine", 0.52), ("Pelvis", 0.55))
AXIS = {"Pelvis": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head"}
for side in SIDES:
    AXIS.update({f"{side} Clavicle": f"{side} UpperArm", f"{side} UpperArm": f"{side} Forearm", f"{side} Forearm": f"{side} Hand", f"{side} Hand": f"{side} Finger2", f"{side} Thigh": f"{side} Calf", f"{side} Calf": f"{side} Foot"})
    for finger in range(5):
        AXIS[f"{side} Finger{finger}"] = f"{side} Finger{finger}1"
random.seed(1984)


def rest_local(rig, name):
    bone = rig.data.bones[name]
    if bone.parent is None:
        return bone.matrix_local.to_quaternion()
    return (bone.parent.matrix_local.inverted() @ bone.matrix_local).to_quaternion()


def retarget(bag, source, target):
    """Blender keys are relative to the clip rig's rest pose, which differs from the avatar's."""
    by_bone = {}
    for curve in bag.fcurves:
        if curve.data_path.endswith("rotation_quaternion"):
            by_bone.setdefault(curve.data_path.split('"')[1], {})[curve.array_index] = curve
    for name, parts in by_bone.items():
        if name not in target.data.bones or name not in source.data.bones or len(parts) != 4:
            continue
        fix = rest_local(target, name).inverted() @ rest_local(source, name)
        for k in range(len(parts[0].keyframe_points)):
            key = Quaternion([parts[i].keyframe_points[k].co[1] for i in range(4)])
            value = fix @ key
            for i in range(4):
                parts[i].keyframe_points[k].co[1] = value[i]
        for curve in parts.values():
            curve.update()


def short(name):
    return name.replace("Bip01 ", "")


def thin_of(name):
    for key, value in THIN:
        if key in name:
            return value
    return 1.25


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SOURCE, ignore_leaf_bones=True)
armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH")
to_world = armature.matrix_world.copy()
forward = (to_world.to_3x3() @ Vector((1, 0, 0))).normalized()
left = (to_world.to_3x3() @ Vector((0, 1, 0))).normalized()
up = Vector((0, 0, 1))

old = {b.name: to_world @ b.head_local for b in armature.data.bones}
new = {}
for bone in armature.data.bones:
    if bone.parent is None:
        new[bone.name] = old[bone.name].copy()
        continue
    factor = LENGTH.get(short(bone.name), 1.0)
    new[bone.name] = new[bone.parent.name] + (old[bone.name] - old[bone.parent.name]) * factor
lowest = min(new[f"Bip01 {s} Foot"].z for s in SIDES)
foot_drop = min((body.matrix_world @ v.co).z for v in body.data.vertices) - min(old[f"Bip01 {s} Foot"].z for s in SIDES)
lift = -(lowest + foot_drop * 1.3)
for name in new:
    new[name] = (new[name] + up * lift) * GROW

# Each vertex follows the bones it is skinned to: along the bone it stretches, across it thins.
inverse = body.matrix_world.inverted()
names = {group.index: group.name for group in body.vertex_groups}
for vertex in body.data.vertices:
    world = body.matrix_world @ vertex.co
    total = Vector((0, 0, 0))
    weight_sum = 0.0
    for link in vertex.groups:
        name = names[link.group]
        if name not in old or link.weight <= 0.0:
            continue
        origin = old[name]
        child = AXIS.get(short(name))
        thin = thin_of(name)
        if child is None:
            mapped = new[name] + (world - origin) * GROW * thin
        else:
            end = old[f"Bip01 {child}"]
            closest, t = intersect_point_line(world, origin, end)
            t = max(0.0, min(1.0, t))
            closest = origin.lerp(end, t)
            mapped = new[name].lerp(new[f"Bip01 {child}"], t) + (world - closest) * GROW * thin
        total += mapped * link.weight
        weight_sum += link.weight
    if weight_sum > 0.0:
        vertex.co = inverse @ (total / weight_sum)

bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
to_local = to_world.inverted()
targets = {b.name: to_local @ new[b.name] for b in armature.data.edit_bones}
for bone in armature.data.edit_bones:
    bone.use_connect = False
for bone in armature.data.edit_bones:
    shift = targets[bone.name] - bone.head
    bone.tail += shift
    bone.head = targets[bone.name]
bpy.ops.object.mode_set(mode="OBJECT")


class Extras:
    def __init__(self):
        self.points = []
        self.faces = []
        self.bones = []
        self.slots = []

    def tube(self, path, radii, bones, slot=0, sides=7, flat=1.0):
        """bones: one name for all rings, or a list of (bone, weight) lists per ring."""
        start = len(self.points)
        for i, centre in enumerate(path):
            along = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
            side = along.cross(up if abs(along.dot(up)) < 0.9 else forward).normalized()
            other = along.cross(side).normalized()
            for n in range(sides):
                angle = n * math.tau / sides
                self.points.append(centre + (side * math.cos(angle) + other * math.sin(angle) * flat) * radii[i])
                self.bones.append(bones if isinstance(bones, str) else bones[i])
        for i in range(len(path) - 1):
            for n in range(sides):
                a = start + i * sides + n
                b = start + i * sides + (n + 1) % sides
                self.faces.append((a, b, b + sides, a + sides))
                self.slots.append(slot)
        top = start + (len(path) - 1) * sides
        self.faces.append(tuple(range(top, top + sides)))
        self.slots.append(slot)

    def spike(self, root, tip, width, bone, slot=0, bend=Vector((0, 0, 0))):
        path = [root.lerp(tip, t) + bend * math.sin(t * math.pi) for t in (0.0, 0.3, 0.65, 1.0)]
        self.tube(path, [width, width * 0.72, width * 0.36, width * 0.02], bone, slot, 6)


extras = Extras()
head = new["Bip01 Head"]
head_top = head + up * 0.42
for sign in (-1, 1):
    base = head_top + left * 0.07 * sign - up * 0.06
    extras.tube([base, base + left * 0.12 * sign + up * 0.14, base + left * 0.2 * sign + up * 0.3, base + left * 0.17 * sign + up * 0.48, base + left * 0.09 * sign + up * 0.62], [0.05, 0.04, 0.03, 0.018, 0.002], "Bip01 Head")
    side = "L" if sign > 0 else "R"
    shoulder = new[f"Bip01 {side} UpperArm"]
    clavicle = new[f"Bip01 {side} Clavicle"]
    for n in range(10):
        t = n / 9.0
        root = clavicle.lerp(shoulder, 0.25 + t * 0.85)
        angle = math.radians(5 + t * 62)
        tip = root + (up * math.cos(angle) + left * sign * math.sin(angle)) * random.uniform(0.34, 0.62) - forward * random.uniform(0.0, 0.2)
        extras.spike(root + up * 0.02, tip, random.uniform(0.05, 0.085), f"Bip01 {side} UpperArm" if t > 0.5 else f"Bip01 {side} Clavicle", 0, left * sign * 0.05)
    for finger in range(5):
        tip_bone = f"Bip01 {side} Finger{finger}1"
        joint = new[tip_bone]
        aim = (joint - new[f"Bip01 {side} Finger{finger}"]).normalized()
        extras.spike(joint + aim * 0.05, joint + aim * 0.3, 0.012, tip_bone, 0, forward * 0.02)
    for n in range(4):
        wrist = new[f"Bip01 {side} Forearm"].lerp(new[f"Bip01 {side} Hand"], n / 4.0 + 0.1)
        extras.spike(wrist, wrist - forward * 0.17 + left * sign * 0.07, 0.016, f"Bip01 {side} Forearm")

# Three eyes in a triangle and a row of teeth.
face = forward * 0.2 * GROW
for offset, radius in ((left * 0.07 + up * 0.14, 0.024), (-left * 0.07 + up * 0.14, 0.024), (up * 0.25, 0.022)):
    centre = head + face + offset + forward * 0.015
    extras.tube([centre - forward * radius, centre - forward * radius * 0.2, centre + forward * radius * 0.5, centre + forward * radius], [0.002, radius, radius * 0.8, 0.002], "Bip01 Head", 1, 8)
for n in range(9):
    across = (n - 4) * 0.018
    root = head + face * 0.96 + left * across * 1.3 + up * 0.01
    extras.spike(root, root - up * random.uniform(0.03, 0.055), 0.008, "Bip01 Head", 2)

# Tail from the base of the spine, with an arrow head near the floor.
pelvis = new["Bip01 Pelvis"]
turn = left * -1
path = [pelvis - forward * (0.14 + 0.2 * n) + turn * 0.008 * n * n + up * (0.1 * math.sin(n * 0.6) - 0.1 * n) for n in range(10)]
extras.tube(path, [0.05 - 0.0048 * n for n in range(10)], "Bip01 Pelvis")
extras.spike(path[-1] + (path[-1] - path[-2]).normalized() * 0.33, path[-1] - (path[-1] - path[-2]).normalized() * 0.04, 0.09, "Bip01 Pelvis")

# Long coat: split by side so the skirt follows each thigh instead of cutting through it.
ankle = new["Bip01 L Foot"].z + 0.55
waist = new["Bip01 Spine1"].z
rings = 13
segments = 24
start = len(extras.points)
for ring in range(rings):
    t = ring / (rings - 1)
    z = waist + (ankle - waist) * t
    radius = 0.17 + 0.09 * t
    for n in range(segments):
        angle = n * math.tau / segments
        side_amount = math.sin(angle)
        point = pelvis.copy()
        point.z = z
        point += left * side_amount * radius + forward * (math.cos(angle) * radius * 0.72 - 0.02)
        extras.points.append(point)
        # Mostly hangs from the waist; the hem only leans with the legs, so it never tears open.
        follow = 0.45 * t
        extras.bones.append([("Bip01 Spine", 1.0 - follow), ("Bip01 L Thigh" if side_amount >= 0.0 else "Bip01 R Thigh", follow)])
for ring in range(rings - 1):
    for n in range(segments):
        a = start + ring * segments + n
        b = start + ring * segments + (n + 1) % segments
        extras.faces.append((b, a, a + segments, b + segments))
        extras.slots.append(0)

mesh = bpy.data.meshes.new("extras")
matrix = body.matrix_world.inverted()
mesh.from_pydata([matrix @ p for p in extras.points], [], extras.faces)
mesh.update()
extra = bpy.data.objects.new("extras", mesh)
bpy.context.collection.objects.link(extra)
extra.matrix_world = body.matrix_world
for bone in armature.data.bones:
    extra.vertex_groups.new(name=bone.name)
for i, binding in enumerate(extras.bones):
    for name, weight in ([(binding, 1.0)] if isinstance(binding, str) else binding):
        if weight > 0.0:
            extra.vertex_groups[name].add([i], weight, "REPLACE")

materials = []
for title, colour, rough, emit in (("EnvySkin", (0.006, 0.006, 0.008, 1), 0.62, 0.0), ("EnvyEye", (0.9, 0.02, 0.02, 1), 0.3, 18.0), ("EnvyTeeth", (0.55, 0.5, 0.4, 1), 0.45, 0.0)):
    material = bpy.data.materials.new(title)
    material.use_nodes = True
    shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = colour
    shader.inputs["Roughness"].default_value = rough
    if emit:
        shader.inputs["Emission Color"].default_value = colour
        shader.inputs["Emission Strength"].default_value = emit
    materials.append(material)
body.data.materials.clear()
extra.data.materials.clear()
for target in (body, extra):
    for material in materials:
        target.data.materials.append(material)
for polygon in body.data.polygons:
    polygon.material_index = 0
for index, polygon in enumerate(extra.data.polygons):
    polygon.material_index = extras.slots[index]

bpy.ops.object.select_all(action="DESELECT")
extra.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = "EnvyDemon"
bm = bmesh.new()
bm.from_mesh(body.data)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(body.data)
bm.free()

armature.animation_data_create()
kept = []
for title, clip in CLIPS.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=f"assets/rocketbox/animations/{clip}.fbx", ignore_leaf_bones=True)
    fresh = set(bpy.data.objects) - before
    # The import also makes near-empty actions for helper objects; the rig's is the largest.
    actions = [o.animation_data.action for o in fresh if o.animation_data and o.animation_data.action]
    action = max(actions, key=lambda a: len(a.layers[0].strips[0].channelbags[0].fcurves))
    action.name = title
    action.use_fake_user = True
    bag = action.layers[0].strips[0].channelbags[0]
    for curve in list(bag.fcurves):
        if "pose.bones" not in curve.data_path or curve.data_path.endswith("location") or curve.data_path.endswith("scale"):
            bag.fcurves.remove(curve)
    retarget(bag, next(o for o in fresh if o.type == "ARMATURE"), armature)
    kept.append(action)
    for item in fresh:
        bpy.data.objects.remove(item)
armature.animation_data.action = kept[0]
armature.animation_data.action_slot = kept[0].slots[0]

for item in list(bpy.data.objects):
    if item.type == "EMPTY":
        bpy.data.objects.remove(item)
for action in list(bpy.data.actions):
    if action not in kept:
        bpy.data.actions.remove(action)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUTPUT, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_skins=True, export_yup=True, export_morph=False)
heights = [(body.matrix_world @ v.co).z for v in body.data.vertices]
print("CLIPS", [(a.name, len(a.layers[0].strips[0].channelbags[0].fcurves)) for a in kept])
print("BUILT height", round(max(heights) - min(heights), 2), "floor", round(min(heights), 2), "verts", len(heights), "actions", [a.name for a in kept])
