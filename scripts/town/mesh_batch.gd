@tool
extends RefCounted
# Collects geometry by map chunk and material, so a whole street is a handful of draw calls.
const CHUNK := 72.0
var sets := {}
var chunk := Vector2i.ZERO

func at(p: Vector3) -> void:
	chunk = Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))

func _arrays(material: String) -> Array:
	var key := [chunk, material]
	if not sets.has(key):
		sets[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedInt32Array()]
	return sets[key]

func quad(material: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color := Color.WHITE, uv := Vector2.ONE) -> void:
	var data := _arrays(material)
	var base: int = data[0].size()
	var normal := (b - a).cross(d - a).normalized()
	data[0].append_array(PackedVector3Array([a, b, c, d]))
	data[1].append_array(PackedVector3Array([normal, normal, normal, normal]))
	data[2].append_array(PackedColorArray([color, color, color, color]))
	data[3].append_array(PackedVector2Array([Vector2(0, uv.y), Vector2(uv.x, uv.y), Vector2(uv.x, 0), Vector2(0, 0)]))
	data[4].append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))

# For surfaces laid out along a path, where the winding depends on the road's direction.
func facing(toward: Vector3, material: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color := Color.WHITE, uv := Vector2.ONE) -> void:
	if (b - a).cross(d - a).dot(toward) < 0.0:
		quad(material, a, d, c, b, color, uv)
	else:
		quad(material, a, b, c, d, color, uv)

# centre and size are in the frame's local space; open_bottom saves faces nobody sees.
func box(material: String, frame: Transform3D, centre: Vector3, size: Vector3, color := Color.WHITE, open_bottom := true) -> void:
	var h := size * 0.5
	var p := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for i in range(8):
		p[i] = frame * (centre + p[i])
	quad(material, p[3], p[2], p[6], p[7], color)
	quad(material, p[1], p[0], p[4], p[5], color)
	quad(material, p[0], p[3], p[7], p[4], color)
	quad(material, p[2], p[1], p[5], p[6], color)
	quad(material, p[7], p[6], p[5], p[4], color)
	if not open_bottom:
		quad(material, p[0], p[1], p[2], p[3], color)

func bake(parent: Node3D, materials: Dictionary, reach: Dictionary) -> int:
	var triangles := 0
	for key in sets:
		var data: Array = sets[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data[0]
		arrays[Mesh.ARRAY_NORMAL] = data[1]
		arrays[Mesh.ARRAY_COLOR] = data[2]
		arrays[Mesh.ARRAY_TEX_UV] = data[3]
		arrays[Mesh.ARRAY_INDEX] = data[4]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, materials[key[1]])
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.name = "%s_%d_%d" % [key[1], key[0].x, key[0].y]
		node.visibility_range_end = reach.get(key[1], 0.0)
		if key[1] in ["cable", "rail"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		triangles += data[4].size() / 3
	sets.clear()
	return triangles
