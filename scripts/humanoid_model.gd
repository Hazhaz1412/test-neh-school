extends Node3D

# Quaternius CC0 source rigs are left intact. Normalize their source units once,
# then expose stable animation names and bone frames to gameplay/cinematics.
var variant := "Casual_Male"
var target_height := 1.85
var shirt_color := Color(0.18, 0.24, 0.28)
var faceless := false
var visual: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var head_pitch := 0.0
var reach := 0.0
var melee_swing := -1.0
var hand_target := Vector3(INF, INF, INF)
static var faceless_mesh: ArrayMesh
static var animation_libraries := {}
static var proportion_meshes := {}

func _ready() -> void:
	process_priority = 3
	visual = load("res://assets/quaternius_characters/%s.fbx" % variant).instantiate()
	add_child(visual)
	skeleton = visual.find_child("Skeleton3D", true, false)
	animation = visual.find_child("AnimationPlayer", true, false)
	var body: MeshInstance3D = visual.find_child("Body2", true, false)
	if not faceless:
		if not proportion_meshes.has(variant):
			proportion_meshes[variant] = _adjust_head(body)
		body.mesh = proportion_meshes[variant]
	var bound: AABB = (global_transform.affine_inverse() * body.global_transform) * body.mesh.get_aabb()
	var scale_by := target_height / bound.size.y
	visual.scale *= scale_by
	visual.position.y -= bound.position.y * scale_by
	var aliases := {"idle": "Idle", "walk": "Walk", "sprint": "Walk", "attack-melee-right": "Punch", "pickup": "PickUp", "carry": "Walk_Carry"}
	if not animation_libraries.has(variant):
		var library: AnimationLibrary = animation.get_animation_library("").duplicate()
		for alias in aliases:
			for source in animation.get_animation_list():
				if String(source).ends_with("|" + aliases[alias]):
					var clip: Animation = animation.get_animation(source).duplicate()
					clip.loop_mode = Animation.LOOP_LINEAR if alias in ["idle", "walk", "sprint", "carry"] else Animation.LOOP_NONE
					library.add_animation(alias, clip)
					break
		animation_libraries[variant] = library
	animation.remove_animation_library("")
	animation.add_animation_library("", animation_libraries[variant])
	if faceless:
		if faceless_mesh == null:
			faceless_mesh = _without_head(body)
		body.mesh = faceless_mesh
	for surface in range(body.mesh.get_surface_count()):
		var source: StandardMaterial3D = body.mesh.surface_get_material(surface)
		var mat: StandardMaterial3D = source.duplicate()
		mat.roughness = 0.95
		mat.metallic = 0
		if source.resource_name == "Shirt":
			mat.albedo_color = shirt_color
		elif source.resource_name == "Skin":
			mat.albedo_color = Color(0.66, 0.53, 0.42) if not faceless else Color(0.47, 0.45, 0.40)
		elif source.resource_name == "Pants" or source.resource_name == "Black":
			mat.albedo_color = Color(0.06, 0.075, 0.09)
		body.set_surface_override_material(surface, mat)
	animation.play("idle")

func _adjust_head(body: MeshInstance3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	var pivot := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(vertices.size()):
			# Source head/hair are oversized; preserve the rig and round silhouette,
			# but give the investigators a less exaggerated proportion.
			if vertices[i].z > pivot.z - 0.002:
				vertices[i] = pivot + (vertices[i] - pivot) * 0.55
		arrays[Mesh.ARRAY_VERTEX] = vertices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, body.mesh.surface_get_material(surface))
	return result

func _without_head(body: MeshInstance3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	var head_binds: Array[int] = []
	var head_cutoff := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin.z - 0.0015
	for bind in range(body.skin.get_bind_count()):
		var bone := body.skin.get_bind_bone(bind)
		var bone_name := body.skin.get_bind_name(bind)
		if String(bone_name).begins_with("Head") or bone >= 0 and String(skeleton.get_bone_name(bone)).begins_with("Head"):
			head_binds.append(bind)
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var stride := bones.size() / vertices.size()
		var removed: Array[bool] = []
		for v in range(vertices.size()):
			var head_weight := 0.0
			for slot in range(stride):
				var idx := int(v * stride + slot)
				if bones[idx] in head_binds:
					head_weight += weights[idx]
			removed.append(head_weight > 0.45 or vertices[v].z > head_cutoff)
		var filtered := PackedInt32Array()
		for tri in range(0, indices.size(), 3):
			if not removed[indices[tri]] and not removed[indices[tri + 1]] and not removed[indices[tri + 2]]:
				filtered.append_array(indices.slice(tri, tri + 3))
		# Keep surface numbering stable for per-instance materials and Skin bindings.
		if filtered.is_empty():
			filtered = PackedInt32Array([0, 0, 0])
		arrays[Mesh.ARRAY_INDEX] = filtered
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, body.mesh.surface_get_material(surface))
	return result

func bone_frame(bone_name: String, label: String) -> Node3D:
	var bind := BoneAttachment3D.new()
	bind.name = label + "Bone"
	bind.bone_name = bone_name
	skeleton.add_child(bind)
	var index := skeleton.find_bone(bone_name)
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
		var bone := skeleton.find_bone("Head")
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, head_pitch))
	if melee_swing >= 0:
		var arm := skeleton.find_bone("UpperArm.R")
		var elbow := skeleton.find_bone("LowerArm.R")
		var swing := sin(melee_swing * PI)
		skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * Quaternion(Vector3.RIGHT, -0.9 + swing * 1.7))
		if elbow >= 0:
			skeleton.set_bone_pose_rotation(elbow, skeleton.get_bone_pose_rotation(elbow) * Quaternion(Vector3.RIGHT, -0.5 * (1 - melee_swing)))
	if reach > 0:
		var bone := skeleton.find_bone("UpperArm.R")
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, -reach))

	if hand_target.is_finite():
		aim_hand(hand_target)

func aim_hand(goal: Vector3) -> void:
	var arm := skeleton.find_bone("UpperArm.R")
	var hand := skeleton.find_bone("Fist.R")
	var arm_pose := skeleton.global_transform * skeleton.get_bone_global_pose(arm)
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	var local_wrist: Vector3 = arm_pose.basis.inverse() * (wrist.origin - arm_pose.origin)
	var local_goal: Vector3 = arm_pose.basis.inverse() * (goal - arm_pose.origin)
	if local_wrist.length_squared() > 0.000001 and local_goal.length_squared() > 0.000001:
		var aim := Quaternion(local_wrist.normalized(), local_goal.normalized())
		skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * aim)
