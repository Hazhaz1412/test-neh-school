"""Exports the CC0 OpenGameArt "Spider 2" blend to glTF, keeping its rig and walk cycle.
blender --background <spider.blend> --python tools/build_spider.py -- <spider.png> <out.glb>"""
import bpy, sys

texture, output = sys.argv[sys.argv.index("--") + 1:]
image = next(i for i in bpy.data.images if i.name == "spider.png")
image.filepath = texture
image.reload()
image.pack()
for thing in list(bpy.data.objects):
    if thing.type in {"CAMERA", "LIGHT"}:
        bpy.data.objects.remove(thing)
armature = bpy.data.objects["Spider_Armature"]
armature.animation_data_create()
armature.animation_data.action = bpy.data.actions["WALK"]
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(filepath=output, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS", export_skins=True, export_image_format="JPEG", export_apply=False)
