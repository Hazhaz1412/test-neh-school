"""Thins Poly Haven's jacaranda_tree (CC0, 3.8M faces) into a street tree of about 25k faces.
The file is cut as raw arrays first because Blender alone runs out of memory on it.
blender --background --python tools/build_town_tree.py -- <jacaranda.gltf> <out.glb>"""
import json, os, sys
import bpy
import numpy as np

source, target = sys.argv[-2:]
KEEP_LEAVES = 0.012
LEAF_GROW = 4.0
BRANCH_FACES = 160000
FINAL = {"branches": 5000, "trunk": 3000}
rng = np.random.default_rng(4)
gltf = json.load(open(source))
blob = np.memmap(os.path.join(os.path.dirname(source), gltf["buffers"][0]["uri"]), dtype=np.uint8, mode="r")

def accessor(index, kind, width):
    item = gltf["accessors"][index]
    view = gltf["bufferViews"][item["bufferView"]]
    start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    stride = view.get("byteStride", 0)
    if stride and stride != np.dtype(kind).itemsize * width:
        raw = np.ndarray((item["count"], stride), np.uint8, blob, start)
        return np.array(raw[:, :np.dtype(kind).itemsize * width]).reshape(-1).view(kind).reshape(-1, width)
    return np.array(np.frombuffer(blob, kind, item["count"] * width, start)).reshape(-1, width)

# Each leaf or twig is written as one run of vertices, so a run ends where indices stop touching.
def islands(faces):
    low = faces.min(1)
    high = np.maximum.accumulate(faces.max(1))
    starts = np.flatnonzero(np.r_[True, low[1:] > high[:-1]])
    return starts, np.r_[starts[1:], len(faces)]

def pick(faces, keep):
    return np.concatenate([faces[a:b] for a, b in keep])

def build(name, points, normals, uvs, faces, material):
    used, remap = np.unique(faces, return_inverse=True)
    faces = remap.reshape(-1, 3)
    mesh = bpy.data.meshes.new(name)
    mesh.vertices.add(len(used))
    mesh.vertices.foreach_set("co", np.stack([points[used, 0], -points[used, 2], points[used, 1]], 1).ravel())
    mesh.loops.add(faces.size)
    mesh.loops.foreach_set("vertex_index", faces.ravel())
    mesh.polygons.add(len(faces))
    mesh.polygons.foreach_set("loop_start", np.arange(len(faces)) * 3)
    mesh.update(calc_edges=True)
    layer = mesh.uv_layers.new()
    flipped = uvs[used][faces.ravel()] * [1, -1] + [0, 1]
    layer.uv.foreach_set("vector", flipped.ravel())
    mesh.materials.append(material)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    return body

bpy.ops.wm.read_factory_settings(use_empty=True)
folder = os.path.dirname(source)
for primitive in gltf["meshes"][0]["primitives"]:
    name = gltf["materials"][primitive["material"]]["name"].rsplit("_", 1)[1]
    points = accessor(primitive["attributes"]["POSITION"], "f4", 3).copy()
    normals = None
    uvs = accessor(primitive["attributes"]["TEXCOORD_0"], "f4", 2)
    faces = accessor(primitive["indices"], "u4", 1).reshape(-1, 3)
    starts, ends = islands(faces)
    print(name, "faces", len(faces), "islands", len(starts))
    if name == "leaves":
        chosen = rng.random(len(starts)) < KEEP_LEAVES
        for a, b in zip(starts[chosen], ends[chosen]):
            ids = np.unique(faces[a:b])
            centre = points[ids].mean(0)
            points[ids] = centre + (points[ids] - centre) * LEAF_GROW
        faces = pick(faces, list(zip(starts[chosen], ends[chosen])))
    elif name == "branches":
        size = ends - starts
        order = np.argsort(-size)
        last = np.searchsorted(np.cumsum(size[order]), BRANCH_FACES) + 1
        faces = pick(faces, [(starts[i], ends[i]) for i in order[:last]])
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    node = material.node_tree.nodes["Principled BSDF"]
    picture = material.node_tree.nodes.new("ShaderNodeTexImage")
    picture.image = bpy.data.images.load(f"{folder}/textures/jacaranda_tree_{name}_diff_1k.jpg")
    material.node_tree.links.new(picture.outputs["Color"], node.inputs["Base Color"])
    node.inputs["Roughness"].default_value = 0.85
    body = build(name, points, normals, uvs, faces, material)
    if name in FINAL:
        thin = body.modifiers.new("thin", "DECIMATE")
        thin.ratio = min(1.0, FINAL[name] / len(body.data.polygons))
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_apply(modifier="thin")
    print(name, "kept", len(body.data.polygons), [round(x, 1) for x in body.dimensions])
bpy.ops.export_scene.gltf(filepath=target, export_format="GLB", export_yup=True, export_image_format="JPEG")
