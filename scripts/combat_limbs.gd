extends Node3D

# First-person limbs reuse the CC0 investigator mesh, materials and silhouette.
# Extract once; there is no extra animated full-body skeleton on the camera.
static var meshes := {}
var left: MeshInstance3D
var right: MeshInstance3D
var boot: MeshInstance3D

func _ready() -> void:
	if meshes.is_empty():
		var source: Node3D = load("res://assets/quaternius_characters/Casual_Male.fbx").instantiate()
		var body: MeshInstance3D = source.find_child("Body2", true, false)
		var skeleton: Skeleton3D = source.find_child("Skeleton3D", true, false)
		for part in ["left", "right", "boot"]:
			var names = ["LowerLeg.R", "Foot.R"] if part == "boot" else (["LowerArm.L", "Fist.L"] if part == "left" else ["LowerArm.R", "Fist.R"])
			var binds: Array[int] = []
			for i in range(body.skin.get_bind_count()):
				if String(body.skin.get_bind_name(i)) in names:
					binds.append(i)
			var pivot := skeleton.get_bone_global_rest(skeleton.find_bone(names[0])).origin
			var result := ArrayMesh.new()
			for surface in range(body.mesh.get_surface_count()):
				var arrays := body.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				var stride := int(bones.size() / vertices.size())
				var selected: Array[bool] = []
				for v in range(vertices.size()):
					var weight := 0.0
					for slot in range(stride):
						if bones[v * stride + slot] in binds:
							weight += weights[v * stride + slot]
					selected.append(weight > 0.40)
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				var count := 0
				for tri in range(0, indices.size(), 3):
					if not (selected[indices[tri]] and selected[indices[tri + 1]] and selected[indices[tri + 2]]):
						continue
					for v in indices.slice(tri, tri + 3):
						if not colors.is_empty():
							builder.set_color(colors[v])
						var point := vertices[v] - pivot
						point = Vector3(point.x, -point.y, point.z) if part == "boot" else Vector3(point.y, point.z, point.x * (-1 if part == "left" else 1))
						builder.add_vertex(point * 65)
						count += 1
				if count == 0:
					continue
				var material: StandardMaterial3D = body.mesh.surface_get_material(surface).duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.albedo_color = Color(0.12, 0.14, 0.16) if part == "boot" else Color(0.66, 0.51, 0.40)
				material.roughness = 0.95
				material.emission_enabled = true
				material.emission = Color(0.025, 0.032, 0.04) if part == "boot" else Color(0.10, 0.068, 0.045)
				builder.set_material(material)
				builder.generate_normals()
				builder.commit(result)
			meshes[part] = result
		source.free()
	left = _limb("left")
	right = _limb("right")
	boot = _limb("boot")
	hide()

func _limb(part: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part.capitalize()
	node.mesh = meshes[part]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func pose(grip: Vector3, punch: float, kick: float) -> void:
	_segment(left, Vector3(-0.34, -0.40, -0.12), grip)
	_segment(right, Vector3(0.37, -0.34, -0.10), Vector3(0.29, -0.14, -0.35).lerp(Vector3(0.02, -0.02, -1.15), punch))
	boot.visible = kick > 0.01
	_segment(boot, Vector3(0.21, -0.86, -0.10), Vector3(0.08, -0.45, -1.35).lerp(Vector3(0.08, -0.22, -1.55), kick))
	boot.scale *= kick

func _segment(node: Node3D, start: Vector3, end: Vector3) -> void:
	node.position = start
	var direction := end - start
	node.basis = Basis.looking_at(direction, Vector3.UP)
	node.scale.z = direction.length() / 0.45
